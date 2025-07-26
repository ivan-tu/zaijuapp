//
//  XZWKWebViewBaseController.m
//  XZVientiane
//
//  Created by Assistant on 2024/12/19.
//  Copyright © 2024年 TuWeiA. All rights reserved.
//

#import "XZWKWebViewBaseController.h"
#import "XZFunctionDefine.h"
#import "WKWebView+XZAddition.h"
#import "BaseFileManager.h"
#import "AFHTTPSessionManager.h"
#import "NSString+addition.h"
#import "XZBaseHead.h"
#import "HTMLCache.h"
#import "XZOrderModel.h"
#import "RNCachingURLProtocol.h"
#import "UIView+AutoLayout.h"
#import "EGOCache.h"
#import <QuartzCore/QuartzCore.h>
#import "SVStatusHUD.h"
#import <Masonry.h>
#import <MJRefresh.h>
#import "XZPackageH5.h"
#import "LoadingView.h"
#import "CustomHybridProcessor.h"
#import <objc/runtime.h>
#import "AppDelegate.h"

// 导入WebViewJavascriptBridge
#import "../../ThirdParty/WKWebViewJavascriptBridge/WKWebViewJavascriptBridge.h"

// iPhone X系列检测
static inline BOOL isIPhoneXSeries() {
    BOOL iPhoneXSeries = NO;
    if (UIDevice.currentDevice.userInterfaceIdiom != UIUserInterfaceIdiomPhone) {
        return iPhoneXSeries;
    }
    
    if (@available(iOS 11.0, *)) {
        UIWindow *mainWindow = [[[UIApplication sharedApplication] delegate] window];
        if (mainWindow.safeAreaInsets.bottom > 0.0) {
            iPhoneXSeries = YES;
        }
    }
    
    return iPhoneXSeries;
}

// 兼容性常量定义（避免重复定义）
#ifndef GDPUSHTYPE_CONSTANTS_IMPLEMENTATION
#define GDPUSHTYPE_CONSTANTS_IMPLEMENTATION
// 枚举值已在头文件中定义，无需重复声明常量
#endif

@interface XZWKWebViewBaseController ()<WKNavigationDelegate, WKUIDelegate, UIScrollViewDelegate>
{
    __block int timeout; // 倒计时时间
    NSDate *lastLoadTime; // 上次加载时间，用于防止频繁重新加载
    BOOL _isDisappearing; // 标记页面是否正在消失
    NSMutableArray *_pendingJavaScriptOperations; // 待执行的JavaScript操作
    NSInteger _retryCount; // 重试次数（非static）
    NSString *_lastFailedUrl; // 上次失败的URL（非static）
}

@property (nonatomic, strong) WKWebViewJavascriptBridge *bridge;  // 使用WebViewJavascriptBridge
@property (nonatomic, strong) UIActivityIndicatorView *activityIndicatorView; // 加载指示器
@property (nonatomic, strong) UIProgressView *progressView; // 进度条
@property (nonatomic, strong) NSString *currentTempFileName; // 当前临时文件名
@property (nonatomic, strong) NSOperationQueue *jsOperationQueue; // JavaScript操作队列
@property (nonatomic, strong) NSTimer *healthCheckTimer; // WebView健康检查定时器

@end

@implementation XZWKWebViewBaseController

@synthesize componentJsAndCs = _componentJsAndCs;
@synthesize componentDic = _componentDic;
@synthesize templateDic = _templateDic;
@synthesize nextPageData = _nextPageData;
@synthesize navDic = _navDic;
@synthesize isCheck = _isCheck;
@synthesize isTabbarShow = _isTabbarShow;
@synthesize pushType = _pushType;
@synthesize isExist = _isExist;
@synthesize replaceUrl = _replaceUrl;
@synthesize nextPageDataBlock = _nextPageDataBlock;

#pragma mark - Life Cycle

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    
    // 初始化属性
    self.isWebViewLoading = NO;
    self.isLoading = NO;
    self.isCreat = NO;
    _isDisappearing = NO;
    _pendingJavaScriptOperations = [NSMutableArray array];
    _retryCount = 0;
    _lastFailedUrl = nil;
    
    // 创建JavaScript操作队列
    self.jsOperationQueue = [[NSOperationQueue alloc] init];
    self.jsOperationQueue.maxConcurrentOperationCount = 1;
    self.jsOperationQueue.name = @"com.xz.javascript.queue";
    
    // 创建网络状态提示视图
    [self setupNetworkNoteView];
    
    // 延迟WebView创建到需要时，避免阻塞Tab切换动画
    NSLog(@"在局⏳ [viewDidLoad] 延迟WebView创建到实际需要时");
    
    // 创建加载指示器
    [self setupLoadingIndicators];
    
    // 添加通知监听
    [self addNotificationObservers];
    
    // 初始化JavaScript执行管理
    [self initializeJavaScriptManagement];
    
    // 添加应用生命周期通知监听
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appWillTerminate:) name:@"AppWillTerminateNotification" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidEnterBackground:) name:@"AppDidEnterBackgroundNotification" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appWillResignActive:) name:@"AppWillResignActiveNotification" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidBecomeActive:) name:@"AppDidBecomeActiveNotification" object:nil];
    
    // 添加场景更新通知监听，iOS 13+
    if (@available(iOS 13.0, *)) {
        [[NSNotificationCenter defaultCenter] addObserver:self 
                                                 selector:@selector(sceneWillDeactivate:) 
                                                     name:UISceneWillDeactivateNotification 
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self 
                                                 selector:@selector(sceneDidEnterBackground:) 
                                                     name:UISceneDidEnterBackgroundNotification 
                                                   object:nil];
    }
    
    // 开始操作
    [self domainOperate];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.lastSelectedIndex = self.tabBarController.selectedIndex;
    
    // 检查WebView状态，但不在viewWillAppear中创建，避免阻塞转场
    if (!self.webView) {
        if (animated) {
            NSLog(@"在局⏳ [viewWillAppear] 检测到动画，WebView将在viewDidAppear中创建以避免阻塞转场");
        } else {
            NSLog(@"在局⏳ [viewWillAppear] 无动画，WebView将在viewDidAppear中创建");
        }
    } else {
        NSLog(@"在局ℹ️ [viewWillAppear] WebView已存在，无需创建");
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    // 清除消失标志
    _isDisappearing = NO;
    
    // 记录这一次选中的索引
    self.lastSelectedIndex = self.tabBarController.selectedIndex;
    
    // 在viewDidAppear中创建WebView，确保转场动画完成后再创建
    if (!self.webView) {
        NSLog(@"在局🔧 [viewDidAppear] 转场完成，开始创建WebView");
        
        // 修复：异步创建WebView，避免阻塞主线程导致9秒卡顿
        dispatch_async(dispatch_get_main_queue(), ^{
            [self setupWebView];
            [self addWebView];
            NSLog(@"在局✅ [viewDidAppear] WebView创建完成");
            
            // WebView创建完成后，检查htmlStr是否已准备好
            if (self.htmlStr && self.htmlStr.length > 0) {
                NSLog(@"在局🔄 [viewDidAppear] htmlStr已准备好，触发内容加载");
                [self loadHTMLContent];
            } else {
                NSLog(@"在局⏳ [viewDidAppear] htmlStr未准备好，等待domainOperate完成");
                // htmlStr还没准备好，等待domainOperate完成后自动调用loadHTMLContent
            }
        });
        return;
        
        // WebView创建完成后，检查htmlStr是否已准备好
        if (self.htmlStr && self.htmlStr.length > 0) {
            NSLog(@"在局🔄 [viewDidAppear] htmlStr已准备好，触发内容加载");
            [self loadHTMLContent];
        } else {
            NSLog(@"在局⏳ [viewDidAppear] htmlStr未准备好，等待domainOperate完成");
            // htmlStr还没准备好，等待domainOperate完成后自动调用loadHTMLContent
        }
    } else {
        NSLog(@"在局ℹ️ [viewDidAppear] WebView已存在，跳过创建");
        
        // 修复真机权限授予后首页空白问题 - 检查是否需要重新加载
        if (!self.isWebViewLoading && !self.isLoading && self.pinUrl && self.htmlStr) {
            NSLog(@"在局 🚨 [viewDidAppear] 检测到WebView存在但未加载内容，触发加载");
            [self loadHTMLContent];
        }
    }
    
    // 启动网络监控
    [self listenToTimer];
    
    // 处理重复点击tabbar刷新
    if (self.lastSelectedIndex == self.tabBarController.selectedIndex && [self isShowingOnKeyWindow] && self.isWebViewLoading) {
        [self.webView.scrollView scrollRectToVisible:CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.height) animated:YES];
    }
    
    // 故障保护：如果WebView没有加载内容，重新加载
    if (!self.isWebViewLoading && !self.isLoading && self.pinUrl) {
        NSLog(@"在局⚠️ [viewDidAppear] WebView未加载内容，重新加载");
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (!self.isWebViewLoading && !self.isLoading) {
                [self domainOperate];
            }
        });
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    // 设置消失标志
    _isDisappearing = YES;
    
    // 取消所有延迟的JavaScript任务
    [self cancelAllDelayedJavaScriptTasks];
    
    // 立即取消所有JavaScript操作
    [self.jsOperationQueue cancelAllOperations];
    
    // 取消所有延迟执行的方法
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    
    // 清理所有待执行的定时器
    for (NSTimer *timer in _pendingJavaScriptOperations) {
        if ([timer isKindOfClass:[NSTimer class]]) {
            [timer invalidate];
        }
    }
    [_pendingJavaScriptOperations removeAllObjects];
    
    // 停止WebView的所有活动
    if (self.webView) {
        [self.webView stopLoading];
        // 清空JavaScript执行
        [self.webView evaluateJavaScript:@"" completionHandler:nil];
    }
    
    // 停止下拉刷新
    if ([self.webView.scrollView.mj_header isRefreshing]) {
        [self.webView.scrollView.mj_header endRefreshing];
    }
    
    // 停止健康检查定时器
    if (self.healthCheckTimer) {
        [self.healthCheckTimer invalidate];
        self.healthCheckTimer = nil;
    }
    
    // 停止loading指示器
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.activityIndicatorView stopAnimating];
        self.progressView.hidden = YES;
        self.progressView.progress = 0.0;
    });
    
    // 停止网络监控
    self.lastSelectedIndex = 100;
    // 安全地取消timer，防止野指针
    dispatch_source_t timerToCancel = self.timer;
    if (timerToCancel) {
        self.timer = nil; // 先置空
        dispatch_source_cancel(timerToCancel); // 再取消
    }
    
    // 清理临时HTML文件
    [self cleanupTempHtmlFiles];
}

- (void)cleanupTempHtmlFiles {
    // 只清理当前控制器的临时文件
    if (self.currentTempFileName) {
        BOOL fileRemoved = NO;
        
        // 首先尝试在Documents目录中查找
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *documentsPath = [paths firstObject];
        NSString *documentsFilePath = [documentsPath stringByAppendingPathComponent:self.currentTempFileName];
        
        if ([[NSFileManager defaultManager] fileExistsAtPath:documentsFilePath]) {
            [[NSFileManager defaultManager] removeItemAtPath:documentsFilePath error:nil];
            NSLog(@"在局🗑️ 清理临时文件（Documents）: %@", self.currentTempFileName);
            fileRemoved = YES;
        }
        
        // 兼容旧版本，同时检查manifest目录
        NSString *manifestPath = [BaseFileManager appH5LocailManifesPath];
        NSString *manifestFilePath = [manifestPath stringByAppendingPathComponent:self.currentTempFileName];
        
        if ([[NSFileManager defaultManager] fileExistsAtPath:manifestFilePath]) {
            [[NSFileManager defaultManager] removeItemAtPath:manifestFilePath error:nil];
            NSLog(@"在局🗑️ 清理临时文件（Manifest）: %@", self.currentTempFileName);
            fileRemoved = YES;
        }
        
        if (!fileRemoved) {
            NSLog(@"在局⚠️ 未找到临时文件: %@", self.currentTempFileName);
        }
        
        self.currentTempFileName = nil;
    }
}

#pragma mark - JavaScript执行时机管理

- (void)initializeJavaScriptManagement {
    NSLog(@"在局 🔧 [XZWKWebViewBaseController] 优化JavaScript执行时机管理");
    if (!self.pendingJavaScriptTasks) {
        self.pendingJavaScriptTasks = [NSMutableArray array];
    }
    if (!self.delayedTimers) {
        self.delayedTimers = [NSMutableArray array];
    }
}

// 添加延迟执行的JavaScript任务（可取消）
- (NSTimer *)scheduleJavaScriptTask:(void(^)(void))task afterDelay:(NSTimeInterval)delay {
    NSLog(@"在局 ⏱️ [JS时机管理] 安排JavaScript任务，延迟: %.1f秒", delay);
    
    NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:delay
                                                     repeats:NO
                                                       block:^(NSTimer * _Nonnull timer) {
        NSLog(@"在局 ▶️ [JS时机管理] 执行延迟的JavaScript任务");
        if (task) {
            task();
        }
        [self.delayedTimers removeObject:timer];
    }];
    
    [self.delayedTimers addObject:timer];
    return timer;
}

// 取消所有延迟的JavaScript任务
- (void)cancelAllDelayedJavaScriptTasks {
    NSLog(@"在局 🛑 [JS时机管理] 取消所有延迟的JavaScript任务，数量: %lu", (unsigned long)self.delayedTimers.count);
    
    for (NSTimer *timer in self.delayedTimers) {
        [timer invalidate];
    }
    [self.delayedTimers removeAllObjects];
}

// 基于状态的JavaScript执行（替代固定延迟）
- (void)executeJavaScriptWhenReady:(NSString *)javascript completion:(void(^)(id result, NSError *error))completion {
    NSLog(@"在局 🎯 [JS时机管理] 等待合适时机执行JavaScript");
    
    // 检查WebView和JavaScript环境是否就绪
    if (self.webView && self.isWebViewLoading) {
        // 立即执行
        NSLog(@"在局 ✅ [JS时机管理] JavaScript环境已就绪，立即执行");
        [self safelyEvaluateJavaScript:javascript completion:completion];
    } else {
        // 添加到待执行队列
        NSLog(@"在局 ⏳ [JS时机管理] JavaScript环境未就绪，加入待执行队列");
        NSDictionary *taskInfo = @{
            @"javascript": javascript ?: @"",
            @"completion": completion ?: ^(id r, NSError *e){}
        };
        [self.pendingJavaScriptTasks addObject:taskInfo];
    }
}

// 处理所有待执行的JavaScript任务
- (void)processPendingJavaScriptTasks {
    if (self.pendingJavaScriptTasks.count == 0) return;
    
    NSLog(@"在局 🚀 [JS时机管理] 处理待执行的JavaScript任务，数量: %lu", (unsigned long)self.pendingJavaScriptTasks.count);
    
    NSArray *tasks = [self.pendingJavaScriptTasks copy];
    [self.pendingJavaScriptTasks removeAllObjects];
    
    for (NSDictionary *taskInfo in tasks) {
        NSString *javascript = taskInfo[@"javascript"];
        void(^completion)(id, NSError *) = taskInfo[@"completion"];
        
        [self safelyEvaluateJavaScript:javascript completion:completion];
    }
}

- (void)dealloc {
    // 取消所有延迟的JavaScript任务
    [self cancelAllDelayedJavaScriptTasks];
    
    // 取消所有JavaScript操作
    [self.jsOperationQueue cancelAllOperations];
    self.jsOperationQueue = nil;
    
    // 清理待执行的操作
    for (NSTimer *timer in _pendingJavaScriptOperations) {
        if ([timer isKindOfClass:[NSTimer class]]) {
            [timer invalidate];
        }
    }
    [_pendingJavaScriptOperations removeAllObjects];
    
    // 移除通知监听
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    // 安全地取消timer，防止野指针
    dispatch_source_t timerToCancel = self.timer;
    if (timerToCancel) {
        self.timer = nil; // 先置空
        dispatch_source_cancel(timerToCancel); // 再取消
    }
    
    // 清理WebView
    if (self.webView) {
        // 停止加载
        [self.webView stopLoading];
        
        // 清理桥接
        if (self.bridge) {
            [self.bridge reset];
            self.bridge = nil;
        }
        
        // 移除委托
        self.webView.navigationDelegate = nil;
        self.webView.UIDelegate = nil;
        
        // 根据资料建议，移除KVO观察者
        @try {
            [self.webView removeObserver:self forKeyPath:@"estimatedProgress"];
            [self.webView removeObserver:self forKeyPath:@"title"];
        } @catch (NSException *exception) {
            NSLog(@"在局⚠️ [WKWebView] 移除KVO观察者时发生异常: %@", exception.reason);
        }
        
        // 移除WebView
        [self.webView removeFromSuperview];
        self.webView = nil;
    }
    
    // 清理临时HTML文件
    [self cleanupTempHtmlFiles];
    
    // 清理Bridge（根据资料，WebViewJavascriptBridge会自动清理）
    if (self.bridge) {
        [self.bridge reset];
        self.bridge = nil;
    }
    
    // 清理UserContentController - 优化内存管理
    NSLog(@"在局 🔧 [XZWKWebViewBaseController] 处理WKUserContentController内存泄漏风险");
    if (self.userContentController) {
        // 移除所有用户脚本
        [self.userContentController removeAllUserScripts];
        NSLog(@"在局 ✅ [内存管理] 已移除所有用户脚本");
        
        // 注意：只有在添加了scriptMessageHandler时才需要移除
        // 当前代码未使用addScriptMessageHandler，所以注释掉以下行
        // [self.userContentController removeScriptMessageHandlerForName:@"consoleLog"];
        
        self.userContentController = nil;
        NSLog(@"在局 ✅ [内存管理] WKUserContentController已清理");
    }
    
    if (self.webView) {
        self.webView.navigationDelegate = nil;
        self.webView.UIDelegate = nil;
        self.webView.scrollView.delegate = nil;
        [self.webView stopLoading];
        self.webView = nil;
    }
}

