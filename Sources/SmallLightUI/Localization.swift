import Foundation

public enum UILocalized {
    public static func string(_ key: String) -> String {
        NSLocalizedString(key, bundle: .module, comment: "")
    }

    public static func formatted(_ key: String, _ args: CVarArg...) -> String {
        let format = string(key)
        return String(format: format, arguments: args)
    }
}
