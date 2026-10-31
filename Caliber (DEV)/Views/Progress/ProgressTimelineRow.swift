import HeliosDesign
import ImageIO
import SwiftUI

/// Presentation only: the same saved check-in is used by the timeline and editor.
struct ProgressTimelineRow: View {
  @Environment(\.heliosTheme) private var theme
  let entry: ProgressEntry
  let unit: WeightUnit
  let isFirst: Bool
  let isLast: Bool

  private var dateLabel: String {
    let date = entry.date.formatted(.dateTime.month(.abbreviated).day())
    if Calendar.current.isDateInToday(entry.date) { return "Today · \(date)" }
    if Calendar.current.isDateInYesterday(entry.date) { return "Yesterday · \(date)" }
    return entry.date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
  }

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      // The rail is drawn behind the row so long notes and large text can
      // grow the card without stretching the date marker.
      Color.clear.frame(width: 16)

      VStack(alignment: .leading, spacing: 12) {
        Text(dateLabel)
          .heliosFont(.metricLabel)
          .foregroundStyle(theme.palette.text.secondary.color)
          .fixedSize(horizontal: false, vertical: true)
          .accessibilityLabel(entry.date.formatted(date: .complete, time: .omitted))

        if !entry.photos.isEmpty { photoPreviews }

        if let weight = entry.weightEntry?.weightInPounds {
          Label {
            Text(
              "\(unit.fromPounds(weight), format: .number.precision(.fractionLength(0...2))) \(unit.symbol)"
            )
          } icon: {
            Image(systemName: "scalemass")
          }
          .heliosFont(.bodyStrong)
          .foregroundStyle(theme.palette.accent.base.color)
          .padding(.horizontal, 10)
          .padding(.vertical, 7)
          .background(
            theme.palette.accent.subtle.color,
            in: RoundedRectangle(cornerRadius: HeliosTokens.radius.chip, style: .continuous))
        }

        if !entry.notes.isEmpty {
          Text(entry.notes)
            .heliosFont(.subheadline)
            .foregroundStyle(theme.palette.text.primary.color)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(HeliosTokens.spacing[3])
      // V2: notes and dates sit on the opaque tone, with the glass edge and shadow kept.
      .background {
        GlassBackground()
          .transformEnvironment(\.heliosTheme) { $0.reduceTransparency = true }
      }
    }
    .padding(.bottom, 14)
    .background {
      GeometryReader { geometry in
        Path { path in
          path.move(to: CGPoint(x: 8, y: isFirst ? 26 : 0))
          path.addLine(to: CGPoint(x: 8, y: isLast ? 26 : geometry.size.height))
        }
        // Increase Contrast swaps the faint rail for the audited strong edge.
        .stroke(
          theme.palette.isHighContrast
            ? theme.palette.border.strong.color : theme.palette.accent.base.color.opacity(0.22),
          lineWidth: 2)

        Circle()
          .fill(theme.palette.accent.base.color)
          .frame(width: 10, height: 10)
          .overlay {
            Circle().stroke(theme.palette.opaque.base.color, lineWidth: 3)
          }
          .position(x: 8, y: 26)
      }
      .accessibilityHidden(true)
    }
  }

  private var photoPreviews: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(spacing: 6) {
        ForEach(Array(entry.sortedPhotos.prefix(3).enumerated()), id: \.element.id) {
          index, photo in
          Group {
            if let image = thumbnail(from: photo.imageData) {
              Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: entry.photos.count == 1 ? .fit : .fill)
            } else {
              Image(systemName: "photo")
                .foregroundStyle(theme.palette.text.secondary.color)
            }
          }
          .frame(minWidth: 0, maxWidth: .infinity)
          .frame(height: 150)
          .clipped()
          .background(
            theme.reduceTransparency
              ? theme.palette.opaque.raised.color : theme.palette.glass.raised.color
          )
          .clipShape(RoundedRectangle(cornerRadius: HeliosTokens.radius.chip, style: .continuous))
          .overlay(alignment: .bottomTrailing) {
            if index == 2 && entry.photos.count > 3 {
              Text("+\(entry.photos.count - 3)")
                .heliosFont(.metricLabel)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .foregroundStyle(.white)
                .background(.black.opacity(0.65), in: Capsule())
                .padding(6)
            }
          }
          .accessibilityHidden(true)
        }
      }
      Text("\(entry.photos.count) \(entry.photos.count == 1 ? "photo" : "photos") · Tap to view")
        .heliosFont(.caption)
        .foregroundStyle(theme.palette.text.secondary.color)
    }
  }

  private func thumbnail(from data: Data) -> UIImage? {
    // Decode small previews as rows appear, while keeping full saved photos
    // for the detail screen.
    guard
      let source = CGImageSourceCreateWithData(
        data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary
      ),
      let image = CGImageSourceCreateThumbnailAtIndex(
        source, 0,
        [
          kCGImageSourceCreateThumbnailFromImageAlways: true,
          kCGImageSourceCreateThumbnailWithTransform: true,
          kCGImageSourceThumbnailMaxPixelSize: 576,
        ] as CFDictionary)
    else { return nil }
    return UIImage(cgImage: image)
  }
}
