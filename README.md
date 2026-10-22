# PodLilt

PodLilt 是一款轻量的 macOS 悬浮播客播放器，用于展示和控制 **Apple Podcasts** 当前播放的内容。它常驻桌面、保持在其他窗口上方，并提供完整、紧凑和封面三种显示模式。

![PodLilt UI 预览](assets/podlilt-ui-preview.webp)

## 功能特性

- 显示单集封面、标题、节目名称、播放状态、当前进度和剩余时间。
- 支持播放／暂停、后退 15 秒和前进 30 秒。
- 提供完整模式、紧凑模式和封面模式，可从播放器设置或菜单栏切换。
- 完整模式和紧凑模式中的长标题会无缝向左滚动，每轮结束后暂停两秒。
- 封面模式在播放时显示绿色状态圆点；鼠标悬停后显示播放控制和底部播放进度。
- 悬浮窗口可直接拖动，并始终保持在屏幕可见区域内。
- 自动记忆窗口模式、窗口位置和语言偏好。
- 菜单栏支持显示或隐藏播放器、打开 Podcasts、切换模式和语言、查看关于信息及退出应用。
- 支持简体中文、繁體中文、English 和日本語；默认跟随 macOS 系统语言，也可以手动覆盖。无法匹配系统语言时使用 English。
- 播客节目名称、简介和单集标题始终保留原文。

## 播放器模式

| 模式 | 尺寸 | 说明 |
| --- | --- | --- |
| 完整模式 / Full Mode | 360 × 236 | 展示完整的播放信息、进度和控制按钮。 |
| 紧凑模式 / Compact Mode | 360 × 80 | 在单行布局中保留完整播放信息和控制能力。 |
| 封面模式 / Cover Mode | 96 × 96 | 默认仅显示封面；悬停时显示播放、后退、前进及播放进度。 |

## 系统要求

- macOS 14.0 或更高版本
- Apple Podcasts
- 从源码构建时需要安装在 `/Applications/Xcode.app` 的 Xcode

## 构建与运行

克隆仓库后，在项目根目录执行：

```sh
./scripts/build.sh
open "dist/PodLilt.app"
```

构建脚本会：

1. 编译并签名 MediaRemote Adapter。
2. 以 Release 配置构建 `PodLilt` 可执行文件。
3. 生成应用图标并组装 `dist/PodLilt.app`。
4. 对最终应用执行本地临时签名。

如果 Xcode 更新后尚未完成首次设置或接受许可证，请先根据终端提示完成 Xcode 配置，再重新运行构建脚本。

## 辅助功能权限

PodLilt 需要读取 Apple Podcasts 的辅助功能控件，以获取播放信息并执行播放控制。

首次运行时：

1. 点击播放器中的“开启辅助功能权限”。
2. 在“系统设置 → 隐私与安全性 → 辅助功能”中允许 **PodLilt** 控制电脑。
3. 返回 Podcasts，暂停并重新播放一次当前内容。

完成授权后，Podcasts 窗口可以继续在后台运行。如果其他音乐播放器接管了系统播放通道，PodLilt 可能暂时无法控制 Podcasts；重新在 Podcasts 中暂停并播放一次即可恢复。

## 数据与隐私

- PodLilt 只读取和控制 Bundle Identifier 为 `com.apple.podcasts` 的 Apple Podcasts，不会控制其他播放器。
- 播放信息优先通过 MediaRemote Adapter 获取，并在需要时读取 Podcasts 的辅助功能控件。
- 当系统接口没有返回封面或时长时，PodLilt 会使用单集标题查询 Apple iTunes Search API，并下载匹配的封面。
- 除上述 Apple 服务请求外，PodLilt 不会上传、收集或存储播客播放数据。
- 窗口模式、窗口位置和语言偏好仅保存在本机的 `UserDefaults` 中。

## 项目结构

```text
PodLilt
├── Sources/PodLilt          # 应用源码
│   └── Localization         # 多语言文案
├── Resources                # 应用图标资源
├── Vendor                   # MediaRemote Adapter
├── assets                   # README 图片资源
├── scripts/build.sh         # 应用构建与打包脚本
├── AppInfo.plist            # macOS 应用配置
└── Package.swift            # Swift Package 配置
```

## 已知限制

- MediaRemote Adapter 依赖未公开的 macOS 接口，因此本项目不适合作为 Mac App Store 版本的直接基础。
- Apple Podcasts 的辅助功能控件结构可能随 macOS 更新发生变化。
- Apple iTunes Search API 可能无法为所有单集匹配到封面或时长；缺少封面时会显示占位图，缺少时长时进度时间显示为 `--:--`。

## 许可证

PodLilt 基于 [MIT License](LICENSE.txt) 开源，Copyright © 2026 diandian。

`Vendor/MediaRemoteAdapter` 使用 [MediaRemote Adapter](https://github.com/ungive/mediaremote-adapter) 的 BSD 3-Clause 许可证，协议文本保留在其源码目录和构建后的应用包中。

## 反馈与联系

- Email：[support@podlilt.com](mailto:support@podlilt.com)
- Twitter（X）：[@callmediandian](https://x.com/callmediandian)
- GitHub：[cndiandian/PodLilt](https://github.com/cndiandian/PodLilt)
