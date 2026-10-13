import AppKit
import DimmelaCore
import Observation
import SwiftUI

/// The pill at the bottom of the screen during a Dictation. A non-activating panel that never
/// becomes key: the frontmost app keeps the focus, so the paste lands where the cursor was.
@MainActor
final class OverlayPanel {
    private let controller: DictationController
    private let panel: NSPanel
    /// Room for the pill and, above it, the list of nine Modes; the empty part is transparent
    /// and lets clicks through.
    private static let size = NSSize(width: 340, height: 360)

    init(controller: DictationController) {
        self.controller = controller
        panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: Self.size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.contentView = NSHostingView(rootView: OverlayView(controller: controller))
        follow()
    }

    /// Shows the panel while a Dictation is in progress, on the screen with the pointer.
    private func follow() {
        let isActive = withObservationTracking {
            controller.phase != .idle
        } onChange: { [weak self] in
            Task { @MainActor in self?.follow() }
        }
        if isActive {
            if !panel.isVisible { place() }
            panel.orderFrontRegardless()
        } else {
            panel.orderOut(nil)
        }
    }

    private func place() {
        let pointer = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(pointer, $0.frame, false) }) ?? NSScreen.main
        else { return }
        let visible = screen.visibleFrame
        panel.setFrameOrigin(NSPoint(x: visible.midX - Self.size.width / 2, y: visible.minY + 24))
    }
}

private struct OverlayView: View {
    let controller: DictationController

    var body: some View {
        VStack(spacing: 8) {
            Spacer(minLength: 0)
            if controller.isModeListVisible {
                ModeList(choices: controller.modeChoices, selected: controller.mode)
                    .transition(.opacity)
            }
            pill
        }
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeOut(duration: 0.12), value: controller.isModeListVisible)
    }

    private var pill: some View {
        HStack(spacing: 10) {
            if controller.phase == .processing {
                PulsingDots()
            } else {
                LevelBars(level: controller.level)
            }
            Text(controller.mode?.name ?? "Transcript")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(1)
        }
        .padding(.horizontal, 16)
        .frame(height: 36)
        .background(Capsule().fill(.black.opacity(0.82)))
        .overlay(Capsule().strokeBorder(.white.opacity(0.12)))
    }
}

/// The Modes the digits choose, numbered; the current one highlighted. 0 is the Transcript alone.
private struct ModeList: View {
    let choices: [Mode]
    let selected: Mode?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            row(digit: 0, name: "Transcript", isSelected: selected == nil)
            ForEach(Array(choices.enumerated()), id: \.offset) { index, mode in
                row(digit: index + 1, name: mode.name, isSelected: mode == selected)
            }
        }
        .padding(6)
        .frame(width: 240)
        .background(RoundedRectangle(cornerRadius: 12).fill(.black.opacity(0.82)))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.white.opacity(0.12)))
    }

    private func row(digit: Int, name: String, isSelected: Bool) -> some View {
        HStack(spacing: 10) {
            Text(verbatim: "\(digit)")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.6))
                .frame(width: 14)
            Text(name)
                .font(.system(size: 13))
                .foregroundStyle(.white)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: 7).fill(isSelected ? .white.opacity(0.18) : .clear))
    }
}

/// Five bars that rise with the voice, the middle ones most.
private struct LevelBars: View {
    let level: Float
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let weights: [CGFloat] = [0.45, 0.75, 1, 0.75, 0.45]

    var body: some View {
        HStack(spacing: 3) {
            ForEach(weights.indices, id: \.self) { index in
                Capsule()
                    .fill(.red)
                    .frame(width: 3, height: 4 + 14 * CGFloat(level) * weights[index])
            }
        }
        .frame(height: 18)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.08), value: level)
    }
}

/// Three white dots pulsing one after the other while the Dictation is processed. With Reduce
/// Motion they stay still.
private struct PulsingDots: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let period = 1.6

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(.white)
                        .frame(width: 5, height: 5)
                        .opacity(reduceMotion ? 0.8 : opacity(at: time, index: index))
                }
            }
        }
        .frame(height: 18)
    }

    /// A wave that peaks on each dot a third of a period after the previous one.
    private func opacity(at time: TimeInterval, index: Int) -> Double {
        let phase = (time / period - Double(index) / 3).truncatingRemainder(dividingBy: 1)
        return 0.3 + 0.7 * (0.5 + 0.5 * cos(phase * 2 * .pi))
    }
}
