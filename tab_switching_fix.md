# Tab页切换卡顿问题修复方案

## 问题总结

Release版本在真机上从首页切换到第二个Tab时，主线程阻塞超过9秒，原因是：
1. WKWebView在主线程同步创建，阻塞了UI
2. iOS 18的viewDidAppear不被自动调用，手动触发时机不当
3. 在转场动画进行时创建复杂视图导致系统资源竞争

## 修复方案一：紧急修复（推荐）

修改 `XZWKWebViewBaseController.m` 的 `viewDidAppear` 方法：

```objc
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    NSLog(@"在局 🌟 [XZWKWebViewBaseController] viewDidAppear - view显示在窗口");
    
    // 记录这一次选中的索引
    self.lastSelectedIndex = self.tabBarController.selectedIndex;
    
    // 修复：延迟创建WebView，避免与转场动画冲突
    if (!self.webView) {
        NSLog(@"在局🔧 [viewDidAppear] 检测到WebView未创建，延迟创建");
        
        // 使用更长的延迟，确保转场动画完全结束
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (!self.webView && !self->_isDisappearing) {
                NSLog(@"在局🔧 [viewDidAppear] 开始创建WebView");
                [self setupWebView];
                [self addWebView];
                NSLog(@"在局✅ [viewDidAppear] WebView创建完成");
                
                // WebView创建完成后，检查是否需要加载内容
                if (self.htmlStr) {
                    NSLog(@"在局📝 [viewDidAppear] htmlStr已准备好，加载内容");
                    [self loadHTMLContent];
                } else if (self.pinUrl) {
                    NSLog(@"在局📝 [viewDidAppear] 触发domainOperate");
                    [self domainOperate];
                }
            }
        });
        
        // 立即返回，不执行后续操作
        return;
    }
    
    // 已有WebView的后续处理...
}
```

修改 `CFJClientH5Controller.m` 的 `viewWillAppear` 方法中的iOS 18修复：

```objc
// iOS 18修复：增加延迟时间，避免与转场动画冲突
if (@available(iOS 13.0, *)) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (!self.viewDidAppearCalled && !self->_isDisappearing) {
            NSLog(@"在局🚨 [CFJClientH5Controller] iOS 18检测到viewDidAppear未被调用，手动触发");
            [self viewDidAppear:animated];
        }
    });
}
```

## 修复方案二：优化WebView创建（长期方案）

修改 `XZWKWebViewBaseController.m` 的 `setupWebView` 方法：

```objc
- (void)setupWebView {
    NSLog(@"在局🔧 [setupWebView] 开始创建WebView");
    
    // 防止重复创建
    if (self.webView) {
        NSLog(@"在局⚠️ [setupWebView] WebView已存在，跳过创建");
        return;
    }
    
    // 创建配置（这部分很快，可以在主线程）
    WKWebViewConfiguration *configuration = [[WKWebViewConfiguration alloc] init];
    configuration.allowsInlineMediaPlayback = YES;
    configuration.mediaTypesRequiringUserActionForPlayback = WKAudiovisualMediaTypeNone;
    
    configuration.preferences = [[WKPreferences alloc] init];
    configuration.preferences.javaScriptEnabled = YES;
    configuration.preferences.javaScriptCanOpenWindowsAutomatically = YES;
    
    if (@available(iOS 14.0, *)) {
        configuration.defaultWebpagePreferences.allowsContentJavaScript = YES;
    }
    
    configuration.websiteDataStore = [WKWebsiteDataStore defaultDataStore];
    
    self.userContentController = [[WKUserContentController alloc] init];
    configuration.userContentController = self.userContentController;
    
    // 创建一个临时frame，避免使用CGRectZero
    CGRect webViewFrame = self.view.bounds;
    if (CGRectIsEmpty(webViewFrame)) {
        webViewFrame = CGRectMake(0, 0, [UIScreen mainScreen].bounds.size.width, [UIScreen mainScreen].bounds.size.height);
    }
    
    // 在主线程创建WebView，但使用CATransaction包装减少阻塞
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    
    self.webView = [[WKWebView alloc] initWithFrame:webViewFrame configuration:configuration];
    self.webView.backgroundColor = [UIColor whiteColor];
    self.webView.opaque = YES;
    
    [CATransaction commit];
    
    NSLog(@"在局✅ [setupWebView] WebView创建成功");
    
    // 后续配置...
}
```

## 修复方案三：优化domainOperate调用时机

修改 `XZWKWebViewBaseController.m` 的 `viewDidLoad` 方法：

```objc
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    
    // ... 初始化代码 ...
    
    // 优化：只有第一个Tab立即加载，其他Tab延迟到显示时
    if (self.isTabbarShow && self.tabBarController.selectedIndex == 0) {
        NSLog(@"在局🏠 [viewDidLoad] 首页Tab，立即调用domainOperate");
        [self domainOperate];
    } else {
        NSLog(@"在局⏳ [viewDidLoad] 非首页Tab，延迟加载到viewDidAppear");
        // 不调用domainOperate，等待viewDidAppear
    }
}
```

## 测试建议

1. 在iOS 18设备上重点测试Tab切换流畅性
2. 监控主线程阻塞时间，确保不超过100ms
3. 检查WebView加载是否正常，特别是第二个Tab
4. 验证内存使用情况，确保没有内存泄漏

## 性能优化建议

1. **预加载策略**：在用户可能切换到某个Tab前，预先创建WebView
2. **懒加载优化**：将WebView的某些配置延迟到真正需要时
3. **使用WKWebView池**：预创建一定数量的WKWebView实例，复用以减少创建开销

## 监控代码

添加性能监控以跟踪修复效果：

```objc
// 在Tab切换开始时记录时间
- (BOOL)tabBarController:(UITabBarController *)tabBarController shouldSelectViewController:(UIViewController *)viewController {
    self.tabSwitchStartTime = CACurrentMediaTime();
    // ... 其他代码
}

// 在WebView加载完成时计算耗时
- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    if (self.tabSwitchStartTime > 0) {
        double elapsed = CACurrentMediaTime() - self.tabSwitchStartTime;
        NSLog(@"在局📊 [性能] Tab切换到页面加载完成耗时: %.2f秒", elapsed);
        self.tabSwitchStartTime = 0;
    }
    // ... 其他代码
}
```