#pragma mark - App Lifecycle Methods

- (void)appWillTerminate:(NSNotification *)notification {
    // 应用终止时只执行最少的必要操作
    
    // 立即停止定时器
    if (self.timer) {
        dispatch_source_cancel(self.timer);
        self.timer = nil;
    }
    
    // 快速清理WebView
    if (self.webView) {
        [self.webView stopLoading];
        self.webView.navigationDelegate = nil;
        self.webView.UIDelegate = nil;
    }
    
    // 不执行任何耗时操作，让系统快速终止应用
}

- (void)appDidEnterBackground:(NSNotification *)notification {
    NSLog(@"在局🔔 [XZWKWebView] 应用进入后台，暂停JavaScript执行");
    
    // 取消所有延迟执行的方法
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    
    // 清理所有待执行的定时器
    for (NSTimer *timer in _pendingJavaScriptOperations) {
        if ([timer isKindOfClass:[NSTimer class]]) {
            [timer invalidate];
        }
    }
    [_pendingJavaScriptOperations removeAllObjects];
    
    // 暂停所有正在进行的JavaScript执行
    if (self.webView) {
        // 停止任何正在进行的加载
        [self.webView stopLoading];
        
        // 不再执行JavaScript，避免在后台触发新的执行
    }
    
    // 停止定时器，防止后台继续执行
    // 安全地取消timer，防止野指针
    dispatch_source_t timerToCancel = self.timer;
    if (timerToCancel) {
        self.timer = nil; // 先置空
        dispatch_source_cancel(timerToCancel); // 再取消
    }
}

- (void)appWillResignActive:(NSNotification *)notification {
    NSLog(@"在局🔔 [XZWKWebView] 应用即将失去活跃状态，暂停所有JavaScript执行");
    
    // 立即释放键盘焦点，避免在非活跃状态占用键盘
    [self.view endEditing:YES];
    [[UIApplication sharedApplication].keyWindow endEditing:YES];
    
    // 取消所有延迟执行的方法
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    
    // 清理所有待执行的定时器
    for (NSTimer *timer in _pendingJavaScriptOperations) {
        if ([timer isKindOfClass:[NSTimer class]]) {
            [timer invalidate];
        }
    }
    
    // 立即取消所有正在进行的JavaScript操作
    if (self.webView) {
        // 停止加载
        [self.webView stopLoading];
        
        // 不再执行JavaScript，避免在非活跃状态触发新的执行
        
        // 暂停定时器
        // 安全地取消timer，防止野指针
        dispatch_source_t timerToCancel = self.timer;
        if (timerToCancel) {
            self.timer = nil; // 先置空
            dispatch_source_cancel(timerToCancel); // 再取消
        }
    }
}

- (void)appDidBecomeActive:(NSNotification *)notification {
    NSLog(@"在局🔔 [XZWKWebView] 应用恢复活跃状态");
    
    // 检查是否需要重新启动定时器
    if (!self.timer && self.networkNoteView && self.networkNoteView.hidden) {
        [self listenToTimer];
    }
}

#pragma mark - Scene Lifecycle Methods (iOS 13+)

- (void)sceneWillDeactivate:(NSNotification *)notification API_AVAILABLE(ios(13.0)) {
    NSLog(@"在局🔔 [XZWKWebView] 场景即将失去活跃状态");
    
    // 取消所有延迟执行的方法
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    
    // 清理所有待执行的定时器
    for (NSTimer *timer in _pendingJavaScriptOperations) {
        if ([timer isKindOfClass:[NSTimer class]]) {
            [timer invalidate];
        }
    }
    
    // 立即停止所有JavaScript执行
    if (self.webView) {
        [self.webView stopLoading];
    }
    
    // 停止定时器
    // 安全地取消timer，防止野指针
    dispatch_source_t timerToCancel = self.timer;
    if (timerToCancel) {
        self.timer = nil; // 先置空
        dispatch_source_cancel(timerToCancel); // 再取消
    }
}

- (void)sceneDidEnterBackground:(NSNotification *)notification API_AVAILABLE(ios(13.0)) {
    NSLog(@"在局🔔 [XZWKWebView] 场景进入后台");
    
    // 确保停止所有活动
    if (self.webView) {
        [self.webView stopLoading];
    }
}

#pragma mark - Setup Methods

- (void)setupNetworkNoteView {
    self.networkNoteView = [[UIView alloc] init];
    self.networkNoteView.backgroundColor = [UIColor colorWithRed:0.9 green:0.9 blue:0.9 alpha:1.0];
    self.networkNoteView.hidden = YES;
    [self.view addSubview:self.networkNoteView];
    
    self.networkNoteBt = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.networkNoteBt setTitle:@"网络连接失败，点击重试" forState:UIControlStateNormal];
    [self.networkNoteBt setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [self.networkNoteBt addTarget:self action:@selector(networkNoteBtClick) forControlEvents:UIControlEventTouchUpInside];
    [self.networkNoteView addSubview:self.networkNoteBt];
    
    [self.networkNoteView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.view);
    }];
    
    [self.networkNoteBt mas_makeConstraints:^(MASConstraintMaker *make) {
        make.center.equalTo(self.networkNoteView);
        make.height.mas_equalTo(40);
    }];
}

- (void)setupWebView {
    NSLog(@"在局🔧 [setupWebView] 开始创建WebView");
    
    // 优化：使用CATransaction包装WebView创建，减少UI阻塞
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    
    // 创建WKWebView配置
    WKWebViewConfiguration *configuration = [[WKWebViewConfiguration alloc] init];
    configuration.allowsInlineMediaPlayback = YES;
    configuration.mediaTypesRequiringUserActionForPlayback = WKAudiovisualMediaTypeNone;
    
    // 关键：配置WKWebView的安全策略，允许JavaScript执行
    configuration.preferences = [[WKPreferences alloc] init];
    configuration.preferences.javaScriptEnabled = YES;
    configuration.preferences.javaScriptCanOpenWindowsAutomatically = YES;
    
    // 关键：WKWebView有更好的安全机制，不需要设置私有API
    // 注意：allowFileAccessFromFileURLs 和 allowUniversalAccessFromFileURLs 是私有API
    // WKWebView使用loadHTMLString:baseURL:加载HTML内容，baseURL用于指定资源路径
    
    // 根据资料建议，配置默认网页首选项
    if (@available(iOS 14.0, *)) {
        configuration.defaultWebpagePreferences.allowsContentJavaScript = YES;
    }
    
    // 配置安全设置，允许混合内容
    if (@available(iOS 10.0, *)) {
        configuration.mediaTypesRequiringUserActionForPlayback = WKAudiovisualMediaTypeNone;
    }
    
    // 允许任意加载（开发环境）
    if (@available(iOS 9.0, *)) {
        configuration.allowsAirPlayForMediaPlayback = YES;
        configuration.allowsPictureInPictureMediaPlayback = YES;
    }
    
    // 根据资料，确保正确配置数据存储
    configuration.websiteDataStore = [WKWebsiteDataStore defaultDataStore];
    
    // 创建UserContentController（WebViewJavascriptBridge会自动处理消息）
    self.userContentController = [[WKUserContentController alloc] init];
    configuration.userContentController = self.userContentController;
    
    // 根据资料建议，添加调试脚本（仅在Debug模式）
    #ifdef DEBUG
    NSString *debugScript = @"window.isWKWebView = true;";
    WKUserScript *userScript = [[WKUserScript alloc] initWithSource:debugScript
                                                      injectionTime:WKUserScriptInjectionTimeAtDocumentStart 
                                                   forMainFrameOnly:NO];
    [self.userContentController addUserScript:userScript];
    #endif
    
    // 创建WKWebView
    self.webView = [[WKWebView alloc] initWithFrame:CGRectZero configuration:configuration];
    self.webView.navigationDelegate = self;
    self.webView.UIDelegate = self;
    self.webView.scrollView.delegate = self;
    self.webView.backgroundColor = [UIColor whiteColor];
    
    NSLog(@"在局✅ [setupWebView] WebView创建成功: %@", self.webView);
    
    // 修复左滑返回手势冲突：禁用WKWebView的左滑后退手势
    if (@available(iOS 9.0, *)) {
        self.webView.allowsBackForwardNavigationGestures = NO;
    }
    
    // 配置滚动视图 - 修复iOS 12键盘弹起后布局问题
    NSLog(@"在局 🔧 [XZWKWebViewBaseController] 修复iOS 12键盘布局问题");
    if (@available(iOS 12.0, *)) {
        // iOS 12及以上版本使用Automatic，避免键盘弹起后视图不恢复的问题
        self.webView.scrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentAutomatic;
        NSLog(@"在局 ✅ [XZWKWebViewBaseController] iOS 12+使用UIScrollViewContentInsetAdjustmentAutomatic");
    } else if (@available(iOS 11.0, *)) {
        // iOS 11使用Never
        self.webView.scrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
        NSLog(@"在局 ✅ [XZWKWebViewBaseController] iOS 11使用UIScrollViewContentInsetAdjustmentNever");
    } else {
        self.automaticallyAdjustsScrollViewInsets = NO;
    }
    
    // 根据资料建议，添加进度监听
    [self.webView addObserver:self forKeyPath:@"estimatedProgress" options:NSKeyValueObservingOptionNew context:NULL];
    [self.webView addObserver:self forKeyPath:@"title" options:NSKeyValueObservingOptionNew context:NULL];
    
    // 配置滚动视图属性
    self.webView.scrollView.scrollsToTop = YES;
    self.webView.scrollView.showsVerticalScrollIndicator = NO;
    self.webView.scrollView.showsHorizontalScrollIndicator = NO;
    self.webView.scrollView.bounces = YES;
    self.webView.scrollView.decelerationRate = UIScrollViewDecelerationRateNormal;
    
    // 添加下拉刷新支持
    [self setupRefreshControl];
    
    // 设置用户代理
    [self setCustomUserAgent];
    
    // 结束CATransaction
    [CATransaction commit];
}

- (void)setupRefreshControl {
    // 配置下拉刷新控件
    __weak UIScrollView *scrollView = self.webView.scrollView;
    MJRefreshNormalHeader *header = [MJRefreshNormalHeader headerWithRefreshingTarget:self refreshingAction:@selector(loadNewData)];
    header.lastUpdatedTimeLabel.hidden = YES;
    header.stateLabel.hidden = YES;
    
    // 添加下拉刷新控件
    scrollView.mj_header = header;
}

- (void)setupLoadingIndicators {
    NSLog(@"在局 🔧 [XZWKWebViewBaseController] 设置加载指示器和进度条");
    
    // 创建加载指示器
    self.activityIndicatorView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    self.activityIndicatorView.center = CGPointMake(self.view.bounds.size.width / 2, self.view.bounds.size.height / 2);
    self.activityIndicatorView.hidesWhenStopped = YES;
    [self.view addSubview:self.activityIndicatorView];
    
    // 创建进度条
    self.progressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
    self.progressView.frame = CGRectMake(0, 0, self.view.bounds.size.width, 3); // 增加高度到3像素
    self.progressView.progressTintColor = [UIColor colorWithRed:0.2 green:0.6 blue:1.0 alpha:1.0];
    self.progressView.trackTintColor = [UIColor colorWithRed:0.9 green:0.9 blue:0.9 alpha:0.5]; // 设置背景色让进度条更明显
    self.progressView.hidden = YES;
    self.progressView.alpha = 1.0;
    self.progressView.transform = CGAffineTransformMakeScale(1.0f, 2.0f); // 增加进度条厚度
    [self.view addSubview:self.progressView];
    
    // 调整进度条位置到导航栏下方
    if (self.navigationController && !self.navigationController.navigationBar.hidden) {
        CGFloat navBarMaxY = CGRectGetMaxY(self.navigationController.navigationBar.frame);
        self.progressView.frame = CGRectMake(0, navBarMaxY, self.view.bounds.size.width, 3);
    } else {
        // 如果没有导航栏，放在状态栏下方
        CGFloat statusBarHeight = [UIApplication sharedApplication].statusBarFrame.size.height;
        self.progressView.frame = CGRectMake(0, statusBarHeight, self.view.bounds.size.width, 3);
    }
    
    NSLog(@"在局 ✅ [XZWKWebViewBaseController] 加载指示器和进度条设置完成");
}

- (void)loadNewData {
    
    // 调用JavaScript的下拉刷新事件
    NSDictionary *callJsDic = [CustomHybridProcessor custom_objcCallJsWithFn:@"pagePullDownRefresh" data:nil];
    [self objcCallJs:callJsDic];
    
    // 如果没有网络，直接停止刷新
    if (NoReachable) {
        if ([self.webView.scrollView.mj_header isRefreshing]) {
            [self.webView.scrollView.mj_header endRefreshing];
        }
        return;
    }
    
    // 设置一个10秒的超时，避免刷新一直显示 - 使用可取消的定时器
    __weak typeof(self) weakSelf = self;
    // 增加刷新超时时间以适应Release版本
    NSTimer *refreshTimeoutTimer = [NSTimer scheduledTimerWithTimeInterval:15.0 repeats:NO block:^(NSTimer * _Nonnull timer) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        
        if (strongSelf->_isDisappearing) {
            return;
        }
        
        // 检查应用状态 - 确保在主线程访问UIApplication
        __block UIApplicationState state;
        if ([NSThread isMainThread]) {
            state = [[UIApplication sharedApplication] applicationState];
        } else {
            dispatch_sync(dispatch_get_main_queue(), ^{
                state = [[UIApplication sharedApplication] applicationState];
            });
        }
        if (state != UIApplicationStateActive) {
            return;
        }
        
        if ([strongSelf.webView.scrollView.mj_header isRefreshing]) {
            [strongSelf.webView.scrollView.mj_header endRefreshing];
            NSLog(@"在局🔄 下拉刷新超时，强制结束");
        }
    }];
    
    // 添加到待执行列表以便清理
    [_pendingJavaScriptOperations addObject:refreshTimeoutTimer];
}

- (void)addNotificationObservers {
    WEAK_SELF;
    
    // 监听TabBar重复点击刷新
    [[NSNotificationCenter defaultCenter] addObserverForName:@"refreshCurrentViewController" object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
        STRONG_SELF;
        if (!self) {
            return;
        }
        
        // 防止页面消失时处理通知
        if (self->_isDisappearing) {
            return;
        }
        
        // 只处理当前显示的页面
        if (![self isShowingOnKeyWindow]) {
            return;
        }
        
        if (self.lastSelectedIndex == self.tabBarController.selectedIndex && self.isWebViewLoading) {
            if ([AFNetworkReachabilityManager manager].networkReachabilityStatus == AFNetworkReachabilityStatusNotReachable) {
                return;
            }
            
            // 如果当前已经在刷新中，先停止
            if ([self.webView.scrollView.mj_header isRefreshing]) {
                [self.webView.scrollView.mj_header endRefreshing];
            }
            
            // 开始刷新
            [self.webView.scrollView.mj_header beginRefreshing];
        }
        
        // 记录这一次选中的索引
        self.lastSelectedIndex = self.tabBarController.selectedIndex;
    }];
    
    // 监听其他页面登录/退出后的刷新
    [[NSNotificationCenter defaultCenter] addObserverForName:@"RefreshOtherAllVCNotif" object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
        STRONG_SELF;
        if (!self) {
            return;
        }
        
        UIViewController *vc = note.object;
        if (self == vc) {
            return;
        }
        
        NSLog(@"在局🔄 [XZWKWebView] 收到RefreshOtherAllVCNotif通知，开始刷新页面");
        
        // 彻底刷新页面，让条件页面重新执行状态判断
        if ([AFNetworkReachabilityManager manager].networkReachabilityStatus != AFNetworkReachabilityStatusNotReachable) {
            NSLog(@"在局🔄 [XZWKWebView] 使用domainOperate彻底刷新页面，重新执行状态判断");
            [self domainOperate];
        } else {
            NSLog(@"在局⚠️ [XZWKWebView] 网络不可用，跳过页面刷新");
        }
    }];
    
    // 监听网络权限恢复通知 - 修复Release版本首页空白问题
    [[NSNotificationCenter defaultCenter] addObserverForName:@"NetworkPermissionRestored" object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
        STRONG_SELF;
        if (!self) return;
        
        NSLog(@"在局🔥 [XZWKWebViewBaseController] 收到网络权限恢复通知");
        
        // 如果是首页且WebView已经创建但可能未完成加载，重新触发JavaScript初始化
        if (self.tabBarController.selectedIndex == 0 && self.webView) {
            NSLog(@"在局🔄 [XZWKWebViewBaseController] 网络权限恢复，强制重新执行JavaScript初始化");
            
            // 重新触发JavaScript桥接初始化和pageReady
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                // 直接触发JavaScript桥接初始化
                [self performJavaScriptBridgeInitialization];
            });
        }
    }];
    
    // 监听backToHome通知，用于tab切换
    [[NSNotificationCenter defaultCenter] addObserverForName:@"backToHome" object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
        STRONG_SELF;
        if (!self) {
            return;
        }
        
        NSLog(@"在局🏠 [XZWKWebView] 收到backToHome通知");
        
        // 如果当前页面是tab页面，确保正确刷新
        if (self.isTabbarShow && [self isShowingOnKeyWindow]) {
            // 检查应用状态 - 确保在主线程访问UIApplication
            __block UIApplicationState state;
            if ([NSThread isMainThread]) {
                state = [[UIApplication sharedApplication] applicationState];
            } else {
                dispatch_sync(dispatch_get_main_queue(), ^{
                    state = [[UIApplication sharedApplication] applicationState];
                });
            }
            if (state == UIApplicationStateActive) {
                // 使用performSelector延迟执行，可以被取消
                [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(domainOperate) object:nil];
                [self performSelector:@selector(domainOperate) withObject:nil afterDelay:0.2];
            }
        }
    }];
}

