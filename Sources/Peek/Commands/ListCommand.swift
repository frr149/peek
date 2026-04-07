import ArgumentParser

struct List: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "List running apps with capturable windows."
    )

    func run() throws {
        print("TODO: list capturable windows")
    }
}
