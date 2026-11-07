import SwiftUI

/// Create or edit a virtual display. Pass `editing` to edit an existing one.
/// A compact editor separating desktop dimensions, backing pixels and refresh.
struct VirtualDisplayEditorView: View {
    @Environment(DisplayManagerViewModel.self) private var viewModel
    @Environment(LocaleManager.self) private var locale

    let editing: DisplayInfo?
    /// Panel size and zoom the display was created with. The live mode can differ
    /// (a zoom level picked from the row menu, or macOS's remembered mode), so
    /// the editor starts from the saved config, not from what is on screen.
    private let saved: VirtualDisplayService.VirtualDisplayConfig?

    @State private var name: String
    @State private var width: Int
    @State private var height: Int
    @State private var hiDPI: Bool
    @State private var refreshRate: Double
    @State private var confirmRemoval = false

    private var isEditing: Bool { editing != nil }
    private var isOnlyActiveDisplay: Bool {
        editing?.isActive == true && viewModel.activeDisplays.count <= 1
    }

    init(editing: DisplayInfo? = nil, saved: VirtualDisplayService.VirtualDisplayConfig? = nil) {
        self.editing = editing
        self.saved = saved
        if let d = editing {
            _name = State(initialValue: d.name)
            _width = State(initialValue: saved?.width ?? d.currentMode.width)
            _height = State(initialValue: saved?.height ?? d.currentMode.height)
            _hiDPI = State(initialValue: saved?.hiDPI ?? d.currentMode.isHiDPI)
            _refreshRate = State(initialValue: saved?.refreshRate ?? d.currentMode.refreshRate)
        } else {
            _name = State(initialValue: "Virtual Display")
            _width = State(initialValue: 1920)
            _height = State(initialValue: 1080)
            _hiDPI = State(initialValue: true)
            _refreshRate = State(initialValue: 60)
        }
    }

    private var hasChanges: Bool {
        guard let d = editing else { return true }
        let baseW = saved?.width ?? d.currentMode.width
        let baseH = saved?.height ?? d.currentMode.height
        let baseHiDPI = saved?.hiDPI ?? d.currentMode.isHiDPI
        return width != baseW || height != baseH || hiDPI != baseHiDPI || name != d.name
            || refreshRate != (saved?.refreshRate ?? d.currentMode.refreshRate)
    }

    /// CGVirtualDisplay dimensions are logical; HiDPI doubles backing pixels.
    private var looksLike: String { "\(width) × \(height)" }
    private var backingSize: String {
        "\(width * (hiDPI ? 2 : 1)) × \(height * (hiDPI ? 2 : 1))"
    }
    private var isValid: Bool {
        (100...8192).contains(width) && (100...8192).contains(height)
        && (!hiDPI || (width <= 4096 && height <= 4096))
        && !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && (1...120).contains(refreshRate)
    }
    private var rates: [Double] { Array(Set([60.0, 90.0, 120.0, refreshRate])).sorted() }