- (void)setCustomUserAgent {
    // 检查应用状态 - 确保在主线程访问UIApplication
    __block UIApplicationState state;
    if ([NSThread isMainThread]) {
        state = [[UIApplication sharedApplication] applicationState];
    } else {
        dispatch_sync(dispatch_get_main_queue(), ^{
            state = [[UIApplication sharedApplication] applicationState];
        });
    }
    if (state != UIApplicationStateActive) {
        NSLog(@"在局[XZWKWebView] 应用不在前台，跳过UserAgent设置");
        return;
    }
    
    // 直接设置UserAgent，避免执行JavaScript
    NSString *customUserAgent = @"Mozilla/5.0 (iPhone; CPU iPhone OS 13_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/13.0 Mobile/15E148 Safari/604.1 XZApp/1.0";
    dispatch_async(dispatch_get_main_queue(), ^{
        self.webView.customUserAgent = customUserAgent;
    });
}

#pragma mark - WebView Management

- (void)addWebView {
    NSLog(@"在局🔧 [addWebView] 开始添加WebView到视图");
    NSLog(@"在局🔧 [addWebView] self.view.frame: %@", NSStringFromCGRect(self.view.frame));
    NSLog(@"在局🔧 [addWebView] self.view.bounds: %@", NSStringFromCGRect(self.view.bounds));
    
    [self.view addSubview:self.webView];
    NSLog(@"在局🔧 [addWebView] WebView已添加到视图");
    
    if (self.navigationController.viewControllers.count > 1) {
        NSLog(@"在局🔧 [addWebView] 使用导航模式约束（内页）");
        [self.webView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.left.equalTo(self.view);
            make.right.equalTo(self.view);
            make.bottom.equalTo(self.view);
            make.top.equalTo(self.view);
        }];
    } else {
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"NoTabBar"]) {
            NSLog(@"在局🔧 [addWebView] 使用无TabBar约束");
            // 如果没有tabbar，将tabbar的frame设为0
            self.tabBarController.tabBar.frame = CGRectZero;
            [self.webView mas_makeConstraints:^(MASConstraintMaker *make) {
                make.left.equalTo(self.view);
                make.right.equalTo(self.view);
                make.bottom.equalTo(self.view);
                make.top.equalTo(self.view);
            }];
        } else {
            NSLog(@"在局🔧 [addWebView] 使用TabBar模式约束");
            [self.webView mas_makeConstraints:^(MASConstraintMaker *make) {
                make.left.equalTo(self.view);
                make.right.equalTo(self.view);
                if (@available(iOS 11.0, *)) {
                    make.bottom.equalTo(self.view.mas_safeAreaLayoutGuideBottom);
                } else {
                    make.bottom.equalTo(self.view);
                }
                make.top.equalTo(self.view);
            }];
        }
    }
    
    // 强制立即布局，确保WebView获得正确的frame
    NSLog(@"在局🔧 [addWebView] 约束设置完成，强制立即布局");
    [self.view setNeedsLayout];
    [self.view layoutIfNeeded];
    
    // 检查约束是否生效
    NSLog(@"在局🔧 [addWebView] 布局完成后WebView.frame: %@", NSStringFromCGRect(self.webView.frame));
    
    // 确保进度条始终在最上层
    if (self.progressView) {
        [self.view bringSubviewToFront:self.progressView];
        NSLog(@"在局🔧 [addWebView] 将进度条移到最上层");
    }
    
    // 确保活动指示器也在最上层
    if (self.activityIndicatorView) {
        [self.view bringSubviewToFront:self.activityIndicatorView];
    }
    
    if (CGRectEqualToRect(self.webView.frame, CGRectZero)) {
        NSLog(@"在局❌ [addWebView] WebView frame仍然是零，手动设置frame");
        // 如果约束没有生效，手动设置frame
        CGRect viewBounds = self.view.bounds;
        if (CGRectEqualToRect(viewBounds, CGRectZero)) {
            // 如果view的bounds也是0，使用默认尺寸
            viewBounds = CGRectMake(0, 0, [UIScreen mainScreen].bounds.size.width, [UIScreen mainScreen].bounds.size.height - 100);
            NSLog(@"在局⚠️ [addWebView] view.bounds也是零，使用屏幕尺寸: %@", NSStringFromCGRect(viewBounds));
        }
        
        // 为TabBar模式预留底部空间
        if (self.navigationController.viewControllers.count <= 1 && ![[NSUserDefaults standardUserDefaults] boolForKey:@"NoTabBar"]) {
            viewBounds.size.height -= 83; // TabBar高度
        }
        
        self.webView.frame = viewBounds;
        NSLog(@"在局✅ [addWebView] 手动设置WebView frame: %@", NSStringFromCGRect(self.webView.frame));
    } else {
        NSLog(@"在局✅ [addWebView] WebView约束生效，frame正确");
    }
}

- (void)loadWebBridge {
    NSLog(@"在局🚀 开始建立WKWebView JavaScript桥接...");
    
    // 使用成熟的WebViewJavascriptBridge库
    // 在Release版本也启用日志，以确保桥接正常工作
    [WKWebViewJavascriptBridge enableLogging];
    
    // 使用统一的桥接设置方法
    [self setupJavaScriptBridge];
    
    // 注册额外的处理器（如果需要）
    WEAK_SELF;
    
    // 注册用于调试的处理器
    [self.bridge registerHandler:@"debugLog" handler:^(id data, WVJBResponseCallback responseCallback) {
        NSLog(@"在局🔍 [JS Debug] %@", data);
        if (responseCallback) {
            responseCallback(@{@"received": @YES});
        }
    }];
    
    NSLog(@"在局✅ WKWebView JavaScript桥接设置完成");
}



- (void)domainOperate {
    NSLog(@"在局🌐 domainOperate 被调用 - URL: %@", self.pinUrl);
    NSLog(@"在局 🔧 [XZWKWebViewBaseController] 优化domainOperate - 使用异步文件I/O");
    
    // 防止频繁调用（与loadHTMLContent共享时间检查）
    NSDate *now = [NSDate date];
    if (lastLoadTime && [now timeIntervalSinceDate:lastLoadTime] < 2.0) {
        NSLog(@"在局⚠️ domainOperate 调用过于频繁，跳过（间隔: %.2f秒）", [now timeIntervalSinceDate:lastLoadTime]);
        return;
    }
    
    self.isLoading = NO;
    self.isWebViewLoading = NO; // 重置WebView加载标志
    
    // 显示loading指示器
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.activityIndicatorView startAnimating];
    });
    
    // 延迟启动计时器，避免立即执行
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self listenToTimer];
    });
    
    // 在后台队列异步读取HTML文件，避免阻塞主线程
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        NSLog(@"在局 🚀 [XZWKWebViewBaseController] 开始异步读取HTML文件");
        
        NSString *filepath = [[BaseFileManager appH5LocailManifesPath] stringByAppendingPathComponent:@"app.html"];
        NSLog(@"在局📁 读取HTML文件: %@", filepath);
        
        if ([[NSFileManager defaultManager] fileExistsAtPath:filepath]) {
            NSError *error;
            NSString *htmlContent = [NSString stringWithContentsOfURL:[NSURL fileURLWithPath:filepath] encoding:NSUTF8StringEncoding error:&error];
            
            // 回到主线程处理结果
            dispatch_async(dispatch_get_main_queue(), ^{
                if (!error && htmlContent) {
                    NSLog(@"在局✅ HTML文件读取成功，长度: %lu", (unsigned long)htmlContent.length);
                    self.htmlStr = htmlContent;
                    
                    // 检查WebView是否已经创建
                    if (self.webView) {
                        NSLog(@"在局📝 [domainOperate] WebView已存在，直接调用loadHTMLContent");
                        [self loadHTMLContent];
                    } else {
                        NSLog(@"在局📝 [domainOperate] WebView尚未创建，等待viewDidAppear");
                        // WebView还没创建，等待viewDidAppear中创建后会自动调用loadHTMLContent
                    }
                } else {
                    NSLog(@"在局❌ 读取HTML文件失败: %@", error.localizedDescription);
                    self.networkNoteView.hidden = NO;
                }
            });
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                NSLog(@"在局❌ HTML文件不存在: %@", filepath);
                self.networkNoteView.hidden = NO;
            });
        }
    });
}

- (void)loadHTMLContent {
    NSLog(@"在局🚀 [loadHTMLContent] 开始加载 - pinUrl: %@, isTabbarShow: %@", self.pinUrl, self.isTabbarShow ? @"YES" : @"NO");
    
    // 检查WebView是否存在 - 如果不存在，等待viewWillAppear创建
    if (!self.webView) {
        NSLog(@"在局❌ [loadHTMLContent] WebView不存在！等待viewWillAppear创建...");
        // 重置防重复时间，允许WebView创建后重新加载
        lastLoadTime = nil;
        return; // 不在这里创建WebView，等待viewWillAppear
    }
    
    // 防止频繁重新加载（2秒内只允许加载一次） - 但只在WebView存在时检查
    NSDate *now = [NSDate date];
    if (lastLoadTime && [now timeIntervalSinceDate:lastLoadTime] < 2.0) {
        NSLog(@"在局⚠️ [loadHTMLContent] 加载过于频繁，跳过（间隔: %.2f秒）", [now timeIntervalSinceDate:lastLoadTime]);
        return;
    }
    lastLoadTime = now;
    
    // 重置加载标志，准备处理新的页面加载
    self.isWebViewLoading = NO;
    self.isLoading = NO; // 同时重置页面就绪标志
    
    // 立即取消可能存在的计时器，避免干扰
    dispatch_source_t timerToCancel = self.timer;
    if (timerToCancel) {
        self.timer = nil;
        dispatch_source_cancel(timerToCancel);
    }
    
    if (self.htmlStr) {
        // 确保JavaScript桥接已建立
        if (!self.bridge) {
            [self loadWebBridge];
            
            // 直接尝试加载，不再延迟 - 修复tab切换时dispatch_after不执行的问题
            NSLog(@"在局⚡ [loadHTMLContent] 桥接初始化完成，立即加载HTML");
            
            // 添加桥接状态检查
            if (self.bridge) {
                NSLog(@"在局✅ [loadHTMLContent] 桥接验证成功，开始加载");
                [self performHTMLLoading];
            } else {
                NSLog(@"在局❌ [loadHTMLContent] 桥接验证失败，延迟重试");
                // 如果桥接创建失败，使用performSelector延迟重试（可以被取消）
                [self performSelector:@selector(retryHTMLLoading) withObject:nil afterDelay:0.1];
            }
        } else {
            // 桥接已存在，直接加载
            NSLog(@"在局⚡ [loadHTMLContent] 桥接已存在，直接加载");
            [self performHTMLLoading];
        }
    } else {
        NSLog(@"在局❌ [loadHTMLContent] htmlStr为空，无法加载页面");
    }
}

// 重试HTML加载的方法
- (void)retryHTMLLoading {
    NSLog(@"在局🔄 [retryHTMLLoading] 重试HTML加载");
    
    if (_isDisappearing) {
        NSLog(@"在局❌ [retryHTMLLoading] 页面正在消失，取消重试");
        return;
    }
    
    if (self.bridge) {
        NSLog(@"在局✅ [retryHTMLLoading] 桥接现在可用，开始加载");
        [self performHTMLLoading];
    } else {
        NSLog(@"在局❌ [retryHTMLLoading] 桥接仍然不可用，停止重试");
    }
}

