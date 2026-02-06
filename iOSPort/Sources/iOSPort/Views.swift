// iOS-only UI layer; prevents watchOS/macOS from compiling UIKit/AVFoundation usage.
#if os(iOS)
import AVFoundation
import AVKit
import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct RootView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        ZStack {
            VideoLayerView()
            OverlayLayerView()
            UILayerView()
        }
        .frame(width: UIConstants.width, height: UIConstants.height)
        .background(Color.black)
        .task {
            state.refreshAssets()
        }
    }
}

struct VideoLayerView: View {
    @EnvironmentObject var state: AppState
    @State private var player = AVPlayer()

    private var loopVideoURL: URL? {
        guard let asset = state.selectedOperator,
              let file = asset.config.loop?.file else {
            return nil
        }
        return AssetPathResolver.resolve(file, baseURL: asset.baseURL)
    }

    var body: some View {
        Group {
            if let url = loopVideoURL {
                VideoPlayer(player: player)
            } else {
                Color.black
            }
        }
        .frame(width: UIConstants.width, height: UIConstants.height)
        .clipped()
        .onAppear {
            updatePlayer()
        }
        .onChange(of: loopVideoURL) { _ in
            updatePlayer()
        }
    }

    private func updatePlayer() {
        if let url = loopVideoURL {
            player.replaceCurrentItem(with: AVPlayerItem(url: url))
            player.play()
        } else {
            player.replaceCurrentItem(with: nil)
        }
    }
}

struct OverlayLayerView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        ZStack {
            if let overlay = state.selectedOperator?.config.overlay {
                OverlayInfoView(overlay: overlay)
            }
        }
        .frame(width: UIConstants.width, height: UIConstants.height)
    }
}

struct OverlayInfoView: View {
    let overlay: OverlayConfig

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(overlay.type ?? "overlay")
                .font(.headline)
            if let options = overlay.options {
                Text(options.operatorName ?? "OPERATOR")
                    .font(.title3)
                Text(options.operatorCode ?? "")
                    .font(.caption)
                Text(options.auxText ?? "")
                    .font(.footnote)
            }
        }
        .padding(12)
        .background(Color.black.opacity(0.4))
        .foregroundColor(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        .padding(.leading, 12)
        .padding(.bottom, 40)
    }
}

struct UILayerView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        Group {
            switch state.currentScreen {
            case .mainMenu:
                MainMenuView()
            case .mainScreen:
                MainScreenView()
            case .settings:
                SettingsScreenView()
            case .warning:
                WarningScreenView()
            case .oplist:
                OperatorListView()
            case .sysinfo:
                SystemInfoView()
            case .fileManager:
                FileManagerView()
            case .appList:
                AppListView()
            case .confirm:
                ConfirmView()
            }
        }
        .frame(width: UIConstants.width, height: UIConstants.height)
    }
}

struct MainMenuView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(spacing: 12) {
            ScreenTitleView(title: "主菜单")
            HStack(spacing: 12) {
                MenuButton(title: "主页") { state.currentScreen = .mainScreen }
                MenuButton(title: "设置") { state.currentScreen = .settings }
            }
            HStack(spacing: 12) {
                MenuButton(title: "干员") { state.currentScreen = .oplist }
                MenuButton(title: "系统") { state.currentScreen = .sysinfo }
            }
            HStack(spacing: 12) {
                MenuButton(title: "文件") { state.currentScreen = .fileManager }
                MenuButton(title: "应用") { state.currentScreen = .appList }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, UIConstants.mainMenuY)
    }
}

struct MainScreenView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(spacing: 12) {
            ScreenTitleView(title: state.selectedOperator?.config.displayName ?? "电子通行证")
            if let description = state.selectedOperator?.config.description {
                Text(description)
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
            }
            HStack(spacing: 10) {
                MenuButton(title: "菜单") { state.currentScreen = .mainMenu }
                MenuButton(title: "设置") { state.currentScreen = .settings }
                MenuButton(title: "告警") { state.currentScreen = .warning }
            }
            OperatorListView(compact: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, 32)
    }
}

