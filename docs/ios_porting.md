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
   - **路线 A：原样复制** → 为 LVGL 编写 iOS 显示驱动（或找现有移植），保持 UI 结构；
   - **路线 B：原生重写** → 使用 SwiftUI/UIKit 重新实现 UI（更符合 iOS 生态）。
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

## 需要注意的关键点

- **性能与内存**：iOS 合成链路与嵌入式 DRM 完全不同，需关注纹理上传与帧率。
- **视频格式适配**：确保素材编码格式（H.264/AAC 等）适配 iOS 硬解能力。
- **多线程模型**：避免阻塞主线程；渲染与解码应使用 GCD/OperationQueue。
- **授权与合规**：复用的开源库需核对许可证（LVGL/JSON/stb 等）。
- **UI 生成链路**：若继续用 EEZ Studio，需验证生成代码是否适合 iOS 平台。

## 风险提示

- **“原样复制”成本高**：DRM/Plane/硬件合成不可用，功能等价实现依赖新渲染架构。
- **Cedar 解码不可用**：必须全面替换为 AVFoundation/VideoToolbox。
- **IPC 与扩展 App 机制**（`src/apps/*`）在 iOS 需重新设计（可能需内嵌或改为 App 内模块）。