// 新增方法：执行实际的HTML加载
- (void)performHTMLLoading {
    NSLog(@"在局🎯 [performHTMLLoading] 开始执行HTML加载 - pinDataStr: %@, pinUrl: %@", 
          self.pinDataStr ? @"有数据" : @"无数据", self.pinUrl);
    
    // 添加WebView健康检查和重建机制
    if (![self checkAndRebuildWebViewIfNeeded]) {
        NSLog(@"在局❌ [performHTMLLoading] WebView健康检查失败，等待重建");
        return;
    }
    
    if (self.pinDataStr && self.pinDataStr.length > 0) {
        // 直接数据模式
        NSLog(@"在局📄 使用直接数据模式加载页面");
        NSLog(@"在局📄 [直接数据模式] pinDataStr长度: %lu", (unsigned long)self.pinDataStr.length);
        
        if (self.pagetitle) {
            [self getnavigationBarTitleText:self.pagetitle];
        }
        
        NSString *allHtmlStr = [self.htmlStr stringByReplacingOccurrencesOfString:@"{{body}}" withString:self.pinDataStr];
        
        if ([self isHaveNativeHeader:self.pinUrl]) {
            allHtmlStr = [allHtmlStr stringByReplacingOccurrencesOfString:@"{{phoneClass}}" withString:isIPhoneXSeries() ? @"iPhoneLiuHai" : @"iPhone"];
        }
        
        NSLog(@"在局🌐 开始加载HTML字符串...");
        
        // 使用manifest目录作为baseURL，确保资源正确加载
        NSString *manifestPath = [BaseFileManager appH5LocailManifesPath];
        NSURL *baseURL = [NSURL fileURLWithPath:manifestPath isDirectory:YES];
        
        NSLog(@"在局📁 [WKWebView-Direct] BaseURL: %@", baseURL);
        
        // 检查是否是首页加载
        if (self.isTabbarShow) {
            NSLog(@"在局🏠 [首页加载] 正在加载TabBar页面内容");
        }
        
        NSLog(@"在局🚀 [直接数据模式] 即将调用loadHTMLString - HTML长度: %lu", (unsigned long)allHtmlStr.length);
        NSLog(@"在局🚀 [直接数据模式] WebView delegate设置: navigationDelegate=%@, UIDelegate=%@", 
              self.webView.navigationDelegate, self.webView.UIDelegate);
        
        // 关键修复：简化dispatch调用，避免Release版本中的嵌套问题
        NSLog(@"在局🔧 [直接数据模式] 准备在主队列中执行loadHTMLString");
        
        // 验证WebView状态
        if (!self.webView) {
            NSLog(@"在局❌ [直接数据模式] WebView为nil！");
            return;
        }
        
        // 检查WebView的navigation delegate状态（但不强制重新设置）
        if (!self.webView.navigationDelegate) {
            NSLog(@"在局❌ [直接数据模式] navigationDelegate丢失！这是严重问题");
            if (self.bridge) {
                NSLog(@"在局🔧 [直接数据模式] Bridge存在但delegate丢失，可能是时序问题");
            } else {
                NSLog(@"在局❌ [直接数据模式] Bridge不存在，无法恢复delegate");
                return;
            }
        } else {
            NSLog(@"在局✅ [直接数据模式] navigationDelegate正常: %@", self.webView.navigationDelegate);
        }
        
        // 确保WebView在window中且有正确frame
        if (!self.webView.superview) {
            NSLog(@"在局❌ [直接数据模式] WebView没有superview！");
            return;
        }
        
        NSLog(@"在局🔧 [直接数据模式] WebView状态验证完成:");
        NSLog(@"在局🔧 [直接数据模式] - frame: %@", NSStringFromCGRect(self.webView.frame));
        NSLog(@"在局🔧 [直接数据模式] - superview: %@", self.webView.superview);
        NSLog(@"在局🔧 [直接数据模式] - navigationDelegate: %@", self.webView.navigationDelegate);
        
        // 停止任何正在进行的加载
        [self.webView stopLoading];
        
        // 直接数据模式也增加详细的dispatch追踪
        NSLog(@"在局🎯 [DISPATCH-DEBUG-DIRECT] 准备提交dispatch_async任务到主队列");
        
        static int directDispatchTaskId = 1000;
        int currentDirectTaskId = ++directDispatchTaskId;
        NSLog(@"在局🎯 [DISPATCH-DEBUG-DIRECT] 创建直接数据模式任务ID: %d", currentDirectTaskId);
        
        dispatch_async(dispatch_get_main_queue(), ^{
            NSLog(@"在局🔥🔥🔥 [DISPATCH-DEBUG-DIRECT] ===== 直接数据模式 dispatch回调开始执行！任务ID: %d =====", currentDirectTaskId);
            
            // 检查self和WebView状态
            if (!self || !self.webView) {
                NSLog(@"在局❌ [DISPATCH-DEBUG-DIRECT] self或WebView已释放！任务ID: %d", currentDirectTaskId);
                return;
            }
            
            NSLog(@"在局🚀 [直接数据模式] 主队列中开始loadHTMLString - 任务ID: %d", currentDirectTaskId);
            
            // 对于第二个Tab，启动加载监控
            if (self.tabBarController && self.tabBarController.selectedIndex > 0) {
                NSLog(@"在局👁️ [直接数据模式] 第二个Tab，启动加载监控");
                [self startWebViewLoadingMonitor];
            }
            
            // 直接使用loadHTMLString:baseURL:方法
            NSLog(@"在局🚀 [直接数据模式] 即将调用loadHTMLString，HTML长度: %lu - 任务ID: %d", (unsigned long)allHtmlStr.length, currentDirectTaskId);
            
            @try {
                [self.webView loadHTMLString:allHtmlStr baseURL:baseURL];
                NSLog(@"在局✅ [DISPATCH-DEBUG-DIRECT] loadHTMLString调用成功完成！任务ID: %d", currentDirectTaskId);
            } @catch (NSException *exception) {
                NSLog(@"在局💥 [DISPATCH-DEBUG-DIRECT] loadHTMLString调用异常！任务ID: %d, 异常: %@", currentDirectTaskId, exception);
            }
            
            NSLog(@"在局🚀 [直接数据模式] loadHTMLString调用完成，等待navigation delegate... - 任务ID: %d", currentDirectTaskId);
            
            // 启动定时器监控页面加载
            [self startPageLoadMonitor];
            
            NSLog(@"在局🔥🔥🔥 [DISPATCH-DEBUG-DIRECT] ===== 直接数据模式 dispatch回调执行完成！任务ID: %d =====", currentDirectTaskId);
        });
        
        NSLog(@"在局🎯 [DISPATCH-DEBUG-DIRECT] 直接数据模式 dispatch_async任务已提交，任务ID: %d", currentDirectTaskId);
        
        // 直接数据模式也增加fallback机制
        NSLog(@"在局🕰️ [FALLBACK-DIRECT] 设置3秒fallback机制以防直接数据模式dispatch未执行");
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (self && self.webView && !self.isWebViewLoading) {
                NSLog(@"在局⚠️ [FALLBACK-DIRECT] 3秒后检查发现WebView仍未开始加载，执行直接数据模式fallback");
                
                @try {
                    [self.webView loadHTMLString:allHtmlStr baseURL:baseURL];
                    NSLog(@"在局✅ [FALLBACK-DIRECT] 直接数据模式 Fallback loadHTMLString调用成功");
                } @catch (NSException *exception) {
                    NSLog(@"在局💥 [FALLBACK-DIRECT] 直接数据模式 Fallback loadHTMLString异常: %@", exception);
                }
            } else {
                NSLog(@"在局✅ [FALLBACK-DIRECT] 3秒检查：直接数据模式WebView已开始加载或self已释放，无需fallback");
            }
        });
    } else {
        // 使用CustomHybridProcessor处理
        NSLog(@"在局🔄 使用CustomHybridProcessor处理页面 - URL: %@", self.pinUrl);
        [CustomHybridProcessor custom_LocialPathByUrlStr:self.pinUrl
                                             templateDic:self.templateDic
                                        componentJsAndCs:self.componentJsAndCs
                                          componentDic:self.componentDic
                                                 success:^(NSString *filePath, NSString *templateStr, NSString *title, BOOL isFileExsit) {
            
            @try {
                NSLog(@"在局🔥 [CustomHybridProcessor] ===== 回调开始执行 =====");
                NSLog(@"在局🔥 [CustomHybridProcessor] 步骤1: 回调参数检查");
                NSLog(@"在局📋 CustomHybridProcessor处理完成 - 文件存在: %@, 标题: %@", isFileExsit ? @"是" : @"否", title);
                NSLog(@"在局📋 templateStr长度: %lu", (unsigned long)templateStr.length);
                NSLog(@"在局📋 filePath: %@", filePath);
                
                NSLog(@"在局🔥 [CustomHybridProcessor] 步骤2: 检查self状态");
                if (!self) {
                    NSLog(@"在局❌ [CustomHybridProcessor] self已经被释放，终止回调执行");
                    return;
                }
                if (self->_isDisappearing) {
                    NSLog(@"在局❌ [CustomHybridProcessor] 页面正在消失，终止回调执行");
                    return;
                }
                if (!self.webView) {
                    NSLog(@"在局❌ [CustomHybridProcessor] WebView不存在，终止回调执行");
                    return;
                }
                
                NSLog(@"在局🔥 [CustomHybridProcessor] 步骤3: 设置导航标题");
                [self getnavigationBarTitleText:title];
                NSLog(@"在局✅ [CustomHybridProcessor] 导航标题设置完成");
                
                NSLog(@"在局🔥 [CustomHybridProcessor] 步骤4: 处理HTML模板");
                if (!self.htmlStr) {
                    NSLog(@"在局❌ [CustomHybridProcessor] htmlStr为空，无法继续");
                    return;
                }
                if (!templateStr) {
                    NSLog(@"在局❌ [CustomHybridProcessor] templateStr为空，使用空字符串");
                    templateStr = @"";
                }
                
                NSString *allHtmlStr = [self.htmlStr stringByReplacingOccurrencesOfString:@"{{body}}" withString:templateStr];
                NSLog(@"在局✅ [CustomHybridProcessor] HTML模板替换完成，长度: %lu", (unsigned long)allHtmlStr.length);
                
                NSLog(@"在局🔥 [CustomHybridProcessor] 步骤5: 处理iPhone X适配");
                if ([self isHaveNativeHeader:self.pinUrl]) {
                    allHtmlStr = [allHtmlStr stringByReplacingOccurrencesOfString:@"{{phoneClass}}" withString:isIPhoneXSeries() ? @"iPhoneLiuHai" : @"iPhone"];
                    NSLog(@"在局✅ [CustomHybridProcessor] iPhone X适配完成");
                }
                
                NSLog(@"在局🔥 [CustomHybridProcessor] 步骤6: HTML内容调试");
                // 关键调试：检查实际的HTML内容
                NSLog(@"在局📄 [HTML-DEBUG] HTML长度: %lu", (unsigned long)allHtmlStr.length);
                NSLog(@"在局📄 [HTML-DEBUG] 包含app.js: %@", [allHtmlStr containsString:@"app.js"] ? @"YES" : @"NO");
                NSLog(@"在局📄 [HTML-DEBUG] 包含webviewbridge.js: %@", [allHtmlStr containsString:@"webviewbridge.js"] ? @"YES" : @"NO");
                
                // 添加调试：检查body内容是否正确替换
                NSRange bodyRange = [allHtmlStr rangeOfString:@"<div id=\"pageWrapper\">"];
                if (bodyRange.location != NSNotFound) {
                    NSRange endRange = [allHtmlStr rangeOfString:@"</div>" options:0 range:NSMakeRange(bodyRange.location, allHtmlStr.length - bodyRange.location)];
                    if (endRange.location != NSNotFound) {
                        NSString *bodyContent = [allHtmlStr substringWithRange:NSMakeRange(bodyRange.location, endRange.location - bodyRange.location + 6)];
                        NSLog(@"在局📄 [HTML-DEBUG] pageWrapper内容长度: %lu", (unsigned long)bodyContent.length);
                        NSLog(@"在局📄 [HTML-DEBUG] pageWrapper是否为空: %@", [bodyContent isEqualToString:@"<div id=\"pageWrapper\"></div>"] ? @"YES" : @"NO");
                    }
                }
                
                NSLog(@"在局🔥 [CustomHybridProcessor] 步骤7: 准备baseURL");
                // 使用manifest目录作为baseURL，确保资源正确加载
                NSString *manifestPath = [BaseFileManager appH5LocailManifesPath];
                NSURL *baseURL = [NSURL fileURLWithPath:manifestPath isDirectory:YES];
                
                NSLog(@"在局📁 [WKWebView-CustomHybrid] BaseURL: %@", baseURL);
                
                // 检查是否是首页加载
                if (self.isTabbarShow) {
                    NSLog(@"在局🏠 [首页加载] 正在加载TabBar页面内容");
                }
                
                NSLog(@"在局🔥 [CustomHybridProcessor] 步骤8: 最终WebView检查");
                if (!self.webView) {
                    NSLog(@"在局❌ [CustomHybridProcessor] 最终检查：WebView已经被释放！");
                    return;
                }
                
                NSLog(@"在局🚀 [CustomHybridProcessor] 步骤9: 即将调用loadHTMLString - HTML长度: %lu", (unsigned long)allHtmlStr.length);
                NSLog(@"在局🚀 [CustomHybridProcessor] WebView delegate设置: navigationDelegate=%@, UIDelegate=%@", 
                      self.webView.navigationDelegate, self.webView.UIDelegate);
                
                NSLog(@"在局🔥 [CustomHybridProcessor] 步骤10: 执行loadHTMLString");
                
                // 关键修复：简化dispatch调用，避免Release版本中的嵌套问题
                NSLog(@"在局🔧 [CustomHybridProcessor] 准备在主队列中执行loadHTMLString");
                
                // 验证WebView状态
                if (!self.webView) {
                    NSLog(@"在局❌ [CustomHybridProcessor] WebView为nil！");
                    return;
                }
                
                // 检查WebView的navigation delegate状态（但不强制重新设置）
                if (!self.webView.navigationDelegate) {
                    NSLog(@"在局❌ [CustomHybridProcessor] navigationDelegate丢失！这是严重问题");
                    if (self.bridge) {
                        NSLog(@"在局🔧 [CustomHybridProcessor] Bridge存在但delegate丢失，可能是时序问题");
                    } else {
                        NSLog(@"在局❌ [CustomHybridProcessor] Bridge不存在，无法恢复delegate");
                        return;
                    }
                } else {
                    NSLog(@"在局✅ [CustomHybridProcessor] navigationDelegate正常: %@", self.webView.navigationDelegate);
                }
                
                // 确保WebView在window中且有正确frame
                if (!self.webView.superview) {
                    NSLog(@"在局❌ [CustomHybridProcessor] WebView没有superview！");
                    return;
                }
                
                NSLog(@"在局🔧 [CustomHybridProcessor] WebView状态验证完成:");
                NSLog(@"在局🔧 [CustomHybridProcessor] - frame: %@", NSStringFromCGRect(self.webView.frame));
                NSLog(@"在局🔧 [CustomHybridProcessor] - superview: %@", self.webView.superview);
                NSLog(@"在局🔧 [CustomHybridProcessor] - navigationDelegate: %@", self.webView.navigationDelegate);
                
                // 停止任何正在进行的加载
                [self.webView stopLoading];
                
                // 关键修复：增加dispatch执行追踪，解决Release版本中断问题
                NSLog(@"在局🎯 [DISPATCH-DEBUG] 准备提交dispatch_async任务到主队列");
                NSLog(@"在局🎯 [DISPATCH-DEBUG] 当前线程: %@", [NSThread currentThread]);
                NSLog(@"在局🎯 [DISPATCH-DEBUG] 是否主线程: %@", [NSThread isMainThread] ? @"YES" : @"NO");
                
                // 检查主队列状态
                if (dispatch_queue_get_label(DISPATCH_CURRENT_QUEUE_LABEL) != NULL) {
                    NSLog(@"在局🎯 [DISPATCH-DEBUG] 当前队列标签: %s", dispatch_queue_get_label(DISPATCH_CURRENT_QUEUE_LABEL));
                }
                
                // 添加任务计数器
                static int dispatchTaskId = 0;
                int currentTaskId = ++dispatchTaskId;
                NSLog(@"在局🎯 [DISPATCH-DEBUG] 创建dispatch任务ID: %d", currentTaskId);
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    NSLog(@"在局🔥🔥🔥 [DISPATCH-DEBUG] ===== dispatch_async回调开始执行！任务ID: %d =====", currentTaskId);
                    NSLog(@"在局🔥 [DISPATCH-DEBUG] 回调执行线程: %@", [NSThread currentThread]);
                    NSLog(@"在局🔥 [DISPATCH-DEBUG] 回调是否主线程: %@", [NSThread isMainThread] ? @"YES" : @"NO");
                    
                    // 检查self状态
                    if (!self) {
                        NSLog(@"在局❌ [DISPATCH-DEBUG] self已释放！任务ID: %d", currentTaskId);
                        return;
                    }
                    
                    // 检查WebView状态
                    if (!self.webView) {
                        NSLog(@"在局❌ [DISPATCH-DEBUG] WebView已释放！任务ID: %d", currentTaskId);
                        return;
                    }
                    
                    NSLog(@"在局🚀 [CustomHybridProcessor] 主队列中开始loadHTMLString - 任务ID: %d", currentTaskId);
                    
                    // 对于第二个Tab，启动加载监控
                    if (self.tabBarController && self.tabBarController.selectedIndex > 0) {
                        NSLog(@"在局👁️ [CustomHybridProcessor] 第二个Tab，启动加载监控");
                        [self startWebViewLoadingMonitor];
                    }
                    
                    // 再次验证关键对象状态
                    NSLog(@"在局🔍 [DISPATCH-DEBUG] 执行前最终检查 - WebView: %@", self.webView);
                    NSLog(@"在局🔍 [DISPATCH-DEBUG] HTML字符串长度: %lu", (unsigned long)allHtmlStr.length);
                    NSLog(@"在局🔍 [DISPATCH-DEBUG] BaseURL: %@", baseURL);
                    
                    // 直接使用loadHTMLString:baseURL:方法
                    NSLog(@"在局🚀 [CustomHybridProcessor] 即将调用loadHTMLString，HTML长度: %lu - 任务ID: %d", (unsigned long)allHtmlStr.length, currentTaskId);
                    
                    @try {
                        [self.webView loadHTMLString:allHtmlStr baseURL:baseURL];
                        NSLog(@"在局✅ [DISPATCH-DEBUG] loadHTMLString调用成功完成！任务ID: %d", currentTaskId);
                    } @catch (NSException *exception) {
                        NSLog(@"在局💥 [DISPATCH-DEBUG] loadHTMLString调用异常！任务ID: %d, 异常: %@", currentTaskId, exception);
                    }
                    
                    NSLog(@"在局🚀 [CustomHybridProcessor] loadHTMLString调用完成，等待navigation delegate... - 任务ID: %d", currentTaskId);
                    
                    // 启动定时器监控页面加载
                    [self startPageLoadMonitor];
                    
                    NSLog(@"在局🔥🔥🔥 [DISPATCH-DEBUG] ===== dispatch_async回调执行完成！任务ID: %d =====", currentTaskId);
                    NSLog(@"在局🔥 [CustomHybridProcessor] ===== 回调执行成功完成 =====");
                });
                
                NSLog(@"在局🎯 [DISPATCH-DEBUG] dispatch_async任务已提交，任务ID: %d", currentTaskId);
                
                // Release版本fallback机制：如果dispatch在短时间内未执行，直接在主线程调用
                NSLog(@"在局🕰️ [FALLBACK] 设置3秒fallback机制以防dispatch未执行");
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    // 检查是否已经成功调用loadHTMLString（通过检查WebView的loading状态）
                    if (self && self.webView && !self.isWebViewLoading) {
                        NSLog(@"在局⚠️ [FALLBACK] 3秒后检查发现WebView仍未开始加载，执行fallback");
                        NSLog(@"在局🆘 [FALLBACK] 直接在主线程调用loadHTMLString作为fallback");
                        
                        @try {
                            [self.webView loadHTMLString:allHtmlStr baseURL:baseURL];
                            NSLog(@"在局✅ [FALLBACK] Fallback loadHTMLString调用成功");
                        } @catch (NSException *exception) {
                            NSLog(@"在局💥 [FALLBACK] Fallback loadHTMLString异常: %@", exception);
                        }
                    } else {
                        NSLog(@"在局✅ [FALLBACK] 3秒检查：WebView已开始加载或self已释放，无需fallback");
                    }
                });
                
                // 延迟测试JavaScript桥接是否正常工作
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    @try {
                        NSLog(@"在局🧪 [桥接测试] 开始测试JavaScript桥接");
                        [self safelyEvaluateJavaScript:@"(function(){if(window.WebViewJavascriptBridge){WebViewJavascriptBridge.callHandler('bridgeTest',{test:'from_js'},function(response){});return 'WebViewJavascriptBridge存在';}else{return 'WebViewJavascriptBridge不存在';}})()" 
                                        completionHandler:^(id result, NSError *error) {
                            if (error) {
                                NSLog(@"在局❌ [桥接测试] JavaScript执行错误: %@", error.localizedDescription);
                            } else {
                                NSLog(@"在局🧪 [桥接测试] JavaScript执行结果: %@", result);
                            }
                        }];
                    } @catch (NSException *bridgeException) {
                        NSLog(@"在局💥 [桥接测试] 桥接测试发生异常: %@", bridgeException.reason);
                    }
                });
                
            } @catch (NSException *exception) {
                NSLog(@"在局💥💥💥 [CustomHybridProcessor] 回调执行发生异常！");
                NSLog(@"在局💥 异常名称: %@", exception.name);
                NSLog(@"在局💥 异常原因: %@", exception.reason);
                NSLog(@"在局💥 异常用户信息: %@", exception.userInfo);
                NSLog(@"在局💥 异常调用栈: %@", exception.callStackSymbols);
                NSLog(@"在局💥💥💥 [CustomHybridProcessor] 异常信息结束");
                
                // 即使发生异常，也要确保UI状态正确
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (self && self.networkNoteView) {
                        self.networkNoteView.hidden = NO;
                    }
                });
            }
        }];
    }
}

