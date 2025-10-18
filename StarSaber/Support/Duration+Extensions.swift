//
//  Duration+Extensions.swift
//  StarSaber
//
//  Created by tamakou on 2025/10/18.
//

import Foundation

extension Duration {
    var timeInterval: TimeInterval {
        let components = self.components
        return Double(components.seconds) + Double(components.attoseconds) / 1_000_000_000_000_000_000.0
    }

    func multiplied(by scalar: Int) -> Duration {
        guard scalar > 0 else { return .zero }
        return .seconds(Double(scalar) * timeInterval)
    }
}
