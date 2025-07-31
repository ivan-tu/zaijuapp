# WebView功能文档

## 功能概述
在局APP是一个Hybrid应用，核心功能通过WKWebView加载H5页面实现。WebView功能包括页面加载、JavaScript桥接、导航控制、缓存管理等，是整个应用的基础架构。

## 涉及文件
- `XZWKWebViewBaseController.h/.m` - WebView基类（新）
- `CFJWebViewBaseController.h/.m` - WebView基类（旧）
- `CFJClientH5Controller.m` - 具体业务实现
- `WKWebViewJavascriptBridge` - JS桥接库
- `HybridManager` - 混合开发管理器
- `manifest/app.html` - HTML模板
- `manifest/static/app/webviewbridge.js` - JS桥接代码

## WebView架构

### 1. 继承关系
```
UIViewController
    └── XZViewController
            └── XZWKWebViewBaseController (新基类)
                    └── CFJClientH5Controller
            └── CFJWebViewBaseController (旧基类)
```

### 2. 核心组件
- **WKWebView**: iOS 8+的现代WebView
- **WKWebViewJavascriptBridge**: JS-Native通信桥接
- **WKWebViewConfiguration**: WebView配置
- **WKUserContentController**: JS注入管理

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

### 2. JavaScript桥接设置

```objc
- (void)setupJavaScriptBridge {
    // 启用日志（调试用）
    #ifdef DEBUG
    [WKWebViewJavascriptBridge enableLogging];
    #endif
    
    // 创建桥接
    self.bridge = [WKWebViewJavascriptBridge bridgeForWebView:self.webView];
    [self.bridge setWebViewDelegate:self];
    
    // 注册统一的消息处理器
    [self.bridge registerHandler:@"xzBridge" handler:^(id data, WVJBResponseCallback responseCallback) {
        [self jsCallObjc:data jsCallBack:responseCallback];
    }];
    
    // 注册其他特定处理器
    [self registerJSHandlers];
}

- (void)registerJSHandlers {
    // 页面准备完成
    [self.bridge registerHandler:@"pageReady" handler:^(id data, WVJBResponseCallback responseCallback) {
        [self handlePageReady:data callback:responseCallback];
    }];
    
    // 日志输出
    [self.bridge registerHandler:@"log" handler:^(id data, WVJBResponseCallback responseCallback) {
        NSLog(@"JS Log: %@", data);
        if (responseCallback) {
            responseCallback(@{@"code": @(0)});
        }
    }];
}
```

## HTML加载机制

### 1. 模板加载 (domainOperate方法)

```objc
- (void)domainOperate {
    // 读取HTML模板
    NSString *htmlPath = [[BaseFileManager appH5LocailManifesPath] stringByAppendingPathComponent:@"app.html"];
    NSString *htmlTemplate = [NSString stringWithContentsOfFile:htmlPath encoding:NSUTF8StringEncoding error:nil];
    
    if (!htmlTemplate) {
        [self showErrorView:@"页面加载失败"];
        return;
    }
    
    // 读取页面内容
    NSString *pagePath = [self.urlString stringByReplacingOccurrencesOfString:@"https://zaiju.com" withString:@""];
    NSString *contentPath = [[BaseFileManager appH5LocailManifesPath] stringByAppendingPathComponent:pagePath];
    NSString *pageContent = [NSString stringWithContentsOfFile:contentPath encoding:NSUTF8StringEncoding error:nil];
    
    // 替换模板中的占位符
    NSString *finalHTML = [htmlTemplate stringByReplacingOccurrencesOfString:@"{{body}}" withString:pageContent ?: @""];
    
    // 设置baseURL为manifest目录，以便加载相对路径资源
    NSURL *baseURL = [NSURL fileURLWithPath:[BaseFileManager appH5LocailManifesPath]];
    
    // 加载HTML
    [self.webView loadHTMLString:finalHTML baseURL:baseURL];
}
```

### 2. 页面预加载优化

```objc
// 预加载HTML模板
+ (void)preloadHTMLTemplates {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
            NSString *htmlPath = [[BaseFileManager appH5LocailManifesPath] stringByAppendingPathComponent:@"app.html"];
            NSString *htmlTemplate = [NSString stringWithContentsOfFile:htmlPath encoding:NSUTF8StringEncoding error:nil];
            
            // 缓存到内存
            [[NSCache sharedCache] setObject:htmlTemplate forKey:@"app_html_template"];
        });
    });
}

// 预创建WebView
- (void)preCreateWebViewIfNeeded {
    if (self.preCreatedWebView) {
        return;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        WKWebViewConfiguration *config = [self createWebViewConfiguration];
        self.preCreatedWebView = [[WKWebView alloc] initWithFrame:CGRectZero configuration:config];
    });
}
```

## JavaScript-Native通信

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

### 2. Native端处理 (jsCallObjc方法)

