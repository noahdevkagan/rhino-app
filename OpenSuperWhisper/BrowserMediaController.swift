import Foundation
import Carbon

struct BrowserMediaTicket {
    let browser: MediaPlayer
    let tab: NSAppleEventDescriptor
    let token: String
    /// False when the pause reply timed out: the page may never have run the script.
    let confirmed: Bool
}

protocol BrowserMediaTransport: AnyObject {
    func runningBrowsers() -> [MediaPlayer]
    func hasPermission(for browser: MediaPlayer) -> Bool
    func tabs(in browser: MediaPlayer) throws -> [NSAppleEventDescriptor]
    func execute(_ script: String, in tab: NSAppleEventDescriptor, browser: MediaPlayer) throws -> String
}

/// Called only on the playback worker. No tab URLs/titles or media URLs leave the
/// browser; the only returned data is our own opaque tokens and status words.
final class BrowserMediaController {
    private let transport: BrowserMediaTransport

    init(transport: BrowserMediaTransport = AppleEventBrowserTransport()) {
        self.transport = transport
    }

    func pause(isActive: () -> Bool) -> [BrowserMediaTicket] {
        var tickets: [BrowserMediaTicket] = []
        for browser in transport.runningBrowsers() {
            guard isActive() else { break }
            guard transport.hasPermission(for: browser),
                  let tabs = try? transport.tabs(in: browser) else { continue }
            for tab in tabs {
                guard isActive() else { break }
                let token = UUID().uuidString
                do {
                    let result = try transport.execute(BrowserMediaScript.pause(token: token), in: tab, browser: browser)
                    if result == "paused" {
                        tickets.append(BrowserMediaTicket(browser: browser, tab: tab, token: token, confirmed: true))
                    }
                } catch where (error as NSError).domain == NSOSStatusErrorDomain
                    && (error as NSError).code == Int(errAETimeout) {
                    // The browser may have paused before the reply timed out. The restore
                    // script will only act if this exact token actually exists there.
                    tickets.append(BrowserMediaTicket(browser: browser, tab: tab, token: token, confirmed: false))
                } catch {
                    // Internal pages, denied JavaScript access, closed tabs: leave alone.
                }
            }
        }
        return tickets
    }

    func resume(_ tickets: [BrowserMediaTicket]) {
        // Most restores go directly to saved tabs. Safari tab indices can change and
        // Chrome tabs can move windows, so look for remaining tokens in current tabs.
        var browsers: [MediaPlayer] = []
        for ticket in tickets where !browsers.contains(ticket.browser) { browsers.append(ticket.browser) }
        for browser in browsers {
            let owned = tickets.filter { $0.browser == browser }
            var pending = Set(owned.map(\.token))
            func restore(_ tab: NSAppleEventDescriptor) {
                guard !pending.isEmpty,
                      let response = try? transport.execute(BrowserMediaScript.resume(tokens: Array(pending)),
                                                            in: tab, browser: browser),
                      let data = response.data(using: .utf8),
                      let completed = try? JSONDecoder().decode([String].self, from: data) else { return }
                pending.subtract(completed)
            }
            for ticket in owned { restore(ticket.tab) }
            // Rescan only for confirmed tokens. An unconfirmed one usually means a hung tab
            // whose late script refused the stale pause; searching every tab for it would
            // cost another timeout per hung tab on every dictation.
            pending.formIntersection(owned.filter(\.confirmed).map(\.token))
            if !pending.isEmpty, let currentTabs = try? transport.tabs(in: browser) {
                for tab in currentTabs { restore(tab) }
            }
        }
    }
}

/// Codes come from the installed browsers' scripting dictionaries. Firefox has no
/// equivalent Apple Event interface and is intentionally not enumerated.
final class AppleEventBrowserTransport: BrowserMediaTransport {
    private let events = MediaAppleEventClient()

    func runningBrowsers() -> [MediaPlayer] {
        events.runningApplications(["com.google.Chrome", "com.apple.Safari"])
    }

    func hasPermission(for browser: MediaPlayer) -> Bool { events.hasPermission(for: browser) }

    func tabs(in browser: MediaPlayer) throws -> [NSAppleEventDescriptor] {
        let windows = try events.allElements("cwin", player: browser)
        return windows.flatMap { window in
            (try? events.allElements(browser.bundleID == "com.apple.Safari" ? "bTab" : "CrTb",
                                     of: window, player: browser)) ?? []
        }
    }

    func execute(_ script: String, in tab: NSAppleEventDescriptor, browser: MediaPlayer) throws -> String {
        let reply: NSAppleEventDescriptor
        if browser.bundleID == "com.apple.Safari" {
            reply = try events.send(eventClass: "sfri", id: "dojs", player: browser,
                                    object: NSAppleEventDescriptor(string: script), parameters: ["dcnm": tab])
        } else {
            reply = try events.send(eventClass: "CrSu", id: "ExJa", player: browser,
                                    object: tab, parameters: ["JvSc": NSAppleEventDescriptor(string: script)])
        }
        guard let result = reply.paramDescriptor(forKeyword: keyDirectObject)?.stringValue else {
            throw MediaAppleEventClient.Failure.badReply
        }
        return result
    }
}