#pragma mark - Navigation

- (void)getnavigationBarTitleText:(NSString *)title {
    self.navigationItem.title = title;
}

#pragma mark - Network Monitoring

- (void)listenToTimer {
    if (self.networkNoteView.hidden) {
        // 安全地取消timer，防止野指针
        dispatch_source_t timerToCancel = self.timer;
        if (timerToCancel) {
            self.timer = nil; // 先置空
            dispatch_source_cancel(timerToCancel); // 再取消
        }
        
        dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
        self.timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
        dispatch_source_set_timer(self.timer, dispatch_walltime(NULL, 0), 1.0 * NSEC_PER_SEC, 0);
        timeout = 10; // 增加超时时间到10秒
        
        // 使用实例变量而不是static变量
        
        __weak typeof(self) weakSelf = self;
        dispatch_source_set_event_handler(self.timer, ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            
            // 检查应用状态，如果不是活跃状态则立即取消定时器
            // 直接在后台队列检查，避免同步到主线程
            if (strongSelf->_isDisappearing) {
                NSLog(@"在局🔔 [Timer] 页面正在消失，取消定时器");
                // 安全地取消timer，防止野指针
                dispatch_source_t timerToCancel = strongSelf.timer;
                if (timerToCancel) {
                    strongSelf.timer = nil; // 先置空
                    dispatch_source_cancel(timerToCancel); // 再取消
                }
                return;
            }
            
            if (timeout <= 0) {
                if (strongSelf.isLoading || strongSelf.isWebViewLoading) {
                    NSLog(@"在局🔥 [Timer] 页面已就绪(pageReady: %@, WebView: %@)，取消计时器", 
                          strongSelf.isLoading ? @"YES" : @"NO", 
                          strongSelf.isWebViewLoading ? @"YES" : @"NO");
                    // 安全地取消timer，防止野指针
                    dispatch_source_t timerToCancel = strongSelf.timer;
                    if (timerToCancel) {
                        strongSelf.timer = nil; // 先置空
                        dispatch_source_cancel(timerToCancel); // 再取消
                    }
                    strongSelf->_retryCount = 0; // 重置重试次数
                    strongSelf->_lastFailedUrl = nil;
                } else {
                    // 检查重试次数限制
                    NSString *currentUrl = strongSelf.pinUrl ?: @"";
                    if ([currentUrl isEqualToString:strongSelf->_lastFailedUrl]) {
                        strongSelf->_retryCount++;
                    } else {
                        strongSelf->_retryCount = 1;
                        strongSelf->_lastFailedUrl = currentUrl;
                    }
                    
                    if (strongSelf->_retryCount > 3) {
                        NSLog(@"在局❌ [Timer] 重试次数超过限制(%ld次)，停止重新加载", (long)strongSelf->_retryCount);
                        // 安全地取消timer，防止野指针
                        dispatch_source_t timerToCancel = strongSelf.timer;
                        if (timerToCancel) {
                            strongSelf.timer = nil; // 先置空
                            dispatch_source_cancel(timerToCancel); // 再取消
                        }
                        
                        // 即使加载失败，也要发送showTabviewController通知
                        [[NSNotificationCenter defaultCenter] postNotificationName:@"showTabviewController" object:strongSelf];
                        
                        // 显示错误提示
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [strongSelf.activityIndicatorView stopAnimating];
                            strongSelf.progressView.hidden = YES;
                            strongSelf.networkNoteView.hidden = NO;
                        });
                        return;
                    }
                    
                    NSLog(@"在局⏰ [Timer] 页面加载超时，准备重新加载 (第%ld次重试)", (long)strongSelf->_retryCount);
                    dispatch_async(dispatch_get_main_queue(), ^{
                        // 检查网络状态
                        if (NoReachable) {
                            NSLog(@"在局❌ [Timer] 网络不可达，取消重新加载");
                            return;
                        }
                        [[HTMLCache sharedCache] removeObjectForKey:strongSelf.webViewDomain];
                        [strongSelf domainOperate];
                    });
                }
            } else {
                if (strongSelf.isLoading || strongSelf.isWebViewLoading) {
                    // 安全地取消timer，防止野指针
                    dispatch_source_t timerToCancel = strongSelf.timer;
                    if (timerToCancel) {
                        strongSelf.timer = nil; // 先置空
                        dispatch_source_cancel(timerToCancel); // 再取消
                    }
                    strongSelf->_retryCount = 0; // 重置重试次数
                    strongSelf->_lastFailedUrl = nil;
                } else {
                    timeout--;
                }
            }
        });
        
        dispatch_resume(self.timer);
    }
}

- (void)networkNoteBtClick {
    self.networkNoteView.hidden = YES;
    [self domainOperate];
}

#pragma mark - Page State Management

- (BOOL)isShowingOnKeyWindow {
    // 判断控件是否真正显示在主窗口
    UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
    CGRect newFrame = [keyWindow convertRect:self.view.frame fromView:self.view.superview];
    CGRect winBounds = keyWindow.bounds;
    BOOL intersects = CGRectIntersectsRect(newFrame, winBounds);
    return !self.view.isHidden && self.view.alpha > 0.01 && self.view.window == keyWindow && intersects;
}

- (BOOL)isHaveNativeHeader:(NSString *)url {
    if ([[XZPackageH5 sharedInstance].ulrArray containsObject:url]) {
        return YES;
    }
    return NO;
}

#pragma mark - Status Bar

- (BOOL)prefersStatusBarHidden {
    NSNumber *statusBarStatus = [[NSUserDefaults standardUserDefaults] objectForKey:@"StatusBarStatus"];
    if (statusBarStatus.integerValue == 1) {
        return NO;
    } else {
        return YES;
    }
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    NSString *statusBarTextColor = [[NSUserDefaults standardUserDefaults] objectForKey:@"StatusBarTextColor"];
    if ([statusBarTextColor isEqualToString:@"#000000"] || [statusBarTextColor isEqualToString:@"black"]) {
        return UIStatusBarStyleDefault;
    } else {
        return UIStatusBarStyleLightContent;
    }
}

#pragma mark - JavaScript Bridge

- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message {
    // 保留方法以防其他地方需要使用
    NSLog(@"在局📨 [WKWebView] 收到未处理的JavaScript消息 - name: %@", message.name);
}

- (void)jsCallObjc:(NSDictionary *)jsData jsCallBack:(WVJBResponseCallback)jsCallBack {
    NSDictionary *jsDic = (NSDictionary *)jsData;
    NSString *function = [jsDic objectForKey:@"action"];
    NSDictionary *dataDic = [jsDic objectForKey:@"data"];
    
    NSLog(@"在局🎯 [XZWKWebViewBaseController] jsCallObjc - action: %@", function);
    
    // 父类只处理基础的action
    if ([function isEqualToString:@"pageReady"]) {
        NSLog(@"在局✅ [pageReady] 页面就绪，开始处理");
        self.isLoading = YES;
        
        // 立即取消计时器，防止重复调用domainOperate
        dispatch_source_t timerToCancel = self.timer;
        if (timerToCancel) {
            self.timer = nil;
            dispatch_source_cancel(timerToCancel);
        }
        
        // 确保所有loading指示器都被隐藏
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.activityIndicatorView stopAnimating];
            if (!self.progressView.hidden) {
                [UIView animateWithDuration:0.3 animations:^{
                    self.progressView.alpha = 0.0;
                } completion:^(BOOL finished) {
                    self.progressView.hidden = YES;
                    self.progressView.alpha = 1.0;
                    self.progressView.progress = 0.0;
                }];
            }
        });
        
        // 处理下拉刷新
        @try {
            if (self.webView && self.webView.scrollView) {
                UIScrollView *scrollView = self.webView.scrollView;
                
                if ([scrollView respondsToSelector:@selector(mj_header)]) {
                    id mj_header = [scrollView valueForKey:@"mj_header"];
                    if (mj_header) {
                        NSNumber *isRefreshing = [mj_header valueForKey:@"isRefreshing"];
                        if (isRefreshing && [isRefreshing boolValue]) {
                            [mj_header performSelector:@selector(endRefreshing) withObject:nil];
                        }
                    }
                }
            }
        } @catch (NSException *exception) {
            NSLog(@"在局处理下拉刷新时发生异常: %@", exception.reason);
        }
        
        // 通知页面显示完成 - 只在网络正常时移除LoadingView
        AppDelegate *appDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
        if (!appDelegate.networkRestricted) {
            NSLog(@"在局 🎯 [XZTabBarController] 网络正常，发送showTabviewController通知");
            [[NSNotificationCenter defaultCenter] postNotificationName:@"showTabviewController" object:self];
        } else {
            NSLog(@"在局 ⚠️ [XZTabBarController] 网络受限，不移除LoadingView");
        }
        
        // 调用页面显示的JS事件 - 使用可取消的操作
        if (self.isExist && !_isDisappearing) {
            __weak typeof(self) weakSelf = self;
            NSBlockOperation *pageShowOperation = [NSBlockOperation blockOperationWithBlock:^{
                __strong typeof(weakSelf) strongSelf = weakSelf;
                if (!strongSelf) {
                    return;
                }
                
                if (strongSelf->_isDisappearing) {
                    return;
                }
                
                // 检查应用状态
                UIApplicationState state = [[UIApplication sharedApplication] applicationState];
                if (state != UIApplicationStateActive) {
                    NSLog(@"在局[XZWKWebView] 应用不在前台，跳过pageShow调用");
                    return;
                }
                
                // 使用可取消的定时器替代dispatch_after
                NSTimer *pageShowTimer = [NSTimer scheduledTimerWithTimeInterval:0.1 repeats:NO block:^(NSTimer * _Nonnull timer) {
                    if (!strongSelf) {
                        return;
                    }
                    
                    if (strongSelf->_isDisappearing) {
                        return;
                    }
                    
                    // 再次检查应用状态
                    UIApplicationState currentState = [[UIApplication sharedApplication] applicationState];
                    if (currentState != UIApplicationStateActive) {
                        NSLog(@"在局[XZWKWebView] 定时器执行时应用不在前台，跳过pageShow");
                        return;
                    }
                    
                    NSDictionary *callJsDic = [CustomHybridProcessor custom_objcCallJsWithFn:@"pageShow" data:nil];
                    [strongSelf objcCallJs:callJsDic];
                }];
                
                // 添加到待执行列表以便清理
                [strongSelf->_pendingJavaScriptOperations addObject:pageShowTimer];
            }];
            
            [self.jsOperationQueue addOperation:pageShowOperation];
        }
        
        // 设置页面已存在标志
        self.isExist = YES;
        
        // 确保WebView可交互
        dispatch_async(dispatch_get_main_queue(), ^{
            // 确保WebView在最前面并且可以交互
            if (self.webView) {
                self.webView.userInteractionEnabled = YES;
                self.webView.alpha = 1.0;
                self.webView.hidden = NO;
                [self.view bringSubviewToFront:self.webView];
                
                // 如果有scrollView，确保它也可以交互
                if ([self.webView isKindOfClass:[WKWebView class]]) {
                    WKWebView *wkWebView = (WKWebView *)self.webView;
                    wkWebView.scrollView.scrollEnabled = YES;
                    wkWebView.scrollView.userInteractionEnabled = YES;
                }
                
                NSLog(@"在局✅ [pageReady] WebView交互已启用，frame: %@", NSStringFromCGRect(self.webView.frame));
                
                // 尝试强制刷新页面内容
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [self safelyEvaluateJavaScript:@"(function(){"
                        "try {"
                            "// 强制重新渲染页面"
                            "document.body.style.display = 'none';"
                            "document.body.offsetHeight;" // 强制重排
                            "document.body.style.display = 'block';"
                            "// 检查并触发任何可能的页面初始化函数"
                            "if (typeof window.pageInit === 'function') { window.pageInit(); }"
                            "if (typeof window.initPage === 'function') { window.initPage(); }"
                            "if (typeof app !== 'undefined' && typeof app.init === 'function') { app.init(); }"
                            "// 触发resize事件"
                            "window.dispatchEvent(new Event('resize'));"
                            "return '页面刷新完成';"
                        "} catch(e) {"
                            "return '刷新失败: ' + e.message;"
                        "}"
                    "})()" completionHandler:^(id result, NSError *error) {
                        NSLog(@"在局🔄 [pageReady] 页面强制刷新结果: %@", result ?: @"失败");
                    }];
                });
            }
        });
        
        // 返回成功响应给前端
        if (jsCallBack) {
            jsCallBack(@{
                @"success": @"true",
                @"data": @{},
                @"errorMessage": @"",
                @"code": @0
            });
        }
    } else {
        // 其他所有action交给子类处理
        NSLog(@"在局🔄 [XZWKWebViewBaseController] 将action '%@' 传递给子类处理", function);
        // 默认返回未实现，让子类覆盖
        if (jsCallBack) {
            jsCallBack(@{
                @"success": @"false",
                @"data": @{},
                @"errorMessage": [NSString stringWithFormat:@"Action '%@' not implemented in base class", function],
                @"code": @(-1)
            });
        }
    }
}

