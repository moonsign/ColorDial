import AppKit
import SwiftUI

@main
struct ColorDialApp: App {
  @NSApplicationDelegateAdaptor(ApplicationDelegate.self) private var delegate
  @State private var session = ColorSession()
  @State private var isSampling = false

  var body: some Scene {
    Window("ColorDial", id: "dial") {
      WorkspaceView(session: session, isSampling: isSampling, sample: sample)
    }
    .defaultSize(width: rem(45), height: rem(33))
    .windowResizability(.contentSize)
    .commands {
      CommandGroup(after: .pasteboard) {
        Menu("Copy Color As") {
          ForEach(ColorFormat.allCases) { format in
            Button(format.rawValue) { copy(format, color: session.current) }
          }
        }
        Button("Pick Screen Color", action: sample)
          .keyboardShortcut("i", modifiers: [.command, .shift])
          .disabled(isSampling)
        Button("Save Dial Color to History") { session.saveBase() }
          .keyboardShortcut("d", modifiers: [.command, .shift])
      }
    }
  }

  private func sample() {
    guard !isSampling else { return }
    isSampling = true
    Task { @MainActor in
      defer { isSampling = false }
      let sampler = NSColorSampler()
      if let color = await sampler.sample(), let rgb = RGBColor(color) {
        session.acceptSample(rgb)
      }
    }
  }
}

private final class ApplicationDelegate: NSObject, NSApplicationDelegate {
  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    true
  }
}

extension RGBColor {
  init?(_ color: NSColor) {
    guard let rgb = color.usingColorSpace(.sRGB) else { return nil }
    self.init(rgb.redComponent, rgb.greenComponent, rgb.blueComponent)
  }

  var nsColor: NSColor {
    NSColor(srgbRed: red, green: green, blue: blue, alpha: 1)
  }

  var swatch: Color {
    Color(.sRGB, red: red, green: green, blue: blue)
  }
}

// Native SwiftUI and AppKit geometry use points. Convert from the 16-point design scale at the boundary.
func rem(_ value: CGFloat) -> CGFloat {
  value * 16
}

@discardableResult
func copy(_ format: ColorFormat, color: RGBColor) -> Bool {
  let pasteboard = NSPasteboard.general
  pasteboard.clearContents()
  return pasteboard.setString(format.string(for: color), forType: .string)
}
