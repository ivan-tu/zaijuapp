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

// HTML模板缓存 - 性能优化
static NSString *_cachedHTMLTemplate = nil;
static NSDate *_templateCacheTime = nil;
static NSOperationQueue *_sharedHTMLProcessingQueue = nil;

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
    
    // 初始化lastSelectedIndex为-1，表示尚未选择过任何tab
    self.lastSelectedIndex = -1;
    
    // 创建JavaScript操作队列
    self.jsOperationQueue = [[NSOperationQueue alloc] init];
    self.jsOperationQueue.maxConcurrentOperationCount = 1;
    self.jsOperationQueue.name = @"com.xz.javascript.queue";
    
    // 创建网络状态提示视图
    [self setupNetworkNoteView];
    
    // 延迟WebView创建到需要时，避免阻塞Tab切换动画
    
    // 创建加载指示器
    [self setupLoadingIndicators];
    
    // 添加通知监听
    [self addNotificationObservers];
    
    // 初始化JavaScript执行管理
    [self initializeJavaScriptManagement];
    
    // 【性能优化】初始化优化相关属性和队列
    [self initializePerformanceOptimizations];
    
    // 【性能优化】预创建WebView（异步，不阻塞主线程）
    [self preCreateWebViewIfNeeded];
    
    // 添加应用生命周期通知监听
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appWillTerminate:) name:@"AppWillTerminateNotification" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidEnterBackground:) name:@"AppDidEnterBackgroundNotification" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appWillResignActive:) name:@"AppWillResignActiveNotification" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidBecomeActive:) name:@"AppDidBecomeActiveNotification" object:nil];
    
    // 添加Universal Links通知监听
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleUniversalLinkNavigation:) name:@"UniversalLinkNavigation" object:nil];
    
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
    // 注意：不在这里更新lastSelectedIndex，让通知处理逻辑来管理
    
    // 检查WebView状态，但不在viewWillAppear中创建，避免阻塞转场
    if (!self.webView) {
        // WebView将在viewDidAppear中创建
    }
}

- (void)viewDidAppear:(BOOL)animated {
    NSLog(@"在局🔍 [XZWKWebViewBaseController] viewDidAppear被调用 - self: %@, pinUrl: %@", self, self.pinUrl);
    [super viewDidAppear:animated];
    
    // 清除消失标志
    _isDisappearing = NO;
    
    // 记录这一次选中的索引
    self.lastSelectedIndex = self.tabBarController.selectedIndex;
    
    [self setupAndLoadWebViewIfNeeded];
    
    // 启动网络监控
//    [self listenToTimer];
    
    // 检查是否从交互式转场返回 - 只有在导航栈减少时才是返回操作
    BOOL isFromInteractiveTransition = NO;
    if ([self.navigationController isKindOfClass:NSClassFromString(@"XZNavigationController")]) {
        // 使用KVC安全地检查交互式转场状态和导航栈变化
        @try {
            NSNumber *wasInteractiveValue = [self.navigationController valueForKey:@"isInteractiveTransition"];
            BOOL wasInteractive = [wasInteractiveValue boolValue];
            
            // 只有在真正的交互式返回时才启动特殊恢复流程
            // 检查条件：1. 有动画 2. 曾经是交互式转场 3. 当前在导航栈中（不是push新页面）
            NSInteger currentIndex = [self.navigationController.viewControllers indexOfObject:self];
            isFromInteractiveTransition = animated && wasInteractive && currentIndex != NSNotFound && currentIndex < self.navigationController.viewControllers.count;
            
            NSLog(@"在局🔍 [viewDidAppear] 转场检测: animated=%@, wasInteractive=%@, currentIndex=%ld, totalVC=%ld", 
                  animated ? @"YES" : @"NO", wasInteractive ? @"YES" : @"NO", (long)currentIndex, (long)self.navigationController.viewControllers.count);
        } @catch (NSException *exception) {
            NSLog(@"在局⚠️ [viewDidAppear] 无法检查交互式转场状态: %@", exception.reason);
            isFromInteractiveTransition = NO;
        }
    }
    
    if (isFromInteractiveTransition) {
        NSLog(@"在局🔙 [viewDidAppear] 检测到从交互式转场返回，启动特殊恢复流程");
        
        // 在恢复之前先检查是否有有效内容
        BOOL hasValidContent = [self hasValidWebViewContent];
        NSLog(@"在局🔍 [交互式转场返回] 内容检查 - hasValidContent: %@", hasValidContent ? @"YES" : @"NO");
        
        if (hasValidContent) {
            NSLog(@"在局✅ [交互式转场返回] 页面已有有效内容，仅执行状态恢复，不重新加载");
            // 只执行状态恢复，不重新加载页面
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                // 只恢复UI状态，确保WebView可见
                if (self.webView) {
                    self.webView.hidden = NO;
                    self.webView.alpha = 1.0;
                    [self.webView setNeedsLayout];
                    [self.webView layoutIfNeeded];
                    NSLog(@"在局✅ [交互式转场返回] WebView状态恢复完成");
                }
            });
        } else {
            NSLog(@"在局🔄 [交互式转场返回] 页面无有效内容，执行完整恢复流程");
            // 特殊处理：从交互式转场返回时，需要特别恢复WebView状态
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self restoreWebViewStateAfterInteractiveTransition];
            });
        }
    } else {
        // 优化显示逻辑：检查页面是否已经加载完成，避免重复加载
        BOOL hasValidContent = [self hasValidWebViewContent];
        BOOL isNavigationReturn = [self isNavigationReturnScenario];
        
        NSLog(@"在局🔍 [显示优化] 页面显示检查 - hasValidContent: %@, isNavigationReturn: %@, isWebViewLoading: %@", 
              hasValidContent ? @"YES" : @"NO", 
              isNavigationReturn ? @"YES" : @"NO",
              self.isWebViewLoading ? @"YES" : @"NO");
        
        // 1. 如果页面已有有效内容，无论什么场景都只触发pageShow，不重新加载
        if (hasValidContent) {
            NSLog(@"在局✅ [显示优化] 页面已有有效内容，仅触发pageShow事件，避免重新加载");
            
            // 确保WebView可见性
            self.webView.hidden = NO;
            self.webView.alpha = 1.0;
            self.webView.userInteractionEnabled = YES;
            
            // 触发页面显示事件
            NSDictionary *callJsDic = [CustomHybridProcessor custom_objcCallJsWithFn:@"pageShow" data:nil];
            [self objcCallJs:callJsDic];
            return; // 避免任何重新加载
        }
        
        // 2. 如果是返回导航且WebView已初始化，尝试恢复而非重新加载
        if (isNavigationReturn && self.webView) {
            NSLog(@"在局🔄 [返回优化] 检测到返回导航，尝试恢复页面状态");
            
            // 检查是否有最基本的页面结构
            if (self.webView.URL && ![self.webView.URL.absoluteString containsString:@"manifest/"]) {
                NSLog(@"在局✅ [返回优化] WebView有基础内容，仅恢复状态");
                self.webView.hidden = NO;
                self.webView.alpha = 1.0;
                self.webView.userInteractionEnabled = YES;
                
                NSDictionary *callJsDic = [CustomHybridProcessor custom_objcCallJsWithFn:@"pageShow" data:nil];
                [self objcCallJs:callJsDic];
                return;
            }
        }
        
        // 3. 只有在确实需要加载的情况下才进行加载
        BOOL shouldLoad = NO;
        NSString *loadReason = @"";
        
        if (!self.webView) {
            shouldLoad = YES;
            loadReason = @"WebView未创建";
        } else if (!self.webView.URL) {
            shouldLoad = YES;
            loadReason = @"WebView无内容";
        } else if ([self.webView.URL.absoluteString containsString:@"manifest/"]) {
            shouldLoad = YES;
            loadReason = @"WebView仅加载了基础目录";
        } else if (!self.isWebViewLoading && !self.isExist) {
            shouldLoad = YES;
            loadReason = @"页面加载状态异常";
        }
        
        if (shouldLoad) {
            NSLog(@"在局🔄 [显示优化] 需要加载页面，原因: %@", loadReason);
            
            // 防止过于频繁的加载
            static NSDate *lastLoadTime = nil;
            NSDate *now = [NSDate date];
            if (lastLoadTime && [now timeIntervalSinceDate:lastLoadTime] < 2.0) {
                NSLog(@"在局⏳ [显示优化] 加载过于频繁，跳过此次加载");
                return;
            }
            lastLoadTime = now;
            
            [self domainOperate];
        } else {
            NSLog(@"在局✅ [显示优化] 页面状态正常，无需重新加载");
        }
    }
    
    // 处理重复点击tabbar刷新
    // if (self.lastSelectedIndex == self.tabBarController.selectedIndex && [self isShowingOnKeyWindow] && self.isWebViewLoading) {
    //     [self.webView.scrollView scrollRectToVisible:CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.height) animated:YES];
    // }

}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    
    // 在布局变化时重新调整进度条位置，确保始终贴紧标题栏底部
    if (self.progressView) {
        [self updateProgressViewPosition];
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
        // [self.activityIndicatorView stopAnimating]; // 已禁用loading指示器
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
#pragma mark - WebView Loading Logic

- (void)setupAndLoadWebViewIfNeeded {
    NSLog(@"在局🚀 [性能优化] setupAndLoadWebViewIfNeeded - 使用优化逻辑");
    
    // 检查网络状态 - 改为记录状态而不是直接返回，允许WebView创建和基本设置
    AppDelegate *appDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
    BOOL networkRestricted = appDelegate.networkRestricted;
    if (networkRestricted) {
        NSLog(@"在局⚠️ [性能优化] 网络受限，但继续WebView设置，等待网络恢复后加载内容");
    }

    // 【性能优化】如果WebView已经预创建，直接使用
    if (self.isWebViewPreCreated && self.webView) {
        NSLog(@"在局✅ [性能优化] 使用预创建的WebView");
        
        // 确保WebView已正确添加到视图层级
        if (!self.webView.superview) {
            [self addWebView];
        }
        
        // 确保桥接已设置
        if (!self.isBridgeReady) {
            [self setupOptimizedJavaScriptBridge];
        }
        
        // 检查是否已有有效内容，避免重复加载
        if ([self hasValidWebViewContent]) {
            NSLog(@"在局✅ [预创建WebView] 已有有效内容，跳过重复加载");
            return;
        }
        
        // 检查是否需要加载HTML内容
        if (self.htmlStr && self.htmlStr.length > 0) {
            [self optimizedLoadHTMLContent];
        } else if (self.pinDataStr && self.pinDataStr.length > 0) {
            [self optimizedLoadHTMLContent];
        } else {
            // 等待domainOperate完成后会自动调用加载方法
            NSLog(@"在局⏳ [性能优化] 等待HTML内容准备完成");
        }
        
        return;
    }
    
    // 【性能优化】如果WebView未预创建，启动快速创建流程
    if (!self.webView && !self.isWebViewLoading) {
        NSLog(@"在局🔧 [性能优化] WebView未预创建，启动快速创建流程");
        
        // 标记为正在加载，避免重复创建
        self.isWebViewLoading = YES;
        
        // 使用优化的WebView创建流程
        dispatch_async(dispatch_get_main_queue(), ^{
            // 创建优化的WebView配置
            WKWebViewConfiguration *configuration = [self createOptimizedWebViewConfiguration];
            
            // 创建WebView实例
            self.webView = [[WKWebView alloc] initWithFrame:CGRectZero configuration:configuration];
            self.webView.backgroundColor = [UIColor whiteColor];
            
            // 添加到视图层级
            [self addWebView];
            
            // 设置优化的JavaScript桥接
            [self setupOptimizedJavaScriptBridge];
            
            // 重置加载状态
            self.isWebViewLoading = NO;
            self.isWebViewPreCreated = YES;
            
            NSLog(@"在局✅ [性能优化] 快速WebView创建完成");
            
            // 检查是否需要加载HTML内容
            if (self.htmlStr && self.htmlStr.length > 0) {
                [self optimizedLoadHTMLContent];
            } else if (self.pinDataStr && self.pinDataStr.length > 0) {
                [self optimizedLoadHTMLContent];
            } else {
                NSLog(@"在局⏳ [性能优化] 等待HTML内容准备完成");
            }
        });
    }
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
            fileRemoved = YES;
        }
        
        // 兼容旧版本，同时检查manifest目录
        NSString *manifestPath = [BaseFileManager appH5LocailManifesPath];
        NSString *manifestFilePath = [manifestPath stringByAppendingPathComponent:self.currentTempFileName];
        
        if ([[NSFileManager defaultManager] fileExistsAtPath:manifestFilePath]) {
            [[NSFileManager defaultManager] removeItemAtPath:manifestFilePath error:nil];
            fileRemoved = YES;
        }
        
        
        self.currentTempFileName = nil;
    }
}

#pragma mark - JavaScript执行时机管理

- (void)initializeJavaScriptManagement {
    if (!self.pendingJavaScriptTasks) {
        self.pendingJavaScriptTasks = [NSMutableArray array];
    }
    if (!self.delayedTimers) {
        self.delayedTimers = [NSMutableArray array];
    }
}

