#if os(macOS)
import AppKit

struct HapticPlayer {

    let verbose: Bool
    let leadDelay: TimeInterval

    func play(_ event: HapticHostEvent) {
        let performer = NSHapticFeedbackManager.defaultPerformer
        let fire: () -> Void = {
            switch event.type {
            case .impact:
                self.playImpact(event, performer: performer)
            case .selection:
                performer.perform(.alignment, performanceTime: .now)
            case .notification:
                self.playNotification(event, performer: performer)
            case .coreHaptic:
                self.playCoreHaptic(event, performer: performer)
            }
        }

        if leadDelay > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + leadDelay, execute: fire)
        } else {
            fire()
        }

        if verbose {
            print("[haptic-bridge-host] played \(describe(event)) (lead \(Int(leadDelay * 1000))ms)")
        }
    }

    // MARK: - Mappings

    private func playImpact(_ event: HapticHostEvent, performer: NSHapticFeedbackPerformer) {
        // The trackpad has three patterns: .generic (firm), .alignment (light tick),
        // .levelChange (rising). We map five iOS impact styles onto those plus an
        // optional double-tap for the heaviest cases. Lossy by design.
        switch event.style {
        case .heavy, .rigid:
            performer.perform(.generic, performanceTime: .now)
            tapAfter(0.06) { performer.perform(.generic, performanceTime: .now) }
        case .medium, .none:
            performer.perform(.generic, performanceTime: .now)
        case .light, .soft:
            performer.perform(.alignment, performanceTime: .now)
        }
    }

    private func playNotification(_ event: HapticHostEvent, performer: NSHapticFeedbackPerformer) {
        switch event.feedback {
        case .success:
            performer.perform(.alignment, performanceTime: .now)
            tapAfter(0.09) { performer.perform(.alignment, performanceTime: .now) }
        case .warning:
            performer.perform(.levelChange, performanceTime: .now)
        case .error:
            performer.perform(.generic, performanceTime: .now)
            tapAfter(0.07) { performer.perform(.generic, performanceTime: .now) }
            tapAfter(0.14) { performer.perform(.generic, performanceTime: .now) }
        case .none:
            performer.perform(.generic, performanceTime: .now)
        }
    }

    private func playCoreHaptic(_ event: HapticHostEvent, performer: NSHapticFeedbackPerformer) {
        let intensity = event.intensity ?? 0.5
        if intensity >= 0.75 {
            performer.perform(.generic, performanceTime: .now)
        } else if intensity >= 0.4 {
            performer.perform(.levelChange, performanceTime: .now)
        } else {
            performer.perform(.alignment, performanceTime: .now)
        }
    }

    private func tapAfter(_ seconds: TimeInterval, _ block: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: block)
    }

    private func describe(_ event: HapticHostEvent) -> String {
        switch event.type {
        case .impact: return "impact(\(event.style?.rawValue ?? "?"))"
        case .selection: return "selection"
        case .notification: return "notification(\(event.feedback?.rawValue ?? "?"))"
        case .coreHaptic: return "coreHaptic(i=\(event.intensity ?? 0), s=\(event.sharpness ?? 0))"
        }
    }
}
#endif
