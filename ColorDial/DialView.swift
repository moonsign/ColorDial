import AppKit
import SwiftUI

struct DialView: View {
  let session: ColorSession

  var body: some View {
    let radius = rem(8)
    let swatchSize = rem(2.5)
    let diameter = radius * 2 + swatchSize + rem(0.25)

    ZStack {
      Circle()
        .strokeBorder(.primary.opacity(0.12), lineWidth: rem(0.0625))
        .frame(width: radius * 2)
        .accessibilityHidden(true)

      ForEach(0..<12) { index in
        let angle = Double(index) * .pi / 6
        let degrees = index * 30
        let color = session.dialColor(offset: Double(degrees))
        SwatchButton(
          color: color,
          title: index == 0 ? "Save Dial Color" : "Hue offset \(degrees) degrees",
          symbol: index == 0 ? "plus" : nil,
          circular: true
        ) {
          if index == 0 {
            session.saveBase()
          } else {
            session.selectHue(offset: Double(degrees))
          }
        }
        .frame(width: swatchSize, height: swatchSize)
        .offset(x: radius * sin(angle), y: -radius * cos(angle))
      }

      VStack(spacing: rem(0.375)) {
        HStack(spacing: rem(0.375)) {
          adjustment("Lighten", symbol: "sun.max", color: session.adjusted(lightness: 0.05))
          adjustment("Saturate", symbol: "drop", color: session.adjusted(saturation: 0.05))
        }
        HStack(spacing: rem(0.375)) {
          adjustment("Darken", symbol: "sun.min", color: session.adjusted(lightness: -0.05))
          adjustment(
            "Desaturate", symbol: "drop.halffull", color: session.adjusted(saturation: -0.05))
        }
      }
    }
    .frame(width: diameter, height: diameter)
    .accessibilityElement(children: .contain)
    .accessibilityLabel("Dial swatches")
  }

  private func adjustment(_ title: String, symbol: String, color: RGBColor) -> some View {
    SwatchButton(color: color, title: title, symbol: symbol) { session.select(color) }
      .frame(width: rem(2.5), height: rem(2.5))
      .disabled(color.isNear(session.base))
  }
}

struct SwatchButton: View {
  let color: RGBColor
  let title: String
  var symbol: String?
  var circular = false
  let action: () -> Void

  @Environment(\.isEnabled) private var isEnabled
  @FocusState private var focused: Bool

  var body: some View {
    let shape =
      circular ? AnyShape(Circle()) : AnyShape(RoundedRectangle(cornerRadius: rem(0.4375)))
    let value = ColorFormat.hsl.string(for: color)
    Button(action: action) {
      shape
        .fill(color.swatch)
        .overlay {
          shape.stroke(.primary.opacity(0.2), lineWidth: rem(0.125))
            .clipShape(shape)
        }
        .overlay {
          if let symbol {
            Image(systemName: symbol)
              .font(.system(size: rem(0.9375), weight: .semibold))
              .foregroundStyle(color.prefersDarkInk ? .black : .white)
          }
        }
        .opacity(isEnabled ? 1 : 0.45)
        .contentShape(shape)
    }
    .buttonStyle(SwatchButtonStyle())
    .focused($focused)
    .overlay {
      if focused {
        shape.stroke(.background, lineWidth: rem(0.125))
          .overlay { shape.stroke(.primary, lineWidth: rem(0.0625)) }
          .padding(-rem(0.1875))
          .allowsHitTesting(false)
          .accessibilityHidden(true)
      }
    }
    .onDrag { colorProvider(color) }
    .accessibilityLabel(title)
    .accessibilityValue(value)
    .help("\(title) · \(value)")
  }
}

private struct SwatchButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .opacity(configuration.isPressed ? 0.72 : 1)
  }
}

func colorProvider(_ color: RGBColor) -> NSItemProvider {
  let provider = NSItemProvider()
  let type = NSPasteboard.PasteboardType.color
  if let data = color.nsColor.pasteboardPropertyList(forType: type) as? Data {
    provider.registerDataRepresentation(forTypeIdentifier: type.rawValue, visibility: .all) {
      completion in
      completion(data, nil)
      return nil
    }
  }
  provider.registerObject(ColorFormat.hex.string(for: color) as NSString, visibility: .all)
  return provider
}
