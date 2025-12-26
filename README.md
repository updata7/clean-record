# clean-record

#### 介绍
mac 录屏软件

#### 软件架构
软件架构说明


#### 安装教程

1.  克隆本仓库到本地。
2.  确保已安装 Xcode 命令行工具 (`xcode-select --install`)。
3.  在终端进入项目根目录。

#### 使用说明

1.  **开发调试**: 运行 `swift run` 或使用 Xcode 打开 `Package.swift`。
2.  **打包发布**: 见下方的 "打包发布" 章节。

#### 打包发布 (Packaging)

本项目提供了一个自动打包脚本 `Package.sh`，可以将程序打包成标准的 macOS `.app` 应用程序。

1.  **自动打包**:
    ```bash
    ./Package.sh
    ```
    打包完成后，在 `build/` 目录下会生成 `CleanRecord.app`。您可以直接将其拖入 "应用程序" (Applications) 文件夹。

2.  **脚本包含的内容**:
    - 使用 `swift build -c release` 编译发布版。
    - 自动创建 `Contents/MacOS` 和 `Contents/Resources` 目录结构。
    - 自动生成 `Info.plist`（包含摄像头和麦克风权限声明）。
    - 自动从 PNG 图标生成高分辨率的 `.icns` 图标集。

3.  **手动打包步骤**:
    如果你想手动操作，步骤如下：
    - 编译：`swift build -c release`
    - 创建目录：`mkdir -p CleanRecord.app/Contents/MacOS`
    - 拷贝文件：`cp .build/release/CleanRecord CleanRecord.app/Contents/MacOS/`
    - 添加 `Info.plist` 到 `CleanRecord.app/Contents/`。

> [!TIP]
> 如果您需要在其他没有安装开发环境的 Mac 上运行，建议在打包后进行公证 (Notarization)，或者在首次运行时在 "系统设置 -> 隐私与安全性" 中点击 "仍要打开"。

#### 参与贡献

1.  Fork 本仓库
2.  新建 Feat_xxx 分支
3.  提交代码
4.  新建 Pull Request


#### 特技

1.  使用 Readme\_XXX.md 来支持不同的语言，例如 Readme\_en.md, Readme\_zh.md
2.  Gitee 官方博客 [blog.gitee.com](https://blog.gitee.com)
3.  你可以 [https://gitee.com/explore](https://gitee.com/explore) 这个地址来了解 Gitee 上的优秀开源项目
4.  [GVP](https://gitee.com/gvp) 全称是 Gitee 最有价值开源项目，是综合评定出的优秀开源项目
5.  Gitee 官方提供的使用手册 [https://gitee.com/help](https://gitee.com/help)
6.  Gitee 封面人物是一档用来展示 Gitee 会员风采的栏目 [https://gitee.com/gitee-stars/](https://gitee.com/gitee-stars/)
