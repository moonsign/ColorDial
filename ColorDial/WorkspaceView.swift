import AppKit
import SwiftUI

struct WorkspaceView: View {
  @Environment(\.appearsActive) private var appearsActive
  @Bindable var session: ColorSession
  let isSampling: Bool
  let sample: () -> Void
  @State private var colorWellFocused = false

  var body: some View {
    HStack(alignment: .top, spacing: rem(1.125)) {
      inspector
        .frame(width: rem(24.5))
      Divider()
      dialPanel
        .frame(width: rem(20.25))
      Divider()
      history
        .frame(width: rem(5.5))
    }
    .padding(rem(1.25))
    .fixedSize()
  }

  private var inspector: some View {
    VStack(alignment: .leading, spacing: rem(0.75)) {
      HStack {
        Text("Current Color").font(.headline)
        Spacer()
        Button(action: sample) {
          Label("Pick Screen Color", systemImage: "eyedropper")
        }
        .disabled(isSampling)
        .help("Pick a screen color (⇧⌘I)")
      }
      .frame(height: rem(1.75))

      CurrentColorWell(
        color: session.current, focused: $colorWellFocused, change: session.select
      )
      .frame(maxWidth: .infinity)
      .frame(height: rem(3.625))
      .overlay {
        colorWellFace
      }

      ForEach(session.sliderSpaces.indices, id: \.self) { index in
        SliderGroup(index: index, space: $session.sliderSpaces[index], session: session)
      }

      Divider()

      VStack(spacing: rem(0.375)) {
        ForEach(session.outputFormats.indices, id: \.self) { index in
          FormatRow(index: index, format: $session.outputFormats[index], session: session)
        }
      }
    }
  }

  private var colorWellFace: some View {
    let color = session.current
    let ink: Color = color.prefersDarkInk ? .black : .white
    let hasFocus = colorWellFocused && appearsActive
    return Canvas { context, size in
      let bounds = CGRect(origin: .zero, size: size)
      let shape = RoundedRectangle(cornerRadius: rem(0.625))
      let border = rem(0.0625)
      context.fill(shape.path(in: bounds), with: .color(color.swatch))
      context.stroke(
        shape.inset(by: border / 2).path(in: bounds), with: .color(.primary.opacity(0.16)),
        lineWidth: border)

      let iconSize = rem(0.875)
      var pencil = context.resolve(Image(systemName: "pencil"))
      pencil.shading = .color(ink)
      context.draw(
        pencil,
        in: CGRect(
          x: size.width - rem(1.75), y: (size.height - iconSize) / 2,
          width: iconSize, height: iconSize))

      if hasFocus {
        context.stroke(
          shape.inset(by: rem(0.1875)).path(in: bounds), with: .color(ink),
          lineWidth: rem(0.125))
      }
    }
    .allowsHitTesting(false)
    .accessibilityHidden(true)
  }

  private var dialPanel: some View {
    VStack(alignment: .leading, spacing: rem(0.75)) {
      HStack(spacing: rem(0.5)) {
        Text("Color Dial").font(.headline)
        Spacer()
        Picker("Hue wheel", selection: $session.wheel) {
          Text("RYB").tag(HueWheel.artist)
          Text("RGB").tag(HueWheel.rgb)
        }
        .labelsHidden()
        .pickerStyle(.segmented)
        .fixedSize()
        .help("Artist’s red–yellow–blue wheel or evenly spaced RGB hues")

        Button {
          session.toggleLock()
        } label: {
          Label(
            session.isLocked ? "Unlock Dial" : "Lock Dial",
            systemImage: session.isLocked ? "lock.fill" : "lock.open"
          )
          .labelStyle(.iconOnly)
        }
        .accessibilityValue(session.isLocked ? "Locked" : "Unlocked")
        .help(
          session.isLocked ? "Make the dial follow the current color" : "Hold the dial’s base color"
        )
      }
      .frame(height: rem(1.75))

      DialView(session: session)
        .frame(maxWidth: .infinity)

      Spacer(minLength: 0)

      harmony
    }
  }

  private var harmony: some View {
    VStack(alignment: .leading, spacing: rem(0.75)) {
      HStack {
        Text("Harmony").font(.headline)
        Spacer()
        Picker("Harmony", selection: $session.harmony) {
          ForEach(Harmony.allCases) { harmony in
            Text(harmony.rawValue).tag(harmony)
          }
        }
        .labelsHidden()
        .frame(width: rem(9.5))
      }

      let colors = session.harmony.colors(
        around: session.base, hsv: session.baseHSV, wheel: session.wheel)
      HStack(spacing: rem(0.375)) {
        ForEach(Array(colors.enumerated()), id: \.offset) { index, color in
          SwatchButton(
            color: color, title: index == 2 ? "Harmony base" : "Harmony color \(index + 1)"
          ) {
            session.select(color)
          }
          .frame(maxWidth: .infinity)
        }
      }
      .frame(height: rem(2.5))
    }
  }

