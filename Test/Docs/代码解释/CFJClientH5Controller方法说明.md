# CFJClientH5Controller 方法说明文档

## 文件信息
- **文件路径**: XZVientiane/ClientBase/BaseController/CFJClientH5Controller.h/.m
- **作用**: 具体的H5页面控制器，实现所有JavaScript与Native的交互功能
- **重构状态**: ✅ 已完成JSBridge模块化重构（2025年）
- **创建时间**: 2016年

## 类继承关系
```
UIViewController
    └── XZViewController
            └── XZWKWebViewBaseController
                    └── CFJClientH5Controller
```

## 重大架构变更（2025年）

### JSBridge模块化重构
- **旧架构**: jsCallObjc方法包含500+行代码，50+个if-else分支
- **新架构**: 使用JSActionHandlerManager智能路由，handleJavaScriptCall方法仅47行
- **改进效果**: 代码可维护性大幅提升，功能模块化，易于扩展

### 新增组件
- **JSActionHandlerManager**: 统一管理所有JS处理器
- **各类JSHandler**: 分模块处理不同功能（UI、定位、媒体、网络等）
- **统一管理器**: iOS版本、错误码、WebView性能等统一管理

## 属性说明

### 公开属性
| 属性名 | 类型 | 说明 |
|-------|------|------|
| pageTitle | NSString* | 页面标题 |
| canShare | NSString* | 是否可以分享 |
| showRedpacket | NSString* | 是否显示红包 |
| uid | NSString* | 用户ID |
| urlString | NSString* | 页面URL |

### 重要私有属性
| 属性名 | 类型 | 说明 |
|-------|------|------|
| jsHandlerManager | JSActionHandlerManager* | JSBridge管理器（新增） |
| locationManager | AMapLocationManager* | 高德定位管理器 |
| jsCallPayCallback | WVJBResponseCallback | 支付回调 |
| jsWeiXinLoginCallback | WVJBResponseCallback | 微信登录回调 |
| jsAppleLoginCallback | WVJBResponseCallback | Apple登录回调 |

## 核心方法说明

### 1. JavaScript桥接处理（新架构）

#### handleJavaScriptCall:callback: （替代原jsCallObjc）
```objc
- (void)handleJavaScriptCall:(id)jsData callback:(WVJBResponseCallback)callback
```
**作用**: 处理所有JavaScript调用Native的请求（智能路由版本）
**参数**:
- jsData: JS传递的数据字典
- callback: 回调函数

**实现逻辑（简化后）**:
```objc
- (void)handleJavaScriptCall:(id)jsData callback:(WVJBResponseCallback)callback {
    NSDictionary *jsDic = (NSDictionary *)jsData;
    NSString *action = jsDic[@"action"];
    NSDictionary *data = jsDic[@"data"] ?: jsDic;
    
    // 添加调试日志
    ZJLog(@"在局Claude Code[JS调用Native] action: %@", action);
    
    // 使用JSActionHandlerManager进行智能路由
    BOOL handled = [self.jsHandlerManager handleAction:action data:data callback:callback];
    
    if (!handled) {
        // 处理特殊的非标准action
        if ([self handleSpecialAction:action data:data callback:callback]) {
            return;
        }
        
        // 未知action
        NSDictionary *error = @{
            @"code": @(XZErrorCodeUnknownAction),
            @"msg": [NSString stringWithFormat:@"未知的action: %@", action]
        };
        if (callback) {
            callback(error);
        }
    }
}
```

### 2. JSBridge初始化

#### setupJavaScriptBridge
```objc
- (void)setupJavaScriptBridge
```
**作用**: 初始化JavaScript桥接和处理器
**实现**:
1. 创建WKWebViewJavascriptBridge实例
2. 初始化JSActionHandlerManager
3. 注册统一消息处理器
4. 注册特殊处理器

### 3. 特殊Action处理

#### handleSpecialAction:data:callback:
```objc
- (BOOL)handleSpecialAction:(NSString *)action data:(NSDictionary *)data callback:(WVJBResponseCallback)callback
```
**作用**: 处理不符合标准格式的特殊action
**说明**: 用于兼容旧版本或特殊情况的action

### 4. 页面生命周期

#### viewDidLoad
- 设置导航栏样式
- 配置页面基础属性
- 注册通知观察者

#### viewWillAppear:
- 更新导航栏显示
- 通知JS页面即将显示
- 检测登录状态变化

#### viewDidAppear:
- 首次创建WebView（延迟创建优化）
- 加载页面内容
- 处理iOS 18兼容性

#### viewWillDisappear:
- 通知JS页面即将隐藏
- 保存页面状态

#### dealloc
- 移除通知观察者
- 清理WebView资源
- 释放管理器

## JSHandler模块功能分布

### JSUIHandler - UI相关功能
- showToast、showLoading、hideLoading
- showModal、showActionSheet
- setNavigationBarTitle、setNavigationBarColor
- showNavigationBar、hideNavigationBar

