/// Where a measurement was written, captured at the call site.
///
/// The compiler knows this exactly, so nothing downstream has to guess. That
/// matters more than it sounds: finding the code behind a measurement was
/// previously a search for the group name as a literal — which works only for
/// instrumented views, and only while the name in the source and the name in
/// the report stay spelled the same.
///
/// `#fileID` and not `#filePath`, deliberately. The whole path would spare the
/// companion a search, and would also write the build machine's directory
/// layout — and whoever's home directory name — into any release binary that
/// failed to optimise the unused argument away. A module-qualified file name
/// costs one basename lookup and cannot embarrass anybody.
public struct CallSite: Codable, Equatable, Sendable, Hashable {
    /// `#fileID` — "PrismKitExample/ShopScreens.swift". Module-qualified and
    /// relative, so it reads well in a report and carries no absolute path.
    public let file: String

    /// The line the modifier was written on.
    public let line: Int

    public init(file: String = #fileID, line: Int = #line) {
        self.file = file
        self.line = line
    }

    /// The file name alone — "ShopScreens.swift".
    public var fileName: String {
        String(file.split(separator: "/").last ?? Substring(file))
    }

    /// "ShopScreens.swift:200" — how a person refers to a line out loud.
    public var label: String { "\(fileName):\(line)" }
}