// 安全执行JavaScript的辅助方法
- (void)safelyEvaluateJavaScript:(NSString *)javaScriptString completionHandler:(void (^ _Nullable)(id _Nullable, NSError * _Nullable))completionHandler {
    // 检查页面是否正在消失
    if (_isDisappearing) {
        NSLog(@"在局[XZWKWebView] 页面正在消失，取消JavaScript执行");
        if (completionHandler) {
            NSError *error = [NSError errorWithDomain:@"XZWebView" code:-5 userInfo:@{NSLocalizedDescriptionKey: @"页面正在消失"}];
            completionHandler(nil, error);
        }
        return;
    }
    
    // 检查WebView状态
    if (!self.webView) {
        if (completionHandler) {
            NSError *error = [NSError errorWithDomain:@"XZWebView" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"WebView不存在"}];
            completionHandler(nil, error);
        }
        return;
    }
    
    // 检查应用状态 - 确保在主线程访问UIApplication
    __block UIApplicationState state;
    if ([NSThread isMainThread]) {
        state = [[UIApplication sharedApplication] applicationState];
    } else {
        dispatch_sync(dispatch_get_main_queue(), ^{
            state = [[UIApplication sharedApplication] applicationState];
        });
    }
    
    // 特殊处理：某些关键JavaScript（如桥接初始化）需要在非活跃状态下也能执行
    BOOL isEssentialScript = [javaScriptString containsString:@"WebViewJavascriptBridge"] ||
                           [javaScriptString containsString:@"wx.app"] ||
                           [javaScriptString containsString:@"bridgeTest"] ||
                           [javaScriptString containsString:@"typeof app"];
    
    if (state != UIApplicationStateActive && !isEssentialScript) {
        NSLog(@"在局[XZWKWebView] 应用不在前台，取消非关键JavaScript执行");
        if (completionHandler) {
            NSError *error = [NSError errorWithDomain:@"XZWebView" code:-2 userInfo:@{NSLocalizedDescriptionKey: @"应用不在前台"}];
            completionHandler(nil, error);
        }
        return;
    } else if (state != UIApplicationStateActive && isEssentialScript) {
        NSLog(@"在局[XZWKWebView] 应用不在前台，但允许执行关键JavaScript: %.50@...", javaScriptString);
    }
    
    // 使用weak引用避免在回调时崩溃
    __weak typeof(self) weakSelf = self;
    
    // 创建JavaScript操作
    NSBlockOperation *jsOperation = [NSBlockOperation blockOperationWithBlock:^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completionHandler) {
                    NSError *error = [NSError errorWithDomain:@"XZWebView" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"对象已释放"}];
                    completionHandler(nil, error);
                }
            });
            return;
        }
        
        if (strongSelf->_isDisappearing || !strongSelf.webView) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completionHandler) {
                    NSError *error = [NSError errorWithDomain:@"XZWebView" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"操作已取消"}];
                    completionHandler(nil, error);
                }
            });
            return;
        }
        
        // 再次检查应用状态 - 确保在主线程访问UIApplication
        __block UIApplicationState bgState;
        if ([NSThread isMainThread]) {
            bgState = [[UIApplication sharedApplication] applicationState];
        } else {
            dispatch_sync(dispatch_get_main_queue(), ^{
                bgState = [[UIApplication sharedApplication] applicationState];
            });
        }
        // 同样的关键脚本检查
        BOOL isEssentialInBlock = [javaScriptString containsString:@"WebViewJavascriptBridge"] ||
                                 [javaScriptString containsString:@"wx.app"] ||
                                 [javaScriptString containsString:@"bridgeTest"] ||
                                 [javaScriptString containsString:@"typeof app"];
        
        if (bgState != UIApplicationStateActive && !isEssentialInBlock) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completionHandler) {
                    NSError *error = [NSError errorWithDomain:@"XZWebView" code:-2 userInfo:@{NSLocalizedDescriptionKey: @"应用不在前台"}];
                    completionHandler(nil, error);
                }
            });
            return;
        }
        
        // 回到主线程执行JavaScript
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!strongSelf) {
                if (completionHandler) {
                    NSError *error = [NSError errorWithDomain:@"XZWebView" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"对象已释放"}];
                    completionHandler(nil, error);
                }
                return;
            }
            
            if (strongSelf->_isDisappearing || !strongSelf.webView) {
                if (completionHandler) {
                    NSError *error = [NSError errorWithDomain:@"XZWebView" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"WebView已释放"}];
                    completionHandler(nil, error);
                }
                return;
            }
            
            // 设置超时保护
            __block BOOL hasCompleted = NO;
            NSTimer *timeoutTimer = [NSTimer scheduledTimerWithTimeInterval:5.0 repeats:NO block:^(NSTimer * _Nonnull timer) {
                if (!hasCompleted && completionHandler) {
                    hasCompleted = YES;
                    NSError *timeoutError = [NSError errorWithDomain:@"XZWebView" code:-4 userInfo:@{NSLocalizedDescriptionKey: @"JavaScript执行超时"}];
                    completionHandler(nil, timeoutError);
                }
            }];
            
            // 添加到待执行列表
            [strongSelf->_pendingJavaScriptOperations addObject:timeoutTimer];
            
            // 执行JavaScript
            [strongSelf.webView evaluateJavaScript:javaScriptString completionHandler:^(id result, NSError *error) {
                if (hasCompleted) {
                    return; // 已经超时，忽略结果
                }
                hasCompleted = YES;
                
                // 取消超时定时器
                [timeoutTimer invalidate];
                [strongSelf->_pendingJavaScriptOperations removeObject:timeoutTimer];
                
                if (completionHandler) {
                    // 检查在回调执行时的状态
                    if (!strongSelf) {
                        NSError *stateError = [NSError errorWithDomain:@"XZWebView" code:-5 userInfo:@{NSLocalizedDescriptionKey: @"对象已释放"}];
                        completionHandler(nil, stateError);
                        return;
                    }
                    
                    if (strongSelf->_isDisappearing) {
                        NSError *stateError = [NSError errorWithDomain:@"XZWebView" code:-5 userInfo:@{NSLocalizedDescriptionKey: @"页面已消失"}];
                        completionHandler(nil, stateError);
                        return;
                    }
                    
                    __block UIApplicationState currentState;
                    if ([NSThread isMainThread]) {
                        currentState = [[UIApplication sharedApplication] applicationState];
                    } else {
                        dispatch_sync(dispatch_get_main_queue(), ^{
                            currentState = [[UIApplication sharedApplication] applicationState];
                        });
                    }
                    if (currentState != UIApplicationStateActive) {
                        NSLog(@"在局[XZWKWebView] 回调执行时应用已不在前台");
                        NSError *stateError = [NSError errorWithDomain:@"XZWebView" code:-3 userInfo:@{NSLocalizedDescriptionKey: @"回调执行时应用不在前台"}];
                        completionHandler(nil, stateError);
                        return;
                    }
                    completionHandler(result, error);
                }
            }];
        });
    }];
    
    // 添加到操作队列
    [self.jsOperationQueue addOperation:jsOperation];
}

// 根据资料建议改进的objcCallJs方法
- (void)objcCallJs:(NSDictionary *)dic {
    if (!dic) {
        return;
    }
    
    // 检查应用状态，避免在后台执行 - 确保在主线程访问UIApplication
    __block UIApplicationState state;
    if ([NSThread isMainThread]) {
        state = [[UIApplication sharedApplication] applicationState];
    } else {
        dispatch_sync(dispatch_get_main_queue(), ^{
            state = [[UIApplication sharedApplication] applicationState];
        });
    }
    // 某些关键的objcCallJs操作需要在非活跃状态下也能执行
    NSString *action = dic[@"action"];
    id data = dic[@"data"];
    
    BOOL isEssentialAction = [action isEqualToString:@"bridgeInit"] ||
                           [action isEqualToString:@"pageReady"] ||
                           [action isEqualToString:@"checkBridge"];
    
    if (state != UIApplicationStateActive && !isEssentialAction) {
        NSLog(@"在局[XZWKWebView] 应用不在前台，跳过非关键objcCallJs: %@", action);
        return;
    } else if (state != UIApplicationStateActive && isEssentialAction) {
        NSLog(@"在局[XZWKWebView] 应用不在前台，但允许执行关键objcCallJs: %@", action);
    }
    
    // 确保在主线程执行
    dispatch_async(dispatch_get_main_queue(), ^{
        // 再次检查应用状态 - 已在主线程中
        UIApplicationState currentState = [[UIApplication sharedApplication] applicationState];
        if (currentState != UIApplicationStateActive && !isEssentialAction) {
            NSLog(@"在局[XZWKWebView] 主线程检查：应用不在前台，取消非关键JavaScript调用");
            return;
        }
        
        // 检查WebView和Bridge状态
        if (!self.webView || !self.bridge) {
            NSLog(@"在局[XZWKWebView] WebView或Bridge不存在，取消JavaScript调用");
            return;
        }
        
        // 使用WebViewJavascriptBridge调用JavaScript
        [self.bridge callHandler:@"xzBridge" data:dic responseCallback:^(id responseData) {
            // 静默处理响应
        }];
    });
}

- (void)handleJavaScriptCall:(NSDictionary *)data completion:(XZWebViewJSCallbackBlock)completion {
    // 兼容性方法，转发给jsCallObjc
    [self jsCallObjc:data jsCallBack:^(id responseData) {
        if (completion) {
            completion(responseData);
        }
    }];
}

- (void)callJavaScript:(NSString *)script completion:(XZWebViewJSCallbackBlock)completion {
    // 确保在主线程执行并添加完整错误处理
    dispatch_async(dispatch_get_main_queue(), ^{
        // 检查WebView状态
        if (!self.webView) {
            if (completion) {
                completion(nil);
            }
            return;
        }
        
        // 检查脚本有效性
        if (!script || script.length == 0) {
            if (completion) {
                completion(nil);
            }
            return;
        }
        
        // 检查应用状态，如果不在前台则不执行JavaScript - 确保在主线程访问UIApplication
        __block UIApplicationState state;
        if ([NSThread isMainThread]) {
            state = [[UIApplication sharedApplication] applicationState];
        } else {
            dispatch_sync(dispatch_get_main_queue(), ^{
                state = [[UIApplication sharedApplication] applicationState];
            });
        }
        if (state != UIApplicationStateActive) {
            NSLog(@"在局[XZWKWebView] 应用不在前台，跳过JavaScript执行: %@", script);
            if (completion) {
                completion(nil);
            }
            return;
        }
        
        // 使用安全的JavaScript执行方法
        [self safelyEvaluateJavaScript:script completionHandler:^(id result, NSError *error) {
            if (completion) {
                completion(error ? nil : result);
            }
        }];
    });
}

#pragma mark - Network Request

- (void)rpcRequestWithJsDic:(NSDictionary *)dataDic completion:(void(^)(id result))completion {
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        NSString *dataJsonString = @"";
        if ([dataDic isKindOfClass:[NSDictionary class]]) {
            NSData *data = [NSJSONSerialization dataWithJSONObject:dataDic options:NSJSONWritingPrettyPrinted error:nil];
            dataJsonString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        }
        AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
        manager.responseSerializer = [AFJSONResponseSerializer serializer];
        manager.requestSerializer = [AFJSONRequestSerializer serializer];
            
        if(ISIPAD) {
            [manager.requestSerializer setValue:@"iospad" forHTTPHeaderField:@"from"];
        } else {
            [manager.requestSerializer setValue:@"ios" forHTTPHeaderField:@"from"];
        }
        manager.requestSerializer.timeoutInterval = 45;
        manager.responseSerializer.acceptableContentTypes = [NSSet setWithObjects:@"application/json", @"text/plain", @"text/javascript", @"text/json", @"text/html", nil];
        [manager.requestSerializer setValue:[[NSUserDefaults standardUserDefaults] objectForKey:@"User_Token_String"] forHTTPHeaderField:@"AUTHORIZATION"];
        NSDictionary *header = [dataDic objectForKey:@"header"];
        for (NSString *key in [header allKeys]) {
            [manager.requestSerializer setValue:[header objectForKey:key] forHTTPHeaderField:key];
        }
        
        NSString *requestUrl = [CustomHybridProcessor custom_getRequestLinkUrl:[dataDic objectForKey:@"url"]];
        
        [manager POST:requestUrl parameters:[dataDic objectForKey:@"data"] headers:nil progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
            if (completion) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    // 构造JavaScript期望的响应格式
                    NSDictionary *serverResponse = responseObject;
                    
                    // 检查服务器响应的成功状态
                    BOOL isSuccess = NO;
                    NSNumber *codeValue = [serverResponse objectForKey:@"code"];
                    if (codeValue && [codeValue intValue] == 0) {
                        isSuccess = YES;
                    }
                    
                    // 构造JavaScript期望的响应格式
                    NSDictionary *jsResponse = @{
                        @"success": isSuccess ? @"true" : @"false",
                        @"data": @{
                            @"code": isSuccess ? @"0" : [NSString stringWithFormat:@"%@", codeValue ?: @(-1)],
                            @"data": [serverResponse objectForKey:@"data"] ?: @{},
                            @"errorMessage": [serverResponse objectForKey:@"errorMessage"] ?: @""
                        },
                        @"errorMessage": [serverResponse objectForKey:@"errorMessage"] ?: @"",
                        @"code": codeValue ?: @(-1)
                    };
                    
                    completion(jsResponse);
                });
            }
        } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
            if (completion) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    // 失败时也使用JavaScript期望的格式
                    NSDictionary *errorResponse = @{
                        @"success": @"false",
                        @"data": @{
                            @"code": @"-1",
                            @"data": @{},
                            @"errorMessage": error.localizedDescription ?: @"网络请求失败"
                        },
                        @"errorMessage": error.localizedDescription ?: @"网络请求失败",
                        @"code": @(-1)
                    };
                    completion(errorResponse);
                });
            }
        }];
    });
}

#pragma mark - Payment

- (void)payRequest:(NSDictionary *)payDic {
    // 具体支付过程在子类中实现
}

#pragma mark - Utility Methods

- (NSString *)jsonStringFromObject:(id)object {
    if (!object) return @"{}";
    
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:object
                                                       options:NSJSONWritingPrettyPrinted
                                                         error:&error];
    if (error) {
        NSLog(@"在局JSON序列化失败: %@", error.localizedDescription);
        return @"{}";
    }
    
    return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
}

#pragma mark - Compatibility Properties

- (NSDictionary *)ComponentJsAndCs {
    if (!_componentJsAndCs) {
        _componentJsAndCs = [NSDictionary dictionary];
    }
    return _componentJsAndCs;
}

- (NSDictionary *)ComponentDic {
    if (!_componentDic) {
        _componentDic = [NSDictionary dictionary];
    }
    return _componentDic;
}

- (NSDictionary *)templateDic {
    if (!_templateDic) {
        _templateDic = [NSDictionary dictionary];
    }
    return _templateDic;
}

- (void)titleLableTapped:(UIGestureRecognizer *)gesture {
    [self.webView.scrollView scrollRectToVisible:CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.height) animated:YES];
}

#pragma mark - JavaScript Bridge Initialization

- (void)performJavaScriptBridgeInitialization {
    NSLog(@"在局🔥 [JavaScript桥接初始化] 开始执行桥接初始化");
    
    // 先检查桥接是否存在
    if (!self.bridge) {
        NSLog(@"在局⚠️ [JavaScript桥接初始化] 桥接对象不存在，尝试重新创建");
        [self setupJavaScriptBridge];
        
        // 如果仍然不存在，延迟重试
        if (!self.bridge) {
            NSLog(@"在局❌ [JavaScript桥接初始化] 桥接创建失败，1秒后重试");
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self performJavaScriptBridgeInitialization];
            });
            return;
        }
    }
    
    [self safelyEvaluateJavaScript:@"(function(){"
        "var result = {};"
        ""
        "// 检查各种JavaScript对象的存在性"
        "result.bridgeExists = typeof WebViewJavascriptBridge !== 'undefined';"
        "result.appExists = typeof app !== 'undefined';"
        "result.pageReadyExists = typeof pageReady !== 'undefined';"
        "result.pageReadyCalled = window._pageReadyCalled === true;"
        "result.checkTime = new Date().getTime();"
        ""
        "// 对于非首页标签，可能需要重新初始化JavaScript环境"
        "if (!result.appExists || !result.bridgeExists) {"
        "    // 触发JavaScript环境重新初始化"
        "    if (typeof initJavaScriptEnvironment === 'function') {"
        "        initJavaScriptEnvironment();"
        "        result.reinit = true;"
        "    }"
        "}"
        ""
        "// 确保pageReady被调用"
        "if (!window._pageReadyCalled) {"
        "    window._pageReadyCalled = true;"
        ""
        "    // 尝试多种方式触发pageReady"
        "    if (window.WebViewJavascriptBridge && window.WebViewJavascriptBridge.callHandler) {"
        "        try {"
        "            window.WebViewJavascriptBridge.callHandler('pageReady', {"
        "                manual: true,"
        "                source: 'performJavaScriptBridgeInitialization',"
        "                timestamp: new Date().getTime()"
        "            }, function(response) {"
        "                // 回调处理"
        "            });"
        "            result.success = true;"
        "            result.method = 'callHandler';"
        "        } catch(e) {"
        "            result.error = e.message;"
        "        }"
        "    } else if (typeof pageReady === 'function') {"
        "        // 备用方案：直接调用pageReady函数"
        "        try {"
        "            pageReady();"
        "            result.success = true;"
        "            result.method = 'direct';"
        "        } catch(e) {"
        "            result.error = e.message;"
        "        }"
        "    } else {"
        "        result.error = 'environment_not_ready';"
        ""
        "        // 最后的备用方案：模拟pageReady事件"
        "        var event = new CustomEvent('pageReady', {detail: {manual: true}});"
        "        window.dispatchEvent(event);"
        "        result.fallback = 'custom_event';"
        "    }"
        "} else {"
        "    result.skipped = true;"
        "}"
        ""
        "return JSON.stringify(result);"
    "})()" completionHandler:^(id result, NSError *error) {
        if (result && !error) {
            NSLog(@"在局✅ [JavaScript桥接初始化] 执行结果: %@", result);
            
            // 解析结果，如果初始化失败，可能需要重试
            NSError *jsonError;
            NSDictionary *resultDict = [NSJSONSerialization JSONObjectWithData:[result dataUsingEncoding:NSUTF8StringEncoding] options:0 error:&jsonError];
            
            if (!jsonError && [resultDict[@"error"] isEqualToString:@"environment_not_ready"]) {
                NSLog(@"在局⚠️ [JavaScript桥接初始化] 环境未就绪，将在1秒后重试");
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [self performJavaScriptBridgeInitialization];
                });
            }
        } else {
            NSLog(@"在局❌ [JavaScript桥接初始化] 执行失败: %@", error ? error.localizedDescription : @"未知错误");
        }
    }];
}