// 添加延迟执行的JavaScript任务（可取消）
- (NSTimer *)scheduleJavaScriptTask:(void(^)(void))task afterDelay:(NSTimeInterval)delay {
    NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:delay
                                                     repeats:NO
                                                       block:^(NSTimer * _Nonnull timer) {
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
    for (NSTimer *timer in self.delayedTimers) {
        [timer invalidate];
    }
    [self.delayedTimers removeAllObjects];
}

// 基于状态的JavaScript执行（替代固定延迟）
- (void)executeJavaScriptWhenReady:(NSString *)javascript completion:(void(^)(id result, NSError *error))completion {
    // 检查WebView和JavaScript环境是否就绪
    if (self.webView && self.isWebViewLoading) {
        // 立即执行
        [self safelyEvaluateJavaScript:javascript completion:completion];
    } else {
        // 添加到待执行队列
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
    
    // 修复从外部App返回时的状态问题
    NSLog(@"在局🔔 [appDidBecomeActive] App变为活跃状态，重置_isDisappearing标志");
    _isDisappearing = NO;
    
    // 检查是否需要重新启动定时器
    if (!self.timer && self.networkNoteView && self.networkNoteView.hidden) {
//        [self listenToTimer];
    }
}

#pragma mark - Scene Lifecycle Methods (iOS 13+)

- (void)sceneWillDeactivate:(NSNotification *)notification API_AVAILABLE(ios(13.0)) {
    
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
    
    
    // 修复左滑返回手势冲突：禁用WKWebView的左滑后退手势
    if (@available(iOS 9.0, *)) {
        self.webView.allowsBackForwardNavigationGestures = NO;
    }
    
    // 配置滚动视图 - 修复iOS 12键盘弹起后布局问题
    if (@available(iOS 12.0, *)) {
        // iOS 12及以上版本使用Automatic，避免键盘弹起后视图不恢复的问题
        self.webView.scrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentAutomatic;
    } else if (@available(iOS 11.0, *)) {
        // iOS 11使用Never
        self.webView.scrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
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
    NSLog(@"在局🔄 [下拉刷新] 开始设置下拉刷新控件");
    [self setupRefreshControl];
    NSLog(@"在局✅ [下拉刷新] 下拉刷新控件设置完成");
    
    // 设置用户代理
    [self setCustomUserAgent];
    
    // 结束CATransaction
    [CATransaction commit];
}

// 创建默认的箭头图片
- (UIImage *)createDefaultArrowImage {
    CGSize imageSize = CGSizeMake(30, 30);
    UIGraphicsBeginImageContextWithOptions(imageSize, NO, 0.0);
    
    // 获取上下文
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    // 设置颜色
    [[UIColor grayColor] setStroke];
    
    // 画箭头
    CGContextSetLineWidth(context, 2.0);
    CGContextMoveToPoint(context, 10, 10);
    CGContextAddLineToPoint(context, 15, 20);
    CGContextAddLineToPoint(context, 20, 10);
    CGContextStrokePath(context);
    
    // 获取图片
    UIImage *arrowImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return arrowImage;
}

- (void)setupRefreshControl {
    NSLog(@"在局🔄 [下拉刷新] setupRefreshControl方法开始执行");
    
    // 配置下拉刷新控件
    __weak UIScrollView *scrollView = self.webView.scrollView;
    
    if (!scrollView) {
        NSLog(@"在局❌ [下拉刷新] WebView的scrollView为空，无法设置下拉刷新");
        return;
    }
    
    NSLog(@"在局🔄 [下拉刷新] 创建MJRefreshNormalHeader");
    MJRefreshNormalHeader *header = [MJRefreshNormalHeader headerWithRefreshingTarget:self refreshingAction:@selector(loadNewData)];
    header.lastUpdatedTimeLabel.hidden = YES;
    header.stateLabel.hidden = YES;
    
    // 🔧 修复下拉刷新箭头图标缺失问题
    // 设置箭头图标 (通过配置现有的arrowView)
    if (header.arrowView) {
        // 首先尝试使用MJRefresh自带的图片（正确的路径）
        UIImage *arrowImage = [UIImage imageNamed:@"MJRefresh.bundle/arrow@2x"];
        if (!arrowImage) {
            // 尝试另一种路径格式
            arrowImage = [UIImage imageNamed:@"Pods/MJRefresh/MJRefresh/MJRefresh.bundle/arrow@2x"];
        }
        if (!arrowImage) {
            // 尝试从Bundle中加载
            NSBundle *mjBundle = [NSBundle bundleWithPath:[[NSBundle bundleForClass:[MJRefreshNormalHeader class]] pathForResource:@"MJRefresh" ofType:@"bundle"]];
            arrowImage = [UIImage imageNamed:@"arrow@2x" inBundle:mjBundle compatibleWithTraitCollection:nil];
        }
        if (!arrowImage) {
            // 如果没有找到MJRefresh的图片，尝试项目中的图片
            arrowImage = [UIImage imageNamed:@"arrow"];
        }
        if (!arrowImage) {
            // 如果还是没有，创建默认箭头
            arrowImage = [self createDefaultArrowImage];
        }
        header.arrowView.image = arrowImage;
        header.arrowView.hidden = NO; // 确保箭头可见
        header.arrowView.tintColor = [UIColor grayColor]; // 设置箭头颜色
        
        NSLog(@"在局🏹 [下拉刷新] 箭头图片设置结果: %@", arrowImage ? @"成功" : @"失败");
    }
    
    // 设置下拉刷新文本
    [header setTitle:@"下拉刷新" forState:MJRefreshStateIdle];
    [header setTitle:@"释放刷新" forState:MJRefreshStatePulling];
    [header setTitle:@"正在刷新..." forState:MJRefreshStateRefreshing];
    
    NSLog(@"在局🔄 [下拉刷新] 设置mj_header到scrollView");
    // 添加下拉刷新控件
    scrollView.mj_header = header;
    
    NSLog(@"在局✅ [下拉刷新] 下拉刷新控件设置完成，当前mj_header: %@", scrollView.mj_header);
}


- (void)setupLoadingIndicators {
    
    // 创建加载指示器 - 已禁用以实现更顺滑的加载体验
    // self.activityIndicatorView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    // self.activityIndicatorView.center = CGPointMake(self.view.bounds.size.width / 2, self.view.bounds.size.height / 2);
    // self.activityIndicatorView.hidesWhenStopped = YES;
    // [self.view addSubview:self.activityIndicatorView];
    
    // 创建进度条 - 已禁用以实现更顺滑的加载体验
    // self.progressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
    // self.progressView.frame = CGRectMake(0, 0, self.view.bounds.size.width, 3); // 增加高度到3像素
    // self.progressView.progressTintColor = [UIColor colorWithRed:0.2 green:0.6 blue:1.0 alpha:1.0];
    // self.progressView.trackTintColor = [UIColor colorWithRed:0.9 green:0.9 blue:0.9 alpha:0.5]; // 设置背景色让进度条更明显
    // self.progressView.hidden = YES;
    // self.progressView.alpha = 1.0;
    // self.progressView.transform = CGAffineTransformMakeScale(1.0f, 2.0f); // 增加进度条厚度
    // [self.view addSubview:self.progressView];
    
    // 设置进度条初始位置
    // [self updateProgressViewPosition];
    
}

// 更新进度条位置的专用方法 - 已禁用以实现更顺滑的加载体验
- (void)updateProgressViewPosition {
    // 进度条已禁用，无需更新位置
    return;
    
    /*
    if (!self.progressView) {
        return;
    }
    
    // 调整进度条位置到导航栏下方，确保贴紧标题栏底部
    if (self.navigationController && !self.navigationController.navigationBar.hidden) {
        // 使用Safe Area或传统方式计算导航栏底部位置
        CGFloat navBarBottom;
        if (@available(iOS 11.0, *)) {
            // iOS 11+ 使用Safe Area计算更准确的位置
            navBarBottom = self.view.safeAreaInsets.top;
        } else {
            // iOS 11以下使用传统计算方式
            CGFloat statusBarHeight = [UIApplication sharedApplication].statusBarFrame.size.height;
            CGFloat navBarHeight = self.navigationController.navigationBar.frame.size.height;
            navBarBottom = statusBarHeight + navBarHeight;
        }
        self.progressView.frame = CGRectMake(0, navBarBottom, self.view.bounds.size.width, 3);
    } else {
        // 如果没有导航栏，放在状态栏下方
        CGFloat statusBarHeight;
        if (@available(iOS 11.0, *)) {
            statusBarHeight = self.view.safeAreaInsets.top;
        } else {
            statusBarHeight = [UIApplication sharedApplication].statusBarFrame.size.height;
        }
        self.progressView.frame = CGRectMake(0, statusBarHeight, self.view.bounds.size.width, 3);
    }
    
    // 确保进度条始终在最上层
    [self.view bringSubviewToFront:self.progressView];
    */
}

- (void)loadNewData {
    NSLog(@"在局🔄 [下拉刷新] loadNewData方法被触发");
    
    // 调用JavaScript的下拉刷新事件
    NSLog(@"在局🔄 [下拉刷新] 准备调用JavaScript的pagePullDownRefresh");
    NSDictionary *callJsDic = [CustomHybridProcessor custom_objcCallJsWithFn:@"pagePullDownRefresh" data:nil];
    [self objcCallJs:callJsDic];
    NSLog(@"在局✅ [下拉刷新] JavaScript下拉刷新事件已发送");
    
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

        // 先记录当前索引，用于判断是否为重复点击
        NSInteger currentSelectedIndex = self.tabBarController.selectedIndex;
        BOOL isRepeatClick = (self.lastSelectedIndex == currentSelectedIndex);
        
        NSLog(@"在局🔄 [Tab通知] 当前tab: %ld, 上次tab: %d, 是否重复: %@", 
              (long)currentSelectedIndex, self.lastSelectedIndex, isRepeatClick ? @"是" : @"否");
        
        // 更新记录的索引
        self.lastSelectedIndex = (int)currentSelectedIndex;
        
        // 只有在重复点击同一个tab且页面已加载完成时才触发刷新
        if (isRepeatClick && self.isWebViewLoading) {
            if ([AFNetworkReachabilityManager manager].networkReachabilityStatus == AFNetworkReachabilityStatusNotReachable) {
                return;
            }
            
            
            // 如果当前已经在刷新中，先停止
            if ([self.webView.scrollView.mj_header isRefreshing]) {
                [self.webView.scrollView.mj_header endRefreshing];
            }
            
            // 开始刷新
            [self.webView.scrollView.mj_header beginRefreshing];
        } else {
            NSLog(@"在局ℹ️ [Tab切换] 切换到tab %ld，不触发刷新（上次: %d，重复: %@，页面加载: %@）", 
                  (long)currentSelectedIndex, self.lastSelectedIndex, isRepeatClick ? @"是" : @"否", 
                  self.isWebViewLoading ? @"是" : @"否");
        }
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
//    [[NSNotificationCenter defaultCenter] addObserverForName:@"NetworkPermissionRestored" object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
//        STRONG_SELF;
//        if (!self) return;
//        
//        NSLog(@"在局🔥 [XZWKWebViewBaseController] 收到网络权限恢复通知");
//        
//        // 如果是首页且WebView已经创建但可能未完成加载，重新触发JavaScript初始化
//        if (self.tabBarController.selectedIndex == 0 && self.webView) {
//            NSLog(@"在局🔄 [XZWKWebViewBaseController] 网络权限恢复，强制重新执行JavaScript初始化");
//            
//            // 重新触发JavaScript桥接初始化和pageReady
//            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
//                // 直接触发JavaScript桥接初始化
//                [self performJavaScriptBridgeInitialization];
//            });
//        }
//    }];
    // 监听网络权限恢复通知 - 修复Release版本首页空白问题
    [[NSNotificationCenter defaultCenter] addObserverForName:@"NetworkPermissionRestored" object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
        STRONG_SELF;
        if (!self) return;

        NSLog(@"在局🔥 [XZWKWebViewBaseController] 收到网络权限恢复通知");

        // 增加防重复处理机制
        static NSDate *lastNetworkRecoveryTime = nil;
        NSDate *now = [NSDate date];
        if (lastNetworkRecoveryTime && [now timeIntervalSinceDate:lastNetworkRecoveryTime] < 5.0) {
            NSLog(@"在局⚠️ [XZWKWebViewBaseController] 网络权限恢复通知过于频繁，跳过处理");
            return;
        }
        lastNetworkRecoveryTime = now;

        // 只对当前显示在窗口中的视图控制器进行操作，且必须是首页
        if (self.isViewLoaded && self.view.window && self.tabBarController.selectedIndex == 0) {
            NSLog(@"在局🔄 [网络恢复] 首页处理开始");
            
            // 1. 重置节流阀，允许重新加载
            lastLoadTime = nil;
            
            // 2. 停止当前加载
            if (self.webView) {
                NSLog(@"在局🛑 [网络恢复] 停止当前WebView加载");
                [self.webView stopLoading];
            }
            
            // 3. 重置加载状态
            self.isWebViewLoading = NO;
            self.isLoading = NO;
            
            // 4. 延迟执行加载操作
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), 
                dispatch_get_main_queue(), ^{
                // 再次检查是否仍然是首页
                if (self.tabBarController.selectedIndex == 0 && self.pinUrl) {
                    NSLog(@"在局🚀 [网络恢复] 开始重新加载首页内容");
                    // 如果WebView不存在，会在setupAndLoadWebViewIfNeeded中创建
                    [self setupAndLoadWebViewIfNeeded];
                } else {
                    NSLog(@"在局ℹ️ [网络恢复] 不是首页或URL为空，跳过加载");
                }
            });
        } else {
            NSLog(@"在局ℹ️ [网络恢复] 视图不在前台或不是首页，跳过处理");
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
    // 在 XZWKWebViewBaseController.m 的 addNotificationObservers 方法中
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        STRONG_SELF;
        if (!self) return;

        NSLog(@"在局🔔 [XZWKWebView] 应用进入活跃状态");

        // 同样调用统一的加载方法。
        // 它内部的检查会防止在已加载的情况下重复执行。
        [self setupAndLoadWebViewIfNeeded];
    }];
}

//- (void)setCustomUserAgent {
//    // 检查应用状态 - 确保在主线程访问UIApplication
//    __block UIApplicationState state;
//    if ([NSThread isMainThread]) {
//        state = [[UIApplication sharedApplication] applicationState];
//    } else {
//        dispatch_sync(dispatch_get_main_queue(), ^{
//            state = [[UIApplication sharedApplication] applicationState];
//        });
//    }
//    if (state != UIApplicationStateActive) {
//        NSLog(@"在局[XZWKWebView] 应用不在前台，跳过UserAgent设置");
//        return;
//    }
//    
//    // 直接设置UserAgent，避免执行JavaScript
//    NSString *customUserAgent = @"Mozilla/5.0 (iPhone; CPU iPhone OS 13_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/13.0 Mobile/15E148 Safari/604.1 XZApp/1.0";
//    dispatch_async(dispatch_get_main_queue(), ^{
//        self.webView.customUserAgent = customUserAgent;
//    });
//}
// 在 XZWKWebViewBaseController.m 中
- (void)setCustomUserAgent {
    // 直接定义一个完整的UserAgent字符串，防止异步等待和死锁的问题
    NSString *customUserAgent = @"Mozilla/5.0 (iPhone; CPU iPhone OS 13_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/13.0 Mobile/15E148 Safari/604.1 XZApp/1.0";
    
    // 直接在主线程上安全地设置它
    // 确保在主线程执行
    if ([NSThread isMainThread]) {
        self.webView.customUserAgent = customUserAgent;
        NSLog(@"✅ Custom UserAgent 已被直接设置");
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.webView.customUserAgent = customUserAgent;
            NSLog(@"✅ Custom UserAgent 已被直接设置 (dispatched to main)");
        });
    }
}
#pragma mark - WebView Management

- (void)addWebView {
    
    [self.view addSubview:self.webView];
    
    if (self.navigationController.viewControllers.count > 1) {
        NSLog(@"在局🔧 [addWebView] 内页模式，设置全屏约束");
        [self.webView mas_makeConstraints:^(MASConstraintMaker *make) {
            // 内页模式使用标准优先级约束，确保布局正确
            make.left.equalTo(self.view);
            make.right.equalTo(self.view);
            make.bottom.equalTo(self.view);
            make.top.equalTo(self.view);
        }];
    } else {
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"NoTabBar"]) {
            // 如果没有tabbar，将tabbar的frame设为0
            self.tabBarController.tabBar.frame = CGRectZero;
            [self.webView mas_makeConstraints:^(MASConstraintMaker *make) {
                make.left.equalTo(self.view).priority(999);
                make.right.equalTo(self.view).priority(999);
                make.bottom.equalTo(self.view).priority(999);
                make.top.equalTo(self.view).priority(999);
            }];
        } else {
            [self.webView mas_makeConstraints:^(MASConstraintMaker *make) {
                make.left.equalTo(self.view).priority(999);
                make.right.equalTo(self.view).priority(999);
                if (@available(iOS 11.0, *)) {
                    make.bottom.equalTo(self.view.mas_safeAreaLayoutGuideBottom).priority(999);
                } else {
                    make.bottom.equalTo(self.view).priority(999);
                }
                make.top.equalTo(self.view).priority(999);
            }];
        }
    }
    
    // 强制立即布局，确保WebView获得正确的frame
    [self.view setNeedsLayout];
    [self.view layoutIfNeeded];
    
    // 检查约束是否生效
    
    // 恢复下拉刷新控件（修复WebView重新创建后下拉刷新丢失的问题）
    NSLog(@"在局🔄 [addWebView] 检查并恢复下拉刷新控件");
    if (self.webView.scrollView && !self.webView.scrollView.mj_header) {
        NSLog(@"在局🔧 [addWebView] 下拉刷新控件缺失，重新设置");
        [self setupRefreshControl];
    } else if (self.webView.scrollView.mj_header) {
        NSLog(@"在局✅ [addWebView] 下拉刷新控件已存在");
    }
    
    // 确保进度条位置正确且始终在最上层
    if (self.progressView) {
        [self updateProgressViewPosition];
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
            CGSize screenSize = [UIScreen mainScreen].bounds.size;
            viewBounds = CGRectMake(0, 0, screenSize.width, screenSize.height);
            NSLog(@"在局⚠️ [addWebView] view.bounds也是零，使用屏幕尺寸: %@", NSStringFromCGRect(viewBounds));
        }
        
        // 根据页面类型调整frame
        if (self.navigationController.viewControllers.count > 1) {
            // 内页模式：全屏显示
            NSLog(@"在局🔧 [addWebView] 内页模式，设置全屏frame");
            self.webView.frame = viewBounds;
        } else {
            // 首页模式：需要考虑TabBar
            if (![[NSUserDefaults standardUserDefaults] boolForKey:@"NoTabBar"]) {
                viewBounds.size.height -= 83; // TabBar高度
                NSLog(@"在局🔧 [addWebView] 首页模式，预留TabBar空间");
            }
            self.webView.frame = viewBounds;
        }
        
        NSLog(@"在局✅ [addWebView] 手动设置WebView frame完成: %@", NSStringFromCGRect(self.webView.frame));
    } else {
        NSLog(@"在局✅ [addWebView] WebView约束生效，frame: %@", NSStringFromCGRect(self.webView.frame));
    }
}

- (void)loadWebBridge {
    
    // 使用成熟的WebViewJavascriptBridge库
    // 在Release版本也启用日志，以确保桥接正常工作
    [WKWebViewJavascriptBridge enableLogging];
    
    // 使用统一的桥接设置方法
    [self setupJavaScriptBridge];
    
    // 注册额外的处理器（如果需要）
    WEAK_SELF;
    
    // 注册用于调试的处理器
    [self.bridge registerHandler:@"debugLog" handler:^(id data, WVJBResponseCallback responseCallback) {
        if (responseCallback) {
            responseCallback(@{@"received": @YES});
        }
    }];
    
}



