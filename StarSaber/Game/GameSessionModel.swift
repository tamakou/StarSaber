//
//  GameSessionModel.swift
//  StarSaber
//
//  Created by tamakou on 2025/10/18.
//

import Foundation
import Observation

@MainActor
@Observable
final class GameSessionModel {

    enum Phase {
        case idle
        case tutorial
        case waveInProgress
        case victory
        case defeat
        case results
        case restartPending
    }

    enum CombatLogEntry: Hashable {
        case waveStarted(Int)
        case enemySpawned(UUID)
        case enemyDefeated(UUID)
        case playerTookDamage(Float)
        case playerDefeated
        case forcePushTriggered
        case parrySuccess(UUID)
        case waveCleared(Int)
    }

    struct PlayerState: Sendable {
        var health: Float
        let maxHealth: Float
        var score: Int
        var forceCooldown: Duration
        var forceCooldownRemaining: Duration = .zero

        var healthRatio: Float { max(0, min(1, health / maxHealth)) }
        var isForceReady: Bool { forceCooldownRemaining <= .zero }
    }

    struct EnemyState: Identifiable, Hashable {
        enum AIState: Hashable {
            case idle
            case telegraphing
            case attacking
            case recovering
            case stunned
        }

        let id: UUID
        var health: Float
        var maxHealth: Float
        var aiState: AIState
        var stateDeadline: Date
        var stunTimeout: Date?

        var healthRatio: Float { max(0, min(1, health / maxHealth)) }
        var isAlive: Bool { health > 0 }
    }

    struct WaveState {
        var index: Int
        var totalEnemies: Int
        var defeatedEnemies: Int

        var remainingEnemies: Int { max(0, totalEnemies - defeatedEnemies) }
        var progressRatio: Float {
            guard totalEnemies > 0 else { return 0 }
            return Float(defeatedEnemies) / Float(totalEnemies)
        }
    }

    private(set) var phase: Phase = .idle
    private(set) var player: PlayerState
    private(set) var wave: WaveState?
    private(set) var activeEnemies: [EnemyState] = []
    private(set) var combatLog: [CombatLogEntry] = []

    let config: GameConfig

    private var scheduledTasks: [Task<Void, Never>] = []
    private var enemyAttackLoops: [UUID: Task<Void, Never>] = [:]
    private var forceCooldownMonitor: Task<Void, Never>?
    private var spawnedEnemies: Int = 0

    init(config: GameConfig = GameConfigLoader.load()) {
        self.config = config
        self.player = PlayerState(
            health: config.player.maxHealth,
            maxHealth: config.player.maxHealth,
            score: 0,
            forceCooldown: config.player.forceCooldown
        )
    }

    // MARK: - Session Lifecycle

    func beginSession() {
        resetSession()
        transition(to: .tutorial)
    }

    func startWave() {
        guard phase == .tutorial || phase == .idle || phase == .restartPending else { return }
        transition(to: .waveInProgress)
        wave = WaveState(index: (wave?.index ?? 0) + 1,
                         totalEnemies: config.openingWave.enemyCount,
                         defeatedEnemies: 0)
        spawnedEnemies = 0
        enqueue(event: .waveStarted(wave?.index ?? 1))
        spawnWaveEnemies()
    }

    func restartSession() {
        resetSession()
        transition(to: .tutorial)
    }

    private func resetSession() {
        cancelAllTasks()
        player.health = config.player.maxHealth
        player.score = 0
        player.forceCooldownRemaining = .zero
        wave = nil
        activeEnemies = []
        combatLog.removeAll(keepingCapacity: true)
        spawnedEnemies = 0
        transition(to: .idle)
    }

    private func transition(to newPhase: Phase) {
        phase = newPhase
    }

    // MARK: - Enemy Lifecycle

    private func spawnWaveEnemies() {
        guard let wave else { return }
        let total = wave.totalEnemies
        let spawnInterval = config.openingWave.spawnInterval

        for index in 0..<total {
            let task = Task { [weak self] in
                guard let self else { return }
                let delay = spawnInterval.multiplied(by: index)
                if delay > .zero {
                    try? await Task.sleep(for: delay)
                }
                await self.spawnEnemyIfPossible()
            }
            scheduledTasks.append(task)
        }
    }

    private func spawnEnemyIfPossible() {
        guard phase == .waveInProgress else { return }
        guard let currentWave = wave else { return }
        guard spawnedEnemies < currentWave.totalEnemies else { return }
        guard activeEnemies.count < config.basicEnemy.maxCount else { return }

        let enemyID = UUID()
        let enemy = EnemyState(
            id: enemyID,
            health: config.basicEnemy.maxHealth,
            maxHealth: config.basicEnemy.maxHealth,
            aiState: .idle,
            stateDeadline: Date().addingTimeInterval(config.basicEnemy.attackInterval.timeInterval),
            stunTimeout: nil
        )

        activeEnemies.append(enemy)
        spawnedEnemies += 1
        enqueue(event: .enemySpawned(enemyID))
        scheduleEnemyAttackLoop(for: enemyID)
    }

