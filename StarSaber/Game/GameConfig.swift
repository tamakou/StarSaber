//
//  GameConfig.swift
//  StarSaber
//
//  Created by tamakou on 2025/10/18.
//

import Foundation

/// Immutable configuration describing gameplay tuning values.
struct GameConfig: Sendable {
    struct Player: Sendable {
        var maxHealth: Float
        var saberDamage: Float
        var forceCooldown: Duration
        var forcePushImpulse: Float
        var parryAngleThreshold: Float
    }

    struct Enemy: Sendable {
        var maxCount: Int
        var maxHealth: Float
        var attackDamage: Float
        var attackInterval: Duration
        var telegraphDuration: Duration
        var stunDuration: Duration
        var knockbackImpulse: Float
    }

    struct Wave: Sendable {
        var enemyCount: Int
        var spawnInterval: Duration
    }

    let player: Player
    let basicEnemy: Enemy
    let openingWave: Wave
}

extension GameConfig {
    static let `default` = GameConfig(
        player: .init(
            maxHealth: 100,
            saberDamage: 25,
            forceCooldown: .seconds(8),
            forcePushImpulse: 6.5,
            parryAngleThreshold: .pi / 4.0
        ),
        basicEnemy: .init(
            maxCount: 3,
            maxHealth: 60,
            attackDamage: 15,
            attackInterval: .seconds(5),
            telegraphDuration: .seconds(1.2),
            stunDuration: .seconds(2.5),
            knockbackImpulse: 4.5
        ),
        openingWave: .init(
            enemyCount: 3,
            spawnInterval: .seconds(2)
        )
    )
}

/// Loads `GameConfig` from bundled JSON if present, otherwise falls back to defaults.
enum GameConfigLoader {

    struct RawConfig: Codable {
        struct Player: Codable {
            var maxHealth: Float
            var saberDamage: Float
            var forceCooldownSeconds: Double
            var forcePushImpulse: Float
            var parryAngleDegrees: Double
        }

        struct Enemy: Codable {
            var maxCount: Int
            var maxHealth: Float
            var attackDamage: Float
            var attackIntervalSeconds: Double
            var telegraphDurationSeconds: Double
            var stunDurationSeconds: Double
            var knockbackImpulse: Float
        }

        struct Wave: Codable {
            var enemyCount: Int
            var spawnIntervalSeconds: Double
        }

        var player: Player
        var basicEnemy: Enemy
        var openingWave: Wave
    }

    static func load() -> GameConfig {
        guard let url = Bundle.main.url(forResource: "GameBalance", withExtension: "json") else {
            return .default
        }

        do {
            let data = try Data(contentsOf: url)
            let raw = try JSONDecoder().decode(RawConfig.self, from: data)
            return GameConfig(
                player: .init(
                    maxHealth: raw.player.maxHealth,
                    saberDamage: raw.player.saberDamage,
                    forceCooldown: .seconds(raw.player.forceCooldownSeconds),
                    forcePushImpulse: raw.player.forcePushImpulse,
                    parryAngleThreshold: Float(raw.player.parryAngleDegrees * .pi / 180.0)
                ),
                basicEnemy: .init(
                    maxCount: raw.basicEnemy.maxCount,
                    maxHealth: raw.basicEnemy.maxHealth,
                    attackDamage: raw.basicEnemy.attackDamage,
                    attackInterval: .seconds(raw.basicEnemy.attackIntervalSeconds),
                    telegraphDuration: .seconds(raw.basicEnemy.telegraphDurationSeconds),
                    stunDuration: .seconds(raw.basicEnemy.stunDurationSeconds),
                    knockbackImpulse: raw.basicEnemy.knockbackImpulse
                ),
                openingWave: .init(
                    enemyCount: raw.openingWave.enemyCount,
                    spawnInterval: .seconds(raw.openingWave.spawnIntervalSeconds)
                )
            )
        } catch {
            assertionFailure("Failed to parse GameBalance.json: \(error)")
            return .default
        }
    }
}