- (void)domainOperate {
    NSLog(@"在局🌐 domainOperate 被调用 - URL: %@", self.pinUrl);
    NSLog(@"在局🌐 domainOperate - webView存在: %@", self.webView ? @"YES" : @"NO");
    NSLog(@"在局🌐 domainOperate - isWebViewLoading: %@", self.isWebViewLoading ? @"YES" : @"NO");
    NSLog(@"在局🌐 domainOperate - tabIndex: %ld", (long)self.tabBarController.selectedIndex);
    NSLog(@"在局🌐 domainOperate - navigationController.viewControllers.count: %ld", (long)self.navigationController.viewControllers.count);
    
    // 强化防重复逻辑 - 如果WebView已有有效内容，不要重复加载
    // 但首次加载时（isExist为NO）应该继续加载
    if (self.isExist && [self hasValidWebViewContent]) {
        NSLog(@"在局✅ domainOperate - WebView已有有效内容，避免重复加载");
        
        // 如果已有内容，只触发pageShow事件
        if (self.webView && self.isLoading) {
            NSDictionary *callJsDic = [CustomHybridProcessor custom_objcCallJsWithFn:@"pageShow" data:nil];
            [self objcCallJs:callJsDic];
        }
        return;
    }
    
    // 防止频繁调用（与loadHTMLContent共享时间检查），但如果WebView未创建则允许执行
    NSDate *now = [NSDate date];
    if (lastLoadTime && [now timeIntervalSinceDate:lastLoadTime] < 2.0 && self.webView != nil) {
        NSLog(@"在局⚠️ domainOperate 调用过于频繁，跳过（间隔: %.2f秒）", [now timeIntervalSinceDate:lastLoadTime]);
        return;
    }
    
    NSLog(@"在局 🔧 [XZWKWebViewBaseController] 优化domainOperate - 使用异步文件I/O");
    
    // 只重置isLoading，不重置isWebViewLoading
    // isWebViewLoading应该在WebView创建流程中管理
    self.isLoading = NO;
    
    // 显示loading指示器
    dispatch_async(dispatch_get_main_queue(), ^{
        // [self.activityIndicatorView startAnimating]; // 已禁用loading指示器
    });
    
    // 延迟启动计时器，避免立即执行
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
//        [self listenToTimer];
    });
    
    // 在后台队列异步读取HTML文件，避免阻塞主线程
    NSLog(@"在局 🚀 [XZWKWebViewBaseController] 开始异步读取HTML文件");
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        NSString *filepath = [[BaseFileManager appH5LocailManifesPath] stringByAppendingPathComponent:@"app.html"];
        NSLog(@"在局📁 读取HTML文件: %@", filepath);
        
        if ([[NSFileManager defaultManager] fileExistsAtPath:filepath]) {
            NSError *error;
            NSString *htmlContent = [NSString stringWithContentsOfURL:[NSURL fileURLWithPath:filepath] encoding:NSUTF8StringEncoding error:&error];
            
            // 回到主线程处理结果
            dispatch_async(dispatch_get_main_queue(), ^{
                if (!error && htmlContent) {
                    NSLog(@"在局✅ HTML文件读取成功，长度: %ld", (long)htmlContent.length);
                    self.htmlStr = htmlContent;
                    
                    // 检查WebView是否已经创建
                    if (self.webView) {
                        NSLog(@"在局📝 [domainOperate] WebView已存在，开始加载HTML内容");
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
                NSLog(@"在局 HTML文件不存在: %@", filepath);
                self.networkNoteView.hidden = NO;
            });
        }
    });
}

- (void)loadHTMLContent {
    NSLog(@"在局🚀 [loadHTMLContent] 开始加载 - pinUrl: %@, isTabbarShow: %@", self.pinUrl, self.isTabbarShow ? @"YES" : @"NO");
    
    // 【性能优化】优先使用优化的HTML加载方法
    if (self.webView && (self.pinDataStr || [[self class] getCachedHTMLTemplate])) {
        NSLog(@"在局⚡ [性能优化] 使用优化的HTML加载方法");
        [self optimizedLoadHTMLContent];
        return;
    }
    
    // 检查WebView是否存在 - 如果不存在，等待viewWillAppear创建
    if (!self.webView) {
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
    
    // 应用与CustomHybridProcessor相同的修复逻辑
    if (_isDisappearing) {
        UIApplicationState appState = [[UIApplication sharedApplication] applicationState];
        BOOL isFromExternalApp = (appState == UIApplicationStateActive) && 
                               (self.view.window != nil) && 
                               (self.tabBarController != nil);
        
        if (isFromExternalApp) {
            NSLog(@"在局⚠️ [retryHTMLLoading] 检测到从外部App返回，忽略_isDisappearing标志，继续重试");
            _isDisappearing = NO;
        } else {
            NSLog(@"在局❌ [retryHTMLLoading] 页面正在真正消失，取消重试");
            return;
        }
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
    
    // 🔧 关键修复：在加载HTML前确保WebView frame正确
    if (CGRectIsEmpty(self.webView.frame) || self.webView.frame.size.width == 0) {
        NSLog(@"在局🔧 [performHTMLLoading] 检测到WebView frame异常: %@", NSStringFromCGRect(self.webView.frame));
        
        // 强制重新添加WebView以修复frame问题
        [self.webView removeFromSuperview];
        [self addWebView];
        
        NSLog(@"在局🔧 [performHTMLLoading] WebView重新添加后frame: %@", NSStringFromCGRect(self.webView.frame));
        
        // 如果仍然是0，直接返回，等待布局完成
        if (CGRectIsEmpty(self.webView.frame)) {
            NSLog(@"在局⚠️ [performHTMLLoading] WebView frame仍然异常，延迟重试");
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self performHTMLLoading];
            });
            return;
        }
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
                // 修复微信回调后的重建循环问题：
                // 当从外部App（如微信）返回时，_isDisappearing可能暂时为YES，
                // 但这不意味着页面真的在消失，需要检查更多条件
                if (self->_isDisappearing) {
                    // 检查是否是从外部App返回的情况
                    UIApplicationState appState = [[UIApplication sharedApplication] applicationState];
                    BOOL isFromExternalApp = (appState == UIApplicationStateActive) && 
                                           (self.view.window != nil) && 
                                           (self.tabBarController != nil);
                    
                    if (isFromExternalApp) {
                        NSLog(@"在局⚠️ [CustomHybridProcessor] 检测到从外部App返回，忽略_isDisappearing标志，继续执行");
                        // 重置标志，允许继续执行
                        self->_isDisappearing = NO;
                    } else {
                        NSLog(@"在局❌ [CustomHybridProcessor] 页面正在真正消失，终止回调执行");
                        return;
                    }
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
                
                // 防重复执行检查
                if (self.isLoadingInProgress) {
                    NSLog(@"在局⚠️ [DISPATCH-DEBUG] 检测到重复loadHTMLString任务，跳过执行");
                    return;
                }
                
                // 标记正在执行中
                self.isLoadingInProgress = YES;
                NSLog(@"在局🔒 [DISPATCH-DEBUG] 设置加载锁定状态");
                
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
                    
                    // 解除加载锁定状态（延迟解除，防止时序问题）
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        if (self) {
                            self.isLoadingInProgress = NO;
                            NSLog(@"在局🔓 [DISPATCH-DEBUG] 解除加载锁定状态 - 任务ID: %d", currentTaskId);
                        }
                    });
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
                        
                        // fallback执行后也解除锁定
                        if (self) {
                            self.isLoadingInProgress = NO;
                            NSLog(@"在局🔓 [FALLBACK] Fallback执行后解除加载锁定状态");
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
                    // 异常情况下也要解除加载锁定
                    if (self) {
                        self.isLoadingInProgress = NO;
                        NSLog(@"在局🔓 [DISPATCH-DEBUG] 异常情况下解除加载锁定状态");
                    }
                });
            }
        }];
    }
}

#pragma mark - Navigation

