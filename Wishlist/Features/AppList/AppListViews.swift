import SwiftUI
import WishlistFoundation

struct AppSummary: Identifiable, Equatable {
  enum PriceChange {
    case same
    case decrease
    case increase
  }

  enum Details: Equatable {
    case price(String, change: PriceChange)
    case updated(Date, seen: Bool)
  }

  let id: App.ID
  let selected: Bool
  let title: String
  let details: Details
  let icon: URL
  let url: URL
}

struct AppRow: View {
  let title: String
  let details: AppSummary.Details
  let icon: URL

  var body: some View {
    HStack {
      AppIcon(icon, width: 50)
      Text(title)
        .fontWeight(.medium)
        .layoutPriority(1)
      Spacer()
      appDetailsView()
        .layoutPriority(1)
    }
  }

  private func appDetailsView() -> some View {
    switch details {
    case let .price(price, change):
      return ViewBuilder.buildEither(first:
        AppPriceDetails(price: price, change: change)
      ) as _ConditionalContent<AppPriceDetails, AppUpdateDetails>
    case let .updated(date, seen):
      return ViewBuilder.buildEither(second:
        AppUpdateDetails(date: date, seen: seen)
      ) as _ConditionalContent<AppPriceDetails, AppUpdateDetails>
    }
  }
}

private struct AppPriceDetails: View {
  let price: String
  let change: AppSummary.PriceChange

  var body: some View {
    HStack {
      if change == .increase {
        Image(systemName: "arrow.up")
      } else if change == .decrease {
        Image(systemName: "arrow.down")
      }
      Text(price)
        .lineLimit(1)
        .multilineTextAlignment(.trailing)
    }
      .foregroundColor(color)
  }

  private var color: Color {
    switch change {
    case .same: return .primary
    case .decrease: return .green
    case .increase: return .red
    }
  }
}

private struct AppUpdateDetails: View {
  let date: Date
  let seen: Bool

  @Environment(\.updateDateFormatter) private var dateFormatter

  var body: some View {
    ZStack(alignment: .topTrailing) {
      Text(dateFormatter.string(from: date))
        .lineLimit(1)
        .multilineTextAlignment(.trailing)

      if !seen {
        Circle()
          .foregroundColor(.blue)
          .frame(width: 15, height: 15)
          .offset(x: 8, y: -14)
      }
    }
  }
}
