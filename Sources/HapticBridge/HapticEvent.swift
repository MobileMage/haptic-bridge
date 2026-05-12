import Foundation

public struct HapticEvent: Codable, Equatable {

    public enum Kind: String, Codable {
        case impact
        case selection
        case notification
        case coreHaptic
    }

    public enum ImpactStyle: String, Codable {
        case light
        case medium
        case heavy
        case soft
        case rigid
    }

    public enum NotificationFeedback: String, Codable {
        case success
        case warning
        case error
    }

    public var type: Kind
    public var style: ImpactStyle?
    public var feedback: NotificationFeedback?
    public var intensity: Double?
    public var sharpness: Double?

    public init(
        type: Kind,
        style: ImpactStyle? = nil,
        feedback: NotificationFeedback? = nil,
        intensity: Double? = nil,
        sharpness: Double? = nil
    ) {
        self.type = type
        self.style = style
        self.feedback = feedback
        self.intensity = intensity
        self.sharpness = sharpness
    }

    public static func impact(_ style: ImpactStyle, intensity: Double? = nil) -> HapticEvent {
        HapticEvent(type: .impact, style: style, intensity: intensity)
    }

    public static let selection = HapticEvent(type: .selection)

    public static func notification(_ feedback: NotificationFeedback) -> HapticEvent {
        HapticEvent(type: .notification, feedback: feedback)
    }

    public static func coreHaptic(intensity: Double, sharpness: Double) -> HapticEvent {
        HapticEvent(type: .coreHaptic, intensity: intensity, sharpness: sharpness)
    }
}