- (void)getnavigationBarTitleText:(NSString *)title {
    NSLog(@"在局🏷️ [标题设置] 收到标题: %@", title);
    NSLog(@"在局🏷️ [标题设置] 当前pinUrl: %@", self.pinUrl);
    NSLog(@"在局🏷️ [标题设置] 导航控制器: %@", self.navigationController);
    NSLog(@"在局🏷️ [标题设置] 当前navigationItem: %@", self.navigationItem);
    
    // 如果标题为空，根据URL尝试提取标题
    if (!title || title.length == 0 || [title isEqualToString:@"(null)"]) {
        NSString *fallbackTitle = @"详情";  // 默认标题
        
        // 尝试从URL中提取更有意义的标题
        if (self.pinUrl) {
            NSLog(@"在局🔍 [标题设置] 标题为空，从URL提取: %@", self.pinUrl);
            
            // 解析URL路径来生成标题
            if ([self.pinUrl containsString:@"/activity/"]) {
                fallbackTitle = @"活动详情";
            } else if ([self.pinUrl containsString:@"/news/"]) {
                fallbackTitle = @"新闻详情";
            } else if ([self.pinUrl containsString:@"/user/"]) {
                fallbackTitle = @"用户信息";
            } else if ([self.pinUrl containsString:@"/detail/"]) {
                fallbackTitle = @"详情";
            } else if ([self.pinUrl containsString:@"/list/"]) {
                fallbackTitle = @"列表";
            } else if ([self.pinUrl containsString:@"/p/"]) {
                // 进一步解析p路径
                NSArray *components = [self.pinUrl componentsSeparatedByString:@"/"];
                if (components.count >= 4) {
                    NSString *pageType = components[3]; // 获取 /p/ 后的第一个部分
                    if ([pageType isEqualToString:@"activity"]) {
                        fallbackTitle = @"活动详情";
                    } else if ([pageType isEqualToString:@"news"]) {
                        fallbackTitle = @"新闻详情";
                    } else if ([pageType isEqualToString:@"user"]) {
                        fallbackTitle = @"用户信息";
                    } else {
                        fallbackTitle = @"详情页";
                    }
                }
            }
            
            NSLog(@"在局🔍 [标题设置] URL分析结果: %@", fallbackTitle);
        } else {
            NSLog(@"在局⚠️ [标题设置] pinUrl为空，使用默认标题");
        }
        
        NSLog(@"在局✅ [标题设置] 使用备用标题: %@", fallbackTitle);
        self.navigationItem.title = fallbackTitle;
        
        // 强制刷新导航栏显示
        [self.navigationController.navigationBar setNeedsLayout];
        [self.navigationController.navigationBar layoutIfNeeded];
        NSLog(@"在局🔄 [标题设置] 已强制刷新导航栏显示");
    } else {
        NSLog(@"在局✅ [标题设置] 使用原标题: %@", title);
        self.navigationItem.title = title;
        
        // 强制刷新导航栏显示
        [self.navigationController.navigationBar setNeedsLayout];
        [self.navigationController.navigationBar layoutIfNeeded];
    }
    
    // 验证设置结果
    NSLog(@"在局🔍 [标题设置] 设置完成后的标题: %@", self.navigationItem.title);
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
                            // [strongSelf.activityIndicatorView stopAnimating]; // 已禁用loading指示器
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
        NSLog(@"在局✅ [pageReady] 当前控制器: %@", self);
        NSLog(@"在局✅ [pageReady] pinUrl: %@", self.pinUrl);
        NSLog(@"在局✅ [pageReady] tabIndex: %ld", (long)self.tabBarController.selectedIndex);
        NSLog(@"在局✅ [pageReady] navigationController.viewControllers.count: %ld", (long)self.navigationController.viewControllers.count);
        NSLog(@"在局✅ [pageReady] webView frame: %@", NSStringFromCGRect(self.webView.frame));
        NSLog(@"在局✅ [pageReady] isWebViewLoading之前: %@", self.isWebViewLoading ? @"YES" : @"NO");
        
        self.isLoading = YES;
        
        // 立即取消计时器，防止重复调用domainOperate
        dispatch_source_t timerToCancel = self.timer;
        if (timerToCancel) {
            self.timer = nil;
            dispatch_source_cancel(timerToCancel);
        }
        
        // 确保所有loading指示器都被隐藏
        dispatch_async(dispatch_get_main_queue(), ^{
            // [self.activityIndicatorView stopAnimating]; // 已禁用loading指示器
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
        
        // 通知页面显示完成 - pageReady完成后立即移除LoadingView，无论网络状态如何
        AppDelegate *appDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
        
        // 获取当前tab索引
        NSInteger currentTabIndex = self.tabBarController ? self.tabBarController.selectedIndex : -1;
        
        if (!appDelegate.networkRestricted) {
            NSLog(@"在局 🎯 [XZTabBarController] 网络正常，发送showTabviewController通知");
        } else {
            NSLog(@"在局 🎯 [XZTabBarController] 网络受限，但首页内容已准备好，移除LoadingView");
        }
        
        if (currentTabIndex == 0) {
            // 首页需要特殊处理：确保LoadingView移除完成后再允许数据请求
            [self ensureLoadingViewRemovedBeforeDataRequests];
        } else {
            // 其他tab直接发送通知
            [[NSNotificationCenter defaultCenter] postNotificationName:@"showTabviewController" object:self];
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
        
        // 检查并处理待处理的Universal Links
        [self processPendingUniversalLinkIfNeeded];
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
    // 【性能优化】使用简化的状态检查
    if (![self isReadyForJavaScriptExecution]) {
        NSLog(@"在局⚠️ [性能优化] JavaScript执行状态检查未通过");
        if (completionHandler) {
            NSError *error = [NSError errorWithDomain:@"XZWebView" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"JavaScript执行条件不满足"}];
            completionHandler(nil, error);
        }
        return;
    }
    
    // 检查页面是否正在消失（保留原有逻辑作为备用）
    if (_isDisappearing) {
        // 添加更多诊断信息
        UIApplicationState appState = [[UIApplication sharedApplication] applicationState];
        BOOL isShowingOnWindow = [self isShowingOnKeyWindow];
        BOOL hasWebView = (self.webView != nil);
        BOOL hasWindow = (self.view.window != nil);
        
        NSLog(@"在局⚠️ [JavaScript拒绝] _isDisappearing=YES, 应用状态=%ld, 显示中=%@, WebView=%@, Window=%@", 
              (long)appState, 
              isShowingOnWindow ? @"是" : @"否",
              hasWebView ? @"存在" : @"不存在", 
              hasWindow ? @"存在" : @"不存在");
        
        // 特殊情况：如果是手势返回取消的情况，允许执行
        // 🔧 修复：对于交互式转场恢复，不依赖isShowingOnWindow，因为转场期间可能暂时返回NO
        BOOL isInteractiveCancelled = hasWebView && hasWindow && 
                                     (appState == UIApplicationStateActive || appState == UIApplicationStateInactive);
        
        if (isInteractiveCancelled) {
            NSLog(@"在局🔧 [JavaScript修复] 检测到交互式转场取消，重置_isDisappearing并继续执行");
            NSLog(@"在局🔧 [JavaScript修复] 修复条件: hasWebView=%@, hasWindow=%@, appState=%ld", 
                  hasWebView ? @"YES" : @"NO", 
                  hasWindow ? @"YES" : @"NO", 
                  (long)appState);
            _isDisappearing = NO;
        } else {
            NSLog(@"在局[XZWKWebView] 页面正在消失，取消JavaScript执行");
            NSLog(@"在局❌ [JavaScript修复] 修复失败条件: hasWebView=%@, hasWindow=%@, appState=%ld", 
                  hasWebView ? @"YES" : @"NO", 
                  hasWindow ? @"YES" : @"NO", 
                  (long)appState);
            if (completionHandler) {
                NSError *error = [NSError errorWithDomain:@"XZWebView" code:-5 userInfo:@{NSLocalizedDescriptionKey: @"页面正在消失"}];
                completionHandler(nil, error);
            }
            return;
        }
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
    
    // 检查是否是交互式转场恢复场景
    BOOL isInteractiveTransitionRestore = [javaScriptString containsString:@"app.refreshPage"] ||
                                        [javaScriptString containsString:@"document.body.style.display"] ||
                                        [javaScriptString containsString:@"强制重新渲染页面"] ||
                                        [javaScriptString containsString:@"window.dispatchEvent"];
    
    // 检查控制器是否在活跃的window中（即使应用在后台，控制器可能仍在显示）
    BOOL isViewControllerActive = self.view.window != nil && 
                                 !self.view.window.hidden && 
                                 self.view.superview != nil &&
                                 [self isShowingOnKeyWindow];
    
    // 🔧 关键修复：交互式转场恢复期间，优先检查控制器可见性而不是应用状态
    if (isInteractiveTransitionRestore && isViewControllerActive) {
        NSLog(@"在局🔧 [JavaScript执行] 交互式转场恢复场景，控制器可见，强制允许执行: %.50@...", javaScriptString);
    } else if (state == UIApplicationStateBackground) {
        // 后台状态始终拒绝执行（除非是关键脚本）
        if (!isEssentialScript) {
            NSLog(@"在局[XZWKWebView] 应用在后台，取消非关键JavaScript执行");
            if (completionHandler) {
                NSError *error = [NSError errorWithDomain:@"XZWebView" code:-2 userInfo:@{NSLocalizedDescriptionKey: @"应用不在前台"}];
                completionHandler(nil, error);
            }
            return;
        }
    } else if (state == UIApplicationStateInactive && !isEssentialScript && !isInteractiveTransitionRestore && !isViewControllerActive) {
        // 非活跃状态下，只有当不是关键脚本、不是交互式转场恢复、控制器也不活跃时才拒绝
        NSLog(@"在局[XZWKWebView] 应用不在前台，取消非关键JavaScript执行");
        if (completionHandler) {
            NSError *error = [NSError errorWithDomain:@"XZWebView" code:-2 userInfo:@{NSLocalizedDescriptionKey: @"应用不在前台"}];
            completionHandler(nil, error);
        }
        return;
    } else if (state != UIApplicationStateActive && (isEssentialScript || isInteractiveTransitionRestore)) {
        NSLog(@"在局[XZWKWebView] 应用不在前台，但允许执行关键JavaScript (类型: %@): %.50@...", 
              isEssentialScript ? @"桥接脚本" : @"转场恢复脚本", javaScriptString);
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
        
        // 同样检查是否是交互式转场恢复场景
        BOOL isInteractiveTransitionRestoreInBlock = [javaScriptString containsString:@"app.refreshPage"] ||
                                                    [javaScriptString containsString:@"document.body.style.display"] ||
                                                    [javaScriptString containsString:@"强制重新渲染页面"] ||
                                                    [javaScriptString containsString:@"window.dispatchEvent"];
        
        // 🔧 关键修复：交互式转场恢复期间，优先检查控制器可见性
        BOOL isViewControllerActiveInBlock = strongSelf.view.window != nil && 
                                           !strongSelf.view.window.hidden && 
                                           strongSelf.view.superview != nil;
        
        if (isInteractiveTransitionRestoreInBlock && isViewControllerActiveInBlock) {
            // 交互式转场恢复场景，控制器可见，强制允许执行
        } else if (bgState != UIApplicationStateActive && !isEssentialInBlock && !isInteractiveTransitionRestoreInBlock) {
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
                    
                    // 🔧 修复手势返回空白页问题：检查是否为交互式转场恢复场景
                    BOOL isViewControllerActive = strongSelf.view.window != nil && 
                                                 !strongSelf.view.window.hidden && 
                                                 strongSelf.view.superview != nil &&
                                                 [strongSelf isShowingOnKeyWindow];
                    
                    // 检查是否在导航栈中（处理手势返回的情况）
                    BOOL isInNavigationStack = strongSelf.navigationController != nil &&
                                             [strongSelf.navigationController.viewControllers containsObject:strongSelf];
                    
                    // 🔧 修复逻辑：考虑更多的交互式转场场景
                    // 1. 应用在后台时始终拒绝
                    // 2. 应用非活跃但控制器在导航栈中且有window，允许执行（手势返回场景）
                    // 3. 其他情况下，非活跃且控制器不活跃时拒绝
                    if (currentState == UIApplicationStateBackground) {
                        NSLog(@"在局[XZWKWebView] 回调执行时应用已不在前台");
                        NSError *stateError = [NSError errorWithDomain:@"XZWebView" code:-3 userInfo:@{NSLocalizedDescriptionKey: @"回调执行时应用不在前台"}];
                        completionHandler(nil, stateError);
                        return;
                    } else if (currentState == UIApplicationStateInactive && 
                              !isViewControllerActive && 
                              !isInNavigationStack) {
                        NSLog(@"在局[XZWKWebView] 回调执行时应用不活跃且控制器不在导航栈中");
                        NSError *stateError = [NSError errorWithDomain:@"XZWebView" code:-3 userInfo:@{NSLocalizedDescriptionKey: @"回调执行时应用不在前台"}];
                        completionHandler(nil, stateError);
                        return;
                    }
                    
                    // 记录允许执行的情况
                    if (currentState != UIApplicationStateActive && isViewControllerActive) {
                        NSLog(@"在局[XZWKWebView] 应用状态非活跃但控制器活跃，允许执行回调（手势返回场景）");
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
    
    // 扩展关键操作列表，增加转场相关的操作
    BOOL isEssentialAction = [action isEqualToString:@"bridgeInit"] ||
                           [action isEqualToString:@"pageReady"] ||
                           [action isEqualToString:@"checkBridge"] ||
                           [action isEqualToString:@"pageShow"] ||
                           [action isEqualToString:@"setData"];
    
    // 在转场期间，应用状态可能短暂变为非活跃状态，但这并不意味着真正进入后台
    // 检查视图控制器是否在活跃的window中来判断真实状态
    BOOL isViewControllerActive = self.view.window != nil && 
                                 !self.view.window.hidden && 
                                 self.view.superview != nil;
    
    if (state != UIApplicationStateActive && !isEssentialAction && !isViewControllerActive) {
        NSLog(@"在局[XZWKWebView] 应用不在前台且控制器不活跃，跳过非关键objcCallJs: %@", action);
        return;
    } else if (state != UIApplicationStateActive && (isEssentialAction || isViewControllerActive)) {
        NSLog(@"在局[XZWKWebView] 应用状态非活跃但允许执行objcCallJs: %@ (关键操作: %@, 控制器活跃: %@)", action, isEssentialAction ? @"YES" : @"NO", isViewControllerActive ? @"YES" : @"NO");
    }
    
    // 确保在主线程执行
    dispatch_async(dispatch_get_main_queue(), ^{
        // 再次检查应用状态 - 已在主线程中
        UIApplicationState currentState = [[UIApplication sharedApplication] applicationState];
        BOOL isStillViewControllerActive = self.view.window != nil && 
                                          !self.view.window.hidden && 
                                          self.view.superview != nil;
        
        if (currentState != UIApplicationStateActive && !isEssentialAction && !isStillViewControllerActive) {
            NSLog(@"在局[XZWKWebView] 主线程检查：应用不在前台且控制器不活跃，取消非关键JavaScript调用");
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
    
    // 修复JavaScript代码字符串拼接格式
    NSString *javascriptCode = @"(function(){"
        "var result = {};"
        "result.bridgeExists = typeof WebViewJavascriptBridge !== 'undefined';"
        "result.appExists = typeof app !== 'undefined';"
        "result.pageReadyExists = typeof pageReady !== 'undefined';"
        "result.pageReadyCalled = window._pageReadyCalled === true;"
        "result.checkTime = new Date().getTime();"
        "if (!result.appExists || !result.bridgeExists) {"
        "    if (typeof initJavaScriptEnvironment === 'function') {"
        "        initJavaScriptEnvironment();"
        "        result.reinit = true;"
        "    }"
        "}"
        "if (!window._pageReadyCalled) {"
        "    window._pageReadyCalled = true;"
        "    if (window.WebViewJavascriptBridge && window.WebViewJavascriptBridge.callHandler) {"
        "        try {"
        "            window.WebViewJavascriptBridge.callHandler('pageReady', {"
        "                manual: true,"
        "                source: 'performJavaScriptBridgeInitialization',"
        "                timestamp: new Date().getTime()"
        "            }, function(response) {});"
        "            result.success = true;"
        "            result.method = 'callHandler';"
        "        } catch(e) {"
        "            result.error = e.message;"
        "        }"
        "    } else if (typeof pageReady === 'function') {"
        "        try {"
        "            pageReady();"
        "            result.success = true;"
        "            result.method = 'direct';"
        "        } catch(e) {"
        "            result.error = e.message;"
        "        }"
        "    } else {"
        "        result.error = 'environment_not_ready';"
        "        var event = new CustomEvent('pageReady', {detail: {manual: true}});"
        "        window.dispatchEvent(event);"
        "        result.fallback = 'custom_event';"
        "    }"
        "} else {"
        "    result.skipped = true;"
        "}"
        "return JSON.stringify(result);"
    "})()";
    
    NSLog(@"在局🔥 [JavaScript桥接初始化] 即将执行JavaScript代码，长度: %lu", (unsigned long)javascriptCode.length);
    
    [self safelyEvaluateJavaScript:javascriptCode completionHandler:^(id result, NSError *error) {
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
            if (error) {
                NSLog(@"在局❌ [JavaScript桥接初始化] 错误详情: %@", error);
                NSLog(@"在局❌ [JavaScript桥接初始化] 错误代码: %ld", (long)error.code);
                NSLog(@"在局❌ [JavaScript桥接初始化] 错误域: %@", error.domain);
            }
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
        // [self.activityIndicatorView stopAnimating]; // 已禁用loading指示器
    });
    
    // 添加白屏检测机制
    NSLog(@"在局 🔧 [XZWKWebViewBaseController] 添加WebView白屏检测");
    [self scheduleJavaScriptTask:^{
        [self detectBlankWebView];
    } afterDelay:1.0];
    
    // 延迟处理JavaScript桥接初始化，确保页面完全加载
    [self scheduleJavaScriptTask:^{
        NSLog(@"在局🌉 [didFinishNavigation] 开始执行JavaScript桥接初始化");
        [self performJavaScriptBridgeInitialization];
    } afterDelay:0.5];
    
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
        // [self.activityIndicatorView stopAnimating]; // 已禁用loading指示器
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
        // [self.activityIndicatorView stopAnimating]; // 已禁用loading指示器
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
        // [self.activityIndicatorView startAnimating]; // 已禁用loading指示器
        // self.progressView.hidden = NO; // 已禁用进度条
        // self.progressView.progress = 0.1; // 已禁用进度条 // 设置初始进度，让用户知道开始加载
        
        // 确保进度条在最上层
        [self.view bringSubviewToFront:self.progressView];
        [self.view bringSubviewToFront:self.activityIndicatorView];
        
        NSLog(@"在局📊 [didStartProvisionalNavigation] 页面开始加载（进度条已禁用）");
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
                // self.progressView.hidden = NO; // 已禁用进度条
                // [self.progressView setProgress:progress animated:YES]; // 已禁用进度条
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
    
    // 如果页面正在消失，不处理超时
    if (_isDisappearing) {
        NSLog(@"在局⏰ [加载超时] 页面正在消失，忽略超时检查");
        return;
    }
    
    // 检查是否触发了navigation delegate
    NSDate *startTime = objc_getAssociatedObject(self, @selector(startWebViewLoadingMonitor));
    NSTimeInterval elapsed = [[NSDate date] timeIntervalSinceDate:startTime];
    
    NSLog(@"在局⏰ [加载超时] 距离loadHTMLString调用已过去: %.2f秒", elapsed);
    NSLog(@"在局⏰ [加载超时] isWebViewLoading状态: %@", self.isWebViewLoading ? @"YES" : @"NO");
    
    // 更严格的死亡状态判断
    BOOL isReallyDead = !self.isWebViewLoading && 
                        elapsed > 5.0 && // 增加最小时间要求
                        self.webView && 
                        !self.webView.isLoading && 
                        self.webView.navigationDelegate != nil; // 确保delegate存在
    
    if (isReallyDead) {
        NSLog(@"在局⚠️ [WebView状态] WebView需要重建，详细状态: elapsed=%.2f, webView.isLoading=%@, delegate=%@", 
              elapsed, self.webView.isLoading ? @"YES" : @"NO", self.webView.navigationDelegate);
        
        // 强制重建WebView
        [self forceRebuildWebViewForDeadState];
    } else {
        NSLog(@"在局✅ [加载超时] WebView状态正常或未达到重建条件，继续等待");
        
        // 如果不是真正的死亡状态，可以再等待一段时间
        if (elapsed < 10.0) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                if (!self->_isDisappearing && !self.isWebViewLoading) {
                    NSLog(@"在局⏰ [二次检查] 继续检查WebView状态");
                    [self webViewLoadingTimeout];
                }
            });
        }
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
    
    // 不再手动注入桥接脚本，而是触发JavaScript环境的重新初始化
    NSString *bridgeInitScript = @"(function(){"
        "try {"
            "// 检查是否存在wx.app.connect方法"
            "if (window.wx && window.wx.app && typeof window.wx.app.connect === 'function') {"
                "// 重新调用wx.app.connect来建立桥接连接"
                "window.wx.app.connect(function() {"
                    "console.log('在局 ✅ [桥接重连] wx.app.connect回调被触发');"
                    "// 桥接连接完成后立即触发pageReady"
                    "if (typeof window.webViewCall === 'function') {"
                        "window.webViewCall('pageReady', {});"
                    "}"
                "});"
                "return 'reinit_triggered';"
            "} else if (window.WebViewJavascriptBridge) {"
                "// 桥接已存在"
                "return 'already_exists';"
            "} else {"
                "// 环境未准备好"
                "return 'environment_not_ready';"
            "}"
        "} catch(e) {"
            "return 'error: ' + e.message;"
        "}"
    "})()";
    
    [self safelyEvaluateJavaScript:bridgeInitScript completionHandler:^(id result, NSError *error) {
        if (error) {
            NSLog(@"在局 ❌ [桥接注入] 脚本执行失败: %@", error.localizedDescription);
            NSLog(@"在局 ❌ [桥接注入] 错误详情: %@", error);
        } else {
            NSLog(@"在局 ✅ [桥接注入] 脚本执行结果: %@", result);
            
            // 如果环境未准备好，延迟重试
            if ([result isEqualToString:@"environment_not_ready"]) {
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [self performJavaScriptBridgeInitialization];
                });
            }
        }
    }];
}

// 强制重建WebView（针对死亡状态）
- (void)forceRebuildWebViewForDeadState {
    NSLog(@"在局💀 [强制重建] 检测到WebView死亡状态，执行强制重建！");
    
    // 添加循环重建防护机制
    static NSDate *lastForceRebuildTime = nil;
    static NSInteger rebuildCount = 0;
    NSDate *now = [NSDate date];
    
    if (lastForceRebuildTime && [now timeIntervalSinceDate:lastForceRebuildTime] < 10.0) {
        rebuildCount++;
        if (rebuildCount > 3) {
            NSLog(@"在局🚨 [强制重建] 检测到循环重建，停止强制重建！已重建%ld次", (long)rebuildCount);
            return;
        }
    } else {
        rebuildCount = 1;
    }
    lastForceRebuildTime = now;
    
    NSLog(@"在局💀 [强制重建] 开始第%ld次强制重建", (long)rebuildCount);
    
    // 检查页面是否正在消失（如果正在消失，不应该重建）
    if (_isDisappearing) {
        NSLog(@"在局❌ [强制重建] 页面正在消失，取消强制重建");
        return;
    }
    
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

#pragma mark - Universal Links处理

/**
 * 处理Universal Links导航通知
 * @param notification 通知对象，包含路径信息
 */
- (void)handleUniversalLinkNavigation:(NSNotification *)notification {
    NSString *path = notification.userInfo[@"path"];
    if (!path) {
        NSLog(@"在局❌ [Universal Links] 路径为空");
        return;
    }
    
    NSLog(@"在局📱 [Universal Links] WebView收到导航请求: %@", path);
    
    // 确保在主线程执行
    dispatch_async(dispatch_get_main_queue(), ^{
        [self navigateToUniversalLinkPath:path];
    });
}

/**
 * 导航到Universal Link路径
 * @param path 目标路径
 */
- (void)navigateToUniversalLinkPath:(NSString *)path {
    [self navigateToUniversalLinkPath:path retryCount:0];
}

/**
 * 导航到Universal Link路径（带重试计数）
 * @param path 目标路径
 * @param retryCount 重试次数
 */
- (void)navigateToUniversalLinkPath:(NSString *)path retryCount:(NSInteger)retryCount {
    NSLog(@"在局🧭 [Universal Links] 开始导航到路径: %@, 重试次数: %ld", path, (long)retryCount);
    
    // 防止无限重试
    if (retryCount >= 5) {
        NSLog(@"在局❌ [Universal Links] 重试次数过多，放弃导航: %@", path);
        return;
    }
    
    // 检查WebView是否已创建并加载完成
    if (!self.webView) {
        // 保存路径，等待WebView创建完成后处理
        objc_setAssociatedObject(self, @"PendingUniversalLinkPath", path, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return;
    }
    
    if (self.isWebViewLoading || !self.isCreat) {
        NSLog(@"在局⏳ [Universal Links] WebView正在加载，延迟导航 (重试: %ld)", (long)retryCount);
        // 延迟处理，增加重试计数
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self navigateToUniversalLinkPath:path retryCount:retryCount + 1];
        });
        return;
    }
    
    // 通过JavaScript桥接通知H5页面进行路由跳转
    NSString *jsFunction = @"handleUniversalLinkNavigation";
    NSDictionary *params = @{
        @"path": path,
        @"timestamp": @([[NSDate date] timeIntervalSince1970])
    };
    
    // 构造JavaScript调用
    NSDictionary *callInfo = @{
        @"fn": jsFunction,
        @"data": params
    };
    
    NSLog(@"在局📡 [Universal Links] 通知H5页面处理路由: %@", callInfo);
    
    // 执行JavaScript调用
    [self objcCallJs:callInfo];
    
    // 清除待处理的路径
    objc_setAssociatedObject(self, @"PendingUniversalLinkPath", nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

/**
 * 检查并处理待处理的Universal Link路径
 * 在WebView创建完成后调用
 */
- (void)processPendingUniversalLinkIfNeeded {
    NSString *pendingPath = objc_getAssociatedObject(self, @"PendingUniversalLinkPath");
    if (pendingPath) {
        NSLog(@"在局🔄 [Universal Links] 处理待处理的路径: %@", pendingPath);
        [self navigateToUniversalLinkPath:pendingPath];
    }
}

// 首页专用修复方案 - 解决第二次启动JavaScript桥接失败问题
- (void)performHomepageSpecialFix {
    NSLog(@"在局🏠 [首页修复] ========== 开始首页专用修复 ==========");
    
    // 不再清理桥接，而是检查并确保桥接正常
    if (!self.bridge) {
        NSLog(@"在局🏠 [首页修复] 桥接不存在，需要创建");
        [self setupJavaScriptBridge];
    } else {
        NSLog(@"在局🏠 [首页修复] 桥接已存在，保持现有设置");
    }
    
    // 延迟执行桥接初始化，给页面加载一些时间
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSLog(@"在局🏠 [首页修复] 开始执行延迟的桥接初始化");
        
        // 执行桥接初始化
        [self performJavaScriptBridgeInitialization];
        
        // 设置后备检查机制
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self performHomepageFallbackCheck];
        });
    });
    
    NSLog(@"在局🏠 [首页修复] ========== 首页修复方案已启动 ==========");
}

// 首页后备检查机制
- (void)performHomepageFallbackCheck {
    NSLog(@"在局🏠 [首页后备] 开始后备检查");
    
    // 检查JavaScript环境
    [self safelyEvaluateJavaScript:@"typeof window.WebViewJavascriptBridge !== 'undefined'" completionHandler:^(id result, NSError *error) {
        if (error || ![result boolValue]) {
            NSLog(@"在局🏠 [首页后备] JavaScript桥接仍然失败，执行最终修复");
            
            // 最终修复：不能使用window.location.reload()，因为会导致加载baseURL（目录）
            // 应该重新调用domainOperate方法来重新加载HTML内容
            NSLog(@"在局🏠 [首页后备] 重新执行domainOperate方法");
            
            dispatch_async(dispatch_get_main_queue(), ^{
                if (self && !self.isWebViewLoading) {
                    [self domainOperate];
                } else {
                    NSLog(@"在局🏠 [首页后备] WebView正在加载中或self已释放，跳过重载");
                }
            });
        } else {
            NSLog(@"在局🏠 [首页后备] JavaScript桥接正常");
        }
    }];
}

// 确保LoadingView移除完成后再允许数据请求
- (void)ensureLoadingViewRemovedBeforeDataRequests {
    NSLog(@"在局🏠 [首页时序] 开始确保LoadingView移除完成后再允许数据请求");
    
    AppDelegate *appDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
    
    // 首先直接尝试移除LoadingView（如果还存在）
    if (!appDelegate.isLoadingViewRemoved) {
        NSLog(@"在局🏠 [首页时序] LoadingView仍存在，立即移除");
        [appDelegate removeGlobalLoadingViewWithReason:@"首页pageReady完成"];
    }
    
    // 发送通知确保TabBar控制器也处理LoadingView移除
    NSLog(@"在局🏠 [首页时序] 发送showTabviewController通知");
    [[NSNotificationCenter defaultCenter] postNotificationName:@"showTabviewController" object:self];
    
    // 使用更频繁的检查（0.05秒间隔）以减少延迟
    __weak typeof(self) weakSelf = self;
    NSTimer *checkTimer = [NSTimer scheduledTimerWithTimeInterval:0.05 repeats:YES block:^(NSTimer * _Nonnull timer) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            [timer invalidate];
            return;
        }
        
        AppDelegate *appDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
        BOOL loadingViewRemoved = appDelegate.isLoadingViewRemoved;
        
        NSLog(@"在局🏠 [首页时序] 检查LoadingView状态: %@", loadingViewRemoved ? @"已移除" : @"仍存在");
        
        if (loadingViewRemoved) {
            NSLog(@"在局✅ [首页时序] LoadingView已移除，允许数据请求");
            [timer invalidate];
            
            // LoadingView已移除，现在可以安全地允许数据请求
            // 通过JavaScript通知页面可以开始数据请求
            dispatch_async(dispatch_get_main_queue(), ^{
                [strongSelf notifyPageDataRequestsAllowed];
            });
        } else {
            // 设置最大等待时间（2.5秒）：0.05秒 * 50 = 2.5秒
            static NSInteger checkCount = 0;
            checkCount++;
            if (checkCount > 50) {
                NSLog(@"在局⚠️ [首页时序] LoadingView移除等待超时，强制允许数据请求");
                [timer invalidate];
                checkCount = 0; // 重置计数器
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    [strongSelf notifyPageDataRequestsAllowed];
                });
            }
        }
    }];
}

