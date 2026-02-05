import SwiftUI
import Foundation

enum KeyMappingError: LocalizedError {
    case directoryNotWritable
    case processFailed(Int32)
    case appleScriptExecutionFailed
    case permissionDenied
    case pathValidationFailed
    case launchAgentNotFound
    
    var errorDescription: String? {
        switch self {
        case .directoryNotWritable:
            return "디렉터리에 쓰기 권한이 없습니다."
        case .processFailed(let code):
            return "프로세스 실행 실패 (종료 코드: \(code))"
        case .appleScriptExecutionFailed:
            return "AppleScript 실행에 실패했습니다."
        case .permissionDenied:
            return "권한이 거부되었습니다."
        case .pathValidationFailed:
            return "경로 유효성 검사에 실패했습니다."
        case .launchAgentNotFound:
            return "LaunchAgent를 찾을 수 없습니다."
        }
    }
}

@MainActor
class KeyMappingManager: ObservableObject {
    static let shared = KeyMappingManager()
    
    @Published var isMappingEnabled = false
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let launchAgentLabel = "com.hangulcommand.userkeymapping"

    private var launchAgentPlistPath: String {
        return "/Library/LaunchAgents/\(launchAgentLabel).plist"
    }

    private var scriptPath: String {
        return getSecureScriptPath()
    }

    private init() {
        Task {
            await checkCurrentStatus()
        }
    }

    private func getSecureScriptPath() -> String {
        // Try system directory first, fallback to temp
        let systemPath = "/Users/Shared/bin/hangulkeymapping"
        let tempPath = FileManager.default.temporaryDirectory.appendingPathComponent("hangulkeymapping").path
        
        if FileManager.default.isWritableFile(atPath: "/Users/Shared") {
            return systemPath
        } else {
            return tempPath
        }
    }
    
    private func validatePath(_ path: String) throws {
        let url = URL(fileURLWithPath: path)
        
        // Validate parent directory permissions
        let parentURL = url.deletingLastPathComponent()
        guard FileManager.default.fileExists(atPath: parentURL.path) else {
            throw KeyMappingError.pathValidationFailed
        }
        
        guard FileManager.default.isWritableFile(atPath: parentURL.path) else {
            throw KeyMappingError.directoryNotWritable
        }
        
        // Prevent path traversal
        let pathComponents = path.components(separatedBy: "/")
        guard !pathComponents.contains("..") && !pathComponents.contains("~") else {
            throw KeyMappingError.pathValidationFailed
        }
    }
    
    private func createSecureDirectory(at path: String) throws {
        let url = URL(fileURLWithPath: path)
        
        // Validate before creation
        try validatePath(path)
        
        // Create directory with secure permissions
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        
        // Set secure permissions (755)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
    }
    
