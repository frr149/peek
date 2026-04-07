import ArgumentParser

struct Scan: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Discover the accessibility tree of a running app."
    )

    @Argument(help: "The application name to scan.")
    var name: String

    @Option(help: "Maximum depth to traverse the AX tree.")
    var depth: Int = 4

    @Flag(help: "Generate a YAML config template for --all captures.")
    var generateConfig = false

    func run() throws {
        let nodes = try AXScanner.scan(appName: name, maxDepth: depth)

        if generateConfig {
            // AX-4: YAML to stdout, parseable
            let yaml = AXScanner.generateConfig(appName: name, nodes: nodes)
            print(yaml)
        } else {
            // Human-readable tree
            let tree = AXScanner.formatTree(nodes)
            print(tree)
        }
    }
}