// 通知页面可以开始数据请求
- (void)notifyPageDataRequestsAllowed {
    NSLog(@"在局🚀 [首页时序] 通知页面可以开始数据请求");
    
    // 向JavaScript发送允许数据请求的信号
    NSString *jsCode = @"(function(){"
        "try {"
            "// 设置全局标志，表示LoadingView已移除，可以进行数据请求"
            "window.loadingViewRemoved = true;"
            "// 触发数据请求事件"
            "if (typeof window.onLoadingViewRemoved === 'function') {"
                "window.onLoadingViewRemoved();"
            "}"
            "// 发送自定义事件"
            "var event = new CustomEvent('loadingViewRemoved', {"
                "detail: { timestamp: Date.now() }"
            "});"
            "window.dispatchEvent(event);"
            "return 'LoadingView移除通知已发送';"
        "} catch(e) {"
            "return 'LoadingView移除通知发送失败: ' + e.message;"
        "}"
    "})()";
    
    [self safelyEvaluateJavaScript:jsCode completionHandler:^(id result, NSError *error) {
        if (error) {
            NSLog(@"在局❌ [首页时序] 通知数据请求允许失败: %@", error.localizedDescription);
        } else {
            NSLog(@"在局✅ [首页时序] 通知数据请求允许成功: %@", result);
        }
    }];
}

// 交互式转场后的WebView状态恢复
- (void)restoreWebViewStateAfterInteractiveTransition {
    NSLog(@"在局🔙 [交互式转场恢复] 开始恢复WebView状态");
    NSLog(@"在局🔙 [交互式转场恢复] 当前控制器: %@", self);
    NSLog(@"在局🔙 [交互式转场恢复] pinUrl: %@", self.pinUrl);
    NSLog(@"在局🔙 [交互式转场恢复] isWebViewLoading: %@", self.isWebViewLoading ? @"YES" : @"NO");
    NSLog(@"在局🔙 [交互式转场恢复] isExist: %@", self.isExist ? @"YES" : @"NO");
    NSLog(@"在局🔙 [交互式转场恢复] tabBarController.selectedIndex: %ld", (long)self.tabBarController.selectedIndex);
    
    // 🔧 关键修复：重置_isDisappearing标志，允许JavaScript执行
    NSLog(@"在局🔧 [交互式转场恢复] 重置_isDisappearing标志: %@ -> NO", _isDisappearing ? @"YES" : @"NO");
    _isDisappearing = NO;
    
    if (!self.webView) {
        NSLog(@"在局⚠️ [交互式转场恢复] WebView不存在，无需恢复");
        return;
    }
    
    // 检查应用状态并记录详细信息
    UIApplicationState appState = [[UIApplication sharedApplication] applicationState];
    NSString *stateStr = @"Unknown";
    switch (appState) {
        case UIApplicationStateActive:
            stateStr = @"Active";
            break;
        case UIApplicationStateInactive:
            stateStr = @"Inactive";
            break;
        case UIApplicationStateBackground:
            stateStr = @"Background";
            break;
    }
    
    NSLog(@"在局🔍 [交互式转场恢复] 应用状态: %@ (%ld)", stateStr, (long)appState);
    NSLog(@"在局🔍 [交互式转场恢复] 控制器是否显示: %@", [self isShowingOnKeyWindow] ? @"是" : @"否");
    NSLog(@"在局🔍 [交互式转场恢复] WebView frame: %@", NSStringFromCGRect(self.webView.frame));
    NSLog(@"在局🔍 [交互式转场恢复] WebView hidden: %@, alpha: %.2f", self.webView.hidden ? @"是" : @"否", self.webView.alpha);
    
    BOOL isAppActive = (appState == UIApplicationStateActive);
    // 修复：对于手势返回取消的场景，即使应用状态为Inactive也应该执行恢复
    BOOL shouldExecuteRestore = isAppActive || [self isShowingOnKeyWindow];
    
    // 🔧 关键修复：交互式转场期间不依赖应用状态，直接检查控制器可见性
    // 手势返回过程中，系统可能错误地报告应用状态为后台，但实际上控制器仍然可见
    // 特别处理：手势返回刚完成时，isShowingOnKeyWindow可能暂时返回false，但控制器实际上是可见的
    BOOL isInNavigationStack = self.navigationController && 
                              [self.navigationController.viewControllers containsObject:self];
    BOOL hasValidWindow = (self.view.window != nil && !self.view.window.hidden);
    BOOL isViewControllerActive = hasValidWindow && isInNavigationStack && !self.view.isHidden && self.view.alpha > 0.01;
    
    // 如果是首页，额外检查是否在导航栈顶部
    BOOL isTopViewController = (self.navigationController.topViewController == self) || 
                              (self.navigationController.viewControllers.count == 1 && [self.navigationController.viewControllers containsObject:self]);
    
    // 🔧 新增：对于手势返回场景，我们应该更宽松地判断是否需要执行恢复
    // 即使isShowingOnKeyWindow暂时返回false，只要控制器在导航栈中且有窗口，就应该恢复
    BOOL isInteractiveGestureReturn = hasValidWindow && isInNavigationStack;
    
    // 最终决策：只要控制器在导航栈中且有有效窗口，就执行恢复
    BOOL shouldExecuteRestoreForced = isViewControllerActive || 
                                     (isTopViewController && hasValidWindow) ||
                                     isInteractiveGestureReturn;
    
    NSLog(@"在局🔧 [交互式转场恢复] 强制执行恢复逻辑详细状态:");
    NSLog(@"在局🔧 [详细诊断] isShowingOnKeyWindow: %@", [self isShowingOnKeyWindow] ? @"是" : @"否");
    NSLog(@"在局🔧 [详细诊断] isInNavigationStack: %@", isInNavigationStack ? @"是" : @"否");
    NSLog(@"在局🔧 [详细诊断] hasValidWindow: %@", hasValidWindow ? @"是" : @"否");
    NSLog(@"在局🔧 [详细诊断] isViewControllerActive: %@", isViewControllerActive ? @"是" : @"否");
    NSLog(@"在局🔧 [详细诊断] isTopViewController: %@", isTopViewController ? @"是" : @"否");
    NSLog(@"在局🔧 [详细诊断] isInteractiveGestureReturn: %@", isInteractiveGestureReturn ? @"是" : @"否");
    NSLog(@"在局🔧 [详细诊断] shouldExecuteRestoreForced: %@", shouldExecuteRestoreForced ? @"是" : @"否");
    
    // 1. 确保WebView的基本状态正确
    self.webView.hidden = NO;
    self.webView.alpha = 1.0;
    self.webView.userInteractionEnabled = YES;
    
    // 🔧 关键修复：强制WebView重新渲染
    NSLog(@"在局🔧 [强制渲染] 开始强制WebView重新渲染");
    self.webView.backgroundColor = [UIColor whiteColor];
    [self.webView setNeedsDisplay];
    [self.webView setNeedsLayout];
    [self.webView layoutIfNeeded];
    
    // 🔧 新增：强制重新渲染通过移除和重新添加WebView
    NSLog(@"在局🔧 [强制渲染] 通过移除和重新添加WebView强制重渲染");
    UIView *webViewSuperview = self.webView.superview;
    CGRect webViewFrame = self.webView.frame;
    [self.webView removeFromSuperview];
    [webViewSuperview addSubview:self.webView];
    self.webView.frame = webViewFrame;
    
    // 🔧 修复：恢复下拉刷新控件（因为WebView被重新添加）
    NSLog(@"在局🔄 [强制渲染] 检查并恢复下拉刷新控件");
    if (self.webView.scrollView && !self.webView.scrollView.mj_header) {
        NSLog(@"在局🔧 [强制渲染] 下拉刷新控件缺失，重新设置");
        [self setupRefreshControl];
    }
    
    // 2. 确保WebView在视图层级中的正确位置
    [self.view bringSubviewToFront:self.webView];
    
    // 🔧 强制移除可能的遮挡视图
    NSLog(@"在局🔧 [视图诊断] 检查WebView上层的视图");
    for (UIView *subview in self.view.subviews) {
        if (subview != self.webView && subview != self.progressView && subview != self.activityIndicatorView) {
            NSLog(@"在局🔍 [视图诊断] 发现其他子视图: %@ - frame: %@, hidden: %@, alpha: %.2f", 
                  NSStringFromClass([subview class]), 
                  NSStringFromCGRect(subview.frame),
                  subview.hidden ? @"YES" : @"NO",
                  subview.alpha);
            
            // 如果有可能遮挡WebView的视图，临时隐藏
            if (!subview.hidden && subview.alpha > 0.1 && CGRectIntersectsRect(subview.frame, self.webView.frame)) {
                NSLog(@"在局⚠️ [视图诊断] 发现可能遮挡WebView的视图，临时隐藏: %@", NSStringFromClass([subview class]));
                subview.hidden = YES;
            }
        }
    }
    
    // 🔧 新增：通过UIKit强制重新渲染整个视图层级
    NSLog(@"在局🔧 [强制渲染] 强制重新渲染整个视图控制器");
    [self.view setNeedsDisplay];
    [self.view setNeedsLayout];
    [self.view layoutIfNeeded];
    
    // 🔧 新增：通过CALayer强制重渲染
    NSLog(@"在局🔧 [强制渲染] 通过CALayer强制重渲染WebView");
    [self.webView.layer setNeedsDisplay];
    [self.webView.layer displayIfNeeded];
    
    // 🔧 新增：检查WebView的内容大小和滚动位置
    if ([self.webView isKindOfClass:[WKWebView class]]) {
        WKWebView *wkWebView = (WKWebView *)self.webView;
        NSLog(@"在局🔍 [视图诊断] WebView scrollView contentSize: %@", NSStringFromCGSize(wkWebView.scrollView.contentSize));
        NSLog(@"在局🔍 [视图诊断] WebView scrollView contentOffset: %@", NSStringFromCGPoint(wkWebView.scrollView.contentOffset));
        NSLog(@"在局🔍 [视图诊断] WebView scrollView bounds: %@", NSStringFromCGRect(wkWebView.scrollView.bounds));
        
        // 注释掉强制重置滚动位置的代码，避免页面切换时滚动到顶部
        // wkWebView.scrollView.contentOffset = CGPointZero;
        [wkWebView.scrollView setNeedsDisplay];
        [wkWebView.scrollView setNeedsLayout];
        [wkWebView.scrollView layoutIfNeeded];
    }
    
    // 3. 检查并恢复WebView的布局 - 关键修复：强制重新应用约束
    if (CGRectIsEmpty(self.webView.frame) || self.webView.frame.size.width == 0) {
        NSLog(@"在局🔧 [交互式转场恢复] WebView frame异常: %@，强制重新布局", NSStringFromCGRect(self.webView.frame));
        
        // 强制移除并重新添加WebView以修复约束问题
        [self.webView removeFromSuperview];
        [self addWebView]; // 这个方法会重新设置所有约束
        
        NSLog(@"在局🔧 [布局修复] WebView重新添加后frame: %@", NSStringFromCGRect(self.webView.frame));
        
        // 如果还是0，手动设置frame
        if (CGRectIsEmpty(self.webView.frame)) {
            CGRect targetFrame = self.view.bounds;
            if (self.navigationController.viewControllers.count > 1) {
                // 内页模式，全屏显示
                targetFrame = self.view.bounds;
            } else {
                // 首页模式，需要考虑TabBar
                if (![[NSUserDefaults standardUserDefaults] boolForKey:@"NoTabBar"]) {
                    targetFrame.size.height -= 83; // TabBar高度
                }
            }
            
            NSLog(@"在局🔧 [布局修复] 手动设置WebView frame: %@", NSStringFromCGRect(targetFrame));
            self.webView.frame = targetFrame;
        }
    }
    
    // 4. 强制刷新WebView内容（关键修复）
    NSLog(@"在局🔧 [JavaScript执行检查] shouldExecuteRestoreForced = %@", shouldExecuteRestoreForced ? @"是" : @"否");
    if (shouldExecuteRestoreForced) {
        NSLog(@"在局🔧 [交互式转场恢复] 开始执行JavaScript恢复脚本");
        NSString *refreshScript = @"(function() {"
            "try {"
                "console.log('开始强制页面恢复操作');"
                "var result = {};"
                "// 强制显示所有隐藏的内容"
                "if (document.body) {"
                    "document.body.style.visibility = 'visible';"
                    "document.body.style.opacity = '1';"
                    "document.body.style.display = 'block';"
                    "result.bodyVisible = true;"
                "}"
                "// 强制刷新所有元素的显示状态"
                "var allElements = document.querySelectorAll('*');"
                "for (var i = 0; i < allElements.length; i++) {"
                    "var elem = allElements[i];"
                    "if (elem.style.display === 'none' && !elem.classList.contains('hidden')) {"
                        "elem.style.display = 'block';"
                    "}"
                    "if (elem.style.visibility === 'hidden') {"
                        "elem.style.visibility = 'visible';"
                    "}"
                "}"
                "result.elementsProcessed = allElements.length;"
                "// 强制重新渲染"
                "if (document.body) {"
                    "document.body.offsetHeight;" // 触发重排
                "}"
                "// 尝试调用应用的刷新方法"
                "if (typeof app !== 'undefined' && app.loaded) {"
                    "if (typeof app.refreshPage === 'function') {"
                        "app.refreshPage();"
                        "result.appRefresh = 'called';"
                    "} else {"
                        "result.appRefresh = 'not_available';"
                    "}"
                "} else {"
                    "result.appRefresh = 'app_not_ready';"
                "}"
                "return JSON.stringify(result);"
            "} catch(e) {"
                "return 'WebView刷新失败: ' + e.message;"
            "}"
        "})()";
        
        [self safelyEvaluateJavaScript:refreshScript completionHandler:^(id result, NSError *error) {
            if (error) {
                NSLog(@"在局⚠️ [交互式转场恢复] 第一步JavaScript执行失败: %@", error.localizedDescription);
            } else {
                NSLog(@"在局✅ [交互式转场恢复] 第一步JavaScript执行成功: %@", result);
            }
        }];
    } else {
        NSLog(@"在局⚠️ [交互式转场恢复] 控制器状态不合适，跳过JavaScript执行");
        NSLog(@"在局⚠️ [跳过原因] shouldExecuteRestoreForced=NO, 详见上面的详细诊断");
    }
    
    // 5. 触发页面刷新以恢复内容显示（关键修复）
    NSLog(@"在局🔧 [页面刷新检查] shouldExecuteRestoreForced = %@", shouldExecuteRestoreForced ? @"是" : @"否");
    if (shouldExecuteRestoreForced) {
        NSLog(@"在局🔧 [交互式转场恢复] 开始执行页面恢复JavaScript");
        [self safelyEvaluateJavaScript:@"(function(){"
            "try {"
                "console.log('开始深度页面恢复操作');"
                "var result = {};"
                "// 强制重新渲染页面"
                "if (document.body) {"
                    "document.body.style.display = 'none';"
                    "document.body.offsetHeight;" // 强制重排
                    "document.body.style.display = 'block';"
                    "document.body.style.visibility = 'visible';"
                    "document.body.style.opacity = '1';"
                    "result.bodyRestored = true;"
                "}"
                "// 强制所有主要容器可见"
                "var containers = document.querySelectorAll('div, section, main, article');"
                "var containerCount = 0;"
                "for (var i = 0; i < containers.length; i++) {"
                    "var container = containers[i];"
                    "if (container.style.display === 'none' || container.style.visibility === 'hidden') {"
                        "container.style.display = 'block';"
                        "container.style.visibility = 'visible';"
                        "container.style.opacity = '1';"
                        "containerCount++;"
                    "}"
                "}"
                "result.containersRestored = containerCount;"
                "// 触发多种重新渲染事件"
                "if (typeof window.dispatchEvent === 'function') {"
                    "window.dispatchEvent(new Event('resize'));"
                    "window.dispatchEvent(new Event('orientationchange'));"
                    "window.dispatchEvent(new Event('visibilitychange'));"
                    "result.eventsTriggered = true;"
                "}"
                "// 如果存在页面显示函数，调用它"
                "if (typeof window.onPageShow === 'function') { window.onPageShow(); result.onPageShow = 'called'; }"
                "if (typeof window.pageShow === 'function') { window.pageShow(); result.pageShow = 'called'; }"
                "// 强制页面重新渲染"
                "if (typeof document.hidden !== 'undefined') {"
                    "Object.defineProperty(document, 'visibilityState', { value: 'visible', writable: true });"
                    "Object.defineProperty(document, 'hidden', { value: false, writable: true });"
                    "result.visibilityFixed = true;"
                "}"
                "// 强制触发所有input事件来激活页面"
                "var inputs = document.querySelectorAll('input, textarea, select');"
                "if (inputs.length > 0) {"
                    "inputs[0].focus();"
                    "inputs[0].blur();"
                    "result.inputActivated = true;"
                "}"
                "return JSON.stringify(result);"
            "} catch(e) {"
                "console.error('页面恢复失败:', e);"
                "return JSON.stringify({error: e.message});"
            "}"
        "})()" completionHandler:^(id result, NSError *error) {
            if (error) {
                NSLog(@"在局⚠️ [交互式转场恢复] 第二步JavaScript执行失败: %@", error.localizedDescription);
            } else {
                NSLog(@"在局✅ [交互式转场恢复] 第二步JavaScript执行成功: %@", result);
            }  
        }];
    } else {
        NSLog(@"在局⚠️ [交互式转场恢复] 跳过页面恢复JavaScript执行");
    }
    
    // 6. 触发pageShow事件（如果页面已经加载完成）
    NSLog(@"在局🔧 [pageShow检查] shouldExecuteRestoreForced=%@, isWebViewLoading=%@, isExist=%@", 
          shouldExecuteRestoreForced ? @"是" : @"否",
          self.isWebViewLoading ? @"是" : @"否", 
          self.isExist ? @"是" : @"否");
    if (shouldExecuteRestoreForced && self.isWebViewLoading && self.isExist) {
        NSLog(@"在局🔄 [交互式转场恢复] 触发pageShow事件");
        NSDictionary *callJsDic = [CustomHybridProcessor custom_objcCallJsWithFn:@"pageShow" data:nil];
        [self objcCallJs:callJsDic];
    } else {
        NSLog(@"在局⚠️ [交互式转场恢复] 跳过pageShow事件 - shouldExecute: %@, isWebViewLoading: %@, isExist: %@", 
              shouldExecuteRestoreForced ? @"是" : @"否", 
              self.isWebViewLoading ? @"是" : @"否", 
              self.isExist ? @"是" : @"否");
    }
    
    // 7. 确保ScrollView可以正常滚动
    if ([self.webView isKindOfClass:[WKWebView class]]) {
        WKWebView *wkWebView = (WKWebView *)self.webView;
        wkWebView.scrollView.scrollEnabled = YES;
        wkWebView.scrollView.userInteractionEnabled = YES;
    }
    
    NSLog(@"在局✅ [交互式转场恢复] WebView状态恢复完成");
    
    // 8. 添加延迟检查，确保内容真的恢复了
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self checkWebViewContentAfterRestore];
    });
    
    // 9. 添加手势返回专用的快速修复机制
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self quickFixForInteractiveTransition];
    });
    
    // 10. 添加最终救援机制：如果2秒后页面仍然空白，强制重新加载
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self finalRescueForBlankPage];
    });
}