### JSNavigationHandler - 导航功能
- navigateTo、redirectTo、navigateBack
- reLaunch、switchTab

### JSLocationHandler - 定位功能
- getLocation、openLocation、chooseLocation
- startLocationUpdate、stopLocationUpdate

### JSMediaHandler - 媒体功能
- chooseImage、previewImage、saveImageToPhotosAlbum
- chooseVideo、saveVideoToPhotosAlbum
- getImageInfo、compressImage

### JSNetworkHandler - 网络请求
- request、uploadFile、downloadFile
- getNetworkType

### JSPaymentHandler - 支付功能
- requestPayment（支持微信、支付宝）
- getPaymentStatus

### JSShareHandler - 分享功能
- shareToTimeline、shareToSession
- shareToQQ、shareToWeibo

### JSUserHandler - 用户功能
- login、logout
- getUserInfo、updateUserInfo
- checkSession

### JSSystemHandler - 系统功能
- makePhoneCall、scanCode
- setClipboardData、getClipboardData
- openSetting、getSystemInfo、vibrate

### JSFileHandler - 文件操作
- saveFile、getSavedFileList
- getSavedFileInfo、removeSavedFile
- openDocument

### JSPageLifecycleHandler - 页面生命周期
- onPageShow、onPageHide
- onPageUnload、onPageReady

## 第三方SDK集成

### 微信SDK
- 登录：通过JSUserHandler处理
- 支付：通过JSPaymentHandler处理
- 分享：通过JSShareHandler处理

### 支付宝SDK
- 支付功能集成在JSPaymentHandler中

### 高德地图SDK
- 定位功能集成在JSLocationHandler中

### 友盟SDK
- 统计和推送功能

## 错误处理机制

### 统一错误码（XZErrorCodeManager）
```objc
typedef NS_ENUM(NSInteger, XZErrorCode) {
    XZErrorCodeSuccess = 0,              // 成功
    XZErrorCodeInvalidParameter = -1,    // 参数错误
    XZErrorCodeNetworkError = -2,        // 网络错误
    XZErrorCodeUnknownAction = -3,       // 未知action
    XZErrorCodePermissionDenied = -4,    // 权限拒绝
    // ... 更多错误码
};
```

### 错误回调格式
```objc
@{
    @"code": @(errorCode),
    @"msg": @"错误描述",
    @"data": @{} // 可选的额外数据
}
```

## 性能优化措施

1. **延迟创建WebView**: 在viewDidAppear中创建，优化启动速度
2. **模块化加载**: 各功能模块按需加载
3. **统一管理器**: 减少重复代码和性能开销
4. **缓存机制**: HTML模板和静态资源缓存

## 使用注意事项

1. **线程安全**: 所有UI操作必须在主线程
2. **内存管理**: 注意各种回调的及时释放
3. **权限处理**: 相机、相册、定位等需要提前申请权限
4. **iOS版本兼容**: 使用XZiOSVersionManager统一处理
5. **日志规范**: 使用"在局Claude Code[模块名]"前缀

## 已解决的问题

1. ✅ **jsCallObjc方法过长**: 通过JSBridge模块化架构解决
2. ✅ **代码重复**: 通过统一管理器解决
3. ✅ **iOS版本检查混乱**: 通过XZiOSVersionManager解决
4. ✅ **错误处理不统一**: 通过XZErrorCodeManager解决

## 扩展指南

### 添加新的JS功能
1. 创建新的JSHandler子类
2. 在JSActionHandlerManager中注册
3. 实现具体的action处理方法
4. 编写单元测试

### 示例：创建自定义Handler
```objc
// 1. 创建Handler类
@interface JSCustomHandler : JSActionHandler
@end

@implementation JSCustomHandler

- (NSDictionary<NSString *, NSString *> *)supportedActions {
    return @{
        @"customAction": @"handleCustomAction:callback:"
    };
}

- (void)handleCustomAction:(NSDictionary *)params callback:(WVJBResponseCallback)callback {
    // 实现具体功能
    [self callbackSuccess:callback data:@{@"result": @"success"}];
}

@end

// 2. 在JSActionHandlerManager中注册
[self registerHandler:[[JSCustomHandler alloc] initWithWebViewController:webViewController]];
```

## 调试技巧

1. **日志查看**: 搜索"在局Claude Code"查看相关日志
2. **Safari调试**: 使用Safari开发者工具调试WebView
3. **断点调试**: 在handleJavaScriptCall方法设置断点
4. **性能分析**: 使用Instruments分析性能问题

## 最佳实践

1. **保持模块独立**: 每个Handler只处理自己的功能
2. **统一错误处理**: 使用XZErrorCodeManager
3. **及时清理资源**: 在dealloc中清理所有资源
4. **遵循命名规范**: action命名使用驼峰式
5. **添加必要注释**: 复杂逻辑添加详细注释