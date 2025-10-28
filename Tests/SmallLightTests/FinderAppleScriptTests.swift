import XCTest

@testable import SmallLightAppHost

final class FinderAppleScriptTests: XCTestCase {
    func testBaseDirectoryScriptMatchesTemplate() {
        let expected = """
            tell application "Finder"
                if (count of Finder windows) is greater than 0 then
                    set targetPath to POSIX path of (target of front Finder window as alias)
                else
                    set targetPath to POSIX path of (desktop as alias)
                end if
            end tell
            return targetPath
            """
        XCTAssertEqual(FinderAppleScript.baseDirectory, expected)
    }

    func testDirectoryProviderTrimsWhitespace() throws {
        let executor = StubExecutor(result: " /Users/example/Desktop \n")
        let provider = FinderFrontWindowDirectoryProvider(executor: executor)

        let path = try provider.activeDirectoryPath()

        XCTAssertEqual(path, "/Users/example/Desktop")
        XCTAssertEqual(executor.capturedScript, FinderAppleScript.baseDirectory)
    }

    func testPathBuilderAppendsComponent() {
        let path = FinderPathBuilder.buildPath(
            baseDirectory: "/Users/example", itemName: "Documents")
        XCTAssertEqual(path, "/Users/example/Documents")
    }
}

private final class StubExecutor: AppleScriptExecuting {
    var capturedScript: String?
    let result: String?

    init(result: String?) {
        self.result = result
    }

    func run(script: String) throws -> String? {
        capturedScript = script
        return result
    }
}
