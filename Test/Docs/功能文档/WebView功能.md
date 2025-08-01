# WebView功能文档

## 功能概述
在局APP是一个Hybrid应用，核心功能通过WKWebView加载H5页面实现。WebView功能包括页面加载、JavaScript桥接、导航控制、缓存管理等，是整个应用的基础架构。

**重要更新**: 项目已完成JSBridge模块化重构，大幅提升了代码可维护性和扩展性。

## 涉及文件

### 核心文件
- `XZWKWebViewBaseController.h/.m` - WebView基类（当前使用）
- `CFJClientH5Controller.h/.m` - 具体业务实现
- `WKWebViewJavascriptBridge` - JS桥接库

### JSBridge模块化架构（新）
- `JSActionHandlerManager.h/.m` - JSBridge统一管理器
- `JSActionHandler.h/.m` - Handler基类
- **Handler模块**：
  - `JSUIHandler.h/.m` - UI相关功能（toast、loading、modal等）
  - `JSLocationHandler.h/.m` - 定位功能
  - `JSMediaHandler.h/.m` - 媒体功能（相册、拍照等）
  - `JSNetworkHandler.h/.m` - 网络请求
  - `JSFileHandler.h/.m` - 文件操作
  - `JSUserHandler.h/.m` - 用户相关功能
  - `JSMiscHandler.h/.m` - 其他功能
  - `JSPageLifecycleHandler.h/.m` - 页面生命周期
  - `JSSystemHandler.h/.m` - 系统功能（电话、短信等）
  - `JSPaymentHandler.h/.m` - 支付功能
  - `JSShareHandler.h/.m` - 分享功能

### 辅助文件
- `HybridManager` - 混合开发管理器
- `manifest/app.html` - HTML模板
- `manifest/static/app/webviewbridge.js` - JS桥接代码

### 统一管理器
- `XZiOSVersionManager` - iOS版本统一管理
- `XZErrorCodeManager` - 错误码统一管理
- `XZWebViewPerformanceManager` - WebView性能管理

## WebView架构

### 1. 继承关系
```
UIViewController
    └── XZViewController
            └── XZWKWebViewBaseController (当前基类)
                    └── CFJClientH5Controller
```

### 2. JSBridge新架构
```
JavaScript调用
     ↓
xzBridge.callHandler
     ↓
JSActionHandlerManager（智能路由）
     ↓
具体的JSHandler处理
     ↓
回调给JavaScript
```

### 3. 核心组件
- **WKWebView**: iOS 8+的现代WebView
- **WKWebViewJavascriptBridge**: JS-Native通信桥接
- **JSActionHandlerManager**: 统一管理所有JS处理器
- **JSActionHandler子类**: 模块化的功能实现

## WebView创建和配置

### 1. WebView初始化 (XZWKWebViewBaseController.m)

```objc
- (void)createWebView {
    // 配置
    WKWebViewConfiguration *configuration = [[WKWebViewConfiguration alloc] init];
    
    // 偏好设置
    WKPreferences *preferences = [[WKPreferences alloc] init];
    preferences.javaScriptEnabled = YES;
    preferences.javaScriptCanOpenWindowsAutomatically = YES;
    configuration.preferences = preferences;
    
    // 进程池，避免内存占用过大
    configuration.processPool = [[WKProcessPool alloc] init];
    
    // 允许内联播放
    configuration.allowsInlineMediaPlayback = YES;
    configuration.mediaPlaybackRequiresUserAction = NO;
    
    // 创建WebView
    self.webView = [[WKWebView alloc] initWithFrame:self.view.bounds configuration:configuration];
    self.webView.navigationDelegate = self;
    self.webView.UIDelegate = self;
    self.webView.scrollView.delegate = self;
    
    // 支持侧滑返回
    self.webView.allowsBackForwardNavigationGestures = YES;
    
    // 添加到视图
    [self.view addSubview:self.webView];
    
    // 设置约束
    [self.webView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.view);
    }];
    
    // 设置JavaScript桥接
    [self setupJavaScriptBridge];
}
```

### 2. JavaScript桥接设置（新架构）

```objc
- (void)setupJavaScriptBridge {
    // 启用日志（调试用）
    #ifdef DEBUG
    [WKWebViewJavascriptBridge enableLogging];
    #endif
    
    // 创建桥接
    self.bridge = [WKWebViewJavascriptBridge bridgeForWebView:self.webView];
    [self.bridge setWebViewDelegate:self];
    
    // 初始化JSBridge管理器
    self.jsHandlerManager = [[JSActionHandlerManager alloc] initWithWebViewController:self bridge:self.bridge];
    
    // 注册统一的消息处理器（使用智能路由）
    [self.bridge registerHandler:@"xzBridge" handler:^(id data, WVJBResponseCallback responseCallback) {
        [self handleJavaScriptCall:data callback:responseCallback];
    }];
    
    // 注册其他特定处理器
    [self registerJSHandlers];
}

// 新的智能路由处理方法（替代原来500+行的jsCallObjc）
- (void)handleJavaScriptCall:(id)jsData callback:(WVJBResponseCallback)callback {
    NSDictionary *jsDic = (NSDictionary *)jsData;
    NSString *action = jsDic[@"action"];
    NSDictionary *data = jsDic[@"data"] ?: jsDic;
    
    // 添加调试日志
    ZJLog(@"在局Claude Code[JS调用Native] action: %@, data: %@", action, data);
    
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
        ZJLog(@"在局Claude Code[未处理的action] %@", action);
    }
}
```

