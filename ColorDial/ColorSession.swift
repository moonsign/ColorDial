import Foundation
import Observation

@MainActor
@Observable
final class ColorSession {
  private let defaults: UserDefaults
  private(set) var current: RGBColor
  private(set) var hsv: HSV
  private(set) var history: [RGBColor]
  private var locked: RGBColor?
  private var lockedHSV: HSV?

  // The last slider edit retains its coordinates even when the sRGB preview clips.
  // Selecting a different color clears them so both groups follow the new color.
  private var channelEdit: (space: ColorSpace, values: SIMD3<Double>, clipped: Bool)?

  var sliderSpaces: [ColorSpace] {
    didSet { defaults.set(sliderSpaces.map(\.rawValue), forKey: "sliderColorSpaces") }
  }

  var outputFormats: [ColorFormat] {
    didSet { defaults.set(outputFormats.map(\.rawValue), forKey: "outputColorFormats") }
  }

  var harmony: Harmony = .analogous
  var wheel: HueWheel {
    didSet { defaults.set(wheel == .rgb, forKey: "scientificMode") }
  }

  var isLocked: Bool { locked != nil }
  var base: RGBColor { locked ?? current }
  var baseHSV: HSV { lockedHSV ?? hsv }

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    sliderSpaces = Self.choices(
      defaults.stringArray(forKey: "sliderColorSpaces"), defaults: [.rgb, .hsl])
    outputFormats = Self.choices(
      defaults.stringArray(forKey: "outputColorFormats"), defaults: [.hex, .rgb, .hsl])
    let initial = Self.readColor("currentColor", from: defaults) ?? .initial
    current = initial
    hsv = initial.hsv
    wheel = defaults.bool(forKey: "scientificMode") ? .rgb : .artist
    history = (0..<14).map { index in
      let i = Double(index)
      return Self.readColor("historyColor\(index + 1)", from: defaults)
        ?? RGBColor(hsv: HSV(hue: 15 + i * 25, saturation: 0.40 + i * 0.06, value: 0.95 - i * 0.03))
    }
  }

  private static func choices<Choice: RawRepresentable>(
    _ stored: [String]?, defaults: [Choice]
  ) -> [Choice] where Choice.RawValue == String {
    let stored = stored ?? []
    return defaults.enumerated().map { index, fallback in
      guard stored.indices.contains(index) else { return fallback }
      return Choice(rawValue: stored[index]) ?? fallback
    }
  }

  private static func readColor(_ key: String, from defaults: UserDefaults) -> RGBColor? {
    guard let values = defaults.array(forKey: key) as? [Double],
      values.count == 3, values.allSatisfy({ $0.isFinite && (0...1).contains($0) })
    else { return nil }
    return RGBColor(values[0], values[1], values[2])
  }

  func toggleLock() {
    if isLocked {
      locked = nil
      lockedHSV = nil
      persistCurrent()
    } else {
      locked = current
      lockedHSV = hsv
    }
  }

  func select(_ color: RGBColor) {
    apply(color, hsv: color.hsv)
  }

  func saveBase() {
    apply(base, hsv: baseHSV)
    addToHistory(current)
  }

  func acceptSample(_ color: RGBColor) {
    select(color)
    addToHistory(color)
  }

  private func apply(_ color: RGBColor, hsv: HSV) {
    channelEdit = nil
    current = color
    self.hsv = hsv
    if !isLocked { persistCurrent() }
  }

  private func persistCurrent() {
    defaults.set(current.components, forKey: "currentColor")
  }

  private func addToHistory(_ color: RGBColor) {
    if history.first?.isNear(color) == true { return }
    if let match = history.firstIndex(where: { $0.isNear(color) }) {
      history.remove(at: match)
    } else {
      history.removeLast()
    }
    history.insert(color, at: 0)
    for (index, swatch) in history.enumerated() {
      defaults.set(swatch.components, forKey: "historyColor\(index + 1)")
    }
  }

  func dialColor(offset: Double) -> RGBColor {
    guard offset != 0 else { return base }
    let hue = wheel.hue(baseHSV.hue, offset: offset)
    return RGBColor(hsv: HSV(hue: hue, saturation: baseHSV.saturation, value: baseHSV.value))
  }

  func selectHue(offset: Double) {
    let hue = wheel.hue(baseHSV.hue, offset: offset)
    let next = HSV(hue: hue, saturation: baseHSV.saturation, value: baseHSV.value)
    apply(RGBColor(hsv: next), hsv: next)
  }

  func adjusted(saturation: Double = 0, lightness: Double = 0) -> RGBColor {
    let (_, s, l) = base.hsl
    return RGBColor(hue: baseHSV.hue, saturation: s + saturation, lightness: l + lightness)
  }

  func channels(in space: ColorSpace) -> SIMD3<Double> {
    if let channelEdit, channelEdit.space == space {
      return channelEdit.values
    }
    return space.coordinates(of: current, hsv: hsv)
  }

  func isClipped(in space: ColorSpace) -> Bool {
    channelEdit?.space == space && channelEdit?.clipped == true
  }

  func setChannel(_ index: Int, in space: ColorSpace, to value: Double) {
    guard value.isFinite else { return }
    var values = channels(in: space)
    values[index] = space.channels[index].clamp(value)
    let result = space.convert(values)
    let displayedHSV = result.color.hsv
    let nextHSV: HSV
    switch space {
    case .hsv:
      nextHSV = HSV(hue: values.x, saturation: values.y / 100, value: values.z / 100)
    case .hsl:
      nextHSV = HSV(hue: values.x, saturation: displayedHSV.saturation, value: displayedHSV.value)
    default:
      nextHSV = displayedHSV
    }

    apply(result.color, hsv: nextHSV)
    channelEdit = (space, values, result.clipped)
  }
}
