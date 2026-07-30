import SwiftUI
import UIKit

/// A screen built entirely in UIKit, pushed from the same SwiftUI stack.
///
/// It exists to answer a question the SDK's shape invites: PrismKit's entry
/// point is a SwiftUI modifier, so is a UIKit screen invisible to it? The
/// accessibility walk starts at the app's key window rather than at the
/// SwiftUI view, so it should not be — and this screen is how that gets
/// checked rather than assumed.
///
/// The answer is yes: it streams with correct geometry and text. What does
/// not survive is `accessibilityIdentifier` — set on every view below and
/// present at runtime, it still reaches the snapshot as nil. That is a defect
/// in the walk rather than in this screen, and it is why UIKit content cannot
/// yet be paired by identity in a design check.
final class UIKitDetailViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(Shop.Palette.screenBackground)

        let title = label(
            text: "UIKit screen",
            font: .systemFont(ofSize: 22, weight: .semibold),
            color: UIColor(Shop.Palette.primaryText),
            identifier: "uikit-title"
        )

        let card = UIView()
        card.backgroundColor = UIColor(Shop.Palette.cardWhite)
        card.layer.cornerRadius = Shop.Radius.card
        card.layer.cornerCurve = .continuous
        card.translatesAutoresizingMaskIntoConstraints = false
        card.accessibilityIdentifier = "uikit-card"
        card.isAccessibilityElement = false

        let rowLabel = label(
            text: "Rendered by",
            font: .systemFont(ofSize: 16),
            color: UIColor(Shop.Palette.secondaryText),
            identifier: "uikit-row-label"
        )
        let rowValue = label(
            text: "UIKit",
            font: .systemFont(ofSize: 16, weight: .medium),
            color: UIColor(Shop.Palette.primaryText),
            identifier: "uikit-row-value"
        )

        let button = UIButton(type: .system)
        button.setTitle("Primary action", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = UIColor(Shop.Palette.brandBlue)
        button.layer.cornerRadius = Shop.Radius.button
        button.layer.cornerCurve = .continuous
        button.translatesAutoresizingMaskIntoConstraints = false
        button.accessibilityIdentifier = "uikit-primary-button"

        for subview in [title, card, button] { view.addSubview(subview) }
        for subview in [rowLabel, rowValue] { card.addSubview(subview) }

        let margin = Shop.screenMargin
        let guide = view.safeAreaLayoutGuide

        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: guide.topAnchor, constant: Shop.Space.xxl),
            title.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: margin),

            card.topAnchor.constraint(equalTo: title.bottomAnchor, constant: Shop.Space.xxl),
            card.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: margin),
            card.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -margin),

            rowLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: Shop.cardPaddingVertical),
            rowLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: Shop.cardPaddingHorizontal),
            rowLabel.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -Shop.cardPaddingVertical),

            rowValue.centerYAnchor.constraint(equalTo: rowLabel.centerYAnchor),
            rowValue.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -Shop.cardPaddingHorizontal),

            button.topAnchor.constraint(equalTo: card.bottomAnchor, constant: Shop.Space.xxl),
            button.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: margin),
            button.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -margin),
            button.heightAnchor.constraint(equalToConstant: Shop.buttonHeight),
        ])

    }

    private func label(
        text: String,
        font: UIFont,
        color: UIColor,
        identifier: String
    ) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = font
        label.textColor = color
        label.translatesAutoresizingMaskIntoConstraints = false
        label.accessibilityIdentifier = identifier
        return label
    }
}

struct UIKitScreen: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIKitDetailViewController {
        UIKitDetailViewController()
    }

    func updateUIViewController(_ controller: UIKitDetailViewController, context: Context) {}
}
