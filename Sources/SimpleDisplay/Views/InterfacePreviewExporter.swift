import AppKit
import SwiftUI

/// Renders app views only: no desktop capture, no screen recording, no arbitrary output path.
@MainActor
enum InterfacePreviewExporter {
    static func export(viewModel: DisplayManagerViewModel) throws {
        let folder = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SimpleDisplay-Previews-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let locale = LocaleManager()
        for (name, appearance) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua)] {
            try render(MenuBarContentView().environment(viewModel).environment(locale),
                to: folder.appendingPathComponent("displays-\(name).png"), appearance: appearance)
            if let display = viewModel.displays.first(where: { $0.isVirtual && $0.isActive }) {
                try render(VirtualDisplayEditorView(editing: display, saved: viewModel.virtualConfig(for: display))
                    .environment(viewModel).environment(locale),
                    to: folder.appendingPathComponent("editor-\(name).png"), appearance: appearance)
            }
        }
    }

    private static func render<V: View>(_ view: V, to url: URL, appearance: NSAppearance.Name) throws {
        let content = view
            .frame(width: 540).fixedSize(horizontal: false, vertical: true)
            .background(Color(nsColor: .windowBackgroundColor))
            .environment(\.colorScheme, appearance == .darkAqua ? .dark : .light)
        let host = NSHostingView(rootView: content)
        host.appearance = NSAppearance(named: appearance)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 540, height: 700),
            styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: appearance)
        window.backgroundColor = .windowBackgroundColor
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        let height = min(900, max(300, host.fittingSize.height))
        window.setContentSize(NSSize(width: 540, height: height))
        host.frame = NSRect(x: 0, y: 0, width: 540, height: height)
        host.layoutSubtreeIfNeeded()
        guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else {
            throw NSError(domain: "SimpleDisplayPreview", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Could not render interface preview."])
        }
        host.cacheDisplay(in: host.bounds, to: bitmap)
        guard let data = bitmap.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "SimpleDisplayPreview", code: 2)
        }
        try data.write(to: url, options: .atomic)
        window.close()
    }
}
