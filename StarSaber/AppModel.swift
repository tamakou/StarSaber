//
//  AppModel.swift
//  StarSaber
//
//  Created by tamakou on 2025/10/19.
//

import SwiftUI

/// Maintains app-wide state shared between SwiftUI and RealityKit surfaces.
@MainActor
@Observable
class AppModel {
    let immersiveSpaceID = "ImmersiveSpace"

    enum ImmersiveSpaceState {
        case closed
        case inTransition
        case open
    }

    var immersiveSpaceState = ImmersiveSpaceState.closed
    let gameSession: GameSessionModel

    init(gameSession: GameSessionModel = GameSessionModel()) {
        self.gameSession = gameSession
    }

    func prepareForLaunch() {
        if gameSession.phase == .idle {
            gameSession.beginSession()
        }
    }

    func requestWaveStart() {
        gameSession.startWave()
    }

    func requestRestart() {
        gameSession.restartSession()
    }
}
