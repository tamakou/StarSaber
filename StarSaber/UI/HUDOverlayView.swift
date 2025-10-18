//
//  HUDOverlayView.swift
//  StarSaber
//
//  Created by tamakou on 2025/10/18.
//

import SwiftUI

struct HUDOverlayView: View {
    @Bindable var session: GameSessionModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("PLAYER HP")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    ProgressView(value: Double(session.player.healthRatio))
                        .progressViewStyle(.linear)
                        .tint(.mint)
                        .frame(width: 220)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("FORCE")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    ProgressView(value: forceProgress)
                        .progressViewStyle(.linear)
                        .tint(forceColor)
                        .frame(width: 160)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("SCORE")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    Text("\(session.player.score)")
                        .font(.title3)
                        .fontWeight(.bold)
                }
            }

            if let wave = session.wave {
                HStack(spacing: 16) {
                    Label("Wave \(wave.index)", systemImage: "bolt.fill")
                        .font(.callout)
                        .labelStyle(.titleAndIcon)
                    Text("ENEMIES \(wave.totalEnemies - wave.defeatedEnemies)/\(wave.totalEnemies)")
                        .font(.caption)
                        .fontWeight(.medium)
                    ProgressView(value: Double(wave.progressRatio))
                        .progressViewStyle(.linear)
                        .tint(.orange)
                        .frame(width: 160)
                }
                .padding(.top, 4)
            }
        }
        .padding(18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(radius: 12)
    }

    private var forceProgress: Double {
        let remaining = session.player.forceCooldownRemaining
        guard remaining > .zero else { return 1 }
        let cooldown = session.player.forceCooldown
        guard cooldown > .zero else { return 1 }
        let ratio = 1 - min(1, remaining.timeInterval / cooldown.timeInterval)
        return Double(ratio)
    }

    private var forceColor: Color {
        session.player.isForceReady ? .cyan : .blue.opacity(0.6)
    }
}
