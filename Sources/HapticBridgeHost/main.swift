#if os(macOS)
import Foundation
import AppKit

struct CLIOptions {
    var port: UInt16 = 49374
    var verbose: Bool = false
    var leadDelayMS: Int = 120
    var help: Bool = false
}

func parseArgs(_ argv: [String]) -> CLIOptions {
    var options = CLIOptions()
    var i = 1
    while i < argv.count {
        let arg = argv[i]
        switch arg {
        case "--port", "-p":
            i += 1
            if i < argv.count, let p = UInt16(argv[i]) {
                options.port = p
            } else {
                FileHandle.standardError.write(Data("error: --port requires a number\n".utf8))
                exit(64)
            }
        case "--delay", "-d":
            i += 1
            if i < argv.count, let ms = Int(argv[i]), ms >= 0, ms <= 2000 {
                options.leadDelayMS = ms
            } else {
                FileHandle.standardError.write(Data("error: --delay expects a number of milliseconds between 0 and 2000\n".utf8))
                exit(64)
            }
        case "--verbose", "-v":
            options.verbose = true
        case "--help", "-h":
            options.help = true
        default:
            FileHandle.standardError.write(Data("error: unknown argument \(arg)\n".utf8))
            exit(64)
        }
        i += 1
    }
    return options
}

func printUsage() {
    print("""
    haptic-bridge-host: relay iOS Simulator haptics to the Mac trackpad

    USAGE:
      haptic-bridge-host [--port N] [--delay MS] [--verbose]

    OPTIONS:
      --port,    -p N   Port to listen on (default: 49374)
      --delay,   -d MS  Wait this many ms before firing each haptic so the
                        tick lands a beat after the tap, not on top of it
                        (default: 120, set to 0 to fire immediately)
      --verbose, -v     Print every event as it arrives
      --help,    -h     Show this help

    Pair with the HapticBridge Swift package inside your simulator app and
    call HapticBridge.install() during app startup.
    """)
}

setbuf(stdout, nil) // line-buffer is unhelpful when piping/redirecting

let options = parseArgs(CommandLine.arguments)
if options.help {
    printUsage()
    exit(0)
}

// Ensure AppKit is fully initialized so NSHapticFeedbackManager works.
_ = NSApplication.shared

let leadDelay = TimeInterval(options.leadDelayMS) / 1000.0
let server = HapticServer(port: options.port, verbose: options.verbose, leadDelay: leadDelay)
do {
    try server.start()
} catch {
    FileHandle.standardError.write(Data("[haptic-bridge-host] failed to start: \(error)\n".utf8))
    exit(1)
}

// Forward Ctrl-C to a clean exit.
signal(SIGINT) { _ in
    print("\n[haptic-bridge-host] bye")
    exit(0)
}

RunLoop.main.run()
#else
import Foundation
FileHandle.standardError.write(Data("haptic-bridge-host requires macOS\n".utf8))
exit(1)
#endif