  private var history: some View {
    VStack(alignment: .leading, spacing: rem(0.75)) {
      Text("History")
        .font(.headline)
        .frame(height: rem(1.75))
      VStack(spacing: rem(0.3125)) {
        ForEach(Array(session.history.enumerated()), id: \.offset) { index, color in
          SwatchButton(color: color, title: "History color \(index + 1)") {
            session.select(color)
          }
          .frame(maxWidth: .infinity, minHeight: rem(1.5), maxHeight: .infinity)
        }
      }
    }
    .accessibilityElement(children: .contain)
    .accessibilityLabel("Color history")
  }
}

private struct CurrentColorWell: NSViewRepresentable {
  let color: RGBColor
  @Binding var focused: Bool
  let change: (RGBColor) -> Void

  func makeCoordinator() -> Coordinator {
    Coordinator(focused: $focused, change: change)
  }

  func makeNSView(context: Context) -> PreviewColorWell {
    let well = PreviewColorWell(frame: .zero)
    well.supportsAlpha = false
    well.isContinuous = true
    well.focusRingType = .none
    well.focusChanged = { [weak coordinator = context.coordinator] focused in
      coordinator?.focused.wrappedValue = focused
    }
    well.target = context.coordinator
    well.action = #selector(Coordinator.didChange(_:))
    well.toolTip = "Edit the current color"
    well.setAccessibilityLabel("Edit current color")
    return well
  }

  func updateNSView(_ well: PreviewColorWell, context: Context) {
    context.coordinator.focused = $focused
    context.coordinator.change = change
    let nativeColor = color.nsColor
    if well.color != nativeColor {
      well.color = nativeColor
    }
    well.setAccessibilityValue(ColorFormat.hsl.string(for: color))
  }

  static func dismantleNSView(_ well: PreviewColorWell, coordinator: Coordinator) {
    well.focusChanged = nil
    well.deactivate()
  }

  @MainActor
  final class Coordinator: NSObject {
    var focused: Binding<Bool>
    var change: (RGBColor) -> Void

    init(focused: Binding<Bool>, change: @escaping (RGBColor) -> Void) {
      self.focused = focused
      self.change = change
    }

    @objc func didChange(_ sender: NSColorWell) {
      if let color = RGBColor(sender.color) {
        change(color)
      }
    }
  }
}

private final class PreviewColorWell: NSColorWell {
  var focusChanged: ((Bool) -> Void)?

  override func becomeFirstResponder() -> Bool {
    guard super.becomeFirstResponder() else { return false }
    publishFocus()
    return true
  }

  override func resignFirstResponder() -> Bool {
    guard super.resignFirstResponder() else { return false }
    publishFocus()
    return true
  }

  private func publishFocus() {
    // AppKit assigns firstResponder after these callbacks return.
    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      focusChanged?(window?.firstResponder === self)
    }
  }

  override func keyDown(with event: NSEvent) {
    guard isEnabled, event.charactersIgnoringModifiers == " ",
      event.modifierFlags.intersection([.command, .control, .option, .shift]).isEmpty
    else {
      super.keyDown(with: event)
      return
    }
    if !event.isARepeat { activate(true) }
  }
}

private struct FormatRow: View {
  let index: Int
  @Binding var format: ColorFormat
  let session: ColorSession
  @State private var copiedValue: String?

  var body: some View {
    let value = format.string(for: session.current)
    HStack(spacing: rem(0.5)) {
      Picker("Output format \(index + 1)", selection: $format) {
        ForEach(ColorFormat.allCases) { option in
          Text(option.rawValue).tag(option)
        }
      }
      .labelsHidden()
      .frame(width: rem(5.25))
      .help("Choose the CSS format for this row")

      ColorField(title: "\(format.rawValue) color value", value: value) { text in
        guard let result = format.conversion(for: text) else { return nil }
        session.select(result.color)
        return FieldEdit(value: format.string(for: session.current), clipped: result.clipped)
      }
      .id(format)

      Button {
        if copy(format, color: session.current) {
          copiedValue = value
          AccessibilityNotification.Announcement("Copied \(format.rawValue)").post()
        }
      } label: {
        Label {
          Text("Copy \(format.rawValue)")
        } icon: {
          Image(systemName: "document.on.document")
            .opacity(copiedValue == value ? 0 : 1)
            .overlay {
              if copiedValue == value {
                Image(systemName: "checkmark")
              }
            }
        }
        .labelStyle(.iconOnly)
      }
      .help("Copy \(format.rawValue)")
      .onChange(of: format) { copiedValue = nil }
      .task(id: copiedValue) {
        guard copiedValue != nil else { return }
        do {
          try await Task.sleep(for: .seconds(1.5))
          copiedValue = nil
        } catch {}
      }
    }
  }
}