// 手势返回专用的快速修复机制
- (void)quickFixForInteractiveTransition {
    NSLog(@"在局⚡ [快速修复] 开始手势返回专用快速修复");
    
    if (_isDisappearing || !self.webView) {
        NSLog(@"在局⚠️ [快速修复] 页面已消失或WebView不存在，取消修复");
        return;
    }
    
    // 检查控制器是否在导航栈中
    BOOL isInNavigationStack = self.navigationController && 
                              [self.navigationController.viewControllers containsObject:self];
    BOOL hasValidWindow = (self.view.window != nil && !self.view.window.hidden);
    
    if (!isInNavigationStack || !hasValidWindow) {
        NSLog(@"在局⚠️ [快速修复] 控制器状态不符合修复条件");
        return;
    }
    
    NSLog(@"在局⚡ [快速修复] 开始执行快速JavaScript修复");
    
    // 快速JavaScript修复，专门针对手势返回后的显示问题
    NSString *quickFixScript = @"(function(){"
        "try {"
            "console.log('手势返回快速修复开始');"
            "var result = {};"
            "// 1. 强制显示body内容"
            "if (document.body) {"
                "document.body.style.display = 'block';"
                "document.body.style.visibility = 'visible';"
                "document.body.style.opacity = '1';"
                "document.body.style.transform = 'none';"
                "result.bodyFixed = true;"
            "}"
            "// 2. 强制显示主要容器"
            "var mainContainers = document.querySelectorAll('main, .main, #main, .app, #app, .container, #container');"
            "for (var i = 0; i < mainContainers.length; i++) {"
                "var container = mainContainers[i];"
                "container.style.display = 'block';"
                "container.style.visibility = 'visible';"
                "container.style.opacity = '1';"
            "}"
            "result.containersFixed = mainContainers.length;"
            "// 3. 移除可能的遮罩层"
            "var masks = document.querySelectorAll('.mask, .overlay, .loading-mask');"
            "for (var i = 0; i < masks.length; i++) {"
                "masks[i].style.display = 'none';"
            "}"
            "result.masksRemoved = masks.length;"
            "// 4. 强制重新计算布局"
            "if (document.body) {"
                "document.body.offsetHeight;" // 触发重排
                "var event = new Event('resize');"
                "window.dispatchEvent(event);"
                "result.layoutRecalculated = true;"
            "}"
            "// 5. 如果有app对象，尝试调用刷新方法"
            "if (typeof app !== 'undefined' && app.loaded) {"
                "if (typeof app.refreshCurrentPage === 'function') {"
                    "app.refreshCurrentPage();"
                    "result.appRefreshCalled = true;"
                "} else if (typeof app.updateView === 'function') {"
                    "app.updateView();"
                    "result.appUpdateCalled = true;"
                "}"
            "}"
            "return JSON.stringify(result);"
        "} catch(e) {"
            "return JSON.stringify({error: e.message});"
        "}"
    "})()";
    
    [self safelyEvaluateJavaScript:quickFixScript completionHandler:^(id result, NSError *error) {
        if (error) {
            NSLog(@"在局⚠️ [快速修复] JavaScript执行失败: %@", error.localizedDescription);
        } else {
            NSLog(@"在局✅ [快速修复] JavaScript执行成功: %@", result);
        }
    }];
}

// 执行延迟的WebView恢复操作
- (void)executeDelayedRestoreOperations {
    NSLog(@"在局🔄 [延迟恢复] 开始执行延迟的WebView恢复操作");
    
    if (!self.webView) {
        NSLog(@"在局⚠️ [延迟恢复] WebView不存在，取消恢复操作");
        return;
    }
    
    // 4. 强制刷新WebView内容（关键修复）
    NSLog(@"在局🔧 [延迟恢复] 开始执行JavaScript恢复脚本");
    NSString *refreshScript = @"(function() {"
        "try {"
            "if (typeof app !== 'undefined' && app.loaded) {"
                "console.log('强制刷新页面内容');"
                "if (typeof app.refreshPage === 'function') {"
                    "app.refreshPage();"
                "} else if (typeof location !== 'undefined') {"
                    "location.reload();"
                "}"
                "return 'WebView内容已刷新';"
            "} else {"
                "return 'App未初始化，跳过刷新';"
            "}"
        "} catch(e) {"
            "return 'WebView刷新失败: ' + e.message;"
        "}"
    "})()";
    
    [self safelyEvaluateJavaScript:refreshScript completionHandler:^(id result, NSError *error) {
        if (error) {
            NSLog(@"在局⚠️ [延迟恢复] 第一步JavaScript执行失败: %@", error.localizedDescription);
        } else {
            NSLog(@"在局✅ [延迟恢复] 第一步JavaScript执行成功: %@", result);
        }
    }];
    
    // 5. 触发页面刷新以恢复内容显示（关键修复）
    NSLog(@"在局🔧 [延迟恢复] 开始执行页面恢复JavaScript");
    NSString *pageRestoreScript = @"(function(){"
        "try {"
            "console.log('开始页面恢复操作');"
            "if (document.body) {"
                "document.body.style.display = 'none';"
                "document.body.offsetHeight;"
                "document.body.style.display = 'block';"
            "}"
            "if (typeof window.dispatchEvent === 'function') {"
                "window.dispatchEvent(new Event('resize'));"
            "}"
            "if (typeof window.onPageShow === 'function') { window.onPageShow(); }"
            "if (typeof window.pageShow === 'function') { window.pageShow(); }"
            "if (typeof document.hidden !== 'undefined') {"
                "document.visibilityState = 'visible';"
            "}"
            "return '延迟页面恢复完成';"
        "} catch(e) {"
            "console.error('延迟页面恢复失败:', e);"
            "return '恢复失败: ' + e.message;"
        "}"
    "})()";
    
    [self safelyEvaluateJavaScript:pageRestoreScript completionHandler:^(id result, NSError *error) {
        if (error) {
            NSLog(@"在局⚠️ [延迟恢复] 第二步JavaScript执行失败: %@", error.localizedDescription);
        } else {
            NSLog(@"在局✅ [延迟恢复] 第二步JavaScript执行成功: %@", result);
        }  
    }];
    
    // 6. 触发pageShow事件（如果页面已经加载完成）
    if (self.isWebViewLoading && self.isExist) {
        NSLog(@"在局🔄 [延迟恢复] 触发pageShow事件");
        NSDictionary *callJsDic = [CustomHybridProcessor custom_objcCallJsWithFn:@"pageShow" data:nil];
        [self objcCallJs:callJsDic];
    }
    
    NSLog(@"在局✅ [延迟恢复] 延迟恢复操作执行完成");
}

// 检查WebView恢复后的内容状态
- (void)checkWebViewContentAfterRestore {
    if (!self.webView) {
        return;
    }
    
    // 重新检查应用状态
    UIApplicationState appState = [[UIApplication sharedApplication] applicationState];
    BOOL isAppActive = (appState == UIApplicationStateActive);
    BOOL shouldExecuteCheck = isAppActive || [self isShowingOnKeyWindow];
    
    if (!shouldExecuteCheck) {
        NSLog(@"在局⚠️ [内容检查] 应用状态不合适，跳过内容检查");
        return;
    }
    
    NSLog(@"在局🔍 [内容检查] 检查WebView恢复后的内容状态");
    
    [self safelyEvaluateJavaScript:@"(function(){"
        "try {"
            "var bodyHeight = document.body ? document.body.scrollHeight : 0;"
            "var bodyContent = document.body ? (document.body.innerHTML.length > 100 ? '有内容' : '内容不足') : '无body';"
            "var isVisible = document.body ? (document.body.style.display !== 'none' ? '可见' : '隐藏') : '无body';"
            "var hasElements = document.querySelectorAll('*').length > 10 ? '元素充足' : '元素不足';"
            "return JSON.stringify({"
                "'bodyHeight': bodyHeight,"
                "'bodyContent': bodyContent,"
                "'isVisible': isVisible,"
                "'hasElements': hasElements,"
                "'url': window.location.href"
            "});"
        "} catch(e) {"
            "return JSON.stringify({'error': e.message});"
        "}"
    "})()" completionHandler:^(id result, NSError *error) {
        if (result && !error) {
            NSLog(@"在局🔍 [内容检查] 页面状态: %@", result);
            
            // 如果页面内容不足，尝试强制重新加载
            if ([result containsString:@"内容不足"] || [result containsString:@"元素不足"]) {
                NSLog(@"在局⚠️ [内容检查] 检测到页面内容不足，尝试重新加载");
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (self.pinUrl && self.pinUrl.length > 0) {
                        NSLog(@"在局🔄 [内容检查] 重新执行domainOperate");
                        [self domainOperate];
                    }
                });
            }
        } else {
            NSLog(@"在局⚠️ [内容检查] 页面状态检查失败: %@", error.localizedDescription);
        }
    }];
}

