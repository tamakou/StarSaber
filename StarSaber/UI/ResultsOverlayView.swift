//
//  ResultsOverlayView.swift
//  StarSaber
//
//  Created by tamakou on 2025/10/18.
//

import SwiftUI

struct ResultsOverlayView: View {
    @Bindable var session: GameSessionModel
    var restartAction: () -> Void

    private var titleText: String {
        switch session.phase {
            case .victory, .results where session.player.health > 0:
                return "勝利"
            case .defeat:
                return "敗北"
            default:
                return "結果"
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            Text(titleText)
                .font(.largeTitle)
                .fontWeight(.heavy)
            VStack(alignment: .leading, spacing: 8) {
                Text("スコア: \(session.player.score)")
                    .font(.title3)
                if let wave = session.wave {
                    Text("Wave \(wave.index) 制覇")
                        .font(.headline)
                }
            }

            Button(action: restartAction) {
                Text("再挑戦")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 42)
                    .padding(.vertical, 12)
                    .background(.pink, in: Capsule())
                    .foregroundStyle(.white)
            }
        }
        .padding(32)
        .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(radius: 24)
    }
}
