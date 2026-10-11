# Pod Mini Player

一个专门显示 **Apple Podcasts** 当前播放内容的 macOS 悬浮播放器。第一版支持封面、单集标题、播放进度、播放／暂停、后退 15 秒和前进 30 秒。菜单栏图标可以显示或隐藏悬浮窗。

播放器支持大、中、小三档窗口尺寸，可在播放器的设置按钮、菜单栏的“窗口尺寸”或应用的“设置…”中切换。大尺寸显示完整布局；中尺寸将播放信息和全部控制压缩到单行；小尺寸只显示封面，鼠标悬停时显示播放／暂停按钮。尺寸选择会在下次启动时保留。
拖动悬浮窗时可以靠近屏幕边缘；松开鼠标后，超出屏幕可用区域的部分会自动移回当前显示器内。

## 构建与运行

需要 macOS 14 或更新版本，以及安装在 `/Applications/Xcode.app` 的 Xcode。当前应用已在 macOS 27.0、Xcode 26.4.1 上构建并验证。若 Xcode 更新后尚未接受新版本的许可证，需要先在终端按 Xcode 的提示完成首次设置，才能重新构建。

```sh
./scripts/build.sh
open "dist/Pod Mini Player.app"
```

首次运行时，如果播放器请求辅助功能权限，点击窗口里的按钮，并在系统设置中允许 **Pod Mini Player** 控制电脑。授权后窗口会自动重新读取 Podcasts。运行期间可以把 Podcasts 窗口放到后台。

## 数据来源

- 播放信息首先尝试读取 MediaRemote 适配器；在当前测试系统上它没有返回播放数据，因此应用会读取 Podcasts 的辅助功能控件。
- 辅助功能控件提供标题、播放状态、进度以及三个按钮。应用只针对 `com.apple.podcasts`，不会控制其他播放器。
- 如果系统接口没有返回封面或时长，应用会用单集标题查询 Apple 的 iTunes Search API，再下载匹配的封面。查询仅发送给 Apple；未在目录中找到的单集会显示占位封面，时长不可用时进度显示 `--:--`。

## 说明

这是自用原型。`Vendor/MediaRemoteAdapter` 使用 [MediaRemote Adapter](https://github.com/ungive/mediaremote-adapter) 的 BSD 3-Clause 授权，协议文本保留在其目录和 app 包内。它依赖未公开的 macOS 接口，不适合作为 Mac App Store 版本的基础。Podcasts 的辅助功能控件结构也可能随 macOS 更新变化。
