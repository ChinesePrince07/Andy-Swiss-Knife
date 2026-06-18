import Observation
import Foundation

enum SpeedUnit: String, Codable, CaseIterable {
    case kmh, mph
    var label: String { self == .kmh ? "km/h" : "mph" }
}

@Observable
@MainActor
final class BadmintonSettings {
    static let shared = BadmintonSettings(defaults: .standard)

    private let defaults: UserDefaults
    private static let scaleKey = "badminton.scale.v1"
    private static let unitKey = "badminton.unit.v1"
    private static let trackNetKey = "badminton.useTrackNet.v1"

    var scale: ReferenceScale? { didSet { persistScale() } }
    var unit: SpeedUnit { didSet { defaults.set(unit.rawValue, forKey: Self.unitKey) } }
    /// Use the TrackNetV3 Core ML detector (vs the classical motion detector).
    var useTrackNet: Bool { didSet { defaults.set(useTrackNet, forKey: Self.trackNetKey) } }

    init(defaults: UserDefaults) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.scaleKey) {
            self.scale = try? JSONDecoder().decode(ReferenceScale.self, from: data)
        } else {
            self.scale = nil
        }
        self.unit = SpeedUnit(rawValue: defaults.string(forKey: Self.unitKey) ?? "") ?? .kmh
        self.useTrackNet = defaults.object(forKey: Self.trackNetKey) as? Bool ?? true
    }

    private func persistScale() {
        if let scale, let data = try? JSONEncoder().encode(scale) {
            defaults.set(data, forKey: Self.scaleKey)
        } else {
            defaults.removeObject(forKey: Self.scaleKey)
        }
    }

    func display(_ speed: ShotSpeed) -> String {
        let value = unit == .kmh ? speed.kmh : speed.mph
        return "\(Int(value.rounded())) \(unit.label)"
    }
}
