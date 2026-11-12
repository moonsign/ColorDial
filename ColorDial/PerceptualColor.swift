import Foundation
import simd

// CSS Color 4 §19 uses CIE Lab relative to D50. These two matrices combine
// the sRGB↔XYZ D65 transform with Bradford adaptation between D65 and D50.
private enum PerceptualTransform {
  static let d50 = SIMD3(0.3457 / 0.3585, 1.0, (1 - 0.3457 - 0.3585) / 0.3585)
  static let labEpsilon = 216.0 / 24_389
  static let labKappa = 24_389.0 / 27

  static let linearRGBToD50 = simd_double3x3(rows: [
    SIMD3(0.4360657468742695, 0.3851515095901598, 0.1430784199651387),
    SIMD3(0.2224931771105653, 0.7168870130944824, 0.0606198097949524),
    SIMD3(0.0139239214631694, 0.0970813242314102, 0.7140993568158808),
  ])

  static let d50ToLinearRGB = simd_double3x3(rows: [
    SIMD3(3.1341358529001173, -1.6173859980180427, -0.4906622179110973),
    SIMD3(-0.9787954765557777, 1.9162543773959886, 0.0334428733903669),
    SIMD3(0.0719553925579474, -0.2289767598151820, 1.4053860351131182),
  ])

  // D65 matrices from Björn Ottosson’s definition of Oklab.
  static let linearRGBToLMS = simd_double3x3(rows: [
    SIMD3(0.4122214708, 0.5363325363, 0.0514459929),
    SIMD3(0.2119034982, 0.6806995451, 0.1073969566),
    SIMD3(0.0883024619, 0.2817188376, 0.6299787005),
  ])
  static let lmsToOklab = simd_double3x3(rows: [
    SIMD3(0.2104542553, 0.7936177850, -0.0040720468),
    SIMD3(1.9779984951, -2.4285922050, 0.4505937099),
    SIMD3(0.0259040371, 0.7827717662, -0.8086757660),
  ])
  static let oklabToLMS = simd_double3x3(rows: [
    SIMD3(1, 0.3963377774, 0.2158037573),
    SIMD3(1, -0.1055613458, -0.0638541728),
    SIMD3(1, -0.0894841775, -1.2914855480),
  ])
  static let lmsToLinearRGB = simd_double3x3(rows: [
    SIMD3(4.0767416621, -3.3077115913, 0.2309699292),
    SIMD3(-1.2684380046, 2.6097574011, -0.3413193965),
    SIMD3(-0.0041960863, -0.7034186147, 1.7076147010),
  ])
}

extension RGBColor {
  var lab: SIMD3<Double> {
    let xyz = PerceptualTransform.linearRGBToD50 * linearRGB / PerceptualTransform.d50
    let f = mapped(xyz) { value in
      value > PerceptualTransform.labEpsilon
        ? cbrt(value)
        : (PerceptualTransform.labKappa * value + 16) / 116
    }
    let lightness = 116 * f.y - 16
    if red == green && green == blue { return SIMD3(lightness, 0, 0) }
    return SIMD3(lightness, 500 * (f.x - f.y), 200 * (f.y - f.z))
  }

  var oklab: SIMD3<Double> {
    if red == green && green == blue { return SIMD3(cbrt(linearSRGB(red)), 0, 0) }
    let lms = PerceptualTransform.linearRGBToLMS * linearRGB
    return PerceptualTransform.lmsToOklab * mapped(lms, cbrt)
  }

  private var linearRGB: SIMD3<Double> {
    mapped(SIMD3(red, green, blue), linearSRGB)
  }

  static func convertLab(_ lab: SIMD3<Double>) -> (color: RGBColor, clipped: Bool) {
    let lightness = unit(lab.x / 100) * 100
    if lightness == 0 || lightness == 100 {
      return (RGBColor(lightness / 100, lightness / 100, lightness / 100), lab.y != 0 || lab.z != 0)
    }
    let fy = (lightness + 16) / 116
    let f = SIMD3(fy + lab.y / 500, fy, fy - lab.z / 200)
    let xyz = mapped(f) { value in
      let cube = value * value * value
      return cube > PerceptualTransform.labEpsilon
        ? cube : (116 * value - 16) / PerceptualTransform.labKappa
    }
    if lab.y == 0 && lab.z == 0 { return fromLinear(SIMD3(repeating: xyz.y)) }
    return fromLinear(PerceptualTransform.d50ToLinearRGB * (xyz * PerceptualTransform.d50))
  }

  static func convertOklab(_ lab: SIMD3<Double>) -> (color: RGBColor, clipped: Bool) {
    let lightness = unit(lab.x)
    if lightness == 0 || lightness == 1 {
      return (RGBColor(lightness, lightness, lightness), lab.y != 0 || lab.z != 0)
    }
    if lab.y == 0 && lab.z == 0 {
      return fromLinear(SIMD3(repeating: lightness * lightness * lightness))
    }
    let lms = PerceptualTransform.oklabToLMS * SIMD3(lightness, lab.y, lab.z)
    return fromLinear(PerceptualTransform.lmsToLinearRGB * (lms * lms * lms))
  }

  private static func fromLinear(_ value: SIMD3<Double>) -> (color: RGBColor, clipped: Bool) {
    // Matrix rounding can put in-gamut primaries just outside the interval.
    let tolerance = 0.000_001
    let clipped = (0..<3).contains { value[$0] < -tolerance || value[$0] > 1 + tolerance }
    let encoded = mapped(value) { component in
      let bounded = unit(component)
      return bounded <= 0.0031308 ? 12.92 * bounded : 1.055 * pow(bounded, 1 / 2.4) - 0.055
    }
    return (RGBColor(encoded.x, encoded.y, encoded.z), clipped)
  }
}

func polar(_ lab: SIMD3<Double>, powerlessChroma: Double) -> SIMD3<Double> {
  let chroma = hypot(lab.y, lab.z)
  guard chroma > powerlessChroma else { return SIMD3(lab.x, 0, 0) }
  return SIMD3(lab.x, chroma, wrappedHue(atan2(lab.z, lab.y) * 180 / .pi))
}

func rectangular(_ lch: SIMD3<Double>) -> SIMD3<Double> {
  let angle = wrappedHue(lch.z) * .pi / 180
  return SIMD3(lch.x, lch.y * cos(angle), lch.y * sin(angle))
}

func linearSRGB(_ component: Double) -> Double {
  component <= 0.04045 ? component / 12.92 : pow((component + 0.055) / 1.055, 2.4)
}

private func mapped(
  _ values: SIMD3<Double>, _ transform: (Double) -> Double
) -> SIMD3<Double> {
  SIMD3(transform(values.x), transform(values.y), transform(values.z))
}