```objc
- (void)jsCallObjc:(id)jsData jsCallBack:(WVJBResponseCallback)jsCallBack {
    NSDictionary *jsDic = (NSDictionary *)jsData;
    NSString *function = [jsDic objectForKey:@"action"];
    NSDictionary *dataDic = [jsDic objectForKey:@"data"] ?: jsDic;
    
    // 日志记录
    ZJLog(@"JS调用Native: %@", function);
    
    // 页面导航
    if ([function isEqualToString:@"navigateTo"]) {
        [self handleNavigateTo:dataDic callback:jsCallBack];
    }
    else if ([function isEqualToString:@"navigateBack"]) {
        [self handleNavigateBack:dataDic callback:jsCallBack];
    }
    else if ([function isEqualToString:@"redirectTo"]) {
        [self handleRedirectTo:dataDic callback:jsCallBack];
    }
    // 页面交互
    else if ([function isEqualToString:@"setNavigationBarTitle"]) {
        [self handleSetNavigationBarTitle:dataDic callback:jsCallBack];
    }
    else if ([function isEqualToString:@"showToast"]) {
        [self handleShowToast:dataDic callback:jsCallBack];
    }
    else if ([function isEqualToString:@"showLoading"]) {
        [self handleShowLoading:dataDic callback:jsCallBack];
    }
    // 网络请求
    else if ([function isEqualToString:@"request"]) {
        [self handleRequest:dataDic callback:jsCallBack];
    }
    // ... 更多功能
}
```

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

### 1. 页面跳转

```objc
- (void)handleNavigateTo:(NSDictionary *)params callback:(WVJBResponseCallback)callback {
    NSString *url = params[@"url"];
    
    if (!url || url.length == 0) {
        callback(@{@"code": @(-1), @"msg": @"URL不能为空"});
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
    [self.navigationController pushViewController:h5VC animated:YES];
    
    callback(@{@"code": @(0)});
}

- (void)handleNavigateBack:(NSDictionary *)params callback:(WVJBResponseCallback)callback {
    NSInteger delta = [params[@"delta"] integerValue] ?: 1;
    
    NSInteger currentIndex = [self.navigationController.viewControllers indexOfObject:self];
    NSInteger targetIndex = currentIndex - delta;
    
    if (targetIndex >= 0 && targetIndex < self.navigationController.viewControllers.count) {
        UIViewController *targetVC = self.navigationController.viewControllers[targetIndex];
        [self.navigationController popToViewController:targetVC animated:YES];
        callback(@{@"code": @(0)});
    } else {
        callback(@{@"code": @(-1), @"msg": @"无法返回"});
    }
}
```

### 2. 页面重定向

```objc
- (void)handleRedirectTo:(NSDictionary *)params callback:(WVJBResponseCallback)callback {
    NSString *url = params[@"url"];
    
    if (!url || url.length == 0) {
        callback(@{@"code": @(-1), @"msg": @"URL不能为空"});
        return;
    }
    
    // 更新当前页面URL
    self.urlString = url;
    
    // 重新加载页面
    [self domainOperate];
    
    callback(@{@"code": @(0)});
}
```

## 网络请求代理

### 1. 统一请求处理

```objc
- (void)handleRequest:(NSDictionary *)params callback:(WVJBResponseCallback)callback {
    NSString *url = params[@"url"];
    NSString *method = params[@"method"] ?: @"GET";
    NSDictionary *data = params[@"data"];
    NSDictionary *header = params[@"header"];
    
    // 构建请求
    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    manager.requestSerializer = [AFJSONRequestSerializer serializer];
    manager.responseSerializer = [AFJSONResponseSerializer serializer];
    
    // 设置请求头
    [header enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        [manager.requestSerializer setValue:obj forHTTPHeaderField:key];
    }];
    
    // 添加认证token
    NSString *token = [[NSUserDefaults standardUserDefaults] objectForKey:@"token"];
    if (token) {
        [manager.requestSerializer setValue:token forHTTPHeaderField:@"Authorization"];
    }
    
    // 发送请求
    void (^success)(NSURLSessionDataTask *, id) = ^(NSURLSessionDataTask *task, id responseObject) {
        callback(@{
            @"code": @(0),
            @"data": responseObject ?: @{},
            @"statusCode": @(((NSHTTPURLResponse *)task.response).statusCode)
        });
    };
    
    void (^failure)(NSURLSessionDataTask *, NSError *) = ^(NSURLSessionDataTask *task, NSError *error) {
        callback(@{
            @"code": @(-1),
            @"msg": error.localizedDescription ?: @"网络请求失败",
            @"statusCode": @(((NSHTTPURLResponse *)task.response).statusCode)
        });
    };
    
    if ([method isEqualToString:@"GET"]) {
        [manager GET:url parameters:data headers:nil progress:nil success:success failure:failure];
    } else if ([method isEqualToString:@"POST"]) {
        [manager POST:url parameters:data headers:nil progress:nil success:success failure:failure];
    }
}
```

## 缓存管理

### 1. WebView缓存策略

