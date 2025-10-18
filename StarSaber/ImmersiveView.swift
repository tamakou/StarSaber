//
//  ImmersiveView.swift
//  StarSaber
//
//  Created by tamakou on 2025/10/19.
//

import SwiftUI
import RealityKit

struct ImmersiveView: View {

    @Environment(AppModel.self) private var appModel
    @State private var coordinator: BattleImmersiveCoordinator?
    @State private var lastUpdateTime = Date()

    var body: some View {
        RealityView { content in
            let coordinator = coordinator ?? BattleImmersiveCoordinator(gameSession: appModel.gameSession)
            self.coordinator = coordinator
            await coordinator.configureScene(on: content)
        } update: { _ in
            let now = Date()
            let delta = now.timeIntervalSince(lastUpdateTime)
            coordinator?.updateScene(deltaTime: delta)
            lastUpdateTime = now
        }
    }
}

#Preview(immersionStyle: .mixed) {
    ImmersiveView()
        .environment(AppModel())
}
