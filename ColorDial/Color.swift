// Derived from ColorDial's original color conversion code by Kenneth Allan.
// Copyright © 2015 Kenneth Allan. All rights reserved.

import Foundation

struct RGBColor: Equatable, Sendable {
  let red: Double
  let green: Double
  let blue: Double

  init(_ red: Double, _ green: Double, _ blue: Double) {
    self.red = unit(red)
    self.green = unit(green)
    self.blue = unit(blue)
  }

  init(hsv: HSV) {
    let chroma = hsv.value * hsv.saturation
    self.init(hue: hsv.hue, chroma: chroma, offset: hsv.value - chroma)
  }

  init(hue: Double, saturation: Double, lightness: Double) {
    let lightness = unit(lightness)
    let chroma = (1 - abs(2 * lightness - 1)) * unit(saturation)
    self.init(hue: hue, chroma: chroma, offset: lightness - chroma / 2)
  }

  private init(hue: Double, chroma: Double, offset: Double) {
    let sector = wrappedHue(hue) / 60
    let second = chroma * (1 - abs(sector.truncatingRemainder(dividingBy: 2) - 1))
    let components: (Double, Double, Double) =
      switch sector {
      case ..<1: (chroma, second, 0)
      case ..<2: (second, chroma, 0)
      case ..<3: (0, chroma, second)
      case ..<4: (0, second, chroma)
      case ..<5: (second, 0, chroma)
      default: (chroma, 0, second)
      }
    self.init(components.0 + offset, components.1 + offset, components.2 + offset)
  }

  var components: [Double] { [red, green, blue] }

  var hsv: HSV {
    let high = max(red, green, blue)
    let low = min(red, green, blue)
    let chroma = high - low
    guard chroma > 0 else { return HSV(hue: 0, saturation: 0, value: high) }

    let sector: Double
    if high == red {
      sector = (green - blue) / chroma
    } else if high == green {
      sector = (blue - red) / chroma + 2
    } else {
      sector = (red - green) / chroma + 4
    }
    return HSV(hue: sector * 60, saturation: chroma / high, value: high)
  }

  var hsl: (hue: Double, saturation: Double, lightness: Double) {
    let high = max(red, green, blue)
    let low = min(red, green, blue)
    let lightness = (high + low) / 2
    let chroma = high - low
    let range = min(high + low, (1 - high) + (1 - low))
    return (hsv.hue, range > 0 ? unit(chroma / range) : 0, lightness)
  }

  func isNear(_ other: RGBColor) -> Bool {
    let dr = red - other.red
    let dg = green - other.green
    let db = blue - other.blue
    return dr * dr + dg * dg + db * db < 0.000_001
  }

  // Choose the more legible glyph color against this sRGB swatch.
  var prefersDarkInk: Bool {
    let luminance =
      0.2126 * linearSRGB(red) + 0.7152 * linearSRGB(green) + 0.0722 * linearSRGB(blue)
    return luminance > 0.179_128_784_7
  }

  static let initial = RGBColor(0.1, 0.5, 0.75)
}

struct HSV: Equatable, Sendable {
  let hue: Double
  let saturation: Double
  let value: Double

  init(hue: Double, saturation: Double, value: Double) {
    self.hue = wrappedHue(hue)
    self.saturation = unit(saturation)
    self.value = unit(value)
  }
}

func unit(_ value: Double) -> Double {
  guard value.isFinite else { return 0 }
  return min(1, max(0, value))
}

func wrappedHue(_ hue: Double) -> Double {
  guard hue.isFinite else { return 0 }
  let angle = hue.truncatingRemainder(dividingBy: 360)
  return angle < 0 ? angle + 360 : angle
}

enum ColorFormat: String, CaseIterable, Identifiable {
  case hex = "Hex"
  case rgb = "RGB"
  case hsl = "HSL"
  case lab = "Lab"
  case lch = "LCH"
  case oklab = "OKLab"
  case oklch = "OKLCH"

  var id: Self { self }

  func string(for color: RGBColor) -> String {
    switch self {
    case .hex:
      let channels = color.components.map { Int(($0 * 255).rounded()) }
      return String(format: "#%02x%02x%02x", channels[0], channels[1], channels[2])
    case .rgb:
      let channels = color.components.map { Int(($0 * 255).rounded()) }
      return "rgb(\(channels[0]), \(channels[1]), \(channels[2]))"
    case .hsl:
      let (h, s, l) = color.hsl
      return
        "hsl(\(colorNumber(h, places: 1)) \(colorNumber(s * 100, places: 1))% \(colorNumber(l * 100, places: 1))%)"
    case .lab, .lch, .oklab, .oklch:
      let value = perceptualSpace.coordinates(of: color)
      let places = self == .oklab || self == .oklch ? 5 : 2
      let huePlaces = self == .oklch ? 3 : places
      return
        "\(rawValue.lowercased())(\(colorNumber(value.x, places: places)) \(colorNumber(value.y, places: places)) \(colorNumber(value.z, places: huePlaces)))"
    }
  }