    private func scheduleEnemyAttackLoop(for enemyID: UUID) {
        let loop = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(120))
                await self.advanceEnemyState(enemyID: enemyID)
            }
        }
        enemyAttackLoops[enemyID] = loop
    }

    private func advanceEnemyState(enemyID: UUID) {
        guard phase == .waveInProgress else { return }
        guard let index = activeEnemies.firstIndex(where: { $0.id == enemyID }) else { return }
        var enemy = activeEnemies[index]
        guard enemy.isAlive else {
            tearDownEnemy(enemyID: enemyID)
            return
        }

        let now = Date()

        if enemy.aiState == .stunned, let timeout = enemy.stunTimeout, now >= timeout {
            enemy.stunTimeout = nil
            enemy.aiState = .recovering
            enemy.stateDeadline = now.addingTimeInterval(0.8)
        }

        switch enemy.aiState {
            case .idle:
                if now >= enemy.stateDeadline {
                    enemy.aiState = .telegraphing
                    enemy.stateDeadline = now.addingTimeInterval(config.basicEnemy.telegraphDuration.timeInterval)
                }

            case .telegraphing:
                if now >= enemy.stateDeadline {
                    enemy.aiState = .attacking
                    enemy.stateDeadline = now.addingTimeInterval(0.35)
                }

            case .attacking:
                if now >= enemy.stateDeadline {
                    applyDamageToPlayer(config.basicEnemy.attackDamage)
                    enemy.aiState = .recovering
                    enemy.stateDeadline = now.addingTimeInterval(config.basicEnemy.attackInterval.timeInterval)
                }

            case .recovering:
                if now >= enemy.stateDeadline {
                    enemy.aiState = .idle
                    enemy.stateDeadline = now.addingTimeInterval(config.basicEnemy.attackInterval.timeInterval)
                }

            case .stunned:
                break
        }

        activeEnemies[index] = enemy
    }

    func applyDamageToEnemy(enemyID: UUID, amount: Float) {
        guard phase == .waveInProgress else { return }
        guard let index = activeEnemies.firstIndex(where: { $0.id == enemyID }) else { return }
        var enemy = activeEnemies[index]
        guard enemy.isAlive else { return }

        enemy.health = max(0, enemy.health - amount)
        activeEnemies[index] = enemy

        if enemy.health == 0 {
            handleEnemyDefeated(enemyID: enemyID)
        }
    }

    private func handleEnemyDefeated(enemyID: UUID) {
        enqueue(event: .enemyDefeated(enemyID))
        player.score += 100
        wave?.defeatedEnemies += 1
        tearDownEnemy(enemyID: enemyID)

        guard let wave else { return }
        if wave.defeatedEnemies >= wave.totalEnemies {
            enqueue(event: .waveCleared(wave.index))
            transition(to: .victory)
            transition(to: .results)
        }
    }

    func registerParrySuccess(enemyID: UUID) {
        guard let index = activeEnemies.firstIndex(where: { $0.id == enemyID }) else { return }
        var enemy = activeEnemies[index]
        enemy.aiState = .stunned
        let timeout = Date().addingTimeInterval(config.basicEnemy.stunDuration.timeInterval)
        enemy.stunTimeout = timeout
        enemy.stateDeadline = timeout
        activeEnemies[index] = enemy
        enqueue(event: .parrySuccess(enemyID))
        player.score += 35
    }

    private func tearDownEnemy(enemyID: UUID) {
        activeEnemies.removeAll { $0.id == enemyID }
        enemyAttackLoops.removeValue(forKey: enemyID)?.cancel()
    }

    // MARK: - Player Damage / Defeat

    func applyDamageToPlayer(_ amount: Float) {
        guard phase == .waveInProgress else { return }
        player.health = max(0, player.health - amount)
        enqueue(event: .playerTookDamage(amount))
        if player.health == 0 {
            enqueue(event: .playerDefeated)
            transition(to: .defeat)
            transition(to: .results)
        }
    }

    // MARK: - Force Ability

    func canTriggerForcePush() -> Bool {
        player.isForceReady && phase == .waveInProgress
    }

    func triggerForcePush() {
        guard canTriggerForcePush() else { return }
        enqueue(event: .forcePushTriggered)
        player.forceCooldownRemaining = config.player.forceCooldown
        forceCooldownMonitor?.cancel()
        forceCooldownMonitor = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled && self.player.forceCooldownRemaining > .zero {
                try? await Task.sleep(for: .milliseconds(100))
                await self.tickForceCooldown()
            }
        }

        let stunTimeout = Date().addingTimeInterval(config.basicEnemy.stunDuration.timeInterval)
        for index in activeEnemies.indices {
            activeEnemies[index].aiState = .stunned
            activeEnemies[index].stunTimeout = stunTimeout
            activeEnemies[index].stateDeadline = stunTimeout
        }
    }

    private func tickForceCooldown() {
        guard player.forceCooldownRemaining > .zero else { return }
        player.forceCooldownRemaining = max(.zero, player.forceCooldownRemaining - .milliseconds(100))
    }

    func resetForceCooldown() {
        player.forceCooldownRemaining = .zero
    }

    // MARK: - Logging helpers

    private func enqueue(event: CombatLogEntry) {
        combatLog.append(event)
        if combatLog.count > 32 {
            combatLog.removeFirst(combatLog.count - 32)
        }
    }

    // MARK: - Cleanup

    private func cancelAllTasks() {
        scheduledTasks.forEach { $0.cancel() }
        scheduledTasks.removeAll(keepingCapacity: true)
        enemyAttackLoops.values.forEach { $0.cancel() }
        enemyAttackLoops.removeAll(keepingCapacity: true)
        forceCooldownMonitor?.cancel()
        forceCooldownMonitor = nil
    }

    deinit {
        cancelAllTasks()
    }
}

