# CLAUDE.md - Swift升级专用指导文档

此文档为在局APP从Objective-C升级到Swift的专用指导文档，供Claude Code在执行升级任务时使用。

## 项目概述

### 升级目标
- **原项目**：Objective-C + MVC + WKWebView混合开发
- **目标项目**：Swift 5.9+ + MVVM-C + 现代化架构
- **Bundle ID**：com.zaiju
- **最低iOS版本**：iOS 15.0

### 参考资源
- **原OC项目路径**：当前工作目录
- **升级文档路径**：Test/Docs/升级到Swift/
- **原项目CLAUDE.md**：参考原有规范和习惯

## 执行原则

### 第一守则
- 严格遵循Swift 5.9+最佳实践
- 保证功能100%迁移，不遗漏任何功能
- 优先使用Swift原生特性，避免NSObject继承（除非必要）
- 所有第三方库优先选择Swift版本

### 开发规范

#### 命名规范
- **模块命名**：使用namespace避免命名冲突，不使用前缀
- **类型命名**：UpperCamelCase（如UserViewModel）
- **函数/属性**：lowerCamelCase（如fetchUserData）
- **常量**：static let，不使用#define
- **枚举**：使用关联值和原始值特性

#### 架构规范
```swift
// MVVM-C架构示例
class UserViewModel {
    @Published var user: User?
    private let userService: UserServiceProtocol
    
    init(userService: UserServiceProtocol) {
        self.userService = userService
    }
}
```

#### 异步处理
```swift
// 必须使用async/await，禁止回调地狱
func fetchUserData() async throws -> User {
    let data = try await networkManager.request(endpoint: .user)
    return try JSONDecoder().decode(User.self, from: data)
}
```

## JSBridge迁移规范

### Handler实现模板
```swift
protocol JSHandlerProtocol {
    var handlerName: String { get }
    func handle(action: String, data: [String: Any]?) async throws -> Any?
}

class JSNavigationHandler: JSHandlerProtocol {
    let handlerName = "navigation"
    
    func handle(action: String, data: [String: Any]?) async throws -> Any? {
        switch action {
        case "push":
            // 实现逻辑
        default:
            throw JSBridgeError.unknownAction
        }
    }
}
```

### 桥接对象保持一致
- JavaScript端调用：`window.xzBridge.callHandler`
- 保持原有的action名称不变
- 回调格式保持一致

## 文件组织结构

```
ZaiJu/
├── App/
│   ├── AppDelegate.swift
│   └── SceneDelegate.swift
├── Core/
│   ├── Architecture/      # MVVM-C基础
│   ├── Networking/        # 网络层
│   ├── Storage/           # 数据存储
│   └── JSBridge/          # JS桥接
├── Features/              # 功能模块
│   ├── Home/
│   ├── User/
│   └── Payment/
├── Services/              # 业务服务
├── Resources/             # 资源文件
├── Extensions/            # 扩展
└── ThirdParty/           # 第三方库桥接

```

## 具体任务执行指南

### 2.0.2 资源文件迁移
```bash
# 创建资源目录结构
mkdir -p Resources/{Assets.xcassets,Fonts,Audio,Localization}

# 复制资源文件命令示例
cp -r 原项目路径/Assets.xcassets/* Resources/Assets.xcassets/
cp -r 原项目路径/manifest .

# 确保Build Phases包含Copy Bundle Resources
# 添加manifest目录到Copy Bundle Resources
```

资源清单检查：
- [ ] AppIcon.appiconset（所有尺寸）
- [ ] LaunchScreen资源
- [ ] TabBar图标（全部状态）
- [ ] 通用图片资源
- [ ] 自定义字体
- [ ] 音频文件
- [ ] 本地化文件
- [ ] manifest资源包

### 2.1 项目基础配置
```swift
// Info.plist必须包含的权限（完整列表）
<key>NSCameraUsageDescription</key>
<string>在局需要访问您的相机以拍摄照片</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>在局需要访问您的相册以选择图片</string>
<key>NSLocationWhenInUseUsageDescription</key>
<string>在局需要获取您的位置信息以提供本地服务</string>
<key>NSLocationAlwaysUsageDescription</key>
<string>在局需要持续获取您的位置信息</string>
<key>NSMicrophoneUsageDescription</key>
<string>在局需要访问您的麦克风以录制音频</string>

// URL Schemes配置
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>wx10a321f7fbdd6023</string>
        </array>
    </dict>
</array>
```

### 2.5 WebView核心功能
- 必须处理iOS 18的viewDidAppear多次调用问题
- 延迟创建WebView优化启动性能
- Cookie同步机制必须实现

### 2.6 JSBridge架构
- 使用Combine进行事件分发
- 错误处理统一使用Result类型
- 所有Handler必须遵循JSHandlerProtocol

## 测试要求

### 单元测试模板
```swift
class UserViewModelTests: XCTestCase {
    func testFetchUser() async throws {
        // Given
        let mockService = MockUserService()
        let viewModel = UserViewModel(userService: mockService)
        
        // When
        await viewModel.fetchUser()
        
        // Then
        XCTAssertNotNil(viewModel.user)
    }
}
```

### 集成测试
- 每个JSHandler必须有对应的集成测试
- 使用XCUITest测试关键用户流程

## 问题处理

### 常见问题解决方案
1. **Bridging-Header配置**
   - 路径：$(PROJECT_DIR)/ZaiJu/ZaiJu-Bridging-Header.h
   - 仅包含必要的OC头文件

2. **第三方SDK集成**
   - 优先使用Swift Package Manager
   - 其次使用CocoaPods（指定use_frameworks!）
   - 最后考虑手动集成

3. **性能优化**
   - 使用Instruments定位性能瓶颈
   - lazy加载大对象
   - 避免主线程阻塞

## 验证清单

每完成一个任务，必须验证：
- [ ] 编译无错误和警告
- [ ] SwiftLint检查通过
- [ ] 单元测试通过
- [ ] 功能与原OC版本一致
- [ ] 无内存泄漏（使用Instruments验证）

## 日志规范

```swift
// 使用os.log替代NSLog
import os.log

private let logger = Logger(subsystem: "com.zaiju", category: "JSBridge")

logger.info("在局Swift: JSBridge初始化成功")
logger.error("在局Swift: 支付失败 - \(error.localizedDescription)")
```

## 重要提醒

1. **不要遗漏功能**：对照原项目的13个JSHandler逐一实现
2. **保持兼容性**：JS端调用方式不变，仅Native端使用Swift重写
3. **代码质量**：每个类/结构体必须有注释说明用途
4. **及时测试**：完成一个模块立即测试，不要积累问题
5. **性能监控**：关注启动时间、内存占用、帧率等指标

---

此文档将随着升级进程不断更新，如遇到未涵盖的情况，请参考Swift官方文档和最佳实践。