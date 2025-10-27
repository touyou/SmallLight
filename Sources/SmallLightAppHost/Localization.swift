import Foundation

enum AppStrings {
    static func text(_ key: String) -> String {
        NSLocalizedString(key, bundle: .module, comment: "")
    }

    static func formatted(_ key: String, _ args: CVarArg...) -> String {
        let format = text(key)
        return String(format: format, arguments: args)
    }
}
