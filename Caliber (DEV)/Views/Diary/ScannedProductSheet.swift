import HeliosDesign
import SwiftUI

/// An amount picked on the scan result. The review opens on grams, or on portions when the
/// product has no gram weight, so millilitres are never turned into grams (AGENTS.md).
struct ScannedPortion: Equatable {
  let choiceID: String
  let amount: Double
}

/// The product a scan found, as the item a sheet presents.
struct ScannedProduct: Identifiable {
  let id = UUID()
  let product: BarcodeNutritionProduct
}

/// The amount choices on a scanned product: the label's own serving, 100 g when the label gives
/// a gram weight, and a count of either. It only multiplies the product's own values; the
/// weight of a food is never guessed (AGENTS.md). The editable review is where it is saved.
struct ScanPortionPlan: Equatable {
  enum Basis: Equatable { case serving, hundredGrams }

  static let quantities = 1...10

  let product: BarcodeNutritionProduct
  var basis = Basis.serving
  var quantity = 1

  /// 100 g is offered only when the label gives a gram weight and is not already per 100 g.
  var offersHundredGrams: Bool {
    guard let grams = product.basisGrams else { return false }
    return grams != 100
  }

  /// The total mass of the choice. Nil when the product has no gram weight (a millilitre
  /// serving), which is never converted.
  var grams: Double? {
    switch basis {
    case .serving: return product.basisGrams.map { $0 * Double(quantity) }
    case .hundredGrams: return product.basisGrams == nil ? nil : 100 * Double(quantity)
    }
  }

  /// Energy and macros for the choice, from the product's own values.
  var totals: MacroTotals? {
    let reference = FoodNutritionReference.barcode(product)
    let scaled: MacroTotals?
    if let grams {
      scaled = try? reference.portionTotals(grams: grams)
    } else {
      scaled = reference.totals.scaled(by: Double(quantity))
    }
    guard let scaled, scaled.isValid else { return nil }
    return scaled
  }

  /// The amount the review opens on. Nil is the review's own default: one label serving.
  var reviewPortion: ScannedPortion? {
    if basis == .serving && quantity == 1 { return nil }
    if let grams { return ScannedPortion(choiceID: "grams", amount: grams) }
    return ScannedPortion(choiceID: "portions", amount: Double(quantity))
  }

  /// What the nutrition tiles describe, in the product's own words.
  func caption(locale: Locale) -> String {
    switch basis {
    case .serving:
      if quantity == 1 { return "Per \(product.basisDescription)" }
      guard let grams else { return "\(quantity) × \(product.basisDescription)" }
      return
        "\(quantity) × \(product.basisDescription) = \(NutritionInput.format(grams, locale: locale)) g"
    case .hundredGrams:
      if quantity == 1 { return "Per 100 g" }
      return "\(NutritionInput.format(100 * Double(quantity), locale: locale)) g"
    }
  }
}

/// Look book: a scanned product with its serving choices, the nutrition for the choice, the
/// data warning, and one action that opens the editable review. Nothing is saved here.
struct ScannedProductPanel: View {
  let product: BarcodeNutritionProduct
  let mealType: MealType
  /// Prefix of the accessibility identifiers, so the camera sheet and the lookup form differ.
  let idPrefix: String
  let reviewIdentifier: String
  /// Called with the amount chosen here; nil is the review's own default amount.
  let onReview: (ScannedPortion?) -> Void
  @State private var plan: ScanPortionPlan
  @Environment(\.heliosTheme) private var theme
  @Environment(\.locale) private var locale
  @Environment(\.dynamicTypeSize) private var typeSize

  init(
    product: BarcodeNutritionProduct, mealType: MealType, idPrefix: String,
    reviewIdentifier: String, onReview: @escaping (ScannedPortion?) -> Void
  ) {
    self.product = product
    self.mealType = mealType
    self.idPrefix = idPrefix
    self.reviewIdentifier = reviewIdentifier
    self.onReview = onReview
    _plan = State(initialValue: ScanPortionPlan(product: product))
  }

  var body: some View {
    VStack(alignment: .leading, spacing: HeliosTokens.space(3)) {
      header
      chips
      nutrition
      status
      actions
    }
    .font(.body)
    .labelStyle(ScanLabelStyle())
    .foregroundStyle(
      theme.palette.text.primary.color, theme.palette.text.secondary.color,
      theme.palette.text.tertiary.color
    )
    .tint(theme.palette.accent.base.color)
  }

  // MARK: Product

