#if canImport(UIKit)
import Foundation
import ObjectiveC.runtime
import UIKit

private var impactStyleKey: UInt8 = 0

enum Swizzler {

    static func installAll(includeCoreHaptics: Bool) {
        installImpact()
        installSelection()
        installNotification()
        if includeCoreHaptics {
            installCoreHaptics()
        }
    }

    // MARK: - UIImpactFeedbackGenerator

    private static func installImpact() {
        swap(
            UIImpactFeedbackGenerator.self,
            #selector(UIImpactFeedbackGenerator.init(style:)),
            #selector(UIImpactFeedbackGenerator.hb_initWithStyle(_:))
        )
        swap(
            UIImpactFeedbackGenerator.self,
            #selector(UIImpactFeedbackGenerator.impactOccurred as (UIImpactFeedbackGenerator) -> () -> Void),
            #selector(UIImpactFeedbackGenerator.hb_impactOccurred)
        )
        if #available(iOS 13.0, *) {
            swap(
                UIImpactFeedbackGenerator.self,
                #selector(UIImpactFeedbackGenerator.impactOccurred(intensity:)),
                #selector(UIImpactFeedbackGenerator.hb_impactOccurred(intensity:))
            )
        }
    }

    // MARK: - UISelectionFeedbackGenerator

    private static func installSelection() {
        swap(
            UISelectionFeedbackGenerator.self,
            #selector(UISelectionFeedbackGenerator.selectionChanged),
            #selector(UISelectionFeedbackGenerator.hb_selectionChanged)
        )
    }

    // MARK: - UINotificationFeedbackGenerator

    private static func installNotification() {
        swap(
            UINotificationFeedbackGenerator.self,
            #selector(UINotificationFeedbackGenerator.notificationOccurred(_:)),
            #selector(UINotificationFeedbackGenerator.hb_notificationOccurred(_:))
        )
    }

    // MARK: - CHHapticEngine (best effort)

    private static func installCoreHaptics() {
        // CHHapticEngine patterns are intentionally not swizzled in v1 — the
        // trackpad cannot reproduce arbitrary intensity/sharpness curves and
        // the API surface is large. Users who want a rough proxy for Core
        // Haptics can call HapticBridge.fire(.coreHaptic(...)) manually.
    }

    // MARK: - Helpers

    private static func swap(_ cls: AnyClass, _ original: Selector, _ replacement: Selector) {
        guard
            let originalMethod = class_getInstanceMethod(cls, original),
            let replacementMethod = class_getInstanceMethod(cls, replacement)
        else {
            NSLog("[HapticBridge] could not find selectors \(original)/\(replacement) on \(cls)")
            return
        }
        method_exchangeImplementations(originalMethod, replacementMethod)
    }

    static func captureImpactStyle(_ object: AnyObject, raw: Int) {
        objc_setAssociatedObject(object, &impactStyleKey, raw, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    static func readImpactStyle(_ object: AnyObject) -> Int? {
        objc_getAssociatedObject(object, &impactStyleKey) as? Int
    }
}

// MARK: - Bridged methods

extension UIImpactFeedbackGenerator {

    @objc dynamic func hb_initWithStyle(_ rawStyle: Int) -> UIImpactFeedbackGenerator {
        let result = self.hb_initWithStyle(rawStyle) // swizzled → calls original
        Swizzler.captureImpactStyle(result, raw: rawStyle)
        return result
    }

    @objc dynamic func hb_impactOccurred() {
        forwardImpact(intensity: nil)
        self.hb_impactOccurred() // swizzled → calls original (no-op in simulator)
    }

    @objc dynamic func hb_impactOccurred(intensity: CGFloat) {
        forwardImpact(intensity: Double(intensity))
        self.hb_impactOccurred(intensity: intensity)
    }

    private func forwardImpact(intensity: Double?) {
        let raw = Swizzler.readImpactStyle(self) ?? FeedbackStyle.medium.rawValue
        let style = FeedbackStyle(rawValue: raw) ?? .medium
        let mapped: HapticEvent.ImpactStyle
        switch style {
        case .light: mapped = .light
        case .medium: mapped = .medium
        case .heavy: mapped = .heavy
        case .soft: mapped = .soft
        case .rigid: mapped = .rigid
        @unknown default: mapped = .medium
        }
        HapticEventClient.shared.send(.impact(mapped, intensity: intensity))
    }
}

extension UISelectionFeedbackGenerator {

    @objc dynamic func hb_selectionChanged() {
        HapticEventClient.shared.send(.selection)
        self.hb_selectionChanged()
    }
}

extension UINotificationFeedbackGenerator {

    @objc dynamic func hb_notificationOccurred(_ type: FeedbackType) {
        let mapped: HapticEvent.NotificationFeedback
        switch type {
        case .success: mapped = .success
        case .warning: mapped = .warning
        case .error: mapped = .error
        @unknown default: mapped = .success
        }
        HapticEventClient.shared.send(.notification(mapped))
        self.hb_notificationOccurred(type)
    }
}

#endif
