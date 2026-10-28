import SwiftUI

/// How a screen arranges its main content blocks.
enum AdaptiveLayoutMode: Equatable {
    case singleColumn
    case twoColumn
}

/// Pure layout decisions shared by screens that adapt between a phone-width
/// display and a wide one (for example the iPhone Duo inner display).
///
/// Decisions are made from the horizontal size class plus a measured width,
/// never from the device, idiom, orientation, or screen size.
enum AdaptiveLayout {
    /// Minimum available width (pt) for a two-column layout.
    /// iPhone Duo: outer portrait 466, outer landscape 678 (compact class, so
    /// always single column), inner portrait 669 and inner landscape 951
    /// (regular class, so two columns).
    static let twoColumnMinWidth: CGFloat = 600

    /// Maximum width (pt) of one readable column of cards and text.
    static let readableMaxWidth: CGFloat = 640

    /// Two columns only when the horizontal size class is `.regular` and the
    /// available width reaches `twoColumnMinWidth`. A `nil` size class is
    /// treated as compact.
    static func mode(horizontalSizeClass: UserInterfaceSizeClass?, availableWidth: CGFloat) -> AdaptiveLayoutMode {
        guard horizontalSizeClass == .regular, availableWidth >= twoColumnMinWidth else {
            return .singleColumn
        }
        return .twoColumn
    }

    /// Width cap for each column: `readableMaxWidth` side by side, uncapped
    /// when stacked so the single-column layout keeps its full width.
    static func columnMaxWidth(for mode: AdaptiveLayoutMode) -> CGFloat {
        mode == .twoColumn ? readableMaxWidth : .infinity
    }
}

/// Lays its children out side by side in `.twoColumn` mode and stacked in
/// `.singleColumn` mode. Uses `AnyLayout` so children keep their identity and
/// `@State` when the mode changes (fold, unfold, rotation).
struct AdaptiveStack<Content: View>: View {
    let mode: AdaptiveLayoutMode
    var spacing: CGFloat? = nil
    var alignment: VerticalAlignment = .top
    @ViewBuilder let content: () -> Content

    var body: some View {
        // Identity-preserving: do not turn into if/else around stateful views.
        let layout = mode == .twoColumn
            ? AnyLayout(HStackLayout(alignment: alignment, spacing: spacing))
            : AnyLayout(VStackLayout(spacing: spacing))
        layout { content() }
    }
}

extension View {
    /// Caps the view to a comfortable reading width and centers it.
    /// A no-op when the container is already narrower than `max`.
    func readableWidth(_ max: CGFloat = AdaptiveLayout.readableMaxWidth) -> some View {
        frame(maxWidth: max)
            .frame(maxWidth: .infinity)
    }
}