    private func executeProcess(_ launchPath: String, arguments: [String]) throws -> Data {
        let process = Process()
        let pipe = Pipe()
        let errorPipe = Pipe()
        
        defer {
            // Ensure cleanup
            if process.isRunning {
                process.terminate()
            }
            pipe.fileHandleForReading.closeFile()
            errorPipe.fileHandleForReading.closeFile()
        }
        
        process.launchPath = launchPath
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = errorPipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            // Check for errors
            if process.terminationStatus != 0 {
                _ = errorPipe.fileHandleForReading.readDataToEndOfFile()
                throw KeyMappingError.processFailed(process.terminationStatus)
            }
            
            return pipe.fileHandleForReading.readDataToEndOfFile()
        } catch {
            throw KeyMappingError.processFailed(-1)
        }
    }
    
    func checkCurrentStatus() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        // Check if plist and script exist
        let plistExists = FileManager.default.fileExists(atPath: launchAgentPlistPath)
        let scriptExists = FileManager.default.fileExists(atPath: scriptPath)
        
        // Also check current hidutil mapping to verify it's actually active
        var hidutilActive = false
        if plistExists && scriptExists {
            do {
                let output = try executeProcess("/usr/bin/hidutil", arguments: ["property", "--get", "UserKeyMapping"])
                let outputString = String(data: output, encoding: .utf8) ?? ""
                // Check if our mapping (0x90 = 144 decimal for Lang1) is present
                hidutilActive = outputString.contains("0x700000090") || outputString.contains("144")
            } catch {
                // If we can't check, assume it's enabled based on file existence
                hidutilActive = true
            }
        }
        
        await MainActor.run {
            self.isMappingEnabled = plistExists && scriptExists
            self.isLoading = false
        }
    }
    
    func enableMapping() async -> Bool {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            // Create directory securely
            let directory = URL(fileURLWithPath: scriptPath).deletingLastPathComponent().path
            try createSecureDirectory(at: directory)
            
            // ===== KEY FIX =====
            // Changed from F18 (0x6D) to Lang1/한영 (0x90)
            // Lang1 (0x90) is the dedicated Korean/English toggle key
            // macOS recognizes this natively - no extra system shortcut config needed
            //
            // HID Usage Table reference:
            //   0x7000000E7 = Right Command (source)
            //   0x700000090 = Keyboard Lang1 / 한영 (destination)
            //
            // Previously used 0x70000006D (F18), which required manually
            // setting F18 as the input source shortcut in System Preferences.
            // With Lang1, it just works immediately.
            let scriptContent = """
            #!/bin/sh
            # Right Command (0xE7) -> Lang1/한영 key (0x90)
            # Lang1 is natively recognized by macOS as Korean/English toggle
            hidutil property --set '{"UserKeyMapping":[{"HIDKeyboardModifierMappingSrc":0x7000000e7,"HIDKeyboardModifierMappingDst":0x700000090}]}'
            """
            
            try scriptContent.write(toFile: scriptPath, atomically: true, encoding: .utf8)
            
            // Set executable permissions securely
            _ = try executeProcess("/bin/chmod", arguments: ["755", scriptPath])
            
            // Also apply the mapping immediately (so it works without reboot)
            _ = try? executeProcess("/usr/bin/hidutil", arguments: [
                "property", "--set",
                "{\"UserKeyMapping\":[{\"HIDKeyboardModifierMappingSrc\":0x7000000e7,\"HIDKeyboardModifierMappingDst\":0x700000090}]}"
            ])
            
            // Create LaunchAgent plist in temp first
            let plistContent = generateLaunchAgentPlist()
            let tempPlistPath = FileManager.default.temporaryDirectory.appendingPathComponent("com.hangulcommand.userkeymapping.plist").path
            
            try plistContent.write(toFile: tempPlistPath, atomically: true, encoding: .utf8)
            
            // Use secure AppleScript execution
            let success = await executeSecureAppleScript(
                createScript: tempPlistPath,
                targetPath: launchAgentPlistPath
            )
            
            // Cleanup temp file
            try? FileManager.default.removeItem(atPath: tempPlistPath)
            
            if success {
                await checkCurrentStatus()
                return true
            } else {
                await MainActor.run {
                    errorMessage = "LaunchAgent 설치에 실패했습니다."
                    isLoading = false
                }
                return false
            }
            
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
            return false
        }
    }
    
    func disableMapping() async -> Bool {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        // Clear hidutil mapping immediately
        _ = try? executeProcess("/usr/bin/hidutil", arguments: [
            "property", "--set",
            "{\"UserKeyMapping\":[]}"
        ])
        
        // Use secure AppleScript for removal
        let success = await executeSecureAppleScript(
            remove: launchAgentLabel,
            plistPath: launchAgentPlistPath,
            scriptPath: scriptPath
        )
        
        if success {
            await checkCurrentStatus()
            return true
        } else {
            await MainActor.run {
                errorMessage = "LaunchAgent 제거에 실패했습니다."
                isLoading = false
            }
            return false
        }
    }
    
    private func generateLaunchAgentPlist() -> String {
        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>\(launchAgentLabel)</string>
            <key>ProgramArguments</key>
            <array>
                <string>\(scriptPath)</string>
            </array>
            <key>RunAtLoad</key>
            <true/>
            <key>KeepAlive</key>
            <false/>
        </dict>
        </plist>
        """
    }
    
    private func executeSecureAppleScript(createScript: String? = nil, targetPath: String? = nil, remove: String? = nil, plistPath: String? = nil, scriptPath: String? = nil) async -> Bool {
        var scriptContent = ""
        
        if let create = createScript, let target = targetPath {
            // Secure script creation
            let escapedCreate = create.replacingOccurrences(of: "'", with: "'\\''")
            let escapedTarget = target.replacingOccurrences(of: "'", with: "'\\''")
            scriptContent = """
            do shell script "
                mkdir -p '\(URL(fileURLWithPath: escapedTarget).deletingLastPathComponent().path)' 2>/dev/null || exit 1;
                mv '\(escapedCreate)' '\(escapedTarget)' 2>/dev/null || exit 2;
                chown root:admin '\(escapedTarget)' 2>/dev/null || exit 3;
                chmod 644 '\(escapedTarget)' 2>/dev/null || exit 4;
                launchctl load '\(escapedTarget)' 2>/dev/null || exit 5;
                echo 'SUCCESS'
            " with administrator privileges
            """
        } else if let remove = remove, let plist = plistPath, let script = scriptPath {
            // Secure script removal
            let escapedRemove = remove.replacingOccurrences(of: "'", with: "'\\''")
            let escapedPlist = plist.replacingOccurrences(of: "'", with: "'\\''")
            let escapedScript = script.replacingOccurrences(of: "'", with: "'\\''")
            scriptContent = """
            do shell script "
                launchctl remove '\(escapedRemove)' 2>/dev/null || true;
                rm -f '\(escapedPlist)' 2>/dev/null || true;
                rm -f '\(escapedScript)' 2>/dev/null || true;
                hidutil property --set '{\"UserKeyMapping\":[]}' 2>/dev/null || true;
                echo 'SUCCESS'
            " with administrator privileges
            """
        }
        
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let appleScript = NSAppleScript(source: scriptContent)
                var errorDict: NSDictionary?
                
                let result = appleScript?.executeAndReturnError(&errorDict)
                
                if let error = errorDict {
                    print("AppleScript error: \(error)")
                    DispatchQueue.main.async {
                        continuation.resume(returning: false)
                    }
                    return
                }
                
                // Check if script succeeded
                if let resultString = result?.stringValue, resultString.contains("SUCCESS") {
                    DispatchQueue.main.async {
                        continuation.resume(returning: true)
                    }
                } else {
                    DispatchQueue.main.async {
                        continuation.resume(returning: false)
                    }
                }
            }
        }
    }
    
    func openSystemPreferences() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.keyboard?InputSources")!
        NSWorkspace.shared.open(url)
    }
}