  func parse(_ string: String) -> RGBColor? {
    conversion(for: string)?.color
  }

  func conversion(for string: String) -> (color: RGBColor, clipped: Bool)? {
    let input = string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    if self == .hex { return parseHex(input).map { (color: $0, clipped: false) } }

    var body = input[...]
    let prefix = rawValue.lowercased() + "("
    if body.hasPrefix(prefix) {
      guard body.last == ")" else { return nil }
      body = body.dropFirst(prefix.count).dropLast()
    }

    let parts: [Substring]
    if body.contains(",") {
      guard self == .rgb || self == .hsl else { return nil }
      parts = body.split(separator: ",", omittingEmptySubsequences: false)
    } else {
      parts = body.split(whereSeparator: \.isWhitespace)
    }
    guard parts.count == 3 else { return nil }
    let tokens = parts.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

    switch self {
    case .hex:
      return nil
    case .rgb:
      let values = tokens.compactMap { number($0, percentReference: 255) }
      guard values.count == 3 else { return nil }
      return ColorSpace.rgb.convert(SIMD3(values[0], values[1], values[2]))
    case .hsl:
      guard let hue = angle(tokens[0]),
        let saturation = number(tokens[1], percentReference: 100),
        let lightness = number(tokens[2], percentReference: 100)
      else { return nil }
      return ColorSpace.hsl.convert(SIMD3(hue, saturation, lightness))
    case .lab, .lch, .oklab, .oklch:
      return parsePerceptual(tokens)
    }
  }

  private var perceptualSpace: ColorSpace {
    switch self {
    case .lab: .lab
    case .lch: .lch
    case .oklab: .oklab
    case .oklch: .oklch
    default: preconditionFailure("Only perceptual formats have perceptual coordinates")
    }
  }

  private func parsePerceptual(_ tokens: [String]) -> (color: RGBColor, clipped: Bool)? {
    let isOK = self == .oklab || self == .oklch
    guard let lightness = number(tokens[0], percentReference: isOK ? 1 : 100) else { return nil }
    if self == .lch || self == .oklch {
      guard let chroma = number(tokens[1], percentReference: isOK ? 0.4 : 150),
        let hue = angle(tokens[2])
      else { return nil }
      return perceptualSpace.convert(SIMD3(lightness, max(0, chroma), hue))
    }

    let reference = isOK ? 0.4 : 125.0
    guard let a = number(tokens[1], percentReference: reference),
      let b = number(tokens[2], percentReference: reference)
    else { return nil }
    return perceptualSpace.convert(SIMD3(lightness, a, b))
  }

  private func number(_ token: String, percentReference: Double) -> Double? {
    let percentage = token.hasSuffix("%")
    guard let value = Double(percentage ? String(token.dropLast()) : token), value.isFinite
    else { return nil }
    let scaled = percentage ? value / 100 * percentReference : value
    // Leave room for cubing perceptual coordinates during conversion.
    return abs(scaled) <= 1e100 ? scaled : nil
  }

  private func angle(_ token: String) -> Double? {
    for (suffix, turn) in [("turn", 1.0), ("grad", 400), ("deg", 360), ("rad", 2 * Double.pi)] {
      if token.hasSuffix(suffix) {
        guard let value = Double(token.dropLast(suffix.count)), value.isFinite else { return nil }
        return wrappedHue(value.truncatingRemainder(dividingBy: turn) / turn * 360)
      }
    }
    guard let value = Double(token), value.isFinite else { return nil }
    return wrappedHue(value)
  }

  private func parseHex(_ input: String) -> RGBColor? {
    var digits = Array(input.hasPrefix("#") ? input.dropFirst() : input[...])
    guard [3, 6].contains(digits.count),
      digits.allSatisfy({ "0123456789abcdef".contains($0) })
    else { return nil }
    if digits.count == 3 { digits = digits.flatMap { [$0, $0] } }
    guard let number = UInt32(String(digits), radix: 16) else { return nil }
    return RGBColor(
      Double(number >> 16) / 255,
      Double((number >> 8) & 255) / 255,
      Double(number & 255) / 255
    )
  }
}