#pragma mark - WKNavigationDelegate

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    NSLog(@"在局🎉🎉🎉 ===== didFinishNavigation 被调用了！=====");
    NSLog(@"在局✅ WKWebView页面加载完成 - URL: %@", webView.URL.absoluteString);
    NSLog(@"在局✅ WebView: %@", webView);
    NSLog(@"在局✅ Navigation: %@", navigation);
    NSLog(@"在局✅ 当前时间: %@", [NSDate date]);
    
    // 取消页面加载监控器
    if (self.healthCheckTimer) {
        NSLog(@"在局✅ [页面监控] 页面加载成功，取消监控器");
        [self.healthCheckTimer invalidate];
        self.healthCheckTimer = nil;
    }
    
    // 隐藏loading指示器
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.activityIndicatorView stopAnimating];
    });
    
    // 添加白屏检测机制
    NSLog(@"在局 🔧 [XZWKWebViewBaseController] 添加WebView白屏检测");
    [self scheduleJavaScriptTask:^{
        [self detectBlankWebView];
    } afterDelay:1.0];
    
    // 检查是否为非首页标签
    BOOL isNonFirstTab = self.tabBarController && self.tabBarController.selectedIndex > 0;
    
    if (isNonFirstTab) {
        NSLog(@"在局🔥 [非首页标签修复] 检测到非首页标签(index: %ld)，需要特殊处理JavaScript桥接", (long)self.tabBarController.selectedIndex);
        
        // 非首页标签需要延迟处理，确保JavaScript环境完全初始化
        [self scheduleJavaScriptTask:^{
            [self performJavaScriptBridgeInitialization];
        } afterDelay:0.5];
    } else {
        // 首页标签立即触发
        NSLog(@"在局🔥 [didFinishNavigation] 首页标签，立即触发pageReady");
        [self performJavaScriptBridgeInitialization];
    }
    
    if (!self.isWebViewLoading) {
        // 处理loading视图
        // 先在keyWindow中查找，再在主窗口中查找LoadingView
        UIView *loadingView = [[UIApplication sharedApplication].keyWindow viewWithTag:2001];
        if (!loadingView) {
            UIWindow *mainWindow = [UIApplication sharedApplication].delegate.window;
            loadingView = [mainWindow viewWithTag:2001];
        }
        
        if (loadingView && [self isShowingOnKeyWindow]) {
            if (![[NSUserDefaults standardUserDefaults] boolForKey:@"isFirst"]) {
                [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"isFirst"];
            } else {
                // 使用找到的loadingView的父视图
                UIView *parentView = loadingView.superview;
                [parentView bringSubviewToFront:loadingView];
            }
            
            [[NSNotificationCenter defaultCenter] postNotificationName:@"showTabviewController" object:self];
        }
        
        // 使用CSS注入方式禁用选择和长按，避免JavaScript执行
        WKUserContentController *userContentController = self.webView.configuration.userContentController;
        NSString *cssString = @"body { -webkit-user-select: none !important; -webkit-touch-callout: none !important; }";
        NSString *jsString = [NSString stringWithFormat:@"var style = document.createElement('style'); style.textContent = '%@'; document.head.appendChild(style);", cssString];
        WKUserScript *script = [[WKUserScript alloc] initWithSource:jsString injectionTime:WKUserScriptInjectionTimeAtDocumentEnd forMainFrameOnly:YES];
        [userContentController addUserScript:script];
        
        // JavaScript调试已移除
        
        // 设置加载完成标志
        self.isWebViewLoading = YES;
        NSLog(@"在局✅ 页面加载处理完成，设置 isWebViewLoading = YES");
        
        // 处理待执行的JavaScript任务
        [self processPendingJavaScriptTasks];
        
    } else {
        NSLog(@"在局⚠️ 页面加载完成事件已经处理过，跳过重复处理");
    }
}

- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    NSLog(@"在局🔥🔥🔥 ===== didFailNavigation 被调用了！=====");
    NSLog(@"在局❌ WebView加载失败: %@", error.localizedDescription);
    NSLog(@"在局❌ 错误码: %ld, 域: %@", (long)error.code, error.domain);
    NSLog(@"在局❌ URL: %@", webView.URL);
    NSLog(@"在局❌ WebView: %@", webView);
    NSLog(@"在局❌ Navigation: %@", navigation);
    NSLog(@"在局❌ 完整错误信息: %@", error);
    
    // 隐藏loading指示器
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.activityIndicatorView stopAnimating];
        self.progressView.hidden = YES;
        self.progressView.progress = 0.0;
    });
    
    self.networkNoteView.hidden = NO;
}

- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    NSLog(@"在局💥💥💥 ===== didFailProvisionalNavigation 被调用了！=====");
    NSLog(@"在局❌ WebView预加载失败: %@", error.localizedDescription);
    NSLog(@"在局❌ 错误码: %ld, 域: %@", (long)error.code, error.domain);
    NSLog(@"在局❌ URL: %@", webView.URL);
    NSLog(@"在局❌ WebView: %@", webView);
    NSLog(@"在局❌ Navigation: %@", navigation);
    NSLog(@"在局❌ 完整错误信息: %@", error);
    
    // 隐藏loading指示器
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.activityIndicatorView stopAnimating];
        self.progressView.hidden = YES;
        self.progressView.progress = 0.0;
    });
    
    self.networkNoteView.hidden = NO;
}

- (void)webView:(WKWebView *)webView didCommitNavigation:(WKNavigation *)navigation {
    NSLog(@"在局📋📋📋 ===== didCommitNavigation 被调用了！=====");
    NSLog(@"在局📄 WebView开始加载内容: %@", webView.URL);
    NSLog(@"在局📄 WebView: %@", webView);
    NSLog(@"在局📄 Navigation: %@", navigation);
}

- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(WKNavigation *)navigation {
    NSLog(@"在局🚀🚀🚀 ===== didStartProvisionalNavigation 被调用了！=====");
    NSLog(@"在局📄 WebView开始导航: %@", webView.URL);
    NSLog(@"在局📄 WebView: %@", webView);
    NSLog(@"在局📄 Navigation: %@", navigation);
    NSLog(@"在局📄 当前时间: %@", [NSDate date]);
    
    // 取消加载监控定时器（navigation delegate已触发）
    if (self.healthCheckTimer) {
        NSLog(@"在局✅ [加载监控] Navigation开始，取消健康检查定时器");
        [self.healthCheckTimer invalidate];
        self.healthCheckTimer = nil;
    }
    
    // 显示loading指示器
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.activityIndicatorView startAnimating];
        self.progressView.hidden = NO;
        self.progressView.progress = 0.1; // 设置初始进度，让用户知道开始加载
        
        // 确保进度条在最上层
        [self.view bringSubviewToFront:self.progressView];
        [self.view bringSubviewToFront:self.activityIndicatorView];
        
        NSLog(@"在局📊 [didStartProvisionalNavigation] 显示进度条");
    });
}

- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    NSURL *url = navigationAction.request.URL;
    NSString *scheme = url.scheme.lowercaseString;
    
    // 关键：允许WebViewJavascriptBridge的wvjbscheme://连接
    if ([scheme isEqualToString:@"wvjbscheme"]) {
        NSLog(@"在局🔗 [WKWebView] 检测到WebViewJavascriptBridge连接: %@", url.absoluteString);
        decisionHandler(WKNavigationActionPolicyAllow);
        return;
    }
    
    // 处理电话客服按钮
    if ([scheme isEqualToString:@"tel"]) {
        NSLog(@"在局📞 [WKWebView] 检测到电话链接: %@", url.absoluteString);
        // 在iOS 10.0以上使用新的API
        if (@available(iOS 10.0, *)) {
            [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:^(BOOL success) {
                if (success) {
                    NSLog(@"在局✅ [WKWebView] 电话拨打成功");
                } else {
                    NSLog(@"在局❌ [WKWebView] 电话拨打失败");
                }
            }];
        } else {
            // iOS 10.0以下使用旧API
            [[UIApplication sharedApplication] openURL:url];
        }
        decisionHandler(WKNavigationActionPolicyCancel);
        return;
    }
    
    // 允许file://和http/https协议
    if ([scheme isEqualToString:@"file"] || [scheme isEqualToString:@"http"] || [scheme isEqualToString:@"https"]) {
        decisionHandler(WKNavigationActionPolicyAllow);
        return;
    }
    
    NSLog(@"在局🚫 [WKWebView] 阻止未知URL scheme: %@", url.absoluteString);
    decisionHandler(WKNavigationActionPolicyCancel);
}

#pragma mark - WKUIDelegate

- (void)webView:(WKWebView *)webView runJavaScriptAlertPanelWithMessage:(NSString *)message initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(void))completionHandler {
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"提示" message:message preferredStyle:UIAlertControllerStyleAlert];
    [alertController addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        completionHandler();
    }]];
    [self presentViewController:alertController animated:YES completion:nil];
}

- (void)webView:(WKWebView *)webView runJavaScriptConfirmPanelWithMessage:(NSString *)message initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(BOOL))completionHandler {
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"确认" message:message preferredStyle:UIAlertControllerStyleAlert];
    [alertController addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        completionHandler(YES);
    }]];
    [alertController addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
        completionHandler(NO);
    }]];
    [self presentViewController:alertController animated:YES completion:nil];
}

// 根据资料建议，添加KVO监听方法
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqualToString:@"estimatedProgress"]) {
        // 更新进度条
        float progress = [[change objectForKey:NSKeyValueChangeNewKey] floatValue];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (progress > 0.0 && progress < 1.0) {
                // 显示进度条并更新进度
                self.progressView.hidden = NO;
                [self.progressView setProgress:progress animated:YES];
            } else if (progress >= 1.0) {
                // 加载完成，隐藏进度条
                [UIView animateWithDuration:0.3 animations:^{
                    self.progressView.alpha = 0.0;
                } completion:^(BOOL finished) {
                    self.progressView.hidden = YES;
                    self.progressView.alpha = 1.0;
                    self.progressView.progress = 0.0;
                }];
            }
        });
        
    } else if ([keyPath isEqualToString:@"title"]) {
        // 更新标题
        NSString *title = [change objectForKey:NSKeyValueChangeNewKey];
        if (title && title.length > 0) {
            // 可以更新导航栏标题
            // self.navigationItem.title = title;
        }
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void)debugJavaScriptCallback {
    NSLog(@"在局🔍 [JavaScript回调调试] 开始检查JavaScript回调问题...");
    
    // 检查应用状态 - 确保在主线程访问UIApplication
    __block UIApplicationState state;
    if ([NSThread isMainThread]) {
        state = [[UIApplication sharedApplication] applicationState];
    } else {
        dispatch_sync(dispatch_get_main_queue(), ^{
            state = [[UIApplication sharedApplication] applicationState];
        });
    }
    if (state != UIApplicationStateActive) {
        NSLog(@"在局🔍 [JavaScript回调调试] 应用不在前台，取消调试");
        return;
    }
    
    // 1. 检查WebViewJavascriptBridge是否正常工作
    [self safelyEvaluateJavaScript:@"typeof WebViewJavascriptBridge !== 'undefined' && WebViewJavascriptBridge.callHandler ? 'WebViewJavascriptBridge正常' : 'WebViewJavascriptBridge异常'" completionHandler:^(id result, NSError *error) {
        NSLog(@"在局🔍 [JavaScript回调调试] WebViewJavascriptBridge状态: %@", result ?: @"检查失败");
        
        // 2. 检查app.request方法是否存在
        [self safelyEvaluateJavaScript:@"typeof app !== 'undefined' && typeof app.request === 'function' ? 'app.request方法存在' : 'app.request方法不存在'" completionHandler:^(id result, NSError *error) {
            NSLog(@"在局🔍 [JavaScript回调调试] app.request状态: %@", result ?: @"检查失败");
            
            // 3. 检查app.tips方法是否存在
            [self safelyEvaluateJavaScript:@"typeof app !== 'undefined' && typeof app.tips === 'function' ? 'app.tips方法存在' : 'app.tips方法不存在'" completionHandler:^(id result, NSError *error) {
                NSLog(@"在局🔍 [JavaScript回调调试] app.tips状态: %@", result ?: @"检查失败");
                
                // 4. 手动测试app.tips是否能正常工作
                [self safelyEvaluateJavaScript:@"try { if(typeof app !== 'undefined' && typeof app.tips === 'function') { app.tips('JavaScript回调测试'); return 'app.tips调用成功'; } else { return 'app.tips不可用'; } } catch(e) { return 'app.tips调用失败: ' + e.message; }" completionHandler:^(id result, NSError *error) {
                    NSLog(@"在局🔍 [JavaScript回调调试] app.tips测试结果: %@", result ?: @"测试失败");
                    
                    // 5. 手动测试一个简单的app.request调用
                    [self safelyEvaluateJavaScript:@"try { if(typeof app !== 'undefined' && typeof app.request === 'function') { app.request('//test/callback', {}, function(res) { app.tips('手动测试回调成功!'); }); return 'app.request手动测试已发起'; } else { return 'app.request不可用'; } } catch(e) { return 'app.request手动测试失败: ' + e.message; }" completionHandler:^(id result, NSError *error) {
                        NSLog(@"在局🔍 [JavaScript回调调试] app.request手动测试: %@", result ?: @"测试失败");
                        
                        // 6. 检查是否有JavaScript错误
                        [self safelyEvaluateJavaScript:@"(function() { var errors = []; try { if(window.console && window.console.log) { var originalLog = console.log; var originalError = console.error; var logMessages = []; var errorMessages = []; console.log = function(...args) { logMessages.push(args.join(' ')); originalLog.apply(console, args); }; console.error = function(...args) { errorMessages.push(args.join(' ')); originalError.apply(console, args); }; return 'JavaScript错误监听已启动'; } else { return '控制台不可用'; } } catch(e) { return '错误监听设置失败: ' + e.message; } })()" completionHandler:^(id result, NSError *error) {
                            NSLog(@"在局🔍 [JavaScript回调调试] JavaScript错误监听: %@", result ?: @"监听失败");
                        }];
                    }];
                }];
            }];
        }];
    }];
}

#pragma mark - WebView Health Check

// 检查并重建WebView如果需要
- (BOOL)checkAndRebuildWebViewIfNeeded {
    NSLog(@"在局🔍 [checkAndRebuildWebViewIfNeeded] 开始WebView健康检查");
    
    // 检查WebView是否存在
    if (!self.webView) {
        NSLog(@"在局❌ [健康检查] WebView不存在，需要创建");
        [self setupWebView];
        [self addWebView];
        return YES;
    }
    
    // 检查navigation delegate是否正常
    if (!self.webView.navigationDelegate) {
        NSLog(@"在局❌ [健康检查] navigationDelegate丢失！这表明Bridge有严重问题");
        if (self.bridge) {
            NSLog(@"在局⚠️ [健康检查] Bridge存在但delegate丢失，这不应该发生");
            // 不要手动设置delegate，Bridge应该自己管理
            // 记录这个异常情况，但让Bridge自己处理
        } else {
            NSLog(@"在局❌ [健康检查] Bridge不存在，需要重新创建桥接");
            [self setupJavaScriptBridge];
        }
    } else {
        NSLog(@"在局✅ [健康检查] navigationDelegate正常: %@", self.webView.navigationDelegate);
    }
    
    // 检查WebView是否在视图层级中
    if (!self.webView.superview) {
        NSLog(@"在局❌ [健康检查] WebView不在视图层级中，重新添加");
        [self addWebView];
    }
    
    // 检查WebView的frame是否正常
    if (CGRectIsEmpty(self.webView.frame) || CGRectGetWidth(self.webView.frame) == 0) {
        NSLog(@"在局⚠️ [健康检查] WebView frame异常: %@，触发布局", NSStringFromCGRect(self.webView.frame));
        [self.view setNeedsLayout];
        [self.view layoutIfNeeded];
    }
    
    // 对于第二个Tab，进行特殊的健康检查
    if (self.tabBarController && self.tabBarController.selectedIndex > 0) {
        NSLog(@"在局🔍 [健康检查] 检测到非首个Tab，执行深度检查");
        
        // 设置加载超时监控
        [self startWebViewLoadingMonitor];
    }
    
    NSLog(@"在局✅ [健康检查] WebView状态正常");
    return YES;
}

// 启动WebView加载监控
- (void)startWebViewLoadingMonitor {
    NSLog(@"在局⏱️ [加载监控] 启动WebView加载监控");
    
    // 取消之前的监控
    if (self.healthCheckTimer) {
        [self.healthCheckTimer invalidate];
        self.healthCheckTimer = nil;
    }
    
    // 记录当前时间，用于判断是否触发了navigation delegate
    objc_setAssociatedObject(self, @selector(startWebViewLoadingMonitor), [NSDate date], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    // 设置2秒超时监控（更短的超时时间）
    self.healthCheckTimer = [NSTimer scheduledTimerWithTimeInterval:2.0
                                                             target:self
                                                           selector:@selector(webViewLoadingTimeout)
                                                           userInfo:nil
                                                            repeats:NO];
}

// WebView加载超时处理
- (void)webViewLoadingTimeout {
    NSLog(@"在局⏰ [加载超时] WebView加载2秒超时！");
    
    // 检查是否触发了navigation delegate
    NSDate *startTime = objc_getAssociatedObject(self, @selector(startWebViewLoadingMonitor));
    NSTimeInterval elapsed = [[NSDate date] timeIntervalSinceDate:startTime];
    
    NSLog(@"在局⏰ [加载超时] 距离loadHTMLString调用已过去: %.2f秒", elapsed);
    NSLog(@"在局⏰ [加载超时] isWebViewLoading状态: %@", self.isWebViewLoading ? @"YES" : @"NO");
    
    if (!self.isWebViewLoading) {
        NSLog(@"在局🚨 [紧急修复] WebView navigation delegate未触发，进入死亡状态！");
        NSLog(@"在局🚨 [紧急修复] 开始执行强制重建流程...");
        
        // 强制重建WebView
        [self forceRebuildWebViewForDeadState];
    } else {
        NSLog(@"在局✅ [加载超时] WebView正在正常加载，取消超时处理");
    }
}

// 统一的WebView重建管理
- (void)rebuildWebView {
    NSLog(@"在局🔧 [重建WebView] 开始统一的WebView重建流程...");
    NSLog(@"在局 🔧 [XZWKWebViewBaseController] 统一WebView重建管理逻辑");
    
    // 检查重建条件和限制
    static NSDate *lastRebuildTime = nil;
    NSDate *now = [NSDate date];
    if (lastRebuildTime && [now timeIntervalSinceDate:lastRebuildTime] < 2.0) {
        NSLog(@"在局 ⚠️ [重建WebView] 重建请求过于频繁，忽略此次请求");
        return;
    }
    lastRebuildTime = now;
    
    // 记录重建原因（用于调试）
    NSArray *callStack = [NSThread callStackSymbols];
    NSLog(@"在局 📍 [重建WebView] 调用堆栈: %@", [callStack subarrayWithRange:NSMakeRange(0, MIN(5, callStack.count))]);
    
    // 保存当前状态
    NSString *currentUrl = self.pinUrl;
    NSString *currentData = self.pinDataStr;
    BOOL wasLoading = self.isLoading;
    
    // 步骤1：清理旧的WebView
    NSLog(@"在局 🧹 [重建WebView] 步骤1：清理旧的WebView");
    [self cleanupWebView];
    
    // 步骤2：重置相关状态
    NSLog(@"在局 🔄 [重建WebView] 步骤2：重置状态");
    self.isLoading = NO;
    self.isWebViewLoading = NO;
    self->_retryCount = 0;
    
    // 步骤3：重新创建WebView
    NSLog(@"在局 🏗️ [重建WebView] 步骤3：创建新的WebView");
    [self setupWebView];
    [self addWebView];
    
    // 步骤4：重新建立JavaScript桥接
    NSLog(@"在局 🌉 [重建WebView] 步骤4：建立JavaScript桥接");
    [self setupJavaScriptBridge];
    
    // 步骤5：恢复状态
    NSLog(@"在局 📥 [重建WebView] 步骤5：恢复状态");
    self.pinUrl = currentUrl;
    self.pinDataStr = currentData;
    
    NSLog(@"在局 ✅ [重建WebView] WebView重建完成");
    
    // 步骤6：重新加载内容（延迟执行以确保WebView完全准备好）
    if (wasLoading && currentUrl) {
        NSLog(@"在局 🔄 [重建WebView] 步骤6：重新加载内容");
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self domainOperate];
        });
    }
}

