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
            let controller = coordinator ?? BattleImmersiveCoordinator(gameSession: appModel.gameSession)
            if coordinator == nil {
                coordinator = controller
            }

            if controller.rootAnchor.parent == nil {
                content.add(controller.rootAnchor)
            }

            await controller.prepareSceneIfNeeded()
        } update: { _ in
            let now = Date()
            let delta = now.timeIntervalSince(lastUpdateTime)
            if delta > 0 {
                coordinator?.updateScene()
            }
            lastUpdateTime = now
        }
    }
}

#Preview(immersionStyle: .mixed) {
    ImmersiveView()
        .environment(AppModel())
}
