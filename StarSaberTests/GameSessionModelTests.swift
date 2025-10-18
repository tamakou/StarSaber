//
//  GameSessionModelTests.swift
//  StarSaberTests
//
//  Created by tamakou on 2025/10/18.
//

import Testing
@testable import StarSaber

struct GameSessionModelTests {

    private var fastConfig: GameConfig {
        GameConfig(
            player: .init(
                maxHealth: 100,
                saberDamage: 60,
                forceCooldown: .seconds(2),
                forcePushImpulse: 5,
                parryAngleThreshold: .pi / 4
            ),
            basicEnemy: .init(
                maxCount: 2,
                maxHealth: 60,
                attackDamage: 5,
                attackInterval: .seconds(0.8),
                telegraphDuration: .seconds(0.2),
                stunDuration: .seconds(0.4),
                knockbackImpulse: 3
            ),
            openingWave: .init(
                enemyCount: 1,
                spawnInterval: .milliseconds(50)
            )
        )
    }

    @Test("Force push enters cooldown and recovers over time")
    func forcePushCooldown() async throws {
        let session = GameSessionModel(config: fastConfig)
        session.beginSession()
        session.startWave()

        session.triggerForcePush()
        #expect(session.player.forceCooldownRemaining == fastConfig.player.forceCooldown)

        try await Task.sleep(for: .milliseconds(150))
        #expect(session.player.forceCooldownRemaining < fastConfig.player.forceCooldown)
    }

    @Test("Defeating an enemy increases score and wave progress")
    func defeatingEnemyAwardsScore() async throws {
        let session = GameSessionModel(config: fastConfig)
        session.beginSession()
        session.startWave()

        try await Task.sleep(for: .milliseconds(120))
        guard let enemyID = session.activeEnemies.first?.id else {
            Issue.record("Enemy did not spawn in time")
            return
        }

        session.applyDamageToEnemy(enemyID: enemyID, amount: fastConfig.basicEnemy.maxHealth)
        try await Task.sleep(for: .milliseconds(50))

        #expect(session.player.score == 100)
        #expect(session.wave?.defeatedEnemies == 1)
        #expect(session.phase == .results || session.phase == .victory)
    }
}
