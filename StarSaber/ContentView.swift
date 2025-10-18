//
//  ContentView.swift
//  StarSaber
//
//  Created by tamakou on 2025/10/19.
//

import SwiftUI
import RealityKit
import RealityKitContent

struct ContentView: View {

    @Environment(AppModel.self) private var appModel
    @State private var showDebugPanel = true

    var body: some View {
        @Bindable var session = appModel.gameSession

        ZStack {
            RealityView { content in
                if let scene = try? await Entity(named: "Scene", in: realityKitContentBundle) {
                    content.add(scene)
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
