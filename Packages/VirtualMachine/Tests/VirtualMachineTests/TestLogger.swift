import LoggingDomain

struct TestLogger: Logger {
    func info(_ message: String) {}
    func error(_ message: String) {}
}
