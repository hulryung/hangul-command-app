import SwiftUI
import Foundation

struct ContentView: View {
    @StateObject private var keyMappingManager = KeyMappingManager.shared
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = ""
    @State private var showKeyCaptureSheet = false

    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "keyboard.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.accentColor)
                    .accessibilityLabel("키보드 아이콘")

                Text("한영 전환 앱")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("원하는 키를 한영키로 사용")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Key Configuration
            VStack(spacing: 12) {
                Text("전환 키")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack {
                    Image(systemName: "command")
                        .font(.title2)
                        .foregroundColor(.accentColor)

                    Text(keyMappingManager.sourceKeyInfo.displayName)
                        .font(.title3)
                        .fontWeight(.medium)

                    Spacer()

                    Button("키 변경") {
                        showKeyCaptureSheet = true
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(16)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)

            // Status & Toggle
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: keyMappingManager.isMappingEnabled ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(keyMappingManager.isMappingEnabled ? .green : .red)

                    Text("현재 상태: \(keyMappingManager.isMappingEnabled ? "활성화" : "비활성화")")
                        .font(.title3)
                        .fontWeight(.medium)
                }

                Button(action: {
                    Task { await toggleMapping() }
                }) {
                    HStack {
                        if keyMappingManager.isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: keyMappingManager.isMappingEnabled ? "xmark" : "checkmark")
                        }

                        Text(keyMappingManager.isMappingEnabled ? "비활성화" : "활성화")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(keyMappingManager.isMappingEnabled ? Color.red : Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(keyMappingManager.isLoading)
            }
            .padding(20)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(16)
            .shadow(radius: 2)

            // Instructions
            VStack(alignment: .leading, spacing: 12) {
                Text("사용 방법")
                    .font(.headline)
                    .fontWeight(.semibold)

                VStack(alignment: .leading, spacing: 8) {
                    InstructionRow(
                        number: 1,
                        text: "\"키 변경\" 버튼을 눌러 한영 전환에 사용할 키를 설정"
                    )

                    InstructionRow(
                        number: 2,
                        text: "활성화 버튼 클릭 (관리자 비밀번호 입력)"
                    )

                    InstructionRow(
                        number: 3,
                        text: "시스템 설정 > 키보드 > 키보드 단축키 > 입력 소스에서 \"이전 입력 소스 선택\" 단축키를 설정한 키로 변경"
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: {
                keyMappingManager.openSystemPreferences()
            }) {
                HStack {
                    Image(systemName: "gear")
                    Text("시스템 환경설정 열기")
                }
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(10)
            }

            Spacer()

            if let errorMessage = keyMappingManager.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal)
            }

            Text("활성화 즉시 적용 · 재부팅 필요 없음")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(32)
        .frame(minWidth: 400, minHeight: 560)
        .alert(isPresented: $showingAlert) {
            Alert(
                title: Text(alertTitle),
                message: Text(alertMessage),
                dismissButton: .default(Text("확인")) {
                    showingAlert = false
                }
            )
        }
        .sheet(isPresented: $showKeyCaptureSheet) {
            KeyCaptureSheetView(manager: keyMappingManager, isPresented: $showKeyCaptureSheet)
        }
        .task {
            await keyMappingManager.checkCurrentStatus()
        }
        .onReceive(keyMappingManager.$errorMessage) { errorMessage in
            if let errorMessage = errorMessage {
                alertTitle = "오류"
                alertMessage = errorMessage
                showingAlert = true
            }
        }
    }

    private func toggleMapping() async {
        let success: Bool
        let targetState: String

        if keyMappingManager.isMappingEnabled {
            success = await keyMappingManager.disableMapping()
            targetState = "비활성화"
        } else {
            success = await keyMappingManager.enableMapping()
            targetState = "활성화"
        }

        if success {
            alertTitle = "성공"
            alertMessage = "한영 전환이 성공적으로 \(targetState)되었습니다.\n\(keyMappingManager.sourceKeyInfo.displayName) 키로 한영 전환을 사용해 보세요!"
        } else {
            alertTitle = "오류"
            alertMessage = "\(targetState)하는 중 오류가 발생했습니다. 관리자 비밀번호를 확인해주세요."
        }
        showingAlert = true
    }
}

// MARK: - Key Capture Sheet

struct KeyCaptureSheetView: View {
    @ObservedObject var manager: KeyMappingManager
    @Binding var isPresented: Bool
    @State private var pulseAnimation = false

    var body: some View {
        VStack(spacing: 24) {
            if let captured = manager.capturedKeyInfo {
                // Key detected
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.green)

                    Text("감지된 키")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    Text(captured.displayName)
                        .font(.system(size: 28, weight: .bold))

                    HStack(spacing: 16) {
                        Button("다시 입력") {
                            manager.startKeyCapture()
                        }
                        .buttonStyle(.bordered)

                        Button("확인") {
                            manager.setSourceKey(captured)
                            manager.stopKeyCapture()
                            isPresented = false
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            } else {
                // Waiting for key press
                VStack(spacing: 16) {
                    Image(systemName: "keyboard")
                        .font(.system(size: 48))
                        .foregroundColor(.accentColor)
                        .opacity(pulseAnimation ? 0.4 : 1.0)
                        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: pulseAnimation)

                    Text("한영 전환에 사용할 키를\n눌러주세요")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)

                    Text("커맨드, 옵션, 쉬프트 등 수정자 키도 감지됩니다")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Button("취소") {
                        manager.stopKeyCapture()
                        isPresented = false
                    }
                    .buttonStyle(.bordered)
                    .padding(.top, 8)
                }
                .onAppear {
                    pulseAnimation = true
                }
            }
        }
        .padding(40)
        .frame(width: 360, height: 280)
        .onAppear {
            manager.startKeyCapture()
        }
        .onDisappear {
            manager.stopKeyCapture()
        }
    }
}

// MARK: - Instruction Row

struct InstructionRow: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background(Color.accentColor)
                .clipShape(Circle())

            Text(text)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