// 最终救援机制：处理极端的空白页面情况
- (void)finalRescueForBlankPage {
    NSLog(@"在局🆘 [最终救援] 开始最终救援机制检查");
    
    if (_isDisappearing || !self.webView) {
        NSLog(@"在局⚠️ [最终救援] 页面已消失或WebView不存在，取消救援");
        return;
    }
    
    // 检查应用和控制器状态
    UIApplicationState appState = [[UIApplication sharedApplication] applicationState];
    BOOL isAppActive = (appState == UIApplicationStateActive);
    BOOL isViewControllerVisible = [self isShowingOnKeyWindow];
    
    if (!isAppActive && !isViewControllerVisible) {
        NSLog(@"在局⚠️ [最终救援] 应用不活跃且控制器不可见，取消救援");
        return;
    }
    
    NSLog(@"在局🆘 [最终救援] 检查页面最终状态");
    
    // 最终检查页面内容
    [self safelyEvaluateJavaScript:@"(function(){"
        "try {"
            "var bodyHeight = document.body ? document.body.scrollHeight : 0;"
            "var bodyVisible = document.body ? (document.body.style.display !== 'none' && document.body.style.visibility !== 'hidden') : false;"
            "var bodyOpacity = document.body ? parseFloat(document.body.style.opacity || '1') : 0;"
            "var hasVisibleContent = document.querySelectorAll('*:not(script):not(style)').length > 10;"
            "var result = {"
                "bodyHeight: bodyHeight,"
                "bodyVisible: bodyVisible,"
                "bodyOpacity: bodyOpacity,"
                "hasVisibleContent: hasVisibleContent,"
                "needsRescue: (bodyHeight < 100 || !bodyVisible || bodyOpacity < 0.5 || !hasVisibleContent)"
            "};"
            "return JSON.stringify(result);"
        "} catch(e) {"
            "return JSON.stringify({error: e.message, needsRescue: true});"
        "}"
    "})()" completionHandler:^(id result, NSError *error) {
        if (error) {
            NSLog(@"在局❌ [最终救援] 页面检查失败: %@，强制执行救援", error.localizedDescription);
            [self executeForceRescue];
            return;
        }
        
        NSLog(@"在局🔍 [最终救援] 页面最终状态: %@", result);
        
        // 解析结果判断是否需要救援
        NSError *jsonError;
        NSDictionary *resultDict = [NSJSONSerialization JSONObjectWithData:[result dataUsingEncoding:NSUTF8StringEncoding] options:0 error:&jsonError];
        
        if (jsonError || [resultDict[@"needsRescue"] boolValue]) {
            NSLog(@"在局🆘 [最终救援] 检测到页面仍然空白，执行强制救援");
            [self executeForceRescue];
        } else {
            NSLog(@"在局✅ [最终救援] 页面内容正常，无需救援");
        }
    }];
}

// 执行强制救援
- (void)executeForceRescue {
    NSLog(@"在局💥 [强制救援] 开始执行强制救援操作");
    
    // 保存当前状态
    NSString *currentUrl = self.pinUrl;
    NSString *currentData = self.pinDataStr;
    
    NSLog(@"在局💥 [强制救援] 保存状态 - URL: %@, 数据长度: %lu", 
          currentUrl, (unsigned long)(currentData ? currentData.length : 0));
    
    // 1. 强制重置WebView显示状态
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!self.webView) return;
        
        // 强制移除所有可能的遮挡
        for (UIView *subview in self.view.subviews) {
            if (subview != self.webView && subview != self.progressView && subview != self.activityIndicatorView && subview != self.networkNoteView) {
                NSLog(@"在局💥 [强制救援] 临时隐藏可能遮挡的视图: %@", NSStringFromClass([subview class]));
                subview.alpha = 0.1;
            }
        }
        
        // 强制WebView到最前
        self.webView.hidden = NO;
        self.webView.alpha = 1.0;
        self.webView.backgroundColor = [UIColor whiteColor];
        [self.view bringSubviewToFront:self.webView];
        
        // 强制重新布局
        [self.view setNeedsLayout];
        [self.view layoutIfNeeded];
        [self.webView setNeedsDisplay];
        [self.webView.layer displayIfNeeded];
        
        NSLog(@"在局💥 [强制救援] 执行最后的JavaScript救援");
        
        // 2. 最后的JavaScript救援
        NSString *rescueScript = @"(function(){"
            "try {"
                "console.log('执行最终JavaScript救援');"
                "// 强制清除所有隐藏样式"
                "var allElements = document.querySelectorAll('*');"
                "for (var i = 0; i < allElements.length; i++) {"
                    "var elem = allElements[i];"
                    "if (elem.tagName && elem.tagName !== 'SCRIPT' && elem.tagName !== 'STYLE') {"
                        "elem.style.display = elem.style.display === 'none' ? 'block' : elem.style.display;"
                        "elem.style.visibility = elem.style.visibility === 'hidden' ? 'visible' : elem.style.visibility;"
                        "elem.style.opacity = elem.style.opacity === '0' ? '1' : elem.style.opacity;"
                    "}"
                "}"
                "// 强制重新渲染整个文档"
                "if (document.body) {"
                    "document.body.style.transform = 'translateZ(0)';" // 强制GPU渲染
                    "setTimeout(function() {"
                        "document.body.style.transform = '';"
                    "}, 10);"
                "}"
                "// 触发强制重绘"
                "window.scrollTo(0, 1);"
                "window.scrollTo(0, 0);"
                "return '强制救援JavaScript执行完成';"
            "} catch(e) {"
                "return '救援失败: ' + e.message;"
            "}"
        "})();";
        
        [self safelyEvaluateJavaScript:rescueScript completionHandler:^(id result, NSError *error) {
            NSLog(@"在局💥 [强制救援] JavaScript救援结果: %@", result ?: error.localizedDescription);
        }];
        
        // 3. 如果JavaScript救援也失败，最后手段：重新加载内容
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (currentUrl && currentUrl.length > 0) {
                NSLog(@"在局💥 [强制救援] 最后手段：重新加载页面内容");
                self.pinUrl = currentUrl;
                self.pinDataStr = currentData;
                [self domainOperate];
            }
        });
    });
}

#pragma mark - 性能优化方法实现

/**
 * 预加载HTML模板 - 应用启动时调用，缓存HTML模板到内存
 * 优化目标：减少每次页面加载时的文件I/O操作，提升100ms加载速度
 */
+ (void)preloadHTMLTemplates {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSLog(@"在局🚀 [性能优化] 开始预加载HTML模板");
        
        // 异步加载，不阻塞主线程
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            NSString *templatePath = [[BaseFileManager appH5LocailManifesPath] stringByAppendingPathComponent:@"app.html"];
            
            if ([[NSFileManager defaultManager] fileExistsAtPath:templatePath]) {
                NSError *error;
                NSString *templateContent = [NSString stringWithContentsOfFile:templatePath 
                                                                      encoding:NSUTF8StringEncoding 
                                                                         error:&error];
                
                if (!error && templateContent.length > 0) {
                    _cachedHTMLTemplate = [templateContent copy];
                    _templateCacheTime = [NSDate date];
                    
                    NSLog(@"在局✅ [性能优化] HTML模板预加载成功，大小: %lu 字符", (unsigned long)templateContent.length);
                } else {
                    NSLog(@"在局❌ [性能优化] HTML模板预加载失败: %@", error.localizedDescription);
                }
            } else {
                NSLog(@"在局⚠️ [性能优化] HTML模板文件不存在: %@", templatePath);
            }
        });
        
        // 初始化共享的HTML处理队列
        _sharedHTMLProcessingQueue = [[NSOperationQueue alloc] init];
        _sharedHTMLProcessingQueue.name = @"com.xz.html.processing";
        _sharedHTMLProcessingQueue.maxConcurrentOperationCount = 2; // 允许并发处理
        _sharedHTMLProcessingQueue.qualityOfService = NSQualityOfServiceUserInitiated;
    });
}

/**
 * 获取缓存的HTML模板，如果缓存失效则重新加载
 * @return 缓存的HTML模板字符串
 */
+ (NSString *)getCachedHTMLTemplate {
    // 检查缓存是否有效（24小时内）
    if (_cachedHTMLTemplate && _templateCacheTime) {
        NSTimeInterval cacheAge = [[NSDate date] timeIntervalSinceDate:_templateCacheTime];
        if (cacheAge < 24 * 60 * 60) { // 24小时内
            return _cachedHTMLTemplate;
        }
    }
    
    // 缓存失效，重新加载
    [self preloadHTMLTemplates];
    return _cachedHTMLTemplate; // 可能为nil，调用方需要处理
}

/**
 * 初始化性能优化相关属性和队列
 * 在viewDidLoad中调用，设置所有优化相关的属性
 */
- (void)initializePerformanceOptimizations {
    NSLog(@"在局🚀 [性能优化] 初始化性能优化组件");
    
    // 初始化状态标志
    self.isWebViewPreCreated = NO;
    self.isBridgeReady = NO;
    
    // 初始化WebView加载队列
    self.webViewLoadingQueue = [[NSOperationQueue alloc] init];
    self.webViewLoadingQueue.name = @"com.xz.webview.loading";
    self.webViewLoadingQueue.maxConcurrentOperationCount = 1; // 串行执行
    self.webViewLoadingQueue.qualityOfService = NSQualityOfServiceUserInitiated;
    
    // 初始化HTML处理队列
    self.htmlProcessingQueue = _sharedHTMLProcessingQueue ?: [[NSOperationQueue alloc] init];
    if (!_sharedHTMLProcessingQueue) {
        self.htmlProcessingQueue.name = @"com.xz.html.processing.instance";
        self.htmlProcessingQueue.maxConcurrentOperationCount = 1;
        self.htmlProcessingQueue.qualityOfService = NSQualityOfServiceUserInitiated;
    }
    
    NSLog(@"在局✅ [性能优化] 性能优化组件初始化完成");
}

/**
 * 预创建WebView - 在viewDidLoad中异步调用
 * 优化目标：减少WebView创建时间，提升首次显示速度100ms
 */
- (void)preCreateWebViewIfNeeded {
    if (self.isWebViewPreCreated || self.webView) {
        return; // 已经预创建或者已存在
    }
    
    NSLog(@"在局🚀 [性能优化] 开始预创建WebView");
    
    // 异步预创建，避免阻塞主线程
    NSBlockOperation *preCreateOperation = [NSBlockOperation blockOperationWithBlock:^{
        // 切换到主线程创建WebView（UI操作必须在主线程）
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            if (self.webView || self.isWebViewPreCreated) {
                return; // 避免重复创建
            }
            
            NSLog(@"在局🔧 [性能优化] 主线程中预创建WebView");
            
            // 创建WebView配置
            WKWebViewConfiguration *configuration = [self createOptimizedWebViewConfiguration];
            
            // 创建WebView实例
            self.webView = [[WKWebView alloc] initWithFrame:CGRectZero configuration:configuration];
            self.webView.navigationDelegate = nil; // 暂时不设置delegate
            self.webView.UIDelegate = nil;
            self.webView.backgroundColor = [UIColor whiteColor];
            self.webView.hidden = YES; // 预创建时隐藏
            
            // 标记为已预创建
            self.isWebViewPreCreated = YES;
            
            NSLog(@"在局✅ [性能优化] WebView预创建完成");
        }];
    }];
    
    [self.webViewLoadingQueue addOperation:preCreateOperation];
}

/**
 * 创建优化的WebView配置
 * 包含预注入的JavaScript桥接脚本，减少后续初始化时间
 * @return 配置好的WKWebViewConfiguration对象
 */
- (WKWebViewConfiguration *)createOptimizedWebViewConfiguration {
    WKWebViewConfiguration *configuration = [[WKWebViewConfiguration alloc] init];
    
    // 基础配置
    configuration.allowsInlineMediaPlayback = YES;
    configuration.mediaTypesRequiringUserActionForPlayback = WKAudiovisualMediaTypeNone;
    
    // JavaScript配置
    configuration.preferences = [[WKPreferences alloc] init];
    configuration.preferences.javaScriptEnabled = YES;
    configuration.preferences.javaScriptCanOpenWindowsAutomatically = YES;
    
    // iOS 14+ 配置
    if (@available(iOS 14.0, *)) {
        configuration.defaultWebpagePreferences.allowsContentJavaScript = YES;
    }
    
    // 媒体配置
    if (@available(iOS 10.0, *)) {
        configuration.mediaTypesRequiringUserActionForPlayback = WKAudiovisualMediaTypeNone;
    }
    
    if (@available(iOS 9.0, *)) {
        configuration.allowsAirPlayForMediaPlayback = YES;
        configuration.allowsPictureInPictureMediaPlayback = YES;
    }
    
    // 数据存储配置
    configuration.websiteDataStore = [WKWebsiteDataStore defaultDataStore];
    
    // 创建UserContentController并预注入优化脚本
    self.userContentController = [[WKUserContentController alloc] init];
    configuration.userContentController = self.userContentController;
    
    // 【关键优化】预注入JavaScript桥接准备脚本
    NSString *bridgePreparationScript = @""
    "window.webViewBridgeReady = false;"
    "window.webViewOptimized = true;"
    "window.bridgeInitCallbacks = [];"
    "window.onBridgeReady = function(callback) {"
    "    if (window.webViewBridgeReady) {"
    "        callback();"
    "    } else {"
    "        window.bridgeInitCallbacks.push(callback);"
    "    }"
    "};"
    "console.log('在局🚀 [性能优化] 桥接准备脚本已注入');";
    
    WKUserScript *bridgeScript = [[WKUserScript alloc] 
        initWithSource:bridgePreparationScript
        injectionTime:WKUserScriptInjectionTimeAtDocumentStart
        forMainFrameOnly:NO];
    [self.userContentController addUserScript:bridgeScript];
    
    // Debug模式下的调试脚本
    #ifdef DEBUG
    NSString *debugScript = @""
    "window.isWKWebView = true;"
    "window.webViewOptimizedDebug = true;"
    "console.log('在局🔧 [性能优化] Debug脚本已注入');";
    
    WKUserScript *debugUserScript = [[WKUserScript alloc] 
        initWithSource:debugScript
        injectionTime:WKUserScriptInjectionTimeAtDocumentStart
        forMainFrameOnly:NO];
    [self.userContentController addUserScript:debugUserScript];
    #endif
    
    NSLog(@"在局✅ [性能优化] 优化的WebView配置创建完成");
    return configuration;
}

/**
 * 设置优化的JavaScript桥接
 * 使用预创建的WebView和预注入的脚本，减少初始化时间200ms
 */
- (void)setupOptimizedJavaScriptBridge {
    if (!self.webView || self.isBridgeReady) {
        return; // WebView不存在或桥接已就绪
    }
    
    NSLog(@"在局🚀 [性能优化] 开始设置优化的JavaScript桥接");
    
    // 检查是否已经存在桥接实例
    if (self.bridge) {
        NSLog(@"在局⚠️ [性能优化] 桥接已存在，先清理");
        self.bridge = nil;
    }
    
    // 创建桥接实例
    self.bridge = [WKWebViewJavascriptBridge bridgeForWebView:self.webView];
    if (!self.bridge) {
        NSLog(@"在局❌ [性能优化] 桥接创建失败");
        return;
    }
    
    // 设置WebView代理（桥接库会自动处理）
    [self.bridge setWebViewDelegate:self];
    
    // 注册处理器
    [self registerOptimizedBridgeHandlers];
    
    // 标记桥接已就绪
    self.isBridgeReady = YES;
    
    NSLog(@"在局✅ [性能优化] 优化的JavaScript桥接设置完成");
    
    // 通知JavaScript桥接已就绪
    [self notifyJavaScriptBridgeReady];
}

/**
 * 注册优化的桥接处理器
 * 集中注册所有必要的JavaScript桥接处理器
 */
- (void)registerOptimizedBridgeHandlers {
    __weak typeof(self) weakSelf = self;
    
    // 主要的桥接处理器
    [self.bridge registerHandler:@"xzBridge" handler:^(id data, WVJBResponseCallback responseCallback) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf) {
            [strongSelf jsCallObjc:data jsCallBack:responseCallback];
        }
    }];
    
    // 直接的pageReady处理器
    [self.bridge registerHandler:@"pageReady" handler:^(id data, WVJBResponseCallback responseCallback) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf) {
            NSDictionary *pageReadyData = @{
                @"fn": @"pageReady",
                @"params": data ?: @{}
            };
            [strongSelf jsCallObjc:pageReadyData jsCallBack:responseCallback];
        }
    }];
    
    // 桥接测试处理器
    [self.bridge registerHandler:@"bridgeTest" handler:^(id data, WVJBResponseCallback responseCallback) {
        NSLog(@"在局🧪 [桥接测试] 收到测试请求: %@", data);
        if (responseCallback) {
            responseCallback(@{
                @"success": @YES,
                @"message": @"桥接正常工作",
                @"optimized": @YES,
                @"timestamp": @([[NSDate date] timeIntervalSince1970])
            });
        }
    }];
    
    NSLog(@"在局✅ [性能优化] 桥接处理器注册完成");
}

