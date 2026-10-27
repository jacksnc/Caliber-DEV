import CaliberIntegrations
import HeliosDesign
import PhotosUI
import SwiftUI
import UIKit

/// FUEL-10: a meal photo becomes a list of proposed foods and weights. Each one opens the normal
/// review on a database food with that weight filled in; nutrition comes from the database, and
/// nothing is logged until the person confirms it there. Off by default (`feature.fuel-10`).
struct PhotoEstimateView: View {
  let mealType: MealType
  let date: Date
  @EnvironmentObject private var account: HostedAccountModel
  @Environment(\.heliosTheme) private var theme
  @AppStorage("feature.fuel-10") private var isEnabled = false
  @State private var pickerItem: PhotosPickerItem?
  @State private var showsCamera = false
  @State private var isEstimating = false
  @State private var message: String?
  @State private var matches: [PhotoMatch] = []

  struct PhotoMatch: Identifiable {
    let item: FoodPhotoItem
    let food: FoodCatalogEntry?
    var id: String { "\(item.name)|\(item.grams)" }
  }

  private var usesFixture: Bool {
    #if DEBUG
      ProcessInfo.processInfo.arguments.contains("--photo-fixture")
    #else
      false
    #endif
  }
  private var hasCamera: Bool { UIImagePickerController.isSourceTypeAvailable(.camera) }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: HeliosTokens.space(4)) {
        consentCard
        if isEnabled { captureCard }
        if isEstimating { ProgressView("Looking at the photo…") }
        if let message {
          Text(message).heliosFont(.callout)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("photoMessage")
        }
        if !matches.isEmpty { resultsCard }
      }
      .padding()
    }
    .caliberScreen()
    .navigationTitle("Photo Estimate")
    .navigationBarTitleDisplayMode(.inline)
    .onChange(of: pickerItem) { _, item in
      guard let item else { return }
      Task {
        guard let data = try? await item.loadTransferable(type: Data.self),
          let image = UIImage(data: data)
        else {
          message = "That photo could not be opened. Try another."
          return
        }
        await estimate(image)
      }
    }
    .fullScreenCover(isPresented: $showsCamera) {
      CameraPhotoCapture { image in
        showsCamera = false
        if let image { Task { await estimate(image) } }
      }
      .ignoresSafeArea()
    }
  }

  private var consentCard: some View {
    VStack(alignment: .leading, spacing: HeliosTokens.space(3)) {
      Toggle(isOn: $isEnabled) {
        Text("Photo Estimates (Preview)").heliosFont(.bodyStrong)
      }
      .accessibilityIdentifier("photoEstimatesEnabled")
      Text(
        "When on, a smaller copy of your meal photo, without location or other details, goes to Caliber's server and to Anthropic's Claude, which suggests the foods and their weights. Caliber does not keep the photo. Calories and macros always come from the food database, and you check every food before it is logged."
      )
      .heliosFont(.footnote)
      .foregroundStyle(theme.palette.text.secondary.color)
      .fixedSize(horizontal: false, vertical: true)
    }
    .glassCard()
  }

  @ViewBuilder private var captureCard: some View {
    if account.canEstimatePhotos || usesFixture {
      VStack(alignment: .leading, spacing: HeliosTokens.space(3)) {
        if hasCamera {
          Button {
            showsCamera = true
          } label: {
            Label("Take Photo", systemImage: "camera")
              .fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity)
          }
          .buttonStyle(.heliosPrimary)
        }
        PhotosPicker(selection: $pickerItem, matching: .images) {
          Label("Choose Photo", systemImage: "photo.on.rectangle")
            .fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity)
        }
        .buttonStyle(.heliosSecondary)
        #if DEBUG
          if usesFixture {
            Button("Use Sample Meal") { Task { await show(Self.fixture) } }
              .buttonStyle(.heliosSecondary)
              .accessibilityIdentifier("photoUseSample")
          }
        #endif
      }
      .glassCard()
    } else {
      Text(
        "Photo estimates need you to be signed in under Profile, Account and Sync, and need the estimate service turned on for this build. You can still search, scan a barcode or scan a label."
      )
      .heliosFont(.callout)
      .fixedSize(horizontal: false, vertical: true)
      .glassCard()
      .accessibilityIdentifier("photoUnavailable")
    }
  }

  private var resultsCard: some View {
    VStack(alignment: .leading, spacing: HeliosTokens.space(3)) {
      SectionHeader("Foods in the photo")
      Label(
        "Estimates from a photo. Check each food and its weight before you log it.",
        systemImage: "exclamationmark.triangle.fill"
      )
      .heliosFont(.footnote)
      .foregroundStyle(theme.palette.text.secondary.color)
      .fixedSize(horizontal: false, vertical: true)
      ForEach(matches) { match in row(match) }
    }
    .glassCard()
    // A container identifier would replace the identifiers of the links inside it.
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("photoResults")
  }

  @ViewBuilder private func row(_ match: PhotoMatch) -> some View {
    let label = VStack(alignment: .leading, spacing: 2) {
      HStack(alignment: .firstTextBaseline) {
        Text(match.item.name.capitalized).heliosFont(.bodyStrong)
          .fixedSize(horizontal: false, vertical: true)
          .frame(maxWidth: .infinity, alignment: .leading)
        switch match.item.confidence {
        case "high": StatusBadge(.success, "Likely")
        case "medium": StatusBadge(.warning, "Check")
        default: StatusBadge(.warning, "Unsure")
        }
      }
      Text(
        "About \(NutritionInput.format(match.item.grams)) g · "
          + (match.food.map { "matched to \($0.name)" } ?? "no database match")
      )
      .heliosFont(.footnote)
      .foregroundStyle(theme.palette.text.secondary.color)
      .fixedSize(horizontal: false, vertical: true)
    }
    .padding(HeliosTokens.space(3))
    .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
    .background { GlassBackground(level: .raised, cornerRadius: HeliosTokens.radius.tile) }
    if let food = match.food {
      NavigationLink {
        FoodNutritionReviewView(
          reference: .usda(food), meal: mealType, date: date,
          portion: (choiceID: "grams", amount: match.item.grams))
      } label: {
        label
      }
      .buttonStyle(.plain)
      .accessibilityIdentifier("photoItem-\(match.item.name)")
    } else {
      label
    }
  }

  private func estimate(_ image: UIImage) async {
    guard let jpeg = Self.preparedJPEG(image) else {
      message = "That photo could not be prepared. Try another."
      return
    }
    isEstimating = true
    message = nil
    defer { isEstimating = false }
    do {
      let proposal = try await account.estimateFoodPhoto(
        jpegBase64: jpeg.base64EncodedString())
      await show(proposal)
    } catch GatewayError.rateLimited {
      message = "Too many photo estimates in a short time. Try again in a few minutes."
    } catch GatewayError.unauthorized {
      message = "Sign in again under Profile, Account and Sync to use photo estimates."
    } catch {
      message = "The estimate could not be made. Search for the foods or enter them yourself."
    }
  }

  private func show(_ proposal: FoodPhotoProposal) async {
    guard !proposal.items.isEmpty else {
      matches = []
      message = "No food was recognised in that photo."
      return
    }
    let service = await BundledFoodSearchService.prepared()
    matches = proposal.items.map { item in
      // "rice, white, cooked": search the full name, then the food itself, and rank by it.
      let head = item.name.split(separator: ",").first.map(String.init) ?? item.name
      var candidates = (try? service.catalogSearch(query: item.name, limit: 200)) ?? []
      if candidates.isEmpty {
        candidates = (try? service.catalogSearch(query: head, limit: 200)) ?? []
      }
      return PhotoMatch(item: item, food: CatalogMatch.best(for: head, in: candidates))
    }
  }

  /// At most 1024 points on the long side, re-encoded: the redraw drops EXIF and location.
  static func preparedJPEG(_ image: UIImage) -> Data? {
    let longest = max(image.size.width, image.size.height)
    guard longest > 0 else { return nil }
    let scale = min(1, 1024 / longest)
    let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
      image.draw(in: CGRect(origin: .zero, size: size))
    }
    return resized.jpegData(compressionQuality: 0.7)
  }

  #if DEBUG
    static let fixture = FoodPhotoProposal(
      items: [
        FoodPhotoItem(name: "rice, white, cooked", grams: 180, confidence: "medium"),
        FoodPhotoItem(name: "banana", grams: 118, confidence: "high"),
      ], model: "fixture", promptVersion: "fixture")
  #endif
}
