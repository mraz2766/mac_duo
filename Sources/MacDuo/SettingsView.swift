import AppKit
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @ObservedObject var preferences: Preferences
    @ObservedObject var controller: LidController

    @State private var launchesAtLogin = SMAppService.mainApp.status == .enabled
    @State private var hasScreenPermission = CGPreflightScreenCaptureAccess()
    @State private var settingsOpenFailed = false

    var onQuit: () -> Void

    private static let width: CGFloat = 300
    private static let inset: CGFloat = 14
    private static let bodyHeight: CGFloat = 400
    private static let authorURL = URL(string: "https://github.com/sumimakito")!
    private static let screenRecordingSettingsURL = URL(
        string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_ScreenCapture"
    )!
    private static let logo = Bundle.main.url(forResource: "Logo", withExtension: "png")
        .flatMap(NSImage.init(contentsOf:))

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, Self.inset)
                .padding(.top, 12)
                .padding(.bottom, 10)
            Divider()
            if controller.isSensorAvailable {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        switches
                        if !hasScreenPermission {
                            permissionNotice
                        }
                        startGroup
                        lookGroup
                        perspectiveGroup
                    }
                    .padding(.horizontal, Self.inset)
                    .padding(.vertical, 10)
                }
                .frame(height: Self.bodyHeight)
            } else {
                unavailableNotice
                    .padding(.horizontal, Self.inset)
                    .padding(.vertical, 12)
            }
            Divider()
            appGroup
                .padding(.horizontal, Self.inset)
                .padding(.top, 10)
                .padding(.bottom, 12)
        }
        .frame(width: Self.width)
        .onAppear { hasScreenPermission = CGPreflightScreenCaptureAccess() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            hasScreenPermission = CGPreflightScreenCaptureAccess()
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            if let logo = Self.logo {
                Image(nsImage: logo)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 26, height: 26)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .accessibilityHidden(true)
            }
            Text("Mac Duo").font(.title2.weight(.semibold))
            Spacer()
            Text(String(format: "%.1f°", controller.currentAngle))
                .font(.system(.title3, design: .rounded).monospacedDigit())
                .foregroundStyle(.secondary)
                .accessibilityLabel("屏幕开合角度")
        }
    }

    private var unavailableNotice: some View {
        Text("这台 Mac 没有屏幕开合角度传感器。仅部分 MacBook 机型支持此功能。")
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var switches: some View {
        VStack(alignment: .leading, spacing: 4) {
            toggleRow(
                "景深效果",
                isOn: $preferences.isEnabled,
                help: "合上屏幕时，让画面产生向后倾斜的视觉效果。"
            )
            toggleRow(
                "实时渲染",
                isOn: $preferences.isLivePicture,
                help: "关闭后，效果启动时的画面将保持静止。"
            )
            .disabled(!preferences.isEnabled)
        }
    }

    private var startGroup: some View {
        group("触发") {
            slider(
                "起始角度", value: $preferences.thresholdAngle, in: 5...130, format: "%.0f°",
                help: "屏幕合到此角度时开始显示效果。"
            )
            slider(
                "完全生效角度", value: $preferences.blurSpan, in: 5...60, format: "%.0f°",
                help: "继续合上这么多角度后，效果达到最强。"
            )
        }
    }

    private var lookGroup: some View {
        group("外观") {
            slider(
                "模糊强度", value: $preferences.maxBlurRadius, in: 10...160, format: "%.0f pt",
                help: "画面远端的最大模糊半径。"
            )
            slider(
                "模糊范围", value: $preferences.blurEvenness, in: 0...1, format: "%.0f%%", scale: 100,
                help: "0% 仅模糊远端，100% 模糊整个画面。"
            )
            slider(
                "变暗强度", value: $preferences.maxDim, in: 0...1, format: "%.0f%%", scale: 100,
                help: "画面远端变暗的程度。"
            )
            slider(
                "变暗范围", value: $preferences.dimReach, in: 0.2...1, format: "%.0f%%", scale: 100,
                help: "超过此高度的区域将完全变暗。"
            )
        }
    }

    private var perspectiveGroup: some View {
        group("透视") {
            slider(
                "后倾幅度", value: $preferences.recession, in: 0...3, format: "%.1f×",
                help: "每合上 1° 对应的画面后倾量；1× 表示画面相对空间保持静止。"
            )
            slider(
                "透视强度", value: perspective, in: 0...1, format: "%.0f%%", scale: 100,
                help: "0% 保持两侧平行，100% 产生明显汇聚。"
            )
        }
    }

    private var appGroup: some View {
        VStack(alignment: .leading, spacing: 8) {
            toggleRow("在菜单栏显示角度", isOn: $preferences.showsAngleInMenuBar, help: nil)
            toggleRow("登录时自动启动", isOn: $launchesAtLogin, help: nil)
                .onChange(of: launchesAtLogin) { _, newValue in
                    setLaunchAtLogin(newValue)
                }
            HStack {
                Button("恢复默认设置") { preferences.resetToDefaults() }
                Spacer()
                Button("退出", action: onQuit)
            }
            .controlSize(.small)
            .padding(.top, 2)
            HStack(spacing: 0) {
                Text("作者：").foregroundStyle(.secondary)
                Link("Makito", destination: Self.authorURL)
                    .pointingHand()
                Spacer()
                Text("© 2026 Makito").foregroundStyle(.secondary)
            }
            .font(.caption2)
            .padding(.top, 2)
        }
    }

    private func toggleRow(_ title: String, isOn: Binding<Bool>, help: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title)
                Spacer()
                Toggle("", isOn: isOn)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .accessibilityLabel(title)
            }
            description(help)
        }
    }

    @ViewBuilder
    private func description(_ text: String?) -> some View {
        if let text {
            Text(text)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var perspective: Binding<Double> {
        Binding(
            get: { (Preferences.farthestEye - preferences.viewingDistance) / Preferences.eyeRange },
            set: { preferences.viewingDistance = Preferences.farthestEye - $0 * Preferences.eyeRange }
        )
    }

    private var permissionNotice: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("显示景深效果需要“屏幕与系统录音”权限。")
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
            Button("打开系统设置") {
                openScreenRecordingSettings()
            }
            .controlSize(.small)
            if settingsOpenFailed {
                Text("无法打开系统设置。请手动前往“隐私与安全性”>“屏幕与系统录音”，为 Mac Duo 开启权限。")
                    .font(.caption)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
    }

    private func openScreenRecordingSettings() {
        settingsOpenFailed = false
        Task { @MainActor in
            do {
                let configuration = NSWorkspace.OpenConfiguration()
                configuration.activates = true
                _ = try await NSWorkspace.shared.open(Self.screenRecordingSettingsURL, configuration: configuration)
            } catch {
                settingsOpenFailed = true
            }
        }
    }

    private func group<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            content()
        }
        .disabled(!preferences.isEnabled)
    }

    private func slider(
        _ title: String,
        value: Binding<Double>,
        in range: ClosedRange<Double>,
        format: String,
        scale: Double = 1,
        help: String? = nil
    ) -> some View {
        let reading = String(format: format, value.wrappedValue * scale)
        return VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title)
                Spacer()
                Text(reading)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: range)
                .labelsHidden()
                .controlSize(.small)
                .accessibilityLabel(title)
                .accessibilityValue(reading)
            description(help)
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            launchesAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}

private extension View {
    func pointingHand() -> some View {
        modifier(PointingHand())
    }
}

private struct PointingHand: ViewModifier {
    @State private var pushed = false

    func body(content: Content) -> some View {
        content
            .onHover { inside in
                if inside, !pushed {
                    NSCursor.pointingHand.push()
                    pushed = true
                } else if !inside, pushed {
                    NSCursor.pop()
                    pushed = false
                }
            }
            .onDisappear {
                if pushed {
                    NSCursor.pop()
                    pushed = false
                }
            }
    }
}