// 清理WebView的统一方法
- (void)cleanupWebView {
    NSLog(@"在局 🧹 [清理WebView] 开始清理WebView资源");
    
    if (self.webView) {
        // 停止加载
        [self.webView stopLoading];
        
        // 移除KVO观察者
        @try {
            [self.webView removeObserver:self forKeyPath:@"estimatedProgress"];
            [self.webView removeObserver:self forKeyPath:@"title"];
        } @catch (NSException *exception) {
            NSLog(@"在局 ⚠️ [清理WebView] 移除KVO观察者异常: %@", exception);
        }
        
        // 清理代理
        self.webView.navigationDelegate = nil;
        self.webView.UIDelegate = nil;
        
        // 从父视图移除
        [self.webView removeFromSuperview];
        
        // 释放WebView
        self.webView = nil;
    }
    
    // 清理JavaScript桥接
    if (self.bridge) {
        self.bridge = nil;
    }
    
    // 清理UserContentController
    if (self.userContentController) {
        [self.userContentController removeAllUserScripts];
        self.userContentController = nil;
        NSLog(@"在局 ✅ [清理WebView] UserContentController已清理");
    }
    
    NSLog(@"在局 ✅ [清理WebView] WebView资源清理完成");
}

// 设置JavaScript桥接的统一方法
- (void)setupJavaScriptBridge {
    if (self.webView && [self.webView isKindOfClass:[WKWebView class]]) {
        NSLog(@"在局 🌉 [JavaScript桥接] 开始设置WKWebView JavaScript桥接");
        
        // 检查是否已经存在桥接
        if (self.bridge) {
            NSLog(@"在局 ⚠️ [JavaScript桥接] 桥接已存在，先清理");
            self.bridge = nil;
        }
        
        // 创建新的桥接
        NSLog(@"在局 🔧 [JavaScript桥接] 创建WKWebViewJavascriptBridge...");
        self.bridge = [WKWebViewJavascriptBridge bridgeForWebView:(WKWebView *)self.webView];
        
        if (!self.bridge) {
            NSLog(@"在局 ❌ [JavaScript桥接] Bridge创建失败！");
            return;
        }
        
        NSLog(@"在局 🔧 [JavaScript桥接] 设置WebViewDelegate为self");
        [self.bridge setWebViewDelegate:self];
        
        // 验证Bridge是否正确设置为navigationDelegate
        NSLog(@"在局 🔍 [JavaScript桥接] 验证delegate设置 - navigationDelegate: %@", self.webView.navigationDelegate);
        if (self.webView.navigationDelegate != self.bridge) {
            NSLog(@"在局 ❌ [JavaScript桥接] delegate设置异常！期望: %@, 实际: %@", self.bridge, self.webView.navigationDelegate);
        } else {
            NSLog(@"在局 ✅ [JavaScript桥接] navigationDelegate设置正确");
        }
        
        // 设置桥接处理器
        __weak typeof(self) weakSelf = self;
        
        // 注册xzBridge处理器
        [self.bridge registerHandler:@"xzBridge" handler:^(id data, WVJBResponseCallback responseCallback) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            NSLog(@"在局 🌉 [xzBridge] 收到JS调用: %@", data);
            [strongSelf jsCallObjc:data jsCallBack:responseCallback];
        }];
        
        // 注册独立的pageReady处理器
        [self.bridge registerHandler:@"pageReady" handler:^(id data, WVJBResponseCallback responseCallback) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            NSLog(@"在局🎯 [pageReady Handler] 直接pageReady调用");
            
            // 调用原有的pageReady处理逻辑
            NSDictionary *pageReadyData = @{
                @"fn": @"pageReady",
                @"params": data ?: @{}
            };
            [strongSelf jsCallObjc:pageReadyData jsCallBack:responseCallback];
        }];
        
        // 注册桥接测试处理器
        [self.bridge registerHandler:@"bridgeTest" handler:^(id data, WVJBResponseCallback responseCallback) {
            NSLog(@"在局🧪 [桥接测试] 收到测试请求: %@", data);
            if (responseCallback) {
                responseCallback(@{
                    @"success": @YES,
                    @"message": @"桥接正常工作",
                    @"timestamp": @([[NSDate date] timeIntervalSince1970])
                });
            }
        }];
        
        NSLog(@"在局 ✅ [JavaScript桥接] 桥接设置完成，已注册3个处理器: xzBridge, pageReady, bridgeTest");
        
        // 验证桥接是否正常工作，增加延迟以适应Release版本
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self verifyBridgeSetup];
        });
    } else {
        NSLog(@"在局 ❌ [JavaScript桥接] 无法设置桥接: WebView不存在或类型不正确");
    }
}

// 验证桥接设置
- (void)verifyBridgeSetup {
    NSLog(@"在局 🔍 [桥接验证] 开始验证JavaScript桥接设置");
    
    if (!self.bridge) {
        NSLog(@"在局 ❌ [桥接验证] 桥接对象不存在");
        return;
    }
    
    // 检查WebView是否正常
    if (!self.webView || ![self.webView isKindOfClass:[WKWebView class]]) {
        NSLog(@"在局 ❌ [桥接验证] WebView不存在或类型错误");
        return;
    }
    
    // 测试JavaScript环境
    [self safelyEvaluateJavaScript:@"(function(){"
        "var result = {};"
        "result.bridgeExists = typeof WebViewJavascriptBridge !== 'undefined';"
        "result.bridgeReady = window.WebViewJavascriptBridge && typeof window.WebViewJavascriptBridge.callHandler === 'function';"
        "result.appExists = typeof app !== 'undefined';"
        "result.documentReady = document.readyState;"
        "return JSON.stringify(result);"
    "})()" completionHandler:^(id result, NSError *error) {
        if (error) {
            NSLog(@"在局 ❌ [桥接验证] JavaScript执行失败: %@", error.localizedDescription);
        } else {
            NSLog(@"在局 ✅ [桥接验证] JavaScript环境状态: %@", result);
            
            // 如果桥接未就绪，尝试手动注入
            NSError *jsonError;
            NSDictionary *resultDict = [NSJSONSerialization JSONObjectWithData:[result dataUsingEncoding:NSUTF8StringEncoding] options:0 error:&jsonError];
            
            if (!jsonError && ![resultDict[@"bridgeReady"] boolValue]) {
                NSLog(@"在局 ⚠️ [桥接验证] 桥接未就绪，尝试手动初始化");
                [self injectBridgeScript];
            }
        }
    }];
}

// 手动注入桥接脚本
- (void)injectBridgeScript {
    NSLog(@"在局 💉 [桥接注入] 开始手动注入桥接脚本");
    
    // 这里可以手动注入必要的JavaScript代码来确保桥接正常工作
    NSString *bridgeInitScript = @"(function(){"
        "if (window.WebViewJavascriptBridge) {"
        "    return 'already_exists';"
        "} else {"
        "    // WKWebViewJavascriptBridge会自动注入，这里只是触发检查"
        "    if (window.WVJBCallbacks) {"
        "        window.WVJBCallbacks.push(function(bridge) {"
        "            // 桥接回调触发"
        "        });"
        "    }"
        "    return 'waiting_for_injection';"
        "}"
    "})()";
    
    [self safelyEvaluateJavaScript:bridgeInitScript completionHandler:^(id result, NSError *error) {
        if (error) {
            NSLog(@"在局 ❌ [桥接注入] 脚本注入失败: %@", error.localizedDescription);
        } else {
            NSLog(@"在局 ✅ [桥接注入] 脚本注入结果: %@", result);
        }
    }];
}

// 强制重建WebView（针对死亡状态）
- (void)forceRebuildWebViewForDeadState {
    NSLog(@"在局💀 [强制重建] 检测到WebView死亡状态，执行强制重建！");
    
    // 停止健康检查定时器
    if (self.healthCheckTimer) {
        [self.healthCheckTimer invalidate];
        self.healthCheckTimer = nil;
    }
    
    // 保存当前状态
    NSString *currentUrl = self.pinUrl;
    NSString *currentData = self.pinDataStr;
    NSString *currentHtml = self.htmlStr;
    
    NSLog(@"在局💀 [强制重建] 保存的状态 - URL: %@, 有数据: %@, 有HTML: %@", 
          currentUrl, currentData ? @"YES" : @"NO", currentHtml ? @"YES" : @"NO");
    
    // 完全清理现有WebView
    if (self.webView) {
        NSLog(@"在局💀 [强制重建] 开始清理死亡的WebView");
        
        // 移除所有观察者
        @try {
            [self.webView removeObserver:self forKeyPath:@"estimatedProgress"];
            [self.webView removeObserver:self forKeyPath:@"title"];
        } @catch (NSException *exception) {
            NSLog(@"在局⚠️ [强制重建] 移除观察者异常: %@", exception.reason);
        }
        
        // 清理JavaScript桥接
        if (self.bridge) {
            [self.bridge reset];
            self.bridge = nil;
        }
        
        // 停止所有加载
        [self.webView stopLoading];
        
        // 清理委托
        self.webView.navigationDelegate = nil;
        self.webView.UIDelegate = nil;
        self.webView.scrollView.delegate = nil;
        
        // 从视图层级移除
        [self.webView removeFromSuperview];
        
        // 释放WebView
        self.webView = nil;
        
        NSLog(@"在局💀 [强制重建] 死亡WebView清理完成");
    }
    
    // 重置所有状态标志
    self.isWebViewLoading = NO;
    self.isLoading = NO;
    lastLoadTime = nil;
    
    // 延迟创建新的WebView（给系统一点时间清理）
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSLog(@"在局🔧 [强制重建] 开始创建全新的WebView");
        
        // 创建全新的WebView
        [self setupWebView];
        [self addWebView];
        
        // 重新建立桥接
        [self loadWebBridge];
        
        // 恢复保存的状态
        self.pinUrl = currentUrl;
        self.pinDataStr = currentData;
        self.htmlStr = currentHtml;
        
        NSLog(@"在局✅ [强制重建] 新WebView创建完成，准备加载内容");
        
        // 使用不同的加载策略
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            // 统一使用正常加载流程，不区分Tab
            NSLog(@"在局🔄 [强制重建] 开始正常加载流程");
            [self performHTMLLoading];
        });
    });
}

// 移除替代加载方法，统一使用正常加载流程

// 移除所有紧急修复方法，让iOS生命周期正常执行

#pragma mark - 页面加载监控

// 页面加载监控方法
- (void)startPageLoadMonitor {
    NSLog(@"在局⏱️ [页面监控] 启动页面加载监控器");
    
    // 取消之前的监控
    if (self.healthCheckTimer) {
        [self.healthCheckTimer invalidate];
        self.healthCheckTimer = nil;
    }
    
    // 设置5秒超时监控（增加时间以适应Release版本）
    self.healthCheckTimer = [NSTimer scheduledTimerWithTimeInterval:5.0
                                                             target:self
                                                           selector:@selector(checkPageLoadStatus)
                                                           userInfo:nil
                                                            repeats:NO];
}

// 检查页面加载状态
- (void)checkPageLoadStatus {
    NSLog(@"在局🔍 [页面监控] 检查页面加载状态");
    
    if (!self.isLoading) {
        NSLog(@"在局⚠️ [页面监控] 3秒后仍未收到pageReady，尝试手动触发");
        
        // 手动触发pageReady
        [self safelyEvaluateJavaScript:@"(function(){"
            "if (window.webViewCall && typeof window.webViewCall === 'function') {"
            "    window.webViewCall('pageReady');"
            "    return 'pageReady_triggered';"
            "} else if (window.WebViewJavascriptBridge && window.WebViewJavascriptBridge.callHandler) {"
            "    window.WebViewJavascriptBridge.callHandler('xzBridge', {action:'pageReady', data:{}});"
            "    return 'pageReady_via_bridge';"
            "} else {"
            "    // 尝试重新初始化桥接"
            "    if (window.wx && window.wx.app && window.wx.app.connect) {"
            "        window.wx.app.connect(function() {"
            "            if (window.webViewCall) {"
            "                window.webViewCall('pageReady');"
            "            }"
            "        });"
            "        return 'reinit_bridge';"
            "    }"
            "    return 'failed_no_bridge';"
            "}"
        "})()" completionHandler:^(id result, NSError *error) {
            NSLog(@"在局🔥 [手动触发] 结果: %@", result ?: error.localizedDescription);
        }];
    } else {
        NSLog(@"在局✅ [页面监控] pageReady已经触发，页面正常加载");
    }
}

#pragma mark - WebView白屏检测

- (void)detectBlankWebView {
    NSLog(@"在局 🔍 [XZWKWebViewBaseController] 开始检测WebView是否白屏");
    
    // 方法1：检测DOM内容
    NSString *jsCode = @"document.body.innerHTML.length";
    [self.webView evaluateJavaScript:jsCode completionHandler:^(id result, NSError *error) {
        if (error) {
            NSLog(@"在局 ❌ [白屏检测] JavaScript执行错误: %@", error.localizedDescription);
            return;
        }
        
        NSInteger contentLength = [result integerValue];
        NSLog(@"在局 📊 [白屏检测] DOM内容长度: %ld", (long)contentLength);
        
        if (contentLength < 100) {
            NSLog(@"在局 ⚠️ [白屏检测] 检测到可能的白屏，DOM内容过少");
            
            // 方法2：检测页面是否有可见元素
            NSString *checkVisibleElements = @"document.querySelectorAll('*').length";
            [self.webView evaluateJavaScript:checkVisibleElements completionHandler:^(id elementCount, NSError *error) {
                NSInteger count = [elementCount integerValue];
                NSLog(@"在局 📊 [白屏检测] 页面元素数量: %ld", (long)count);
                
                if (count < 10) {
                    NSLog(@"在局 🚨 [白屏检测] 确认白屏！页面元素过少");
                    [self handleBlankWebView];
                } else {
                    NSLog(@"在局 ✅ [白屏检测] 页面正常，有足够的DOM元素");
                }
            }];
        } else {
            NSLog(@"在局 ✅ [白屏检测] 页面正常，DOM内容充足");
        }
    }];
    
    // 方法3：检测JavaScript是否正常执行
    NSString *checkJS = @"typeof app !== 'undefined' && typeof app.request === 'function'";
    [self.webView evaluateJavaScript:checkJS completionHandler:^(id result, NSError *error) {
        BOOL jsReady = [result boolValue];
        NSLog(@"在局 📊 [白屏检测] JavaScript环境就绪: %@", jsReady ? @"YES" : @"NO");
        
        if (!jsReady && self.isLoading) {
            NSLog(@"在局 ⚠️ [白屏检测] JavaScript环境未就绪，可能存在加载问题");
        }
    }];
}

- (void)handleBlankWebView {
    NSLog(@"在局 🚨 [白屏处理] 开始处理白屏问题");
    
    // 检查重试次数
    if (self->_retryCount >= 3) {
        NSLog(@"在局 ❌ [白屏处理] 重试次数已达上限，显示错误页面");
        dispatch_async(dispatch_get_main_queue(), ^{
            self.networkNoteView.hidden = NO;
        });
        return;
    }
    
    self->_retryCount++;
    NSLog(@"在局 🔄 [白屏处理] 尝试重新加载页面（第%ld次）", (long)self->_retryCount);
    
    // 清除缓存并重新加载
    [[HTMLCache sharedCache] removeObjectForKey:self.webViewDomain];
    
    // 重建WebView
    [self rebuildWebView];
}

@end
