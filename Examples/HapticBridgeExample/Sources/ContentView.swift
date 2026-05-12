import SwiftUI
import UIKit

struct ContentView: View {

    @State private var lastFired: String = "tap any row"

    var body: some View {
        NavigationStack {
            List {
                Section("Impact") {
                    row("light")  { UIImpactFeedbackGenerator(style: .light).impactOccurred()  }
                    row("medium") { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
                    row("heavy")  { UIImpactFeedbackGenerator(style: .heavy).impactOccurred()  }
                    row("soft")   { UIImpactFeedbackGenerator(style: .soft).impactOccurred()   }
                    row("rigid")  { UIImpactFeedbackGenerator(style: .rigid).impactOccurred()  }
                }
                Section("Selection") {
                    row("selectionChanged") { UISelectionFeedbackGenerator().selectionChanged() }
                }
                Section("Notification") {
                    row("success") { UINotificationFeedbackGenerator().notificationOccurred(.success) }
                    row("warning") { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
                    row("error")   { UINotificationFeedbackGenerator().notificationOccurred(.error)   }
                }
                Section("Status") {
                    Text(lastFired)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("haptic-bridge demo")
        }
    }

    private func row(_ title: String, action: @escaping () -> Void) -> some View {
        Button {
            action()
            lastFired = "fired \(title)"
        } label: {
            HStack {
                Text(title)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

#Preview { ContentView() }
