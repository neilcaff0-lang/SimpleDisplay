import SwiftUI

/// Quiet, scalable monitor illustration. Not a capture of the user's desktop.
struct DisplaySilhouette: View {
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                RoundedRectangle(cornerRadius: 7)
                    .fill(Color(nsColor: .windowBackgroundColor))
                RoundedRectangle(cornerRadius: 7)
                    .strokeBorder(Color.primary.opacity(0.28), lineWidth: 1)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.primary.opacity(0.035)).padding(5)
                HStack(spacing: 5) {
                    RoundedRectangle(cornerRadius: 2).fill(Color.primary.opacity(0.07)).frame(width: 18)
                    VStack(spacing: 5) {
                        RoundedRectangle(cornerRadius: 2).fill(Color.primary.opacity(0.10))
                        RoundedRectangle(cornerRadius: 2).fill(Color.primary.opacity(0.045))
                    }
                }
                .padding(13)
            }
            Rectangle().fill(Color.primary.opacity(0.25)).frame(width: 9, height: 9)
            Capsule().fill(Color.primary.opacity(0.30)).frame(width: 42, height: 2)
        }
    }
}

struct DisplayMetric: View {
    let title: String
    let value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(verbatim: title).font(.system(size: 10)).foregroundStyle(.secondary)
            Text(verbatim: value).font(.system(size: 12, weight: .medium)).monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
