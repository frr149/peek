import ArgumentParser

@main
struct Peek: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "peek",
        abstract: "Capture app and web UI screenshots without stealing focus.",
        version: "0.1.0",
        subcommands: [App.self, Web.self, Scan.self, List.self]
    )
}