## JavaScript-Native通信（模块化架构）

### 1. JS端调用Native (webviewbridge.js)

```javascript
// 统一的调用接口
function webViewCall(action, params) {
    params = params || {};
    params.action = action;
    
    // 通过桥接调用
    window.WebViewJavascriptBridge.callHandler('xzBridge', params, function(response) {
        if (params.success && response.code === 0) {
            params.success(response);
        } else if (params.fail) {
            params.fail(response);
        }
    });
}

// 使用示例
webViewCall('showToast', {
    message: '操作成功',
    duration: 2000,
    success: function() {
        console.log('Toast显示成功');
    }
});
```

### 2. JSBridge Handler模块功能列表

#### JSUIHandler - UI相关功能
- `showToast` - 显示提示信息
- `showLoading` - 显示加载框
- `hideLoading` - 隐藏加载框
- `showModal` - 显示模态框
- `showActionSheet` - 显示操作菜单
- `setNavigationBarTitle` - 设置导航栏标题
- `setNavigationBarColor` - 设置导航栏颜色
- `showNavigationBar` - 显示导航栏
- `hideNavigationBar` - 隐藏导航栏

#### JSLocationHandler - 定位功能
- `getLocation` - 获取当前位置
- `openLocation` - 打开地图
- `chooseLocation` - 选择位置
- `startLocationUpdate` - 开始位置更新
- `stopLocationUpdate` - 停止位置更新

#### JSMediaHandler - 媒体功能
- `chooseImage` - 选择图片
- `previewImage` - 预览图片
- `saveImageToPhotosAlbum` - 保存图片到相册
- `chooseVideo` - 选择视频
- `saveVideoToPhotosAlbum` - 保存视频到相册
- `getImageInfo` - 获取图片信息
- `compressImage` - 压缩图片

#### JSNetworkHandler - 网络请求
- `request` - 发起网络请求
- `uploadFile` - 上传文件
- `downloadFile` - 下载文件
- `getNetworkType` - 获取网络类型

#### JSFileHandler - 文件操作
- `saveFile` - 保存文件
- `getSavedFileList` - 获取已保存的文件列表
- `getSavedFileInfo` - 获取文件信息
- `removeSavedFile` - 删除已保存的文件
- `openDocument` - 打开文档

#### JSUserHandler - 用户相关
- `login` - 登录
- `logout` - 登出
- `getUserInfo` - 获取用户信息
- `updateUserInfo` - 更新用户信息
- `checkSession` - 检查会话状态

#### JSPaymentHandler - 支付功能
- `requestPayment` - 发起支付
- `getPaymentStatus` - 获取支付状态

#### JSShareHandler - 分享功能
- `shareToTimeline` - 分享到朋友圈
- `shareToSession` - 分享给好友
- `shareToQQ` - 分享到QQ
- `shareToWeibo` - 分享到微博

#### JSSystemHandler - 系统功能
- `makePhoneCall` - 拨打电话
- `scanCode` - 扫码
- `setClipboardData` - 设置剪贴板
- `getClipboardData` - 获取剪贴板
- `openSetting` - 打开设置
- `getSystemInfo` - 获取系统信息
- `vibrate` - 震动

#### JSPageLifecycleHandler - 页面生命周期
- `onPageShow` - 页面显示
- `onPageHide` - 页面隐藏
- `onPageUnload` - 页面卸载
- `onPageReady` - 页面准备完成

### 3. Native调用JS

```objc
// 调用JS函数
- (void)objcCallJs:(NSDictionary *)data {
    NSString *fnName = data[@"fn"];
    id params = data[@"data"];
    
    // 确保在主线程
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.bridge callHandler:fnName data:params responseCallback:^(id responseData) {
            ZJLog(@"JS函数 %@ 返回: %@", fnName, responseData);
        }];
    });
}

// 直接执行JavaScript
- (void)evaluateJavaScript:(NSString *)jsString {
    [self.webView evaluateJavaScript:jsString completionHandler:^(id result, NSError *error) {
        if (error) {
            ZJLog(@"JS执行错误: %@", error);
        }
    }];
}
```

## 导航功能

导航功能现在由JSNavigationHandler统一处理，支持以下操作：

### 1. 页面跳转 (JSNavigationHandler)
- `navigateTo` - 保留当前页面，跳转到新页面
- `redirectTo` - 关闭当前页面，跳转到新页面
- `navigateBack` - 返回上一页面或多级页面
- `reLaunch` - 关闭所有页面，打开到应用内的某个页面
- `switchTab` - 跳转到 tabBar 页面

