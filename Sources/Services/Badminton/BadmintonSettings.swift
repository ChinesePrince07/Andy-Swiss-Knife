import Observation
import Foundation
import CoreGraphics

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
    private static let roiKey = "badminton.courtROI.v1"

    var scale: ReferenceScale? { didSet { persistScale() } }
    var unit: SpeedUnit { didSet { defaults.set(unit.rawValue, forKey: Self.unitKey) } }
    /// The court playing area as a normalized rect (0...1 of the frame). Shuttle
    /// detections outside it are rejected (kills background clutter — banners,
    /// crowd, off-court reflections). nil = use the whole frame.
    var courtROI: CGRect? { didSet { persistROI() } }

    init(defaults: UserDefaults) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.scaleKey) {
            self.scale = try? JSONDecoder().decode(ReferenceScale.self, from: data)
        } else {
            self.scale = nil
        }
        self.unit = SpeedUnit(rawValue: defaults.string(forKey: Self.unitKey) ?? "") ?? .kmh
        if let data = defaults.data(forKey: Self.roiKey) {
            self.courtROI = try? JSONDecoder().decode(CGRect.self, from: data)
        } else {
            self.courtROI = nil
        }
    }

    private func persistScale() {
        if let scale, let data = try? JSONEncoder().encode(scale) {
            defaults.set(data, forKey: Self.scaleKey)
        } else {
            defaults.removeObject(forKey: Self.scaleKey)
        }
    }

    private func persistROI() {
        if let courtROI, let data = try? JSONEncoder().encode(courtROI) {
            defaults.set(data, forKey: Self.roiKey)
        } else {
            defaults.removeObject(forKey: Self.roiKey)
        }
    }

    func display(_ speed: ShotSpeed) -> String {
        let value = unit == .kmh ? speed.kmh : speed.mph
        return "\(Int(value.rounded())) \(unit.label)"
    }
}
