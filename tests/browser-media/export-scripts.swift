import Foundation

@main struct ExportBrowserScripts {
    static func main() throws {
        let scripts = [
            "pause": BrowserMediaScript.pause(token: "browser-regression", deadline: Date().addingTimeInterval(300)),
            "resume": BrowserMediaScript.resume(tokens: ["browser-regression"]),
            "other": BrowserMediaScript.resume(tokens: ["other-recording"]),
            "expired": BrowserMediaScript.pause(token: "expired", deadline: .distantPast),
        ]
        print("window.rhinoScripts = \(String(data: try JSONEncoder().encode(scripts), encoding: .utf8)!);")
    }
}