private struct SliderGroup: View {
  let index: Int
  @Binding var space: ColorSpace
  let session: ColorSession

  var body: some View {
    VStack(alignment: .leading, spacing: rem(0.375)) {
      HStack {
        Picker(
          index == 0 ? "Top slider color space" : "Bottom slider color space", selection: $space
        ) {
          ForEach(ColorSpace.allCases) { option in
            Text(option.rawValue).tag(option)
          }
        }
        .labelsHidden()
        .controlSize(.small)
        .frame(width: rem(4.5))
        .help("Choose the color space for these sliders")

        Spacer()

        if session.isClipped(in: space) {
          Label("Clipped to sRGB", systemImage: "exclamationmark.triangle")
            .font(.caption)
            .foregroundStyle(.primary)
            .help("The preview and copied values use the clipped sRGB color.")
        }
      }
      .frame(height: rem(1.375))

      let values = session.channels(in: space)
      ForEach(0..<3) { channelIndex in
        ChannelRow(index: channelIndex, space: space, values: values, session: session)
      }
      .id(space)
    }
    .accessibilityElement(children: .contain)
    .accessibilityLabel(index == 0 ? "Top sliders" : "Bottom sliders")
  }
}

private struct ChannelRow: View {
  let index: Int
  let space: ColorSpace
  let values: SIMD3<Double>
  let session: ColorSession

  var body: some View {
    let channel = space.channels[index]
    let label = "\(space.rawValue) \(channel.title)"
    HStack(spacing: rem(0.5)) {
      Text(channel.symbol)
        .font(.callout.weight(.medium))
        .frame(width: rem(1), alignment: .leading)
        .accessibilityHidden(true)
      GradientSlider(
        label: label,
        value: values[index],
        range: channel.range,
        step: channel.step,
        colors: space.gradient(for: index, around: values)
      ) { session.setChannel(index, in: space, to: $0) }
      .frame(height: rem(1.25))

      ColorField(title: "\(label) value", value: channel.string(for: values[index])) { text in
        guard let number = Double(text), number.isFinite else { return nil }
        session.setChannel(index, in: space, to: number)
        return FieldEdit(value: channel.string(for: session.channels(in: space)[index]))
      }
      .multilineTextAlignment(.trailing)
      .frame(width: rem(4.25))
    }
  }
}

private struct FieldEdit {
  let value: String
  var clipped = false
}

private struct ColorField: View {
  let title: String
  let value: String
  let apply: (String) -> FieldEdit?
  @State private var draft: (text: String, result: FieldEdit?)?
  @FocusState private var editing: Bool

  private var invalid: Bool {
    draft != nil && draft?.result == nil
  }

  private var clipped: Bool { draft?.result?.clipped == true }

  private var feedback: String {
    if invalid { return "Enter a valid \(title)" }
    if clipped { return "Clipped to sRGB. The preview and copy use the clipped color." }
    return ""
  }

  var body: some View {
    TextField(
      title,
      text: Binding(
        get: { draft?.text ?? value },
        set: { text in draft = (text, apply(text)) }
      )
    )
    .labelsHidden()
    .font(.system(.callout, design: .monospaced))
    .textFieldStyle(.roundedBorder)
    .focused($editing)
    .onSubmit {
      if invalid {
        AccessibilityNotification.Announcement(feedback).post()
      } else {
        if clipped { AccessibilityNotification.Announcement(feedback).post() }
        draft = nil
      }
    }
    .onExitCommand { draft = nil }
    .onChange(of: editing) { _, focused in
      if !focused { draft = nil }
    }
    .onChange(of: value) { _, updated in
      // Keep the text the user typed while the model reflects that edit.
      if draft?.result?.value != updated { draft = nil }
    }
    .overlay {
      if invalid {
        RoundedRectangle(cornerRadius: rem(0.3125))
          .strokeBorder(.red, lineWidth: rem(0.125))
          .allowsHitTesting(false)
          .accessibilityHidden(true)
      }
    }
    .overlay(alignment: .topTrailing) {
      if invalid || clipped {
        Image(systemName: invalid ? "exclamationmark.circle.fill" : "exclamationmark.triangle.fill")
          .font(.system(size: rem(0.6875), weight: .semibold))
          .foregroundStyle(invalid ? Color.red : Color.primary)
          .background(.background, in: Circle())
          .offset(x: rem(0.25), y: -rem(0.25))
          .allowsHitTesting(false)
          .accessibilityHidden(true)
      }
    }
    .accessibilityHint(feedback)
    .help(feedback.isEmpty ? title : feedback)
  }
}
