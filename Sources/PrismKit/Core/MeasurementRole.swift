import Foundation

/// A semantic role describing what part of a logical component a measurement represents.
///
/// Roles let the overlay understand relationships between measured areas of the
/// same component — for example, computing internal padding between a
/// `container` and its `content`.
public enum MeasurementRole: Hashable, Sendable, Codable {
    case container
    case content
    case title
    case subtitle
    case icon
    case image
    case background
    case custom(String)

    /// A short human-readable label used in overlay text and identifiers.
    public var label: String {
        switch self {
        case .container: return "container"
        case .content: return "content"
        case .title: return "title"
        case .subtitle: return "subtitle"
        case .icon: return "icon"
        case .image: return "image"
        case .background: return "background"
        case .custom(let name): return name
        }
    }
}
