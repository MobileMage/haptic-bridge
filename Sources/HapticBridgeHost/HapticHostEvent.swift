import Foundation

struct HapticHostEvent: Codable {

    enum Kind: String, Codable {
        case impact
        case selection
        case notification
        case coreHaptic
    }

    enum ImpactStyle: String, Codable {
        case light, medium, heavy, soft, rigid
    }

    enum NotificationFeedback: String, Codable {
        case success, warning, error
    }

    var type: Kind
    var style: ImpactStyle?
    var feedback: NotificationFeedback?
    var intensity: Double?
    var sharpness: Double?
}
