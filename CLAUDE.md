# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

这是iOS应用的代码库，用于根据不同的manifest资源包打包不同的app，基于 WebView 的混合开发应用，使用 Objective-C 开发。

当前资源包要打包的app：在局。
- **Bundle ID**: com.zaiju
- **最低iOS版本**: iOS 15.0
- **开发语言**: Objective-C
- **包管理**: CocoaPods

## manifest资源包架构说明

这个项目的核心设计理念是：**Native容器 + manifest资源包 = 独立应用**

### 架构特点
1. **Native作为容器**：iOS原生代码仅提供WebView容器和基础能力（如相机、定位、支付等）
2. **H5承载业务**：所有业务逻辑、界面展示都由manifest中的H5资源实现
3. **本地资源加载**：所有H5页面都从本地manifest目录加载，无需网络请求
4. **资源包替换机制**：通过替换manifest目录即可打包成不同的应用

### manifest目录结构
```
manifest/
├── app.html                    # 主模板文件，包含应用配置
├── pages/                      # 所有H5页面
│   ├── home/                  # 首页模块
│   ├── shop/                  # 商城模块
│   └── ...                    # 其他业务模块
└── static/                    # 静态资源
    ├── app/xz-app.js         # 应用核心JS
    └── app/webviewbridge.js  # JS桥接文件
```

### 资源加载流程
1. Native读取`manifest/app.html`作为模板
2. 设置baseURL为manifest目录，确保资源正确加载
3. H5通过相对路径访问pages、static等资源
4. JS通过`window.xzBridge`调用Native功能

### 打包不同应用的方法
1. 准备新的manifest资源包（包含该应用的所有H5资源）
2. 修改`app.html`中的配置（domain、xzAppId等）
3. 替换iOS工程中的manifest目录
4. 修改iOS原生配置（Bundle ID、应用名称、图标等）
5. 重新编译打包

**重要提示**：修改代码时，要明确区分是修改Native容器功能还是H5业务逻辑。大部分业务需求应该在manifest中的H5代码实现，由另一位开发人员解决。

## 修改须知
- 在/Test/Docs/修复文档中保存了修复文档可作为参考
- 所有文档都存在/Test/Doc下自行归类
- 所有脚本都存在/Test/Scripts下自行归类


## 开发规范

### 第一守则
- 使用OC，保持代码先进。
- 禁止使用js的console来做调试日志，如果需要，使用alert来测试
- 若非必要禁止修改manifest！！
- 禁止紧急解决，修改的代码需要稳定且优雅。

### 解决问题规范
- 在不确定问题原因时不要轻易修改，而是确定问题原因！
- 添加的测试代码测试完了请删除
- 当你的修复不产生效果时，把修复的代码撤回，除非你判断它是必要的

### 修改规范
- 不要修改已经注释的代码，除非你要把它删除
- 禁止强制修复！！！
- 修改代码的过程中如果发现隐患，告诉用户
- 修改结束不要测试编译，让用户自己测试

### 优化规范
- 优化代码时注意有则改之无则加勉，不要刻意的优化


### 注释规范
- 为代码添加合理注释
- **WHY > WHAT > HOW**：先写为何存在，再写干什么，最后才是实现细节。
- 避免注释“显而易见”的代码片段。

### 日志规范**NSLog**
- ios中添加日志规范：你添加的所有日志前面必须符合这个规范：在局Claude Code[需要测试的内容]+日志内容
- 避免添加显而易见的日志
- 修复完成后删除无意义的日志



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