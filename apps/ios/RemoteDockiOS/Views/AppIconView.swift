import SwiftUI

struct AppIconView: View {
    var title: String
    var isActive: Bool

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            RoundedRectangle(cornerRadius: 8)
                .fill(iconGradient)
                .overlay {
                    Text(initials)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                }
                .aspectRatio(1, contentMode: .fit)

            if isActive {
                Circle()
                    .fill(.green)
                    .frame(width: 12, height: 12)
                    .overlay {
                        Circle().stroke(.background, lineWidth: 2)
                    }
                    .offset(x: 2, y: 2)
            }
        }
    }

    private var initials: String {
        String(title.prefix(2)).uppercased()
    }

    private var iconGradient: LinearGradient {
        LinearGradient(
            colors: [.blue, .teal],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
