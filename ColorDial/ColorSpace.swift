import Foundation

enum ColorSpace: String, CaseIterable, Identifiable {
  case rgb = "RGB"
  case hsl = "HSL"
  case hsv = "HSV"
  case lab = "Lab"
  case lch = "LCH"
  case oklab = "OKLab"
  case oklch = "OKLCH"

  var id: Self { self }

  var channels: [ColorChannel] {
    switch self {
    case .rgb:
      [
        ColorChannel("R", "Red", 0...255),
        ColorChannel("G", "Green", 0...255),
        ColorChannel("B", "Blue", 0...255),
      ]
    case .hsl:
      [
        ColorChannel("H", "Hue", 0...360, places: 1),
        ColorChannel("S", "Saturation", 0...100, places: 1),
        ColorChannel("L", "Lightness", 0...100, places: 1),
      ]
    case .hsv:
      [
        .hue,
        ColorChannel("S", "Saturation", 0...100),
        ColorChannel("V", "Value", 0...100),
      ]
    case .lab:
      [
        ColorChannel("L", "Lightness", 0...100, places: 1),
        ColorChannel("a", "a axis", -125...125, places: 1),
        ColorChannel("b", "b axis", -125...125, places: 1),
      ]
    case .lch:
      [
        ColorChannel("L", "Lightness", 0...100, places: 1),
        ColorChannel("C", "Chroma", 0...150, places: 1),
        .hue,
      ]
    case .oklab:
      [
        ColorChannel("L", "Lightness", 0...1, places: 3),
        ColorChannel("a", "a axis", -0.4...0.4, places: 3),
        ColorChannel("b", "b axis", -0.4...0.4, places: 3),
      ]
    case .oklch:
      [
        ColorChannel("L", "Lightness", 0...1, places: 3),
        ColorChannel("C", "Chroma", 0...0.4, places: 3),
        .hue,
      ]
    }
  }

  func coordinates(of color: RGBColor, hsv: HSV? = nil) -> SIMD3<Double> {
    switch self {
    case .rgb:
      return SIMD3(color.red, color.green, color.blue) * 255
    case .hsl:
      let (hue, saturation, lightness) = color.hsl
      return SIMD3(hue, saturation * 100, lightness * 100)
    case .hsv:
      let hsv = hsv ?? color.hsv
      return SIMD3(hsv.hue, hsv.saturation * 100, hsv.value * 100)
    case .lab:
      return color.lab
    case .lch:
      return polar(color.lab, powerlessChroma: 0.0015)
    case .oklab:
      return color.oklab
    case .oklch:
      return polar(color.oklab, powerlessChroma: 0.000_004)
    }
  }

  func convert(_ value: SIMD3<Double>) -> (color: RGBColor, clipped: Bool) {
    switch self {
    case .rgb:
      (RGBColor(value.x / 255, value.y / 255, value.z / 255), false)
    case .hsl:
      (RGBColor(hue: value.x, saturation: value.y / 100, lightness: value.z / 100), false)
    case .hsv:
      (RGBColor(hsv: HSV(hue: value.x, saturation: value.y / 100, value: value.z / 100)), false)
    case .lab:
      RGBColor.convertLab(value)
    case .lch:
      RGBColor.convertLab(rectangular(value))
    case .oklab:
      RGBColor.convertOklab(value)
    case .oklch:
      RGBColor.convertOklab(rectangular(value))
    }
  }

  func gradient(for index: Int, around values: SIMD3<Double>) -> [RGBColor] {
    if index == 0 && (self == .hsl || self == .hsv) {
      return (0...12).map { RGBColor(hsv: HSV(hue: Double($0) * 30, saturation: 0.92, value: 0.9)) }
    }
    let range = channels[index].range
    return (0...12).map { stop in
      var sample = values
      sample[index] = range.lowerBound + (range.upperBound - range.lowerBound) * Double(stop) / 12
      return convert(sample).color
    }
  }
}

struct ColorChannel {
  let symbol: String
  let title: String
  let range: ClosedRange<Double>
  let places: Int

  init(_ symbol: String, _ title: String, _ range: ClosedRange<Double>, places: Int = 0) {
    self.symbol = symbol
    self.title = title
    self.range = range
    self.places = places
  }

  var step: Double { pow(10, -Double(places)) }

  func clamp(_ value: Double) -> Double {
    min(range.upperBound, max(range.lowerBound, value))
  }

  func string(for value: Double) -> String {
    colorNumber(clamp(value), places: places)
  }

  static let hue = ColorChannel("H", "Hue", 0...360)
}

func colorNumber(_ value: Double, places: Int) -> String {
  let normalized = abs(value) < pow(10, -Double(places)) / 2 ? 0 : value
  return String(format: "%.*f", locale: Locale(identifier: "en_US_POSIX"), places, normalized)
}
