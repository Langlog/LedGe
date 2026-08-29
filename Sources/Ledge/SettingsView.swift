import LedgeCore
import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel
    let onQuit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(spacing: 18) {
                    settingsCard
                    localDataCard
                    if let message = model.persistenceMessage {
                        Label(message, systemImage: "exclamationmark.triangle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.orange)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(24)
            }
            Divider()
            contactFooter
        }
        .frame(minWidth: 500, minHeight: 560)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var contactFooter: some View {
        Label(
            "联系邮箱：langziyu2025@gmail.com",
            systemImage: "envelope"
        )
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(LedgeStyle.secondaryInk)
        .textSelection(.enabled)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 13)
        .padding(.horizontal, 24)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Ledge")
                        .font(.system(size: 27, weight: .bold, design: .rounded))
                        .foregroundStyle(LedgeStyle.ink)
                    Text("底边文件架与随手便签")
                        .font(.system(size: 13))
                        .foregroundStyle(LedgeStyle.secondaryInk)
                }
                Spacer()
                Circle()
                    .fill(LedgeStyle.accentSoft)
                    .frame(width: 44, height: 44)
                    .overlay {
                        Image(systemName: "rectangle.bottomhalf.inset.filled")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(LedgeStyle.accentInk)
                    }
            }
        }
        .padding(.horizontal, 26)
        .padding(.top, 34)
        .padding(.bottom, 22)
    }

    private var settingsCard: some View {
        VStack(spacing: 0) {
            settingRow(
                title: "登录时启动",
                detail: "登录 Mac 后自动在菜单栏运行"
            ) {
                Toggle(
                    "",
                    isOn: Binding(
                        get: { model.settings.launchAtLogin },
                        set: { model.setLaunchAtLogin($0) }
                    )
                )
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(LedgeStyle.accent)
            }
            Divider().padding(.leading, 16)
            settingRow(
                title: "多显示器",
                detail: "决定 Ledge 出现在哪块屏幕"
            ) {
                Picker(
                    "",
                    selection: Binding(
                        get: { model.settings.displayMode },
                        set: { model.setDisplayMode($0) }
                    )
                ) {
                    Text("跟随鼠标").tag(DisplayMode.followsPointer)
                    Text("主显示器").tag(DisplayMode.mainDisplay)
                }
                .labelsHidden()
                .frame(width: 118)
            }
            Divider().padding(.leading, 16)
            settingRow(
                title: "唤醒灵敏度",
                detail: "底边触发区域的高度"
            ) {
                Picker(
                    "",
                    selection: Binding(
                        get: { model.settings.wakeSensitivity },
                        set: { model.setWakeSensitivity($0) }
                    )
                ) {
                    Text("克制").tag(WakeSensitivity.discreet)
                    Text("平衡").tag(WakeSensitivity.balanced)
                    Text("灵敏").tag(WakeSensitivity.eager)
                }
                .labelsHidden()
                .frame(width: 104)
            }
        }
        .background(LedgeStyle.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(LedgeStyle.hairline, lineWidth: 1)
        }
    }

    private var localDataCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            Text("本地数据")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(LedgeStyle.ink)
            Text("中转文件、设置和便签只保存在这台 Mac。Ledge 不联网，也不收集使用数据。")
                .font(.system(size: 12))
                .foregroundStyle(LedgeStyle.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Button("显示数据文件夹") {
                    model.revealDataDirectory()
                }
                Spacer()
                Button("退出 Ledge", action: onQuit)
                    .foregroundStyle(.red)
            }
            .buttonStyle(.borderless)
            .font(.system(size: 12, weight: .medium))
        }
        .padding(17)
        .background(LedgeStyle.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(LedgeStyle.hairline, lineWidth: 1)
        }
    }

    private func settingRow<Accessory: View>(
        title: String,
        detail: String,
        @ViewBuilder accessory: () -> Accessory
    ) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(LedgeStyle.ink)
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(LedgeStyle.secondaryInk)
            }
            Spacer()
            accessory()
        }
        .padding(.horizontal, 16)
        .frame(height: 66)
    }
}
