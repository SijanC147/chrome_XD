import Foundation

/// Utility to inspect process command-line arguments using sysctl
struct ProcessInspector {

    /// Get command-line arguments for a process by PID
    static func getArguments(for pid: pid_t) -> [String]? {
        var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
        var size: size_t = 0

        // First call to get buffer size
        if sysctl(&mib, 3, nil, &size, nil, 0) != 0 {
            return nil
        }

        // Allocate buffer
        var buffer = [CChar](repeating: 0, count: size)

        // Second call to get actual data
        if sysctl(&mib, 3, &buffer, &size, nil, 0) != 0 {
            return nil
        }

        // Parse the buffer
        return parseArguments(from: buffer, size: size)
    }

    private static func parseArguments(from buffer: [CChar], size: Int) -> [String]? {
        guard size > MemoryLayout<Int32>.size else { return nil }

        // First 4 bytes are argc
        var argc: Int32 = 0
        memcpy(&argc, buffer, MemoryLayout<Int32>.size)

        // Find the start of argv[0] (skip argc and executable path padding)
        var pos = MemoryLayout<Int32>.size

        // Skip the executable path (first string)
        while pos < size && buffer[pos] != 0 {
            pos += 1
        }

        // Skip null terminators between executable path and argv
        while pos < size && buffer[pos] == 0 {
            pos += 1
        }

        // Now parse argc arguments
        var arguments: [String] = []
        var argCount: Int32 = 0

        while pos < size && argCount < argc {
            var argEnd = pos
            while argEnd < size && buffer[argEnd] != 0 {
                argEnd += 1
            }

            if argEnd > pos {
                let argData = Array(buffer[pos..<argEnd])
                if let arg = String(bytes: argData.map { UInt8(bitPattern: $0) }, encoding: .utf8) {
                    arguments.append(arg)
                }
            }

            pos = argEnd + 1
            argCount += 1
        }

        return arguments
    }
}
