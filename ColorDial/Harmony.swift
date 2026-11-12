// Derived from ColorDial’s original harmony algorithms by Kenneth Allan.
// Copyright © 2015 Kenneth Allan. All rights reserved.

import Foundation

enum HueWheel: String, CaseIterable, Identifiable {
  case artist = "RYB"
  case rgb = "RGB"

  var id: Self { self }

  func hue(_ hue: Double, offset: Double) -> Double {
    if offset == 0 { return hue }
    func wrap(_ angle: Double) -> Double {
      (angle + 360).truncatingRemainder(dividingBy: 360)
    }
    switch self {
    case .artist: return convertHueRYBtoRGB(wrap(convertHueRGBtoRYB(hue) + offset))
    case .rgb: return wrap(hue + offset)
    }
  }
}

enum Harmony: String, CaseIterable, Identifiable {
  case analogous = "Analogous"
  case complementary = "Complementary"
  case compound = "Compound"
  case monochromatic = "Monochromatic"
  case shades = "Shades"
  case triadic = "Triadic"

  var id: Self { self }

  func colors(around base: RGBColor, hsv: HSV, wheel: HueWheel) -> [RGBColor] {
    let h = hsv.hue
    let s = hsv.saturation * 100
    let v = hsv.value * 100

    func addHue(_ hue: Double, _ offset: Double) -> Double {
      wheel.hue(hue, offset: offset)
    }

    func swatch(_ hue: Double, s: Double, v: Double) -> RGBColor {
      RGBColor(hsv: HSV(hue: hue, saturation: s / 100, value: v / 100))
    }

    switch self {
    case .analogous:
      return [
        swatch(
          addHue(h, 30), s: addValueOverflowBounce(s, 5), v: addValueOverflowSlow(v, 5, min: 20)),
        swatch(
          addHue(h, 15), s: addValueOverflowBounce(s, 5), v: addValueOverflowFlip(v, 9, min: 20)),
        base,
        swatch(
          addHue(h, -15), s: addValueOverflowBounce(s, 5), v: addValueOverflowFlip(v, 9, min: 20)),
        swatch(
          addHue(h, -30), s: addValueOverflowBounce(s, 5), v: addValueOverflowSlow(v, 5, min: 20)),
      ]
    case .complementary:
      return [
        swatch(
          addHue(h, 0), s: addValueOverflowSlow(s, 10), v: addValueOverflowFlip(v, -30, lcap: 20)),
        swatch(addHue(h, 0), s: addValueOverflowCap(s, -10), v: addValueOverflowCap(v, 30)),
        base,
        swatch(
          addHue(h, 180), s: addValueOverflowCap(s, 20), v: addValueOverflowFlip(v, -30, lcap: 20)),
        swatch(addHue(h, 180), s: s, v: v),
      ]
    case .compound:
      return [
        swatch(addHue(h, 30), s: addValueOverflowFlip(s, 10), v: addValueOverflowFlip(v, 20)),
        swatch(addHue(h, 30), s: addValueOverflowFlip(s, -40), v: addValueOverflowFlip(v, 40)),
        base,
        swatch(
          addHue(h, 165), s: addValueOverflowFlip(s, -25), v: addValueOverflowSlow(v, 5, brake: 40)),
        swatch(addHue(h, 150), s: addValueOverflowFlip(s, 10), v: addValueOverflowCap(v, 20)),
      ]
    case .monochromatic:
      return [
        swatch(addHue(h, 0), s: addValueOverflowCap(s, 0), v: addValueOverflowFlip(v, 30)),
        swatch(
          addHue(h, 0), s: addValueOverflowFlip(s, -30), v: addValueOverflowSlow(v, 10, brake: 50)),
        base,
        swatch(addHue(h, 0), s: addValueOverflowFlip(s, -30), v: addValueOverflowFlip(v, 30)),
        swatch(
          addHue(h, 0), s: addValueOverflowCap(s, 0), v: addValueOverflowOppose(v, 60, roffs: 20)),
      ]
    case .shades:
      return [
        swatch(
          addHue(h, 0), s: addValueOverflowCap(s, 0), v: addValueOverflowFlip(v, -25, lcap: 20)),
        swatch(
          addHue(h, 0), s: addValueOverflowCap(s, 0), v: addValueOverflowFlip(v, -50, lcap: 20)),
        base,
        swatch(addHue(h, 0), s: addValueOverflowCap(s, 0), v: addValueOverflowFlip(v, -75)),
        swatch(
          addHue(h, 0), s: addValueOverflowCap(s, 0), v: addValueOverflowSlow(v, -10, brake: 15)),
      ]
    case .triadic:
      return [
        swatch(
          addHue(h, 0), s: addValueOverflowFlip(s, 10), v: addValueOverflowFlip(v, -30, lcap: 20)),
        swatch(
          addHue(h, 120), s: addValueOverflowFlip(s, -10),
          v: addValueOverflowSlow(v, 5, min: 20, brake: 30)),
        base,
        swatch(
          addHue(h, -120), s: addValueOverflowFlip(s, 10), v: addValueOverflowFlip(v, -20, lcap: 20)
        ),
        swatch(addHue(h, -120), s: addValueOverflowFlip(s, 5), v: addValueOverflowFlip(v, 30)),
      ]
    }
  }
}