  private var header: some View {
    HStack(alignment: .top, spacing: HeliosTokens.space(3)) {
      Image(systemName: "shippingbox")
        .foregroundStyle(theme.palette.text.secondary.color)
        .frame(width: 52, height: 52)
        .background { GlassBackground(level: .raised, cornerRadius: 14) }
        .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 2) {
        Text(product.name)
          .heliosFont(.section)
          .fixedSize(horizontal: false, vertical: true)
          .accessibilityAddTraits(.isHeader)
          .accessibilityIdentifier("\(idPrefix)Name")
        Text(subtitle)
          .heliosFont(.footnote)
          .foregroundStyle(theme.palette.text.secondary.color)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private var subtitle: String {
    [product.brand, product.sourceName].compactMap { $0 }.filter { !$0.isEmpty }
      .joined(separator: " · ")
  }

  // MARK: Serving choices

  private var chips: some View {
    ChipFlow(spacing: HeliosTokens.space(2)) {
      chip(
        product.basisDescription, isSelected: plan.basis == .serving,
        identifier: "\(idPrefix)ChipServing"
      ) { plan.basis = .serving }
      if plan.offersHundredGrams {
        chip(
          "100 g", isSelected: plan.basis == .hundredGrams,
          identifier: "\(idPrefix)Chip100g"
        ) { plan.basis = .hundredGrams }
      }
      // Any other amount is typed in the review, which opens on the choice made so far.
      Button {
        onReview(plan.reviewPortion)
      } label: {
        HeliosChip("Other")
      }
      .buttonStyle(.plain)
      .accessibilityHint("Opens the review so you can enter another amount")
      .accessibilityIdentifier("\(idPrefix)ChipOther")
    }
  }

  private func chip(
    _ title: String, isSelected: Bool, identifier: String, action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      HeliosChip(LocalizedStringKey(title), isSelected: isSelected)
    }
    .buttonStyle(.plain)
    .accessibilityIdentifier(identifier)
  }

  // MARK: Nutrition

  private var nutrition: some View {
    VStack(alignment: .leading, spacing: HeliosTokens.space(2)) {
      Text(plan.caption(locale: locale))
        .heliosFont(.caption)
        .foregroundStyle(theme.palette.text.secondary.color)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityIdentifier("\(idPrefix)Basis")
      ViewThatFits(in: .horizontal) {
        HStack(spacing: HeliosTokens.space(2)) {
          energyTile
          proteinTile
          carbsTile
          fatTile
        }
        VStack(spacing: HeliosTokens.space(2)) {
          HStack(spacing: HeliosTokens.space(2)) {
            energyTile
            proteinTile
          }
          HStack(spacing: HeliosTokens.space(2)) {
            carbsTile
            fatTile
          }
        }
        VStack(spacing: HeliosTokens.space(2)) {
          energyTile
          proteinTile
          carbsTile
          fatTile
        }
      }
    }
  }

  private var energyTile: some View {
    tile(
      "Energy", key: "energy", value: plan.totals?.calories, unit: "kcal",
      color: theme.palette.data.energy.color)
  }

  private var proteinTile: some View {
    tile(
      "Protein", key: "protein", value: plan.totals?.protein, unit: "g",
      color: theme.palette.data.protein.color)
  }

  private var carbsTile: some View {
    tile(
      "Carbs", key: "carbs", value: plan.totals?.carbs, unit: "g",
      color: theme.palette.data.carbs.color)
  }

  private var fatTile: some View {
    tile(
      "Fat", key: "fat", value: plan.totals?.fat, unit: "g",
      color: theme.palette.data.fat.color)
  }

  private func tile(
    _ title: LocalizedStringKey, key: String, value: Double?, unit: String, color: Color
  ) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      HStack(spacing: 4) {
        Circle().fill(color).frame(width: 7, height: 7).accessibilityHidden(true)
        Text(title).heliosFont(.caption)
          .foregroundStyle(theme.palette.text.secondary.color)
          .fixedSize(horizontal: false, vertical: true)
      }
      Text(
        value.map { $0.formatted(.number.precision(.fractionLength(0...1)).locale(locale)) } ?? "–"
      )
      .heliosFont(.bodyStrong)
      .fixedSize(horizontal: false, vertical: true)
      Text(unit).heliosFont(.caption)
        .foregroundStyle(theme.palette.text.secondary.color)
        .fixedSize(horizontal: false, vertical: true)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(HeliosTokens.space(2))
    .background { GlassBackground(level: .raised, cornerRadius: HeliosTokens.radius.tile) }
    .accessibilityElement(children: .combine)
    .accessibilityIdentifier("\(idPrefix)Tile-\(key)")
  }

  // MARK: What the data does and does not say

