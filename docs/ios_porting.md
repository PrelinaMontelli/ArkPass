# iOS 移植可行性与工作清单

## 可行性结论

本项目当前是 **基于嵌入式 Linux + DRM + Allwinner Cedar** 的播放器程序，核心渲染链路依赖 `libdrm`、`drm_warpper`、自定义 ioctl，以及 `libevdev` 和 Cedar 解码器（见 `src/driver/*`、`src/render/*`）。这些 **硬件与内核接口在 iOS 上不可用**，因此无法“直接编译”成 iOS App，但**功能层面是可移植的**：需要在 iOS 上 **重建显示/解码/输入层**，并将业务编排（PRTS、配置解析等）迁移为平台无关逻辑。

## 可复用与需重写的范围

### 可复用（需做平台适配/封装）

- **业务编排与配置解析**：`src/prts/*`、`src/utils/*` 中的定时器、JSON、排期逻辑可重构为“平台无关核心库”。
- **UI 资源与业务回调概念**：EEZ Studio 生成的 UI 资源与交互流程可作为参考（`eez_design/src/ui/*` 与 `src/ui/actions_*.c`）。
- **Overlay/Transition 逻辑思路**：过渡效果的状态机可复用，但绘制实现必须重写。

### 必须重写

- **显示后端**：`src/driver/drm_warpper.c`、自定义 ioctl、vblank 提交逻辑 → 需改为 iOS 渲染管线。
- **视频解码**：`src/render/mediaplayer.c`（Cedar）→ iOS 使用 AVFoundation/VideoToolbox。
- **输入事件**：`src/driver/key_enc_evdev.c`（libevdev）→ iOS 触摸/手势事件。
- **图层合成**：三层 plane 的硬件混叠（Video/Overlay/UI）→ iOS 需用 CALayer/Metal/CoreAnimation 合成。

## iOS 移植工作清单（建议路径）

1. **功能与资源盘点**
   - 明确 App 需要保留的功能与界面；整理 `eez_design` 的 UI 资源与播放素材。
2. **选定 UI 技术路线**
   - **当前选择：SwiftUI 全面重写** → 以 SwiftUI 复刻界面与交互，保持视觉一致性但重构实现细节。
   - EEZ Studio 与 LVGL 生成代码仅作为参考素材，不再直接复用。
3. **抽离“平台无关核心”**
   - 将 `prts`、配置解析、资源索引等抽离为 C 静态库；
   - 通过 Objective-C++/Swift 桥接调用。
4. **重建媒体与渲染管线**
   - 视频解码：AVFoundation/VideoToolbox；
   - Overlay/UI 合成：CoreAnimation 或 Metal；
   - 帧同步驱动：使用 CADisplayLink 代替 vblank。
5. **输入/交互迁移**
   - 将 evdev 事件映射为 iOS 触摸/手势；
   - 重新设计需要实体按键的交互逻辑。
6. **文件系统与配置**
   - `epconfig.json` 等配置改为从 App Bundle / Documents 读取；
   - 处理 iOS 沙盒、权限与资源热更新策略。
7. **工程化与验证**
   - 建立 Xcode 工程与 CI；
   - 关键流程（播放、切换、过渡、UI 操作）做端到端验证。

## SwiftUI 重写落地方案与技术选型建议

### 1) 技术选型（推荐组合）

- **UI 框架**：SwiftUI（主界面、设置、列表等）
- **状态管理**：Combine + `ObservableObject` / `@State`（或 Swift Concurrency + `@MainActor`）
- **视频解码/播放**：AVFoundation（`AVPlayer` / `AVSampleBufferDisplayLayer`）
- **过渡/Overlay**：CoreAnimation（简单叠加）或 Metal（高性能特效）
- **帧同步**：CADisplayLink（驱动过渡动画与时间线）
- **配置解析**：Swift `Codable`（读取 `epconfig.json`）
- **资源管理**：`FileManager` + App Bundle / Documents 沙盒路径

### 2) 模块拆分（建议工程结构）

- **Core 模块（可复用）**：保留 `prts`/`utils` 的业务编排思想，重写为 Swift 或抽成 C 静态库桥接。
- **Playback 引擎**：封装视频播放、时序控制与状态机。
- **Overlay 引擎**：负责过渡/干员信息效果的绘制与帧驱动。
- **UI 层（SwiftUI）**：页面结构、交互逻辑、状态绑定。

### 3) 关键映射关系（示例）

- `prts_timer` → `DispatchSourceTimer` / `Task.sleep`
- `overlay_worker` → `Task` / `OperationQueue` 后台渲染
- `drm_warpper` → `CALayer` 叠加 + `CADisplayLink`
- `epconfig.json` → `Codable` 模型 + `@Published` 状态驱动 UI

### 4) SwiftUI 重写实施步骤（落地顺序）

1. **资源与 UI 盘点**：整理页面与交互流程，建立 SwiftUI 页面结构草图。
2. **模型层落地**：定义 `Operator`/`Playlist` 等模型，与配置 JSON 对齐。
3. **播放链路搭建**：先实现单资源视频播放与切换，再接入排期逻辑。
4. **Overlay/Transition**：用 CoreAnimation/Metal 复现过渡效果。
5. **UI 完成与联调**：对照原 UI 行为补齐细节，处理异常与边界场景。

## 需要注意的关键点

- **性能与内存**：iOS 合成链路与嵌入式 DRM 完全不同，需关注纹理上传与帧率。
- **视频格式适配**：确保素材编码格式（H.264/AAC 等）适配 iOS 硬解能力。
- **多线程模型**：避免阻塞主线程；渲染与解码应使用 GCD/OperationQueue。
- **授权与合规**：复用的开源库需核对许可证（LVGL/JSON/stb 等）。
- **UI 生成链路**：采用 SwiftUI 全面重写，EEZ/LVGL 仅作为设计参考。

## 风险提示

- **“原样复制”成本高**：DRM/Plane/硬件合成不可用，功能等价实现依赖新渲染架构。
- **Cedar 解码不可用**：必须全面替换为 AVFoundation/VideoToolbox。
- **IPC 与扩展 App 机制**（`src/apps/*`）在 iOS 需重新设计（可能需内嵌或改为 App 内模块）。
