//
//  BattleImmersiveCoordinator.swift
//  StarSaber
//
//  Created by tamakou on 2025/10/18.
//

import Foundation
import RealityKit

/// Orchestrates the immersive battle scene, keeping RealityKit entities aligned with the game session.
@MainActor
final class BattleImmersiveCoordinator {

    private enum Constants {
        static let arenaRadius: Float = 3.5
        static let enemyElevation: Float = 1.4
        static let saberLength: Float = 1.1
        static let saberRadius: Float = 0.022
    }

    private let gameSession: GameSessionModel
    private let rootAnchor = AnchorEntity(world: .zero)
    private var environmentEntity = Entity()
    private var saberEntity = Entity()
    private var saberGlowEntity: ModelEntity?
    private var enemyEntities: [UUID: ModelEntity] = [:]

    init(gameSession: GameSessionModel) {
        self.gameSession = gameSession
    }

    func configureScene(on content: RealityViewContent) async {
        if rootAnchor.parent == nil {
            content.add(rootAnchor)
        }

        await setupEnvironment()
        await setupSaber()
    }

    func updateScene(deltaTime _: TimeInterval) {
        syncSaberGlow()
        syncEnemies()
    }

    // MARK: - Setup helpers

    private func setupEnvironment() async {
        guard environmentEntity.parent == nil else { return }

        let floorMesh = MeshResource.generatePlane(width: 6, depth: 6)
        var floorMaterial = PhysicallyBasedMaterial()
        floorMaterial.baseColor = .init(tint: .init(red: 0.05, green: 0.07, blue: 0.12))
        floorMaterial.metallic = 0.2
        floorMaterial.roughness = 0.65

        let floorEntity = ModelEntity(mesh: floorMesh, materials: [floorMaterial])
        floorEntity.transform.translation = [0, -0.01, 0]
        floorEntity.components.set(InputTargetComponent())

        let ringMesh = MeshResource.generateTorus(ringRadius: 3.2, pipeRadius: 0.02)
        let ringMaterial = UnlitMaterial(color: .init(white: 0.2, alpha: 1))
        let ringEntity = ModelEntity(mesh: ringMesh, materials: [ringMaterial])
        ringEntity.transform = .init(scale: .one,
                                     rotation: simd_quatf(angle: .pi / 2, axis: [1, 0, 0]),
                                     translation: [0, Constants.enemyElevation - 0.2, 0])

        let keyLight = DirectionalLight()
        keyLight.light.color = .white
        keyLight.light.intensity = 1600
        keyLight.shadow = DirectionalLightComponent.Shadow(maximumDistance: 10, depthBias: 1.5)
        keyLight.look(at: [0, 0, 0], from: [1.5, 2.6, 1.5], relativeTo: nil)

        let fillLight = DirectionalLight()
        fillLight.light.color = .init(white: 0.25, alpha: 1)
        fillLight.light.intensity = 450
        fillLight.look(at: [0, 0, 0], from: [-2.5, 1.6, -2.2], relativeTo: nil)

        environmentEntity = Entity()
        environmentEntity.addChild(floorEntity)
        environmentEntity.addChild(ringEntity)
        environmentEntity.addChild(keyLight)
        environmentEntity.addChild(fillLight)

        rootAnchor.addChild(environmentEntity)
    }

    private func setupSaber() async {
        guard saberEntity.parent == nil else { return }

        let hiltMesh = MeshResource.generateCylinder(height: 0.22, radius: 0.03)
        var hiltMaterial = PhysicallyBasedMaterial()
        hiltMaterial.baseColor = .init(tint: .init(red: 0.24, green: 0.24, blue: 0.26))
        hiltMaterial.metallic = 0.8
        hiltMaterial.roughness = 0.25
        let hiltEntity = ModelEntity(mesh: hiltMesh, materials: [hiltMaterial])
        hiltEntity.transform.translation = [0, 0.11, 0]

        let bladeMesh = MeshResource.generateCylinder(height: Constants.saberLength, radius: Constants.saberRadius)
        let bladeMaterial = UnlitMaterial(color: .init(red: 0.12, green: 0.6, blue: 1.0, alpha: 0.9))
        let bladeEntity = ModelEntity(mesh: bladeMesh, materials: [bladeMaterial])
        bladeEntity.transform.translation = [0, Constants.saberLength / 2 + 0.22, 0]

        let glowMesh = MeshResource.generateCylinder(height: Constants.saberLength, radius: Constants.saberRadius * 1.6)
        let glowMaterial = UnlitMaterial(color: .init(red: 0.1, green: 0.6, blue: 1.0, alpha: 0.2))
        let glowEntity = ModelEntity(mesh: glowMesh, materials: [glowMaterial])
        glowEntity.transform.translation = bladeEntity.transform.translation
        glowEntity.name = "SaberGlow"

        let saberRoot = Entity()
        saberRoot.name = "PlayerSaber"
        saberRoot.position = [0.45, 1.2, -0.8]
        saberRoot.orientation = simd_quatf(angle: -.pi / 8, axis: [0, 1, 0])
        saberRoot.addChild(hiltEntity)
        saberRoot.addChild(bladeEntity)
        saberRoot.addChild(glowEntity)

        saberEntity = saberRoot
        saberGlowEntity = glowEntity
        rootAnchor.addChild(saberRoot)
    }

    // MARK: - Sync

    private func syncSaberGlow() {
        guard let glow = saberGlowEntity else { return }
        let pulse = Float(sin(CFAbsoluteTimeGetCurrent() * 6.0) * 0.15 + 0.5)
        var material = glow.model?.materials.first as? UnlitMaterial ?? UnlitMaterial()
        material.color = .init(red: 0.1, green: 0.6, blue: 1.0, alpha: 0.12 + CGFloat(pulse) * 0.08)
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
        UnlitMaterial(color: warning ? .init(red: 1, green: 0.35, blue: 0.2, alpha: 0.9)
                                      : .init(red: 0.65, green: 0.75, blue: 0.95, alpha: 0.9))
    }
}