struct SettingsScreenView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(spacing: 16) {
            ScreenTitleView(title: "设置")
            AssetImportView()
            if let status = state.importStatus {
                Text(status)
                    .font(.footnote)
                    .foregroundColor(.white)
            }
            MenuButton(title: "返回") { state.currentScreen = .mainScreen }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct WarningScreenView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(spacing: 8) {
            Text(state.warningInfo.title)
                .font(.title3)
            Text(state.warningInfo.description)
                .font(.footnote)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            MenuButton(title: "确认") { state.currentScreen = .mainScreen }
        }
        .foregroundColor(.white)
        .padding(16)
        .background(state.warningInfo.accentColor.opacity(0.85))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .padding(.bottom, UIConstants.height - UIConstants.warningY)
    }
}

struct OperatorListView: View {
    @EnvironmentObject var state: AppState
    var compact = false

    var body: some View {
        VStack(spacing: 8) {
            if !compact {
                ScreenTitleView(title: "干员列表")
            }
            ForEach(state.operators) { asset in
                Button {
                    state.selectedOperator = asset
                    state.currentScreen = .mainScreen
                } label: {
                    HStack {
                        ResourceIconView(iconPath: asset.config.icon, baseURL: asset.baseURL)
                            .frame(width: 36, height: 36)
                        Text(asset.config.displayName)
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.1))
                }
            }
            if state.operators.isEmpty {
                Text("未检测到干员资源，请导入 assets 目录")
                    .font(.footnote)
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal, 16)
    }
}

struct SystemInfoView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(spacing: 12) {
            ScreenTitleView(title: "系统信息")
            Text("ArkPass iOS Port")
                .foregroundColor(.white)
            MenuButton(title: "返回") { state.currentScreen = .mainScreen }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct FileManagerView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(spacing: 12) {
            ScreenTitleView(title: "文件管理器")
            Text("支持浏览导入的 assets 与 app 资源")
                .font(.footnote)
                .foregroundColor(.white)
            MenuButton(title: "返回") { state.currentScreen = .mainScreen }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct AppListView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(spacing: 12) {
            ScreenTitleView(title: "应用列表")
            Text("展示导入的 app 资源配置")
                .font(.footnote)
                .foregroundColor(.white)
            MenuButton(title: "返回") { state.currentScreen = .mainScreen }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ConfirmView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(spacing: 8) {
            Text("确认操作")
                .font(.headline)
            Text("是否执行关机或重启？")
                .font(.footnote)
            HStack(spacing: 12) {
                MenuButton(title: "取消") { state.currentScreen = .mainScreen }
                MenuButton(title: "确认") { state.currentScreen = .mainScreen }
            }
        }
        .foregroundColor(.white)
        .padding(16)
        .background(Color.black.opacity(0.6))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .padding(.bottom, UIConstants.height - UIConstants.confirmY)
    }
}

struct AssetImportView: View {
    @EnvironmentObject var state: AppState
    @State private var showingImporter = false

    var body: some View {
        Button("导入资源") {
            showingImporter = true
        }
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            guard case let .success(urls) = result, let url = urls.first else {
                return
            }
            let access = url.startAccessingSecurityScopedResource()
            state.importAssets(from: url)
            if access {
                url.stopAccessingSecurityScopedResource()
            }
        }
        .buttonStyle(.borderedProminent)
    }
}

struct MenuButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.footnote)
                .frame(minWidth: 72)
        }
        .buttonStyle(.bordered)
        .tint(.white)
    }
}

struct ScreenTitleView: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.headline)
            .foregroundColor(.white)
    }
}

struct ResourceIconView: View {
    let iconPath: String?
    let baseURL: URL

    var body: some View {
        ResourceImageView(url: AssetPathResolver.resolve(iconPath, baseURL: baseURL))
    }
}

struct ResourceImageView: View {
    let url: URL?

    var body: some View {
        Group {
            if let url, let image = UIImage(contentsOfFile: url.path) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Color.white.opacity(0.2)
            }
        }
    }
}

#endif
