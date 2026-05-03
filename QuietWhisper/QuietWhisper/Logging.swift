import OSLog

/// Centralized loggers, one per concern. Filter in Console.app or `log stream`
/// with `subsystem == "app.quietwhisper" AND category == "<name>"`.
///
/// Levels (per Apple guidance):
/// - `.fault`   process-level corruption, unrecoverable
/// - `.error`   recoverable failures the user should know about
/// - `.notice`  important state transitions worth seeing in normal use
/// - `.info`    useful diagnostics, off by default in Console
/// - `.debug`   verbose; off in release builds
///
/// Privacy: transcript text and titles are user content — log lengths and
/// hashes, never the strings themselves. File paths inside the temp dir are
/// fine as `.public` since they contain only UUIDs.
enum QWLog {
    static let app        = Logger(subsystem: "app.quietwhisper", category: "app")
    static let audio      = Logger(subsystem: "app.quietwhisper", category: "audio")
    static let transcribe = Logger(subsystem: "app.quietwhisper", category: "transcribe")
    static let state      = Logger(subsystem: "app.quietwhisper", category: "state")
    static let ui         = Logger(subsystem: "app.quietwhisper", category: "ui")
    static let input      = Logger(subsystem: "app.quietwhisper", category: "input")
    static let settings   = Logger(subsystem: "app.quietwhisper", category: "settings")
}
