import AppKit
import Carbon
import OSLog

/// All traffic is local Apple Events, addressed to an existing process. Never launch
/// a player, bring it forward, or invoke a shell helper.
final class MediaAppleEventClient {
    private let logger = Logger(subsystem: "com.noahkagan.rhino", category: "media-playback")
    static let supported = ["com.apple.Music", "com.spotify.client"]
    enum Failure: Error { case unavailable, badReply }

    func runningApplications(_ bundleIDs: [String]) -> [MediaPlayer] {
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return [] }
        return bundleIDs.filter { Self.supported.contains($0) }.flatMap { bundleID in
            NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).compactMap { app in
                app.launchDate.map { MediaPlayer(bundleID: bundleID, pid: app.processIdentifier, launchDate: $0) }
            }
        }
    }

    private func target(_ player: MediaPlayer) throws -> NSAppleEventDescriptor {
        guard Self.supported.contains(player.bundleID),
              let app = NSRunningApplication(processIdentifier: player.pid), !app.isTerminated,
              app.bundleIdentifier == player.bundleID, app.launchDate == player.launchDate else {
            throw Failure.unavailable
        }
        return NSAppleEventDescriptor(processIdentifier: player.pid)
    }

    /// Check only. Never prompts: a consent dialog during a recording takes focus, and the
    /// dictated text would paste into the dialog. Prompts come from Settings instead.
    func hasPermission(for player: MediaPlayer) -> Bool {
        guard let target = try? target(player), let address = target.aeDesc else { return false }
        return AEDeterminePermissionToAutomateTarget(address, typeWildCard, typeWildCard, false) == noErr
    }

    /// Shows macOS's Automation consent dialog when needed. Blocks until answered, so call
    /// it off the main thread and only from an explicit Settings action, never mid-recording.
    /// Returns the macOS status: noErr granted, errAEEventNotPermitted denied (no dialog
    /// is shown for an earlier "Don't Allow"; only System Settings can change it).
    @discardableResult
    func requestPermission(for player: MediaPlayer) -> OSStatus {
        guard let target = try? target(player), let address = target.aeDesc else { return OSStatus(procNotFound) }
        return AEDeterminePermissionToAutomateTarget(address, typeWildCard, typeWildCard, true)
    }

    func send(eventClass: String, id: String, player: MediaPlayer,
              object: NSAppleEventDescriptor? = nil,
              parameters: [String: NSAppleEventDescriptor] = [:]) throws -> NSAppleEventDescriptor {
        let event = NSAppleEventDescriptor(eventClass: Self.code(eventClass), eventID: Self.code(id),
                                          targetDescriptor: try target(player),
                                          returnID: AEReturnID(kAutoGenerateReturnID),
                                          transactionID: AETransactionID(kAnyTransactionID))
        if let object { event.setParam(object, forKeyword: keyDirectObject) }
        for (key, value) in parameters { event.setParam(value, forKeyword: Self.code(key)) }
        let reply: NSAppleEventDescriptor
        do {
            reply = try event.sendEvent(options: [.waitForReply, .neverInteract, .dontRecord], timeout: 1)
        } catch {
            logger.error("Media command \(eventClass, privacy: .public)/\(id, privacy: .public) to \(player.bundleID, privacy: .public) failed: \((error as NSError).code)")
            throw error
        }
        if let error = reply.paramDescriptor(forKeyword: keyErrorNumber), error.int32Value != 0 {
            logger.error("Media reply error \(player.bundleID, privacy: .public) \(eventClass, privacy: .public)/\(id, privacy: .public): \(error.int32Value)")
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(error.int32Value))
        }
        return reply
    }

    static func propertySpecifier(_ name: String,
                                  container: NSAppleEventDescriptor = .null()) -> NSAppleEventDescriptor {
        let record = NSAppleEventDescriptor.record()
        record.setDescriptor(NSAppleEventDescriptor(typeCode: typeProperty), forKeyword: AEKeyword(keyAEDesiredClass))
        record.setDescriptor(NSAppleEventDescriptor(enumCode: OSType(formPropertyID)), forKeyword: AEKeyword(keyAEKeyForm))
        record.setDescriptor(NSAppleEventDescriptor(typeCode: code(name)), forKeyword: AEKeyword(keyAEKeyData))
        record.setDescriptor(container, forKeyword: AEKeyword(keyAEContainer))
        return record.coerce(toDescriptorType: typeObjectSpecifier)!
    }

    static func code(_ value: String) -> FourCharCode {
        value.utf8.reduce(0) { ($0 << 8) | UInt32($1) }
    }
}