    /// The preset matching the current size, if any; it names the preset menu.
    private var matchingPreset: DevicePreset? {
        devicePresets.first { $0.width == width && $0.height == height }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    displayPreview
                    form
                    if refreshRate > 60 {
                        Label(locale.t("refresh_experimental_note"), systemImage: "info.circle")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    if !isValid {
                        Text(locale.t("display_validation_note"))
                            .font(.caption).foregroundStyle(.orange)
                    }
                }
                .padding(20)
            }
            .frame(maxHeight: 420)
            if isEditing && hasChanges && name != editing?.name {
                Text(locale.t("recreate_warning"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)
            }
            Divider()
            bottomBar
        }
        .confirmationDialog(locale.t("remove_display_confirmation"), isPresented: $confirmRemoval) {
            Button(locale.t("remove"), role: .destructive) {
                if let display = editing, !isOnlyActiveDisplay {
                    viewModel.removeVirtualDisplay(display)
                    viewModel.navigate(to: .displayList)
                }
            }
            Button(locale.t("cancel"), role: .cancel) {}
        }
    }

    private var displayPreview: some View {
        HStack(spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(LinearGradient(colors: [.indigo, .purple.opacity(0.75)], startPoint: .topLeading, endPoint: .bottomTrailing))
                Image(systemName: "display").font(.system(size: 40, weight: .light)).foregroundStyle(.white)
            }
            .frame(width: 100, height: 76)
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                Text(verbatim: looksLike).font(.system(size: 24, weight: .semibold, design: .rounded)).monospacedDigit()
                Text("\(backingSize) px · \(Int(refreshRate)) Hz")
                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                Text(hiDPI ? "HiDPI · 2×" : "1×")
                    .font(.caption.weight(.medium)).foregroundStyle(.indigo)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Header

    @ViewBuilder
    private var header: some View {
        HStack {
            Image(systemName: "rectangle.dashed")
                .foregroundStyle(.purple)
            Text(verbatim: isEditing ? name : locale.t("new_virtual_display"))
                .font(.headline)
                .lineLimit(1)
            if isEditing {
                BadgeView(text: locale.t("badge_virtual"), color: .purple)
            }
            Spacer()
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { close() }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    // MARK: - Form

    @ViewBuilder
    private var form: some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
            GridRow {
                label("display_name")
                TextField(locale.t("virtual_display"), text: $name)
                    .textFieldStyle(.roundedBorder)
                    .gridCellColumns(2)
                    .accessibilityLabel(locale.t("display_name"))
                    .disabled(isOnlyActiveDisplay)
                    .help(locale.t("rename_safety_note"))
            }
            GridRow {
                label("preset")
                HStack {
                    presetMenu
                    Button("1512 × 982") { width = 1512; height = 982; hiDPI = true }
                        .buttonStyle(.bordered).controlSize(.small)
                }
                .gridCellColumns(2)
            }
            GridRow {
                label("desktop_size")
                HStack(spacing: 6) {
                    TextField("W", value: $width, format: .number.grouping(.never))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 72)
                        .accessibilityLabel(locale.t("width"))
                    Text(verbatim: "×").foregroundStyle(.secondary)
                    TextField("H", value: $height, format: .number.grouping(.never))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 72)
                        .accessibilityLabel(locale.t("height"))
                    Text(locale.t("logical_units"))
                        .font(.caption2).foregroundStyle(.secondary)
                }
                .gridCellColumns(2)
            }
            GridRow {
                label("render_scale")
                Picker("", selection: $hiDPI) {
                    Text(locale.t("zoom_1x")).tag(false)
                    Text(locale.t("zoom_2x")).tag(true)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 160)
                Text(verbatim: locale.t("looks_like_format", looksLike))
                    .font(.caption2).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            GridRow {
                label("refresh_rate")
                Picker(locale.t("refresh_rate"), selection: $refreshRate) {
                    ForEach(rates, id: \.self) { rate in
                        Text("\(Int(rate)) Hz").tag(rate)
                    }
                }
                .pickerStyle(.segmented).labelsHidden()
                .accessibilityLabel(locale.t("refresh_rate"))
                .gridCellColumns(2)
            }
            if let d = editing {
                GridRow {
                    label("active")
                    Text(verbatim: d.currentMode.localizedResolutionString(locale))
                        .font(.caption).foregroundStyle(.secondary)
                        .gridCellColumns(2)
                }
            }
        }
    }

    private func label(_ key: String) -> some View {
        Text(locale.t(key))
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(width: 76, alignment: .leading)
    }

    /// Device presets as one popup button, grouped by family. Picking one fills
    /// the panel size and, unless the display already has a custom name, the name.
    @ViewBuilder
    private var presetMenu: some View {
        Picker("", selection: Binding<UUID?>(
            get: { matchingPreset?.id },
            set: { id in
                if let preset = devicePresets.first(where: { $0.id == id }) { apply(preset) }
            }
        )) {
            Text(locale.t("preset_custom")).tag(UUID?.none)
            ForEach(DevicePreset.PresetCategory.allCases, id: \.self) { cat in
                Section(cat.localizedName(locale)) {
                    ForEach(devicePresets.filter { $0.category == cat }) { preset in
                        Text(verbatim: "\(preset.name)  ·  \(preset.dimensionString)")
                            .tag(Optional(preset.id))
                    }
                }
            }
        }
        .pickerStyle(.menu)
        .labelsHidden()
        .frame(maxWidth: 260, alignment: .leading)
    }

    private func apply(_ preset: DevicePreset) {
        let nameIsGeneric = !isEditing || name == "Virtual Display" || devicePresets.contains { $0.name == name }
        width = preset.width
        height = preset.height
        if nameIsGeneric { name = preset.name }
    }

    // MARK: - Bottom Bar

    @ViewBuilder
    private var bottomBar: some View {
        HStack(spacing: 8) {
            if let d = editing {
                Button(role: .destructive) {
                    confirmRemoval = true
                } label: {
                    Image(systemName: "trash").font(.caption2)
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .help(locale.t(isOnlyActiveDisplay ? "last_display_safety_note" : "remove"))
                .disabled(viewModel.isBusy || isOnlyActiveDisplay)

                if !d.isMain, d.isActive {
                    Button {
                        viewModel.setAsMainDisplay(d)
                    } label: {
                        Image(systemName: "star.fill").font(.caption2)
                    }
                    .buttonStyle(.bordered)
                    .help(locale.t("badge_set_main"))
                    .disabled(viewModel.isBusy)
                }

                Button {
                    viewModel.reconfigureVirtualDisplay(
                        d, width: width, height: height,
                        refreshRate: refreshRate, hiDPI: hiDPI, name: name
                    )
                } label: {
                    Text(verbatim: locale.t("apply_format", width, height))
                        .font(.caption).fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .tint(hasChanges && !viewModel.isBusy ? .purple : .gray)
                .disabled(!hasChanges || viewModel.isBusy || !isValid)
            } else {
                Button(locale.t("cancel")) {
                    withAnimation(.easeInOut(duration: 0.2)) { close() }
                }

                Button {
                    viewModel.newDisplayConfig = VirtualDisplayService.VirtualDisplayConfig(
                        name: name, width: width, height: height, refreshRate: refreshRate, hiDPI: hiDPI
                    )
                    viewModel.createVirtualDisplay()
                } label: {
                    Text(verbatim: locale.t("create_format", width, height))
                        .font(.caption).fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .tint(viewModel.isBusy ? .gray : .purple)
                .disabled(viewModel.isBusy || !isValid)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func close() {
        viewModel.navigate(to: .displayList)
    }
}