private func mapRange(
  _ value: Double, _ fromLower: Double, _ fromUpper: Double, _ toLower: Double, _ toUpper: Double
) -> Double {
  return (round((toLower) + (value - fromLower) * ((toUpper - toLower) / (fromUpper - fromLower))))
}

private func convertHueRYBtoRGB(_ hue: Double) -> Double {
  if hue < 60 { return (round((hue) * (35 / 60))) }
  if hue < 122 { return mapRange(hue, 60, 122, 35, 60) }
  if hue < 165 { return mapRange(hue, 122, 165, 60, 120) }
  if hue < 218 { return mapRange(hue, 165, 218, 120, 180) }
  if hue < 275 { return mapRange(hue, 218, 275, 180, 240) }
  if hue < 330 { return mapRange(hue, 275, 330, 240, 300) }
  return mapRange(hue, 330, 360, 300, 360)
}

private func convertHueRGBtoRYB(_ hue: Double) -> Double {
  if hue < 35 { return (round(hue * (60 / 35))) }
  if hue < 60 { return mapRange(hue, 35, 60, 60, 122) }
  if hue < 120 { return mapRange(hue, 60, 120, 122, 165) }
  if hue < 180 { return mapRange(hue, 120, 180, 165, 218) }
  if hue < 240 { return mapRange(hue, 180, 240, 218, 275) }
  if hue < 300 { return mapRange(hue, 240, 300, 275, 330) }
  return mapRange(hue, 300, 360, 330, 360)
}

private func addValueOverflowCap(
  _ v: Double, _ add: Double, cap: Double = 100, min: Double = -1, max: Double = -1
) -> Double {
  var w = v + add
  if min > -1 && w < min { w = min }
  if max > -1 && w > max { w = max }

  if w > cap {
    return cap
  } else if w < 0 {
    return 0
  }
  return w
}

private func addValueOverflowFlip(
  _ v: Double, _ add: Double, cap: Double = 100, lcap: Double = 0, min: Double = -1,
  max: Double = -1
) -> Double {
  var w = v + add
  if min > -1 && w < min { w = min }
  if max > -1 && w > max { w = max }

  // If we overflow, need to subtract instead
  if w > cap || w < lcap {
    return v - add
  }

  return w
}

private func addValueOverflowBounce(
  _ v: Double, _ add: Double, cap: Double = 100, lcap: Double = 0, min: Double = -1,
  max: Double = -1
) -> Double {
  var w = v + add
  if min > -1 && w < min { w = min }
  if max > -1 && w > max { w = max }

  // If we overflow, need to subtract overflow amount
  if w > cap {
    return cap - (w - cap)
  } else if w < lcap {
    return lcap + (lcap - w)
  }
  return w
}

private func addValueOverflowSlow(
  _ v: Double, _ add: Double, cap: Double = 100, lcap: Double = 0, min: Double = -1,
  max: Double = -1, brake: Double = -1
) -> Double {
  var w = v + add
  if min > -1 && w < min { w = min }
  if max > -1 && w > max { w = max }

  let b = brake > -1 ? brake : abs(add)

  // Stop us from overflowing by slowing add down (by 50%) as we approch cap.
  if w > cap - b {
    let d = v - (cap - b)
    w = v + (floor((add) * (d) / (b)))
    return w
  } else if w < lcap + b {
    let d = lcap + b - w
    w += (floor((d) / 2))
  }
  return w
}

private func addValueOverflowOppose(
  _ v: Double, _ add: Double, cap: Double = 100, roffs: Double = 0
) -> Double {
  var w = v + add
  if w > cap { w = (roffs + w).truncatingRemainder(dividingBy: cap) }
  return w
}
