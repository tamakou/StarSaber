//
//  ContentView.swift
//  StarSaber
//
//  Created by tamakou on 2025/10/19.
//

import SwiftUI
import RealityKit

struct ContentView: View {

    @Environment(AppModel.self) private var appModel
    @State private var showDebugPanel = true

    var body: some View {
        @Bindable var session = appModel.gameSession

        ZStack {
            RealityView { content in
                if content.entities.isEmpty {
                    let root = Entity()

                    let padMesh = MeshResource.generatePlane(width: 1.4, depth: 1.4)
                    let padMaterial = SimpleMaterial(color: .init(red: 0.08, green: 0.08, blue: 0.12, alpha: 1), roughness: 0.85, isMetallic: false)
                    let padEntity = ModelEntity(mesh: padMesh, materials: [padMaterial])
                    padEntity.position = [0, -0.02, 0]
                    root.addChild(padEntity)

                    let orbMaterial = SimpleMaterial(color: .init(red: 0.1, green: 0.5, blue: 1.0, alpha: 1), roughness: 0.1, isMetallic: true)
                    let orb = ModelEntity(mesh: .generateSphere(radius: 0.18), materials: [orbMaterial])
                    orb.position = [0, 0.35, 0]
                    root.addChild(orb)

                    content.add(root)
                }
            }
            .ignoresSafeArea()

            VStack {
                HStack {
                    HUDOverlayView(session: session)
                    Spacer()
                }
                Spacer()
            }

            if session.phase == .tutorial {
                TutorialOverlayView(session: session) {
                    appModel.requestWaveStart()
                }
            }

            if session.phase == .results || session.phase == .victory || session.phase == .defeat {
                ResultsOverlayView(session: session) {
                    appModel.requestRestart()
                }
            }

            VStack {
                Spacer()
                HStack {
                    if showDebugPanel {
                        DebugLogPanelView(session: session)
                    }
                    Spacer()
                }
                .padding()
            }
        }
        .task {
            appModel.prepareForLaunch()
        }
        .toolbar {
            ToolbarItemGroup(placement: .bottomOrnament) {
                Toggle(isOn: $showDebugPanel) {
                    Label("Debug Log", systemImage: showDebugPanel ? "dot.scope.fill" : "dot.scope")
                }
                .toggleStyle(.button)
                .fontWeight(.semibold)

                Button {
                    if let target = session.activeEnemies.first {
                        session.applyDamageToEnemy(enemyID: target.id, amount: session.config.player.saberDamage)
                    }
                } label: {
                    Label("ライトセイバー攻撃", systemImage: "flame.fill")
                }
                .disabled(session.activeEnemies.isEmpty)

                Button {
                    session.triggerForcePush()
                } label: {
                    Label("フォース", systemImage: "sparkles")
                }
                .disabled(!session.canTriggerForcePush())

                ToggleImmersiveSpaceButton()
            }
        }
    }
}

#Preview(windowStyle: .volumetric) {
    ContentView()
        .environment(AppModel())
}