```objc
// 清除缓存
- (void)clearWebViewCache {
    NSSet *websiteDataTypes = [WKWebsiteDataStore allWebsiteDataTypes];
    NSDate *dateFrom = [NSDate dateWithTimeIntervalSince1970:0];
    
    [[WKWebsiteDataStore defaultDataStore] removeDataOfTypes:websiteDataTypes 
        modifiedSince:dateFrom 
        completionHandler:^{
            ZJLog(@"WebView缓存已清除");
    }];
}

// 设置缓存策略
- (void)setupCachePolicy {
    // 离线时使用缓存
    if (![BaseMethod isConnectionAvailable]) {
        self.webView.configuration.websiteDataStore = [WKWebsiteDataStore defaultDataStore];
        self.webView.configuration.preferences.javaScriptEnabled = YES;
    }
}
```

### 2. 资源缓存

```objc
// 缓存静态资源
- (void)cacheStaticResources {
    NSArray *resourcePaths = @[
        @"static/app/app.js",
        @"static/app/app.css",
        @"static/app/webviewbridge.js"
    ];
    
    for (NSString *path in resourcePaths) {
        NSString *fullPath = [[BaseFileManager appH5LocailManifesPath] stringByAppendingPathComponent:path];
        NSData *data = [NSData dataWithContentsOfFile:fullPath];
        
        if (data) {
            [[NSCache sharedCache] setObject:data forKey:path];
        }
    }
}
```

## 生命周期管理

### 1. 页面生命周期

```objc
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    // 通知JS页面即将显示
    [self objcCallJs:@{@"fn": @"pageShow", @"data": @{@"timestamp": @([[NSDate date] timeIntervalSince1970])}];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    // 首次加载
    if (!self.hasLoadedWebView) {
        self.hasLoadedWebView = YES;
        [self createWebView];
        [self domainOperate];
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    // 通知JS页面即将隐藏
    [self objcCallJs:@{@"fn": @"pageHide", @"data": @{@"timestamp": @([[NSDate date] timeIntervalSince1970])}];
}

- (void)dealloc {
    // 清理资源
    [self.webView stopLoading];
    self.webView.navigationDelegate = nil;
    self.webView.UIDelegate = nil;
    self.webView.scrollView.delegate = nil;
    [self.webView removeFromSuperview];
    self.webView = nil;
    
    ZJLog(@"%@ dealloc", NSStringFromClass([self class]));
}
```

### 2. 内存警告处理

```objc
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    
    // 清理缓存
    [[NSCache sharedCache] removeAllObjects];
    
    // 通知JS释放资源
    [self objcCallJs:@{@"fn": @"onMemoryWarning", @"data": @{}}];
}
```

## 错误处理

### 1. 加载失败处理

```objc
- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    ZJLog(@"页面加载失败: %@", error);
    
    if (error.code == NSURLErrorNotConnectedToInternet) {
        [self showNetworkErrorView];
    } else {
        [self showErrorView:@"页面加载失败，请稍后重试"];
    }
}

- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    ZJLog(@"导航失败: %@", error);
}
```

### 2. JavaScript错误捕获

```javascript
// 全局错误捕获
window.addEventListener('error', function(e) {
    webViewCall('reportError', {
        message: e.message,
        filename: e.filename,
        lineno: e.lineno,
        colno: e.colno,
        stack: e.error ? e.error.stack : ''
    });
});

// Promise错误捕获
window.addEventListener('unhandledrejection', function(e) {
    webViewCall('reportError', {
        message: e.reason.toString(),
        type: 'unhandledrejection'
    });
});
```

## 安全机制

### 1. URL白名单

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

```objc
- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    NSURL *url = navigationAction.request.URL;
    
    // 防止JavaScript注入
    if ([url.scheme isEqualToString:@"javascript"]) {
        decisionHandler(WKNavigationActionPolicyCancel);
        return;
    }
    
    // URL白名单检查
    if (![self isURLAllowed:url.absoluteString]) {
        decisionHandler(WKNavigationActionPolicyCancel);
        return;
    }
    
    decisionHandler(WKNavigationActionPolicyAllow);
}
```

## 性能优化

### 1. 资源预加载
- HTML模板预读取
- 静态资源缓存
- WebView预创建

### 2. 渲染优化
- 减少DOM操作
- 使用硬件加速
- 图片懒加载

### 3. 内存优化
- 及时释放资源
- 缓存大小限制
- 内存警告处理

## 已知问题

### 1. WebView相关
- iOS 11 WKWebView Cookie同步问题
- 某些情况下白屏问题
- 内存占用较高

### 2. 桥接相关
- 大数据传输性能问题
- 回调函数内存泄漏风险
- 异步调用时序问题

### 3. 兼容性
- 不同iOS版本差异
- JavaScript兼容性
- 第三方SDK冲突

## 优化建议

### 1. 架构优化
- 统一WebView管理器
- 插件化JS桥接
- 模块化页面加载

### 2. 性能提升
- 增量更新机制
- 离线包方案
- 预渲染优化

### 3. 开发体验
- 调试工具增强
- 错误上报完善
- 自动化测试