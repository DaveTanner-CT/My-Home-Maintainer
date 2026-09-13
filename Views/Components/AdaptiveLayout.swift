import SwiftUI

enum AdaptiveLayout {
    static let wideContentMaxWidth: CGFloat = 1120
    static let detailContentMaxWidth: CGFloat = 920

    static func cardColumns(minimum: CGFloat = 300, spacing: CGFloat = 14) -> [GridItem] {
        [GridItem(.adaptive(minimum: minimum, maximum: 520), spacing: spacing, alignment: .top)]
    }
}

extension View {
    func adaptivePageWidth(_ maxWidth: CGFloat = AdaptiveLayout.wideContentMaxWidth) -> some View {
        frame(maxWidth: maxWidth, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
    }
}