  /// Only what the product record supports: all four values were found, and where they come
  /// from. It carries no allergen list and no cross-check between sources, so none is shown.
  /// The record's own warning stays on screen.
  private var status: some View {
    VStack(alignment: .leading, spacing: HeliosTokens.space(2)) {
      StatusBadge(.success, "Calories and macros found · \(product.sourceName)")
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityIdentifier("\(idPrefix)Complete")
      StatusBadge(.warning, LocalizedStringKey(product.sourceNote))
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityIdentifier("\(idPrefix)Warning")
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  // MARK: Quantity and review

  private var actions: some View {
    let layout =
      typeSize.isAccessibilitySize
      ? AnyLayout(VStackLayout(alignment: .leading, spacing: HeliosTokens.space(3)))
      : AnyLayout(HStackLayout(spacing: HeliosTokens.space(3)))
    return layout {
      stepper
      reviewButton
    }
  }

  private var stepper: some View {
    HStack(spacing: HeliosTokens.space(3)) {
      stepButton(
        "minus", label: "Fewer", identifier: "\(idPrefix)Fewer",
        isEnabled: plan.quantity > ScanPortionPlan.quantities.lowerBound
      ) { plan.quantity -= 1 }
      Text("\(plan.quantity)")
        .heliosFont(.section)
        .monospacedDigit()
        .frame(minWidth: 28)
        .accessibilityLabel("Quantity")
        .accessibilityValue("\(plan.quantity)")
        .accessibilityIdentifier("\(idPrefix)Quantity")
      stepButton(
        "plus", label: "More", identifier: "\(idPrefix)More",
        isEnabled: plan.quantity < ScanPortionPlan.quantities.upperBound
      ) { plan.quantity += 1 }
    }
  }

  private func stepButton(
    _ symbol: String, label: LocalizedStringKey, identifier: String, isEnabled: Bool,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      Image(systemName: symbol)
        .font(.body.weight(.semibold))
        .foregroundStyle(theme.palette.text.primary.color)
        .frame(width: 48, height: 48)
        .background { GlassBackground(level: .raised, cornerRadius: 24) }
        .contentShape(Circle())
    }
    .buttonStyle(.plain)
    .disabled(!isEnabled)
    .opacity(isEnabled ? 1 : 0.4)
    .accessibilityLabel(label)
    .accessibilityIdentifier(identifier)
  }

  /// The one action opens the editable review, where every value can still be changed and
  /// where the food is saved. The look book's "Add to <meal>" is saved only from there.
  private var reviewButton: some View {
    Button {
      onReview(plan.reviewPortion)
    } label: {
      Text("Review and Add to \(mealType.displayName)")
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, minHeight: 48)
    }
    .buttonStyle(.heliosPrimary)
    .accessibilityIdentifier(reviewIdentifier)
  }
}

/// Look book: the product sheet that rises over the camera after a barcode is read.
struct ScannedProductSheet: View {
  let product: BarcodeNutritionProduct
  let mealType: MealType
  let onReview: (ScannedPortion?) -> Void

  var body: some View {
    ScrollView {
      ScannedProductPanel(
        product: product, mealType: mealType, idPrefix: "scan",
        reviewIdentifier: "scanResultReview", onReview: onReview
      )
      .padding(.horizontal, HeliosTokens.space(4))
      .padding(.top, HeliosTokens.space(6))
      .padding(.bottom, HeliosTokens.space(4))
    }
    .presentationDetents([.fraction(0.62), .large])
    .presentationDragIndicator(.visible)
    .presentationBackground { ScanSheetGlass() }
    // A container identifier would replace the identifiers of the controls inside it.
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("scanResultSheet")
  }
}

/// The sheet's surface: system blur with the theme's glass tint, or an opaque surface when
/// Reduce Transparency is on, as `GlassBackground` does.
private struct ScanSheetGlass: View {
  @Environment(\.heliosTheme) private var theme

  var body: some View {
    let palette = theme.palette
    ZStack {
      if theme.reduceTransparency {
        Rectangle().fill(palette.opaque.overlay.color)
      } else {
        Rectangle().fill(.ultraThinMaterial)
        Rectangle().fill(palette.glass.overlay.color)
      }
    }
  }
}

/// A sheet does not inherit the screen's label style, so the icon and text of a status line sit
/// side by side and the text wraps instead of clipping at large sizes.
private struct ScanLabelStyle: LabelStyle {
  func makeBody(configuration: Configuration) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: 10) {
      configuration.icon.accessibilityHidden(true)
      configuration.title.fixedSize(horizontal: false, vertical: true)
    }
  }
}

/// Chips of different widths that wrap onto new rows, so long serving text never forces a
/// sideways scroll.
private struct ChipFlow: Layout {
  var spacing: CGFloat = 8

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    arrange(in: proposal.width ?? .infinity, subviews: subviews).size
  }

  func placeSubviews(
    in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
  ) {
    let arranged = arrange(in: bounds.width, subviews: subviews)
    for (subview, frame) in zip(subviews, arranged.frames) {
      subview.place(
        at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
        anchor: .topLeading, proposal: ProposedViewSize(frame.size))
    }
  }

  private func arrange(in width: CGFloat, subviews: Subviews) -> (
    frames: [CGRect], size: CGSize
  ) {
    var frames: [CGRect] = []
    var x: CGFloat = 0
    var y: CGFloat = 0
    var rowHeight: CGFloat = 0
    var widest: CGFloat = 0
    for subview in subviews {
      // A chip never grows past the row; longer text wraps inside it.
      let size = subview.sizeThatFits(
        ProposedViewSize(width: width.isFinite ? width : nil, height: nil))
      if x > 0, x + size.width > width {
        x = 0
        y += rowHeight + spacing
        rowHeight = 0
      }
      frames.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
      x += size.width + spacing
      rowHeight = max(rowHeight, size.height)
      widest = max(widest, x - spacing)
    }
    return (frames, CGSize(width: widest, height: y + rowHeight))
  }
}