### 2. 实现示例
```objc
// JSNavigationHandler.m
- (void)navigateTo:(NSDictionary *)params callback:(WVJBResponseCallback)callback {
    NSString *url = params[@"url"];
    
    if (!url || url.length == 0) {
        [self callbackError:callback code:XZErrorCodeInvalidParameter msg:@"URL不能为空"];
        return;
    }
    
    // 处理相对路径
    if (![url hasPrefix:@"http"]) {
        url = [NSString stringWithFormat:@"%@%@", JDomain, url];
    }
    
    // 创建新的WebView控制器
    CFJClientH5Controller *h5VC = [[CFJClientH5Controller alloc] init];
    h5VC.urlString = url;
    h5VC.pageTitle = params[@"title"];
    
    // 跳转
    [self.webViewController.navigationController pushViewController:h5VC animated:YES];
    
    [self callbackSuccess:callback data:nil];
}
```

## 错误处理

### 1. 统一错误码管理 (XZErrorCodeManager)
```objc
typedef NS_ENUM(NSInteger, XZErrorCode) {
    XZErrorCodeSuccess = 0,              // 成功
    XZErrorCodeInvalidParameter = -1,    // 参数错误
    XZErrorCodeNetworkError = -2,        // 网络错误
    XZErrorCodeUnknownAction = -3,       // 未知action
    XZErrorCodePermissionDenied = -4,    // 权限拒绝
    XZErrorCodeTimeout = -5,             // 超时
    XZErrorCodeCancelled = -6,           // 用户取消
    XZErrorCodeNotSupported = -7,        // 不支持的功能
    XZErrorCodeSystemError = -99         // 系统错误
};
```

### 2. WebView加载失败处理
```objc
- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    ZJLog(@"页面加载失败: %@", error);
    
    if (error.code == NSURLErrorNotConnectedToInternet) {
        [self showNetworkErrorView];
    } else {
        [self showErrorView:@"页面加载失败，请稍后重试"];
    }
}
```

## 性能优化

### 1. WebView性能管理器 (XZWebViewPerformanceManager)
- 统一管理WebView性能相关配置
- 监控页面加载时间
- 内存使用优化
- 缓存策略管理

### 2. 优化措施
- HTML模板预加载
- 静态资源缓存
- WebView池化管理
- 延迟创建策略（viewDidAppear）
- 图片懒加载

### 3. iOS版本兼容性管理 (XZiOSVersionManager)
- 统一处理iOS版本差异
- 避免重复的版本检查代码
- 提供版本相关的最佳实践

## 安全机制

### 1. URL白名单验证
```objc
- (BOOL)isURLAllowed:(NSString *)urlString {
    NSArray *allowedDomains = @[
        @"zaiju.com",
        @"statics.tuiya.cc",
        @"api.zaiju.com"
    ];
    
    NSURL *url = [NSURL URLWithString:urlString];
    NSString *host = url.host;
    
    for (NSString *domain in allowedDomains) {
        if ([host hasSuffix:domain]) {
            return YES;
        }
    }
    
    return NO;
}
```

### 2. JavaScript注入防护
- 阻止javascript:协议
- Content Security Policy配置
- XSS防护措施

## 调试技巧

### 1. 日志规范
```objc
// 所有日志使用统一前缀
ZJLog(@"在局Claude Code[功能模块] 日志内容");
```

### 2. Safari调试
- 在Safari开发菜单中调试WebView
- 查看网络请求
- JavaScript断点调试

### 3. 性能分析
- 使用Instruments分析内存使用
- Timeline查看渲染性能
- Network查看资源加载

## 已解决的问题

1. **jsCallObjc方法过长问题** ✅
   - 通过JSBridge模块化架构解决
   - 从500+行减少到47行
   - 提高了可维护性和扩展性

2. **iOS版本检查代码重复** ✅
   - 通过XZiOSVersionManager统一管理
   - 减少了代码重复
   - 提高了版本兼容性管理效率

3. **错误码不统一** ✅
   - 通过XZErrorCodeManager统一管理
   - 提供了标准化的错误处理

## 未来优化方向

1. **离线包机制**
   - 实现增量更新
   - 减少首次加载时间
   - 提高用户体验

2. **预渲染优化**
   - 关键页面预渲染
   - 骨架屏优化
   - 首屏加载优化

3. **监控体系完善**
   - 页面性能监控
   - 错误自动上报
   - 用户行为分析

## 最佳实践

1. **新增JS功能**
   - 创建对应的JSHandler子类
   - 在JSActionHandlerManager中注册
   - 编写单元测试

2. **调试建议**
   - 使用统一的日志前缀
   - 及时清理测试代码
   - 保持代码整洁

3. **性能建议**
   - 避免频繁的JS-Native通信
   - 大数据传输使用文件方式
   - 及时释放不需要的资源