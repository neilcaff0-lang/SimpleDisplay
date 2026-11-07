import SwiftUI

struct DisplayRowView: View {
    @Environment(DisplayManagerViewModel.self) private var viewModel
    @Environment(LocaleManager.self) private var locale
    let display: DisplayInfo

    private var isConfiguring: Bool {
        viewModel.navigationState == .configuringDisplay(display.id)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(verbatim: display.name)
                        .font(.system(size: 16, weight: .semibold))
                        .lineLimit(2)
                    HStack(spacing: 6) {
                        Circle().fill(display.isActive ? Color.green : Color.secondary)
                            .frame(width: 5, height: 5).accessibilityHidden(true)
                        Text(verbatim: statusText)
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 8)
                Toggle(display.name, isOn: Binding(
                    get: { display.isActive },
                    set: { _ in viewModel.toggleDisplay(display) }
                ))
                .labelsHidden().toggleStyle(.switch).controlSize(.small)
                .accessibilityLabel("\(display.name), \(locale.t("display_enabled"))")
                .disabled(viewModel.isBusy || (display.isActive && viewModel.activeDisplays.count <= 1))
            }

            if !display.isPlaceholder {
                HStack(alignment: .center, spacing: 20) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text(locale.t("desktop_size"))
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                        Text(verbatim: "\(display.currentMode.width) × \(display.currentMode.height)")
                            .font(.system(size: 32, weight: .medium, design: .rounded))
                            .monospacedDigit().minimumScaleFactor(0.75).lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    DisplaySilhouette().frame(width: 116, height: 82)
                        .accessibilityHidden(true)
                }
                HStack(alignment: .top, spacing: 12) {
                    DisplayMetric(title: locale.t("render_pixels"),
                        value: "\(display.currentMode.pixelWidth) × \(display.currentMode.pixelHeight)")
                    DisplayMetric(title: locale.t("render_scale"),
                        value: display.currentMode.isHiDPI ? "HiDPI · 2×" : "1×")
                    DisplayMetric(title: locale.t("refresh_rate"),
                        value: display.currentMode.localizedRefreshRate(locale))
                }
            }

            Rectangle().fill(Color.primary.opacity(0.07)).frame(height: 1)
            HStack(spacing: 16) {
                if !display.isPlaceholder { modeMenu }
                Spacer(minLength: 8)
                if display.isVirtual {
                    Button {
                        viewModel.navigate(to: .configuringDisplay(display.id))
                    } label: {
                        HStack(spacing: 5) {
                            Text(locale.t("configure_display"))
                            Image(systemName: "arrow.up.right").font(.system(size: 9, weight: .semibold))
                        }
                    }
                    .buttonStyle(.plain).font(.system(size: 12, weight: .medium))
                    .disabled(viewModel.isBusy || viewModel.isNavigating)
                }
                Menu {
                    if !display.isMain && display.isActive {
                        Button(locale.t("badge_set_main")) { viewModel.setAsMainDisplay(display) }
                    }
                    if display.isActive && !display.isVirtual {
                        Button(locale.t(display.isMirrored ? "unmirror_button_help" : "mirror_button_help")) {
                            viewModel.toggleMirror(display)
                        }
                        .disabled(!display.isMirrored && viewModel.activeDisplays.count < 2)
                    }
                    Button(locale.t("refresh_displays")) { viewModel.refresh() }
                } label: {
                    Image(systemName: "ellipsis").font(.system(size: 14, weight: .medium))
                        .frame(width: 22, height: 20)
                }
                .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
                .accessibilityLabel(locale.t("more_actions"))
                .disabled(viewModel.isBusy)
            }
        }
        .padding(24)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.primary.opacity(0.08)))
        .opacity(display.isActive ? 1 : 0.65)
    }

    private var statusText: String {
        var parts = [locale.t(display.isActive ? "display_connected" : "badge_disabled")]
        if display.isVirtual { parts.append(locale.t("badge_virtual")) }
        if display.isMain { parts.append(locale.t("badge_main")) }
        if display.isMirrored { parts.append(locale.t("mirror_button_help")) }
        return parts.joined(separator: " · ")
    }

    /// Resolution and zoom picker. The caption of the row is the menu: sizes
    /// grouped as Retina ("looks like", HiDPI) and native, largest first; a size
    /// with several refresh rates opens a submenu, otherwise it applies directly
    /// keeping the current rate when offered.
    @ViewBuilder
    private var modeMenu: some View {
        let groups = display.modeGroups
        let hidpi = groups.filter { $0.isHiDPI }
        let native = groups.filter { !$0.isHiDPI }
        Menu {
            if !hidpi.isEmpty {
                Section(locale.t("mode_section_hidpi")) {
                    ForEach(hidpi) { group in modeItem(group) }
                }
            }
            if !native.isEmpty {
                Section(locale.t("mode_section_native")) {
                    ForEach(native) { group in modeItem(group) }
                }
            }
        } label: {
            HStack(spacing: 3) {
                Text(locale.t("resolution_modes"))
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .semibold))
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .disabled(viewModel.isBusy || !display.isActive || display.isMirrored || groups.isEmpty)
        .help(locale.t("mode_menu_help"))
    }

    @ViewBuilder
    private func modeItem(_ group: ModeGroup) -> some View {
        let isCurrent = group.width == display.currentMode.width
            && group.height == display.currentMode.height
            && group.isHiDPI == display.currentMode.isHiDPI
        if group.modes.count > 1 {
            Menu {
                ForEach(group.modes) { mode in
                    Button {
                        viewModel.changeResolution(of: display, to: mode)
                    } label: {
                        if mode == display.currentMode {
                            Label(mode.localizedRefreshRate(locale), systemImage: "checkmark")
                        } else {
                            Text(verbatim: mode.localizedRefreshRate(locale))
                        }
                    }
                }
            } label: {
                if isCurrent {
                    Label(group.sizeString, systemImage: "checkmark")
                } else {
                    Text(verbatim: group.sizeString)
                }
            }
        } else {
            Button {
                viewModel.changeResolution(of: display, to: group.preferredMode(near: display.currentMode))
            } label: {
                if isCurrent {
                    Label(group.sizeString, systemImage: "checkmark")
                } else {
                    Text(verbatim: group.sizeString)
                }
            }
        }
    }

    private var iconName: String {
        if display.isVirtual { return "rectangle.dashed" }
        if display.isBuiltIn { return "laptopcomputer" }
        return "display"
    }

    private var iconColor: Color {
        if !display.isActive { return .gray }
        if display.isVirtual { return .purple }
        return .blue
    }
}

struct BadgeView: View {
    let text: String
    let color: Color

    var body: some View {
        Text(verbatim: text)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}
