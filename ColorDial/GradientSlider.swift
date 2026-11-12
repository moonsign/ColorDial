import AppKit
import SwiftUI

struct GradientSlider: NSViewRepresentable {
  let label: String
  let value: Double
  let range: ClosedRange<Double>
  let step: Double
  let colors: [RGBColor]
  let change: (Double) -> Void

  func makeCoordinator() -> Coordinator {
    Coordinator(change: change)
  }

  func makeNSView(context: Context) -> NSSlider {
    let slider = ChannelSlider()
    slider.cell = GradientSliderCell()
    slider.target = context.coordinator
    slider.action = #selector(Coordinator.didSlide(_:))
    slider.isContinuous = true
    slider.setAccessibilityLabel(label)
    return slider
  }

  func updateNSView(_ slider: NSSlider, context: Context) {
    context.coordinator.change = change
    context.coordinator.step = step
    slider.minValue = range.lowerBound
    slider.maxValue = range.upperBound
    slider.doubleValue = min(range.upperBound, max(range.lowerBound, value))
    slider.altIncrementValue = step
    (slider as? ChannelSlider)?.step = step
    (slider.cell as? GradientSliderCell)?.gradient = NSGradient(colors: colors.map(\.nsColor))
    slider.needsDisplay = true
  }

  @MainActor
  final class Coordinator: NSObject {
    var change: (Double) -> Void
    var step = 1.0

    init(change: @escaping (Double) -> Void) {
      self.change = change
    }

    @objc func didSlide(_ sender: NSSlider) {
      change((sender.doubleValue / step).rounded() * step)
    }
  }
}

private final class ChannelSlider: NSSlider {
  var step = 1.0

  override func keyDown(with event: NSEvent) {
    let direction: Double =
      switch event.specialKey {
      case .leftArrow, .downArrow: -1
      case .rightArrow, .upArrow: 1
      default: 0
      }
    guard isEnabled, direction != 0,
      event.modifierFlags.intersection([.command, .control, .shift]).isEmpty
    else {
      super.keyDown(with: event)
      return
    }

    let next = min(maxValue, max(minValue, (doubleValue / step + direction).rounded() * step))
    if next != doubleValue {
      doubleValue = next
      sendAction(action, to: target)
    }
  }
}

private final class GradientSliderCell: NSSliderCell {
  var gradient: NSGradient?

  override func drawBar(inside rect: NSRect, flipped: Bool) {
    let height = rem(0.625)
    let bar = NSRect(x: rect.minX, y: rect.midY - height / 2, width: rect.width, height: height)
    let path = NSBezierPath(roundedRect: bar, xRadius: height / 2, yRadius: height / 2)
    gradient?.draw(in: path, angle: 0)
    NSColor.labelColor.withAlphaComponent(0.18).setStroke()
    path.lineWidth = rem(0.0625)
    path.stroke()
  }
}
