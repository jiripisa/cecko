import Darwin

/// How a student's program ended, in terms the console can explain.
public enum RunOutcome: Equatable, Sendable {
    case finished
    case failed(code: Int32)
    /// `signalName` is the English name of the crash ("segmentation fault").
    case crashed(signalName: String)
    case stopped

    public init(_ termination: Termination, stoppedByUser: Bool) {
        switch termination {
        case .exited(0):
            self = .finished
        case .exited(let code):
            self = stoppedByUser ? .stopped : .failed(code: code)
        case .signaled(let signal):
            self = stoppedByUser ? .stopped : .crashed(signalName: Self.name(of: signal))
        }
    }

    static func name(of signal: Int32) -> String {
        switch signal {
        case SIGSEGV: "segmentation fault"
        case SIGABRT: "abort"
        case SIGFPE: "division by zero"
        case SIGBUS: "bus error"
        case SIGILL: "illegal instruction"
        default: "signal \(signal)"
        }
    }
}
