# <img src="/ColorDial/Assets.xcassets/AppIcon.appiconset/icon_128x128.png" width="32" height="32"/> ColorDial

ColorDial 2 is an Apple silicon fork of [Norganna’s ColorDial](https://github.com/NorgannasAddOns/ColorDial). The November 12, 2026 port rebuilds the workspace in SwiftUI and uses AppKit for native controls and screen sampling.

## Download

Get the Apple silicon ZIP from [GitHub Releases](https://github.com/moonsign/ColorDial/releases/latest). ColorDial 2 requires macOS 27 or later. The app in the ZIP is ad hoc signed and macOS may block it at first launch. You can also [build from source](#build-and-verify).

## Information

ColorDial is a native macOS color utility. The two slider groups start in RGB and HSL. Each can switch to RGB, HSL, HSV, Lab, LCH, OKLab, or OKLCH. Arrow keys move the focused slider by one increment. The three editable CSS rows start in Hex, RGB, and HSL and can switch individually to any supported CSS format, including Lab, LCH, OKLab, and OKLCH. Click the main swatch to edit the current color. Use **Pick Screen Color** or **⇧⌘I** to sample the screen. The dial offers RYB and RGB wheels, six harmonies, and a lock that holds the base color while you explore. Use the dial’s **+** or **⇧⌘D** to add the base to the 14-swatch History column on the right. The system eyedropper adds one sample to history per invocation.

ColorDial stores and previews sRGB colors. Perceptual sliders retain the entered coordinates and show **Clipped to sRGB** when the color falls outside that gamut. An out-of-gamut CSS draft also shows a warning, and the field displays the clipped value after editing. The preview, history, and copied values use the clipped color. Lab and LCH use the CSS D50 white point. OKLab and OKLCH use D65. The five picker choices are saved with the app’s preferences. [CSS Color 4](https://www.w3.org/TR/css-color-4/#lab-colors)

See the [original ColorDial website](https://norgannasaddons.github.io/ColorDial/) for the earlier design.

## Build and verify

ColorDial 2 uses Swift 6 and SwiftUI on Apple silicon with macOS 27 or later. AppKit provides screen sampling, clipboard and color drag data, and the native slider controls. The Xcode target uses ad hoc signing for local builds.

```sh
xcodebuild -project ColorDial.xcodeproj -scheme ColorDial -configuration Release \
  -destination 'platform=macOS,arch=arm64' -derivedDataPath build build
open build/Build/Products/Release/ColorDial.app
```

For a side-by-side install with the original App Store app, add `PRODUCT_BUNDLE_IDENTIFIER=com.norganna.ColorDial.local` to the build command. This gives the local build its own sandbox and history. With access to the original preferences domain, the port reads the original current color, history, and wheel mode keys.

The model checks cover CSS parsing, perceptual conversion reference vectors, gamut clipping, color-space defaults and restoration, both wheel modes, harmony generation, lock and sample transitions, and legacy preference keys.

```sh
mkdir -p build
xcrun swiftc -swift-version 6 ColorDial/Color.swift ColorDial/ColorSpace.swift \
  ColorDial/PerceptualColor.swift ColorDial/Harmony.swift ColorDial/ColorSession.swift Tests/ColorDialChecks.swift -o build/ColorDialChecks
build/ColorDialChecks
```

For a window check, switch each slider group and CSS row independently, exercise signed and fractional edits and an out-of-gamut value, switch wheels and harmonies, hold and release the dial lock, copy a value, and select a history swatch. Confirm both a sample and Escape cancellation. Review the window in light and dark appearance and use Tab and Space to exercise the swatches.

## License

Copyright 2015 Norganna's AddOns Pty Ltd, released under the GNU Affero GPL v3.0.
