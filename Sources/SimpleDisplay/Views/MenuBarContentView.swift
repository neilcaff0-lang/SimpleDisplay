import SwiftUI

struct MenuBarContentView: View {
    @Environment(DisplayManagerViewModel.self) private var viewModel
    @Environment(LocaleManager.self) private var locale

    private var configuringDisplay: DisplayInfo? {
        guard case .configuringDisplay(let id) = viewModel.navigationState else { return nil }
        return viewModel.displays.first { $0.id == id }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "display.2")
                    .font(.system(size: 19, weight: .light)).foregroundStyle(.secondary)
                Text(verbatim: locale.t("app_name"))
                    .font(.system(size: 13, weight: .medium))
                Spacer()
                if viewModel.isBusy {
                    ProgressView().controlSize(.small)
                } else {
                    Button { viewModel.refresh() } label: {
                        Image(systemName: "arrow.clockwise").font(.system(size: 12))
                    }
                    .buttonStyle(.plain).foregroundStyle(.secondary)
                    .accessibilityLabel(locale.t("refresh_displays"))
                }
                Button { viewModel.navigate(to: .settings) } label: {
                    Image(systemName: "slider.horizontal.3").font(.system(size: 13))
                }
                .buttonStyle(.plain).foregroundStyle(.secondary)
                .accessibilityLabel(locale.t("settings"))
                .disabled(viewModel.isNavigating || viewModel.isBusy)
            }
            .padding(.horizontal, 26).padding(.top, 22).padding(.bottom, 18)

            // Headless countdown: the last visible display was just turned off.
            // Whoever can still see this (a remote session) may keep it; nobody
            // confirming turns the screen back on.
            if let pending = viewModel.headlessPending {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Image(systemName: "display.trianglebadge.exclamationmark")
                            .foregroundStyle(.red)
                        Text(verbatim: locale.t("headless_warning"))
                            .font(.caption)
                            .fontWeight(.medium)
                        Spacer()
                        Text(verbatim: locale.t("headless_countdown_format", pending.secondsLeft))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    HStack(spacing: 8) {
                        Button(locale.t("headless_revert")) {
                            viewModel.revertHeadless()
                        }
                        .controlSize(.small)
                        Button(locale.t("headless_keep")) {
                            viewModel.confirmHeadless()
                        }
                        .controlSize(.small)
                        Spacer()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.red.opacity(0.1))

                Divider()
            }

            // Error banner
            if let error = viewModel.errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(verbatim: error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                    Spacer()
                    Button {
                        viewModel.errorMessage = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.orange.opacity(0.1))


                Divider()
            }

            // Busy indicator
            if viewModel.isBusy, let message = viewModel.busyMessage {
                HStack(spacing: 8) {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .controlSize(.mini)
                    Text(verbatim: message)
                        .font(.caption)
                        .foregroundStyle(.blue)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.1))
                .transition(.move(edge: .top).combined(with: .opacity))

                Divider()
            }

            switch viewModel.navigationState {
            case .settings:
                SettingsView()
                    .environment(viewModel)
                    .environment(locale)

            case .addVirtualDisplay:
                VirtualDisplayEditorView(editing: nil)
                    .environment(viewModel)
                    .environment(locale)

            case .configuringDisplay:
                if let display = configuringDisplay, display.isVirtual {
                    VirtualDisplayEditorView(editing: display, saved: viewModel.virtualConfig(for: display))
                        .environment(viewModel)
                        .environment(locale)
                } else {
                    displayListContent
                }

            case .displayList:
                displayListContent
            }
        }
        .frame(width: 540)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            // Fix TextField focus in MenuBarExtra .window style
            NSApp.activate(ignoringOtherApps: true)
            // Re-sync with the live display topology each time the popover opens,
            // so any state left stale by an async reconfiguration self-corrects.
            if !viewModel.isBusy { viewModel.refresh() }
        }
    }

    // MARK: - Display List

    @ViewBuilder
    private var displayListContent: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(locale.t("displays_title"))
                .font(.system(size: 25, weight: .semibold))
            Spacer()
            Text(verbatim: locale.t("active_displays_count", viewModel.activeDisplays.count))
                .font(.system(size: 11)).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 26).padding(.top, 4).padding(.bottom, 20)

        if viewModel.displays.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "display").font(.system(size: 36, weight: .ultraLight))
                Text(locale.t("no_displays")).font(.callout)
            }
            .foregroundStyle(.secondary).frame(maxWidth: .infinity)
            .padding(.vertical, 50)
        } else {
            // Keep a nonzero intrinsic height in MenuBarExtra's window popover.
            ScrollView {
                LazyVStack(spacing: 14) {
                    ForEach(viewModel.displays) { display in DisplayRowView(display: display) }
                }
                .padding(.horizontal, 22).padding(.top, 1).padding(.bottom, 6)
            }
            .frame(minHeight: 300, maxHeight: 450)
        }

        HStack(spacing: 16) {
            Button { viewModel.navigate(to: .addVirtualDisplay) } label: {
                Label(locale.t("add_display"), systemImage: "plus")
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 4).padding(.vertical, 4)
            }
            .buttonStyle(.bordered).controlSize(.regular)
            .disabled(viewModel.isBusy || viewModel.isNavigating)
            Spacer()
            Button(locale.t("quit")) { NSApplication.shared.terminate(nil) }
                .buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 26).padding(.top, 16).padding(.bottom, 22)
    }
}
