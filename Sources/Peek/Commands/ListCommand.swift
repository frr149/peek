import ArgumentParser

struct List: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "List running apps with capturable windows."
    )

    func run() throws {
        let apps = WindowDiscovery.listApps()

        for app in apps {
            let width = Int(app.mainSize.width)
            let height = Int(app.mainSize.height)
            print("\(app.name)\t\(app.windowCount)\t\(width)x\(height)")
        }
    }
}
