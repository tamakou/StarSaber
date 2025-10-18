//
//  BattleImmersiveCoordinator.swift
//  StarSaber
//
//  Created by tamakou on 2025/10/18.
//

import Foundation
import CoreGraphics
import RealityKit

/// Orchestrates the immersive battle scene, keeping RealityKit entities aligned with the game session.
@MainActor
final class BattleImmersiveCoordinator {

    private enum Constants {
        static let arenaRadius: Float = 3.2
        static let enemyElevation: Float = 1.35
        static let saberLength: Float = 1.1
        static let saberRadius: Float = 0.022
    }

    private let gameSession: GameSessionModel
    private(set) var rootAnchor = AnchorEntity(world: .zero)

    private var environmentConfigured = false
    private var saberConfigured = false
    private var saberGlowEntity: ModelEntity?
    private var enemyEntities: [UUID: ModelEntity] = [:]

    init(gameSession: GameSessionModel) {
        self.gameSession = gameSession
    }

    /// Ensures the RealityKit scene graph is ready before rendering frames.
    func prepareSceneIfNeeded() async {
        if !environmentConfigured {
            await setupEnvironment()
            environmentConfigured = true
        }
        if !saberConfigured {
            await setupSaber()
            saberConfigured = true
        }
    }

    func updateScene() {
        syncSaberGlow()
        syncEnemies()
    }

    // MARK: - Setup helpers

    private func setupEnvironment() async {
        let floorMesh = MeshResource.generatePlane(width: 6, depth: 6)
        var floorMaterial = PhysicallyBasedMaterial()
        floorMaterial.baseColor = .init(tint: .init(red: 0.05, green: 0.07, blue: 0.12, alpha: 1))
        floorMaterial.metallic = 0.15
        floorMaterial.roughness = 0.7

        let floorEntity = ModelEntity(mesh: floorMesh, materials: [floorMaterial])
        floorEntity.position = [0, -0.01, 0]
        floorEntity.components.set(InputTargetComponent())

        let keyLight = DirectionalLight()
        keyLight.light.color = .white
        keyLight.light.intensity = 1600
        keyLight.shadow = DirectionalLightComponent.Shadow(maximumDistance: 10, depthBias: 1.2)
        keyLight.look(at: [0, 0, 0], from: [1.5, 2.6, 1.5], relativeTo: nil)

        let fillLight = DirectionalLight()
        fillLight.light.color = .init(red: 0.25, green: 0.4, blue: 0.6, alpha: 1)
        fillLight.light.intensity = 420
        fillLight.look(at: [0, 0, 0], from: [-2.0, 1.9, -2.4], relativeTo: nil)

        rootAnchor.addChild(floorEntity)
        rootAnchor.addChild(keyLight)
        rootAnchor.addChild(fillLight)
    }

    private func setupSaber() async {
        let hiltMesh = MeshResource.generateCylinder(height: 0.22, radius: 0.03)
        var hiltMaterial = PhysicallyBasedMaterial()
        hiltMaterial.baseColor = .init(tint: .init(red: 0.24, green: 0.24, blue: 0.26, alpha: 1))
        hiltMaterial.metallic = 0.8
        hiltMaterial.roughness = 0.25
        let hiltEntity = ModelEntity(mesh: hiltMesh, materials: [hiltMaterial])
        hiltEntity.position = [0, 0.11, 0]

        let bladeMesh = MeshResource.generateCylinder(height: Constants.saberLength, radius: Constants.saberRadius)
        let bladeMaterial = UnlitMaterial(color: .init(red: 0.12, green: 0.6, blue: 1.0, alpha: 0.95))
        let bladeEntity = ModelEntity(mesh: bladeMesh, materials: [bladeMaterial])
        bladeEntity.position = [0, Constants.saberLength / 2 + 0.22, 0]

        let glowMesh = MeshResource.generateCylinder(height: Constants.saberLength, radius: Constants.saberRadius * 1.55)
        let glowMaterial = UnlitMaterial(color: .init(red: 0.1, green: 0.6, blue: 1.0, alpha: 0.18))
        let glowEntity = ModelEntity(mesh: glowMesh, materials: [glowMaterial])
        glowEntity.position = bladeEntity.position
        glowEntity.name = "SaberGlow"

        let saberRoot = Entity()
        saberRoot.name = "PlayerSaber"
        saberRoot.position = [0.45, 1.2, -0.8]
        saberRoot.orientation = simd_quatf(angle: -.pi / 8, axis: [0, 1, 0])
        saberRoot.addChild(hiltEntity)
        saberRoot.addChild(bladeEntity)
        saberRoot.addChild(glowEntity)

        rootAnchor.addChild(saberRoot)
        saberGlowEntity = glowEntity
    }

    // MARK: - Sync

    private func syncSaberGlow() {
        guard let glow = saberGlowEntity else { return }
        let pulse = Float(sin(CFAbsoluteTimeGetCurrent() * 6.0) * 0.15 + 0.5)
        var material = glow.model?.materials.first as? UnlitMaterial ?? UnlitMaterial()
        let alpha = CGFloat(0.12 + Double(pulse) * 0.08)
        material.color = .init(red: 0.1, green: 0.6, blue: 1.0, alpha: alpha)
        glow.model?.materials = [material]
    }

    private func syncEnemies() {
        let liveIDs = Set(gameSession.activeEnemies.map { $0.id })

        for (id, entity) in enemyEntities where !liveIDs.contains(id) {
            entity.removeFromParent()
            enemyEntities.removeValue(forKey: id)
        }

        for (index, enemyState) in gameSession.activeEnemies.enumerated() {
            let entity: ModelEntity
            if let existing = enemyEntities[enemyState.id] {
                entity = existing
            } else {
                entity = makeEnemyEntity()
                enemyEntities[enemyState.id] = entity
                rootAnchor.addChild(entity)
            }

            let angle = Float(index) / max(1, Float(gameSession.activeEnemies.count)) * (.pi * 2)
            let radius = Constants.arenaRadius
            entity.position = [sin(angle) * radius, Constants.enemyElevation, cos(angle) * radius]

            let healthRatio = max(0.35, enemyState.healthRatio)
            entity.scale = [healthRatio, healthRatio, healthRatio]

            let warning = enemyState.aiState == .telegraphing || enemyState.aiState == .attacking
            entity.model?.materials = [enemyMaterial(warning: warning)]
        }
    }

    private func makeEnemyEntity() -> ModelEntity {
        let bodyMesh = MeshResource.generateSphere(radius: 0.28)
        let entity = ModelEntity(mesh: bodyMesh, materials: [enemyMaterial(warning: false)])
        entity.name = "Enemy"
        return entity
    }

    private func enemyMaterial(warning: Bool) -> UnlitMaterial {
        if warning {
            return UnlitMaterial(color: .init(red: 1.0, green: 0.35, blue: 0.2, alpha: 0.9))
        } else {
            return UnlitMaterial(color: .init(red: 0.65, green: 0.75, blue: 0.95, alpha: 0.9))
        }
    }
}