/**
 * 通知JavaScript桥接已就绪
 * 触发预注入脚本中的回调，确保页面能及时响应
 */
- (void)notifyJavaScriptBridgeReady {
    NSString *notifyScript = @""
    "if (window.bridgeInitCallbacks) {"
    "    window.webViewBridgeReady = true;"
    "    window.bridgeInitCallbacks.forEach(function(callback) {"
    "        try { callback(); } catch(e) { console.error('桥接回调执行失败:', e); }"
    "    });"
    "    window.bridgeInitCallbacks = [];"
    "    console.log('在局✅ [性能优化] 桥接就绪通知已发送');"
    "}";
    
    [self safelyEvaluateJavaScript:notifyScript completionHandler:^(id result, NSError *error) {
        if (error) {
            NSLog(@"在局⚠️ [性能优化] 桥接就绪通知失败: %@", error.localizedDescription);
        } else {
            NSLog(@"在局✅ [性能优化] 桥接就绪通知发送成功");
        }
    }];
}

/**
 * 优化的HTML内容加载方法
 * 使用缓存的模板和异步处理，提升加载性能
 */
- (void)optimizedLoadHTMLContent {
    NSLog(@"在局🚀 [性能优化] 开始优化的HTML内容加载");
    
    // 防重复调用检查 - 修复闪烁问题
    if (self.isLoadingInProgress) {
        NSLog(@"在局⚠️ [性能优化] 检测到重复加载调用，跳过执行");
        return;
    }
    
    // 检查WebView状态
    if (!self.webView) {
        NSLog(@"在局⚠️ [性能优化] WebView不存在，触发预创建");
        [self preCreateWebViewIfNeeded];
        
        // 避免无限递归 - 最多重试一次
        static NSInteger retryCount = 0;
        if (retryCount >= 1) {
            NSLog(@"在局⚠️ [性能优化] WebView创建重试次数已达上限，回退到原有方法");
            retryCount = 0;
            [self fallbackToOriginalLoadMethod];
            return;
        }
        
        retryCount++;
        // 延迟重试
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self optimizedLoadHTMLContent];
            retryCount = 0; // 重置计数器
        });
        return;
    }
    
    // 确保WebView已正确添加到视图层级
    if (!self.webView.superview) {
        [self addWebView];
    }
    
    // 确保桥接已设置
    if (!self.isBridgeReady) {
        [self setupOptimizedJavaScriptBridge];
    }
    
    // 创建HTML处理操作
    NSBlockOperation *htmlProcessingOperation = [NSBlockOperation blockOperationWithBlock:^{
        NSString *processedHTML = [self processHTMLContentOptimized];
        
        if (processedHTML) {
            // 回到主线程加载到WebView
            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                [self loadProcessedHTMLContent:processedHTML];
            }];
        } else {
            NSLog(@"在局❌ [性能优化] HTML内容处理失败，回退到原有加载方法");
            // 回退到原有的加载方法
            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                [self fallbackToOriginalLoadMethod];
            }];
        }
    }];
    
    [self.htmlProcessingQueue addOperation:htmlProcessingOperation];
}

/**
 * 优化的HTML内容处理
 * 使用缓存的模板和高效的字符串处理
 * @return 处理完成的HTML字符串
 */
- (NSString *)processHTMLContentOptimized {
    NSString *htmlTemplate = [[self class] getCachedHTMLTemplate];
    
    // 如果缓存的模板不可用，尝试直接读取
    if (!htmlTemplate) {
        NSLog(@"在局⚠️ [性能优化] 缓存模板不可用，直接读取文件");
        NSString *templatePath = [[BaseFileManager appH5LocailManifesPath] stringByAppendingPathComponent:@"app.html"];
        htmlTemplate = [NSString stringWithContentsOfFile:templatePath encoding:NSUTF8StringEncoding error:nil];
    }
    
    if (!htmlTemplate) {
        NSLog(@"在局❌ [性能优化] 无法获取HTML模板");
        return nil;
    }
    
    NSString *bodyContent = @"";
    
    // 处理不同的内容源
    if (self.pinDataStr && self.pinDataStr.length > 0) {
        // 直接数据模式
        bodyContent = self.pinDataStr;
        NSLog(@"在局📄 [性能优化] 使用直接数据模式，内容长度: %lu", (unsigned long)bodyContent.length);
    } else if (self.pinUrl) {
        // URL模式，需要通过CustomHybridProcessor处理
        // 这里暂时返回空内容，实际处理在CustomHybridProcessor中
        NSLog(@"在局🔄 [性能优化] URL模式，等待CustomHybridProcessor处理");
        return nil;
    }
    
    // 执行模板替换
    NSString *processedHTML = [htmlTemplate stringByReplacingOccurrencesOfString:@"{{body}}" withString:bodyContent];
    
    // iPhone X适配
    if ([self isHaveNativeHeader:self.pinUrl]) {
        NSString *phoneClass = isIPhoneXSeries() ? @"iPhoneLiuHai" : @"iPhone";
        processedHTML = [processedHTML stringByReplacingOccurrencesOfString:@"{{phoneClass}}" withString:phoneClass];
    }
    
    NSLog(@"在局✅ [性能优化] HTML内容处理完成，最终长度: %lu", (unsigned long)processedHTML.length);
    return processedHTML;
}

/**
 * 回退到原有的HTML加载方法
 * 当优化的加载方法失败时使用
 */
- (void)fallbackToOriginalLoadMethod {
    NSLog(@"在局🔄 [性能优化] 执行回退策略，使用原有加载方法");
    
    // 禁用优化标志，避免无限循环
    static BOOL isInFallback = NO;
    if (isInFallback) {
        NSLog(@"在局⚠️ [性能优化] 已在回退模式中，避免无限循环");
        return;
    }
    isInFallback = YES;
    
    // 调用原有的loadHTMLContent方法，但跳过优化逻辑
    [self loadHTMLContentWithoutOptimization];
    
    isInFallback = NO;
}

/**
 * 不使用优化的HTML内容加载方法
 * 这是原有逻辑的简化版本，确保基础功能正常工作
 */
- (void)loadHTMLContentWithoutOptimization {
    NSLog(@"在局🔄 [性能优化] 使用原有逻辑加载HTML内容");
    
    // 检查WebView是否存在
    if (!self.webView) {
        NSLog(@"在局⚠️ [loadHTMLContent] WebView不存在，无法加载");
        return;
    }
    
    // 检查htmlStr是否是未处理的模板（包含{{body}}占位符）
    if (self.htmlStr && self.htmlStr.length > 0 && ![self.htmlStr containsString:@"{{body}}"]) {
        // 只有当htmlStr是已处理的完整HTML时才直接加载
        NSString *basePath = [BaseFileManager appH5LocailManifesPath];
        NSURL *baseURL = [NSURL fileURLWithPath:basePath];
        [self.webView loadHTMLString:self.htmlStr baseURL:baseURL];
        NSLog(@"在局✅ [loadHTMLContent] 使用已处理的htmlStr加载HTML内容");
        return;
    }
    
    // 如果有pinDataStr，使用模板加载
    if (self.pinDataStr && self.pinDataStr.length > 0) {
        NSString *templatePath = [[BaseFileManager appH5LocailManifesPath] stringByAppendingPathComponent:@"app.html"];
        NSString *templateContent = [NSString stringWithContentsOfFile:templatePath encoding:NSUTF8StringEncoding error:nil];
        
        if (templateContent) {
            NSString *finalHTML = [templateContent stringByReplacingOccurrencesOfString:@"{{body}}" withString:self.pinDataStr];
            
            if ([self isHaveNativeHeader:self.pinUrl]) {
                NSString *phoneClass = isIPhoneXSeries() ? @"iPhoneLiuHai" : @"iPhone";
                finalHTML = [finalHTML stringByReplacingOccurrencesOfString:@"{{phoneClass}}" withString:phoneClass];
            }
            
            NSString *basePath = [BaseFileManager appH5LocailManifesPath];
            NSURL *baseURL = [NSURL fileURLWithPath:basePath];
            [self.webView loadHTMLString:finalHTML baseURL:baseURL];
            NSLog(@"在局✅ [loadHTMLContent] 使用pinDataStr模板加载HTML内容");
        }
        return;
    }
    
    // 对于URL模式，调用原有的完整加载流程
    if (self.pinUrl && self.pinUrl.length > 0) {
        NSLog(@"在局🔄 [loadHTMLContent] URL模式，调用原有的完整加载流程");
        
        // 确保桥接已建立
        if (!self.bridge) {
            [self loadWebBridge];
        }
        
        // 调用原有的完整加载方法
        if (self.bridge) {
            NSLog(@"在局✅ [loadHTMLContent] 桥接可用，调用performHTMLLoading");
            [self performHTMLLoading];
        } else {
            NSLog(@"在局⚠️ [loadHTMLContent] 桥接不可用，延迟重试");
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self loadHTMLContentWithoutOptimization];
            });
        }
        return;
    }
    
    NSLog(@"在局⚠️ [loadHTMLContent] 没有可用的加载数据");
}

/**
 * 加载处理完成的HTML内容到WebView
 * @param htmlContent 处理完成的HTML字符串
 */
- (void)loadProcessedHTMLContent:(NSString *)htmlContent {
    if (!htmlContent || !self.webView) {
        NSLog(@"在局❌ [性能优化] 无法加载HTML内容：内容或WebView为空");
        return;
    }
    
    NSLog(@"在局🚀 [性能优化] 开始加载处理完成的HTML内容");
    
    // 确保WebView可见
    self.webView.hidden = NO;
    self.webView.alpha = 1.0;
    
    // 设置baseURL
    NSString *manifestPath = [BaseFileManager appH5LocailManifesPath];
    NSURL *baseURL = [NSURL fileURLWithPath:manifestPath isDirectory:YES];
    
    // 显示加载指示器
    // [self.activityIndicatorView startAnimating]; // 已禁用loading指示器
    self.progressView.hidden = NO;
    self.progressView.progress = 0.1;
    
    // 加载HTML内容
    [self.webView loadHTMLString:htmlContent baseURL:baseURL];
    
    NSLog(@"在局✅ [性能优化] HTML内容已提交给WebView加载");
}

/**
 * 简化的JavaScript执行状态检查
 * 优化目标：减少状态检查的复杂度，提升JavaScript执行效率
 * @return YES if ready for JavaScript execution
 */
- (BOOL)isReadyForJavaScriptExecution {
    // 基础检查：WebView存在
    if (!self.webView) {
        return NO;
    }
    
    // 🔧 修复手势返回空白页问题：检查是否为关键操作场景
    UIApplicationState appState = [[UIApplication sharedApplication] applicationState];
    BOOL isControllerActive = self.view.window != nil && 
                             !self.view.window.hidden && 
                             self.view.superview != nil;
    
    // 检查是否为交互式转场恢复场景
    BOOL isInteractiveRestoreScenario = [self isShowingOnKeyWindow] && 
                                       isControllerActive &&
                                       (self.navigationController.viewControllers.lastObject == self ||
                                        [self.navigationController.viewControllers containsObject:self]);
    
    // 如果是交互式转场恢复场景，即使应用在后台也允许执行关键JavaScript
    if (isInteractiveRestoreScenario) {
        NSLog(@"在局[XZWKWebView] 应用状态非活跃但允许执行JavaScript: %@ (关键操作: YES, 控制器活跃: %@)", 
              @"交互式转场恢复", isControllerActive ? @"YES" : @"NO");
        return YES;
    }
    
    // 正常情况下检查应用状态：必须在前台或即将前台
    if (appState == UIApplicationStateBackground) {
        return NO;
    }
    
    // 页面正在消失但需要执行关键JavaScript的情况
    if (_isDisappearing && isControllerActive) {
        NSLog(@"在局[XZWKWebView] 页面消失中但控制器活跃，允许关键JavaScript执行");
        return YES;
    } else if (_isDisappearing) {
        return NO;
    }
    
    return isControllerActive;
}

/**
 * 检测WebView是否有有效内容
 * 用于避免重复加载已经有内容的页面
 */
- (BOOL)hasValidWebViewContent {
    if (!self.webView) {
        NSLog(@"在局🔍 [内容检查] WebView不存在");
        return NO;
    }
    
    // 如果页面已经标记为存在且已经收到pageReady，认为有效
    if (self.isExist && self.isLoading) {
        NSLog(@"在局✅ [内容检查] 页面已标记为存在且加载完成");
        return YES;
    }
    
    // 检查URL - 只有当URL完全无效时才返回NO
    NSURL *currentURL = self.webView.URL;
    if (!currentURL) {
        NSLog(@"在局🔍 [内容检查] WebView没有URL");
        return NO;
    }
    
    NSString *urlString = currentURL.absoluteString;
    NSLog(@"在局🔍 [内容检查] 当前URL: %@", urlString);
    
    // 只有当URL是about:blank或者空的时候才认为无效
    if ([urlString isEqualToString:@"about:blank"] || urlString.length == 0) {
        NSLog(@"在局❌ [内容检查] URL无效: %@", urlString);
        
        // 即使URL是about:blank，如果WebView正在加载，给它一次机会
        if (self.webView.isLoading) {
            NSLog(@"在局🔄 [内容检查] WebView正在加载中，暂时认为有效");
            return YES;
        }
        
        return NO;
    }
    
    // 检查是否是有效的内容URL（不是file://路径的基础目录）
    if ([urlString hasPrefix:@"file://"] && [urlString hasSuffix:@"/manifest/"]) {
        NSLog(@"在局⚠️ [内容检查] 只有基础manifest目录，没有具体内容");
        
        // 如果正在加载或者已经标记为正在加载，认为有效
        if (self.webView.isLoading || self.isWebViewLoading) {
            NSLog(@"在局🔄 [内容检查] 正在加载内容，认为有效");
            return YES;
        }
        
        return NO;
    }
    
    // 如果WebView有有效URL，认为有内容
    NSLog(@"在局✅ [内容检查] WebView有有效URL，认为有内容");
    return YES;
}

/**
 * 检测是否为返回导航后的页面显示场景
 * 用于优化返回逻辑，避免不必要的页面重新加载
 */
- (BOOL)isNavigationReturnScenario {
    // 使用多种方法检测返回场景，提高准确性
    NSInteger currentStackCount = self.navigationController.viewControllers.count;
    
    // 方法1: 检查是否为导航栈顶且有历史
    BOOL isTopViewController = (self.navigationController.topViewController == self);
    BOOL hasNavigationHistory = (currentStackCount > 1) || 
                               (currentStackCount == 1 && self.navigationController.viewControllers.firstObject == self);
    
    // 方法2: 检查导航栈数量变化（使用全局存储而不是实例关联）
    static NSMutableDictionary *navigationStackCounts = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        navigationStackCounts = [[NSMutableDictionary alloc] init];
    });
    
    NSString *navigationKey = [NSString stringWithFormat:@"%p", self.navigationController];
    NSNumber *lastStackCountNumber = navigationStackCounts[navigationKey];
    NSInteger lastStackCount = lastStackCountNumber ? [lastStackCountNumber integerValue] : 0;
    
    // 更新当前栈数量
    navigationStackCounts[navigationKey] = @(currentStackCount);
    
    // 方法3: 检查WebView内容状态（如果有内容且是首页，很可能是返回）
    BOOL hasWebViewContent = (self.webView && self.webView.URL);
    BOOL isHomePage = (currentStackCount == 1);
    
    // 综合判断是否为返回场景
    BOOL isStackDecrease = (lastStackCount > 0 && currentStackCount < lastStackCount);
    BOOL isReturnToHome = (isHomePage && hasWebViewContent && lastStackCount > 1);
    BOOL isReturn = isStackDecrease || isReturnToHome;
    
    if (isReturn || hasWebViewContent) {
        NSLog(@"在局🔄 [返回检测] 栈数量: %ld->%ld, 是首页: %@, 有内容: %@, 判定返回: %@", 
              (long)lastStackCount, (long)currentStackCount,
              isHomePage ? @"YES" : @"NO",
              hasWebViewContent ? @"YES" : @"NO", 
              isReturn ? @"YES" : @"NO");
    }
    
    return isReturn;
}

@end
