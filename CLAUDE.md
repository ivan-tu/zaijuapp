# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

这是iOS应用的代码库，用于根据不同的manifest资源包打包不同的app，基于 WebView 的混合开发应用，使用 Objective-C 开发。

当前资源包要打包的app：在局。
- **Bundle ID**: com.zaiju
- **最低iOS版本**: iOS 15.0
- **开发语言**: Objective-C
- **包管理**: CocoaPods

## 修改须知
- 这是一个老项目，上一次上架还是19年，代码可能老旧且经过多人开发可能有很多冗余或逻辑漏洞。
- 使用OC，保持代码先进。
- 通常不修改manifest中的代码，如果有必要需经过同意。
- 禁止紧急解决，修改的代码需要稳定且优雅。
- 在/Test/Docs/修复文档中保存了修复文档可作为参考
- 禁止使用js的console来做调试日志
- 若非必要禁止修改manifest！！

## 开发规范与记忆
- 修改结束不要测试编译，让用户自己测试
- 禁止使用js的console来做调试日志，因为xcode接收不到console的日志
- 项目刚刚完成大优化，如果有不确定如何实现的问题可以查看优化历史，优化前一切都可以正常运行
- 新增文件后，如果需要引导用户正确添加到Xcode项目
- 检查到没有链接的文件，请先确认我们是否真的不需要，不需要则删除，需要则引导用户正确添加到Xcode项目
- 不要修改已经注释的代码，除非你要把它删除
- 添加日志规范：你添加的所有日志前面必须符合这个规范：在局Claude Code[需要测试的内容]+日志内容
- 修改代码的过程中如果发现隐患，告诉用户
- 禁止强制修复！！！
- 添加的测试代码测试完了请删除
- 所有文档都存在/Test/Doc下自行归类
- 所有脚本都存在/Test/Scripts下自行归类
- 优化代码时注意有则改之无则加勉，不要刻意的优化
- 在不确定问题原因时不要轻易修改，而是确定问题原因！
- 当你的修复不产生效果时，把修复的代码撤回

## 命令行操作

### 特殊路径处理
- 检测到/success时，执行successs.md中的命令。检测到/update时，执行update.md中的命令

### 构建和运行
```bash
# 安装依赖
pod install

# 构建Archive (自动打开Organizer)
cd Test/Scripts && ./build.sh

# 在Xcode中打开项目
open XZVientiane.xcworkspace

# 运行单元测试
xcodebuild test -workspace XZVientiane.xcworkspace -scheme XZVientiane -destination 'platform=iOS Simulator,name=iPhone 15'
```

### 清理和重置
```bash
# 清理构建
xcodebuild clean -workspace XZVientiane.xcworkspace -scheme XZVientiane

# 清理派生数据
rm -rf ~/Library/Developer/Xcode/DerivedData/XZVientiane-*

# 重新安装依赖
pod deintegrate && pod install
```

## 架构概览

### 核心架构
应用采用 MVC + WebView 混合开发模式，主要通过 WKWebView 加载 H5 页面，Native 提供能力支持。

### 关键继承关系
```
UIViewController
  └── XZViewController (提供基础功能)
      └── XZWKWebViewBaseController (WebView基类，处理JS桥接)
          └── CFJClientH5Controller (业务实现)
```

### JavaScript 桥接架构（已重构）
- 使用 WKWebViewJavascriptBridge 实现双向通信
- 桥接对象名称: `xzBridge`
- **新架构**：JSBridge功能已模块化
  - `JSActionHandlerManager`: 统一管理所有JS处理器
  - `JSActionHandler`: 处理器基类
  - 独立的Handler模块：
    - `JSUIHandler`: UI相关功能（toast、loading、modal等）
    - `JSLocationHandler`: 定位功能
    - `JSMediaHandler`: 媒体功能（相册、拍照等）
    - `JSNetworkHandler`: 网络请求
    - `JSFileHandler`: 文件操作
    - `JSUserHandler`: 用户相关功能
    - `JSMiscHandler`: 其他功能
    - `JSPageLifecycleHandler`: 页面生命周期

### 主要模块
- **XZBase/**: 基础框架类，包括导航控制器、TabBar控制器等
- **ClientBase/**: 业务基础组件
  - `BaseController/`: 基础控制器
  - `JSBridge/`: JS桥接模块（新架构）
  - `Network/`: 网络请求封装
  - `Storage/`: 数据存储
- **ThirdParty/**: 第三方SDK集成（微信、支付宝、友盟等）
- **manifest/**: H5资源文件存放目录
- **Module/**: 业务模块
  - `MOFSPickerManager/`: 地区选择器等UI组件
- **Common/**: 公共工具类
  - `ErrorCode/`: 错误码管理
  - `Utilities/`: 工具类
  - `WebView/`: WebView性能管理

## 开发注意事项

### WebView相关
- WebView在 `viewDidAppear` 中延迟创建以优化启动性能
- iOS 18适配：处理了 `viewDidAppear` 多次调用问题
- 导航栏样式设置需要延迟处理，避免闪烁
- JavaScript调用Native时使用 `window.xzBridge.callHandler` 方法

### 第三方SDK配置
- **微信AppID**: wx10a321f7fbdd6023
- **友盟AppKey**: 5db314c23fc195be40000ac6
- 高德地图、支付宝等SDK需要在对应平台配置

### 推送配置
- 当前使用开发环境推送证书
- 生产环境需要上传推送证书到友盟后台

### 已知问题和解决方案
1. ~~`jsCallObjc` 方法过长（500+行），需要重构~~ ✅ 已通过JSBridge模块化解决
2. ~~存在大量重复的iOS版本检查代码~~ ✅ 已通过XZiOSVersionManager统一管理
3. 注释代码和调试日志需要清理
4. 导航栏显示时机问题可能导致闪烁
5. `selectLocation:` 方法缺失导致首页地区选择崩溃（需要修复）

## 测试
目前测试框架已搭建但未实现具体测试用例：
- 单元测试: XZVientianeTests
- UI测试: XZVientianeUITests

## 文档资源
项目包含详细的文档在 `项目文档/` 目录下：
- 功能文档/: WebView、支付、分享、定位等功能说明
- 代码解释/: 主要类的方法说明
- 优化建议/: 代码优化方案
- 任务文档/: 开发任务和需求文档
- 优化文档/: 2025年优化记录、JSBridge优化文档

## 关键文件路径
- 主控制器: `XZVientiane/ClientBase/BaseController/CFJClientH5Controller.m`
- JS桥接管理: `XZVientiane/ClientBase/JSBridge/JSActionHandlerManager.m`
- 地区选择器: `XZVientiane/Module/MOFSPickerManager/`
- 构建脚本: `Test/Scripts/build.sh`
- 修复文档: `Test/Docs/修复文档/`