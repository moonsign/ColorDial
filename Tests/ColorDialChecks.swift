import Foundation

@main
struct ColorDialChecks {
  @MainActor
  static func main() {
    let red = RGBColor(1, 0, 0)
    let green = RGBColor(0, 1, 0)
    let blue = RGBColor(0, 0, 1)

    precondition(ColorFormat.hex.parse("#F00") == red)
    precondition(ColorFormat.hex.parse("ff0000") == red)
    precondition(ColorFormat.hex.parse("#xyz") == nil)
    precondition(ColorFormat.hex.parse("#ff000080") == nil)
    precondition(ColorFormat.rgb.parse("rgb(0 100% 0)") == green)
    precondition(ColorFormat.rgb.parse("rgb(0, 0, 255)") == blue)
    precondition(ColorFormat.rgb.parse("rgb(0,,0,255)") == nil)
    precondition(ColorFormat.rgb.parse("rgb(0,0,nan)") == nil)
    precondition(ColorFormat.hsl.parse("hsl(-120 100% 50%)") == blue)
    precondition(ColorFormat.hsl.parse("hsl(120deg, 100%, 50%)") == green)
    precondition(ColorFormat.hsl.parse(ColorFormat.hsl.string(for: red)) == red)

    for gray in [0.0, 0.5, 1.0] {
      let color = RGBColor(gray, gray, gray)
      precondition(color.hsl.saturation == 0)
      precondition(ColorFormat.hsl.parse(ColorFormat.hsl.string(for: color)) == color)
    }

    // CSS Color 4 §19 reference conversions from encoded sRGB.
    let vectors: [(ColorSpace, ColorFormat, RGBColor, SIMD3<Double>, Double)] = [
      (.lab, .lab, red, SIMD3(54.290541, 80.804928, 69.890965), 0.001),
      (.lch, .lch, blue, SIMD3(29.568302, 131.201448, 301.364268), 0.001),
      (.oklab, .oklab, blue, SIMD3(0.452014, -0.032457, -0.311528), 0.00001),
      (.oklch, .oklch, red, SIMD3(0.627955, 0.257683, 29.233880), 0.0001),
    ]
    for (space, format, color, expected, tolerance) in vectors {
      let channels = space.coordinates(of: color)
      precondition((0..<3).allSatisfy { abs(channels[$0] - expected[$0]) < tolerance })
      let converted = space.convert(channels)
      precondition(converted.color.isNear(color) && !converted.clipped)
      precondition(format.parse(format.string(for: RGBColor.initial))!.isNear(.initial))
    }
    precondition(
      ColorFormat.lab.parse("lab(42% -50% 10%)") == ColorFormat.lab.parse("lab(42 -62.5 12.5)"))
    precondition(
      ColorFormat.lch.parse("lch(60% 30% 0.5turn)") == ColorFormat.lch.parse("lch(60 45 180)"))
    precondition(
      ColorFormat.oklab.parse("oklab(50% 25% -25%)")
        == ColorFormat.oklab.parse("oklab(0.5 0.1 -0.1)"))
    precondition(
      ColorFormat.oklch.parse("oklch(60% 25% 100grad)")
        == ColorFormat.oklch.parse("oklch(0.6 0.1 90deg)"))
    precondition(ColorFormat.oklab.parse("oklab(0.6, 0.1, 0)") == nil)
    precondition(ColorFormat.oklch.parse("oklch(0.6 0.2 20%)") == nil)
    precondition(ColorFormat.lab.parse("lab(100 100 100)") == RGBColor(1, 1, 1))
    precondition(ColorFormat.oklch.parse("oklch(0 0.2 30)") == RGBColor(0, 0, 0))
    for space in [ColorSpace.lab, .lch, .oklab, .oklch] {
      let gray = RGBColor(0.5, 0.5, 0.5)
      let coordinates = space.coordinates(of: gray)
      precondition(coordinates.y == 0 && coordinates.z == 0)
      let converted = space.convert(coordinates)
      precondition(!converted.clipped && converted.color.isNear(gray))
      precondition(
        converted.color.red == converted.color.green
          && converted.color.green == converted.color.blue)
    }

    precondition(ColorFormat.oklch.conversion(for: "oklch(0.6 0.4 42)")?.clipped == true)
    let precisionCases: [(ColorFormat, RGBColor)] = [
      (.oklab, RGBColor(5 / 255, 250 / 255, 100 / 255)),
      (.oklch, RGBColor(3 / 255, 252 / 255, 212 / 255)),
    ]
    for (format, color) in precisionCases {
      let roundTrip = format.parse(format.string(for: color))!
      precondition(ColorFormat.hex.string(for: roundTrip) == ColorFormat.hex.string(for: color))
    }

    let suite = "ColorDialChecks." + UUID().uuidString
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    defaults.set(red.components, forKey: "currentColor")
    defaults.set(green.components, forKey: "historyColor14")
    defaults.set([1], forKey: "historyColor13")
    defaults.set(true, forKey: "scientificMode")

    let session = ColorSession(defaults: defaults)
    precondition(session.sliderSpaces == [.rgb, .hsl])
    precondition(session.outputFormats == [.hex, .rgb, .hsl])
    session.sliderSpaces[1] = .lab
    session.outputFormats[2] = .oklch
    let restored = ColorSession(defaults: defaults)
    precondition(
      restored.sliderSpaces == [.rgb, .lab] && restored.outputFormats == [.hex, .rgb, .oklch])
    precondition(restored.current == red && session.current == red)
    defaults.set(["unknown", "OKLab", "RGB"], forKey: "sliderColorSpaces")
    defaults.set(["Lab"], forKey: "outputColorFormats")
    let partial = ColorSession(defaults: defaults)
    precondition(
      partial.sliderSpaces == [.rgb, .oklab] && partial.outputFormats == [.lab, .rgb, .hsl])
    precondition(session.history.count == 14 && session.history.last == green)
    precondition(session.wheel == .rgb)
    precondition(session.dialColor(offset: 120) == green)
    session.wheel = .artist
    precondition(session.dialColor(offset: 120) != green)
    precondition(!defaults.bool(forKey: "scientificMode"))

    session.toggleLock()
    session.select(blue)
    precondition(session.current == blue && session.base == red)
    precondition(ColorSession(defaults: defaults).current == red)
    session.saveBase()
    precondition(session.current == red && session.history.first == red)
    session.acceptSample(blue)
    precondition(session.current == blue && session.base == red && session.history.first == blue)
    session.toggleLock()
    precondition(session.base == blue && ColorSession(defaults: defaults).current == blue)

    let existing = session.history.last!
    session.acceptSample(existing)
    precondition(session.history.count == 14)
    precondition(
      session.history.first == existing && session.history.filter { $0 == existing }.count == 1)
    precondition(ColorSession(defaults: defaults).history == session.history)

    session.select(RGBColor(0, 0, 0))
    session.setChannel(0, in: .hsv, to: 240)
    session.setChannel(1, in: .hsv, to: 100)
    session.setChannel(2, in: .hsv, to: 100)
    precondition(session.current == blue)

    session.select(RGBColor(0, 0, 0))
    session.setChannel(0, in: .hsl, to: 240)
    session.setChannel(1, in: .hsl, to: 100)
    precondition(session.current == RGBColor(0, 0, 0))
    session.setChannel(2, in: .hsl, to: 50)
    precondition(session.current == blue)

    session.select(RGBColor(0.5, 0.5, 0.5))
    session.setChannel(2, in: .oklch, to: 42)
    precondition(session.channels(in: .oklch).z == 42)
    session.setChannel(1, in: .oklch, to: 0.4)
    precondition(session.isClipped(in: .oklch))
    precondition(session.channels(in: .oklch).y == 0.4)
    precondition(!session.isClipped(in: .lab))
    precondition(
      ColorFormat.oklch.parse(ColorFormat.oklch.string(for: session.current))!.isNear(
        session.current))
    session.select(red)
    precondition(!session.isClipped(in: .oklch) && session.channels(in: .oklch).y < 0.4)

    for base in [RGBColor.initial, red, green, blue, RGBColor(0, 0, 0), RGBColor(1, 1, 1)] {
      for wheel in HueWheel.allCases {
        for harmony in Harmony.allCases {
          let colors = harmony.colors(around: base, hsv: base.hsv, wheel: wheel)
          precondition(colors.count == 5 && colors[2] == base)
          precondition(colors.flatMap(\.components).allSatisfy { (0...1).contains($0) })
        }
      }
    }
    print("ColorDial checks passed")
  }
}
