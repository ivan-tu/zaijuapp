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
#import "XZiOSVersionManager.h"
#import "XZErrorCodeManager.h"
#import "XZWebViewPerformanceManager.h"

// 导入WebViewJavascriptBridge
#import "../../ThirdParty/WKWebViewJavascriptBridge/WKWebViewJavascriptBridge.h"
#import "../../ThirdParty/WKWebViewJavascriptBridge/WebViewJavascriptBridge_JS.h"

// 使用XZiOSVersionManager替代分散的版本检查
static inline BOOL isIPhoneXSeries() {
    return [[XZiOSVersionManager sharedManager] isIPhoneXSeries];
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

// 在局Claude Code[修复空指针传递警告]+支持nullable属性
@property (nonatomic, strong, nullable) WKWebViewJavascriptBridge *bridge;  // 使用WebViewJavascriptBridge
@property (nonatomic, strong) UIActivityIndicatorView *activityIndicatorView; // 加载指示器
@property (nonatomic, strong) UIProgressView *progressView; // 进度条
@property (nonatomic, strong) NSString *currentTempFileName; // 当前临时文件名
@property (nonatomic, strong) NSOperationQueue *jsOperationQueue; // JavaScript操作队列
@property (nonatomic, strong) NSTimer *healthCheckTimer; // WebView健康检查定时器
@property (nonatomic, assign) BOOL isKVORegistered; // 在局Claude Code[KVO崩溃修复]+标记KVO观察者是否已注册

@end

@implementation XZWKWebViewBaseController

@synthesize componentJsAndCs = _componentJsAndCs;
@synthesize componentDic = _componentDic;
@synthesize templateDic = _templateDic;
@synthesize isTabbarShow = _isTabbarShow;
@synthesize pushType = _pushType;
@synthesize isExist = _isExist;
@synthesize nextPageDataBlock = _nextPageDataBlock;

#pragma mark - Life Cycle

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    
    // 初始化属性
    self.isWebViewLoading = NO;
    self.isLoading = NO;
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
    
    // 创建加载指示器
    [self setupLoadingIndicators];
    
    // 添加通知监听
    [self addNotificationObservers];
    
    // 初始化JavaScript执行管理
    [self initializeJavaScriptManagement];
    
    // 【性能优化】初始化优化相关属性和队列
    [self initializePerformanceOptimizations];
    
    // 🚀【性能优化】在viewDidLoad中提前创建WebView
    // 判断是否为首页（第一个tab）
    BOOL isFirstTab = NO;
    if (self.tabBarController && self.isTabbarShow) {
        NSInteger currentIndex = [self.tabBarController.viewControllers indexOfObject:self.navigationController];
        isFirstTab = (currentIndex == 0);
    }
    
    if (isFirstTab) {
        NSLog(@"在局Claude Code[性能优化]+首页在viewDidLoad中提前创建WebView");
        // 立即创建WebView，不等待viewDidAppear
        [self createWebViewImmediately];
    } else {
        // 在局Claude Code[首次安装优化]+非首页也提前创建WebView以减少切换延迟
        NSLog(@"在局Claude Code[首次安装优化]+非首页也提前创建WebView以减少切换延迟");
        // 延迟很短时间后创建，避免阻塞主线程但又能减少切换延迟
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self createWebViewImmediately];
        });
    }
    
    // 添加应用生命周期通知监听
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appWillTerminate:) name:@"AppWillTerminateNotification" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidEnterBackground:) name:@"AppDidEnterBackgroundNotification" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appWillResignActive:) name:@"AppWillResignActiveNotification" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidBecomeActive:) name:@"AppDidBecomeActiveNotification" object:nil];
    
    // 添加Universal Links通知监听
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleUniversalLinkNavigation:) name:@"UniversalLinkNavigation" object:nil];
    
    // 添加场景更新通知监听，iOS 13+
    if ([[XZiOSVersionManager sharedManager] isiOS13Later]) {
        [[NSNotificationCenter defaultCenter] addObserver:self 
                                                 selector:@selector(sceneWillDeactivate:) 
                                                     name:UISceneWillDeactivateNotification 
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self 
                                                 selector:@selector(sceneDidEnterBackground:) 
                                                     name:UISceneDidEnterBackgroundNotification 
                                                   object:nil];
    }
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
    [super viewDidAppear:animated];
    
    // 清除消失标志
    _isDisappearing = NO;
    
    // 记录这一次选中的索引
    self.lastSelectedIndex = self.tabBarController.selectedIndex;
    
    // 🚀【性能优化】检查WebView是否已在viewDidLoad中创建
    if (self.webView && self.isWebViewPreCreated) {
        NSLog(@"在局Claude Code[性能优化]+WebView已在viewDidLoad中创建，跳过重复创建");
        // WebView已创建，只需要检查是否需要加载内容
        if (![self hasValidWebViewContent] && self.pinUrl && self.pinUrl.length > 0) {
            NSLog(@"在局Claude Code[性能优化]+WebView已创建但无内容，执行domainOperate");
            [self domainOperate];
        }
    } else {
        // WebView未创建，使用原有逻辑
        [self setupAndLoadWebViewIfNeeded];
    }
    
    // 启动网络监控
//    [self listenToTimer];
    
    // 检查是否从交互式转场返回 - 需要排除Tab切换情况
    BOOL isFromInteractiveTransition = NO;
    
    // 首先检查是否为Tab切换
    BOOL isTabSwitch = NO;
    if (self.tabBarController) {
        // 检查当前控制器是否是TabBar的直接子控制器或在其导航栈中
        UIViewController *selectedVC = self.tabBarController.selectedViewController;
        if (selectedVC == self || 
            (selectedVC == self.navigationController) ||
            ([selectedVC isKindOfClass:[UINavigationController class]] && 
             [(UINavigationController *)selectedVC viewControllers].count == 1 &&
             ((UINavigationController *)selectedVC).topViewController == self)) {
            isTabSwitch = YES;
        }
    }
    
    if (!isTabSwitch && [self.navigationController isKindOfClass:NSClassFromString(@"XZNavigationController")]) {
        // 使用KVC安全地检查交互式转场状态
        @try {
            NSNumber *wasInteractiveValue = [self.navigationController valueForKey:@"isInteractiveTransition"];
            BOOL wasInteractive = [wasInteractiveValue boolValue];
            
            // 只有在真正的交互式返回时才启动特殊恢复流程
            // 检查条件：1. 有动画 2. 曾经是交互式转场 3. 当前在导航栈中 且不是栈顶页面
            NSInteger currentIndex = [self.navigationController.viewControllers indexOfObject:self];
            NSInteger totalVCCount = self.navigationController.viewControllers.count;
            
            // 进一步检查：只有在导航栈数量 > 1 且不是根控制器时才考虑交互式返回
            isFromInteractiveTransition = animated && wasInteractive && 
                                        currentIndex != NSNotFound && 
                                        totalVCCount > 1 && 
                                        currentIndex < totalVCCount &&
                                        currentIndex > 0; // 不是根控制器
            
        } @catch (NSException *exception) {
            isFromInteractiveTransition = NO;
        }
    }
    
    if (isFromInteractiveTransition) {
        
        // 立即重置交互式转场状态，防止后续误判
        @try {
            [self.navigationController setValue:@NO forKey:@"isInteractiveTransition"];
        } @catch (NSException *exception) {
        }
        
        // 在恢复之前先检查是否有有效内容
        BOOL hasValidContent = [self hasValidWebViewContent];
        
        if (hasValidContent) {
            // 只执行状态恢复，不重新加载页面
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                // 只恢复UI状态，确保WebView可见
                if (self.webView) {
                    self.webView.hidden = NO;
                    self.webView.alpha = 1.0;
                    [self.webView setNeedsLayout];
                    [self.webView layoutIfNeeded];
                }
            });
        } else {
            // 特殊处理：从交互式转场返回时，需要特别恢复WebView状态
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self restoreWebViewStateAfterInteractiveTransition];
            });
        }
    } else {
        // 优化显示逻辑：检查页面是否已经加载完成，避免重复加载
        BOOL hasValidContent = [self hasValidWebViewContent];
        BOOL isNavigationReturn = [self isNavigationReturnScenario];
        
        
        // 1. 如果页面已有有效内容，无论什么场景都只触发pageShow，不重新加载
        if (hasValidContent) {
            
            // 确保WebView可见性
            self.webView.hidden = NO;
            self.webView.alpha = 1.0;
            self.webView.userInteractionEnabled = YES;
            
            // 触发页面显示事件
            NSDictionary *callJsDic = [CustomHybridProcessor custom_objcCallJsWithFn:@"pageShow" data:nil];
            [self objcCallJs:callJsDic];
            
            // 在局Claude Code[Tab空白修复]+pageShow后检查页面是否真的显示
            if (self.isTabbarShow) {
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [self checkAndFixPageVisibility];
                });
            }
            
            return; // 避免任何重新加载
        }
        
        // 2. 如果是返回导航且WebView已初始化，尝试恢复而非重新加载
        if (isNavigationReturn && self.webView) {
            
            // 检查是否有最基本的页面结构
            if (self.webView.URL && ![self.webView.URL.absoluteString containsString:@"manifest/"]) {
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
            
            // 防止过于频繁的加载
            static NSDate *lastLoadTime = nil;
            NSDate *now = [NSDate date];
            if (lastLoadTime && [now timeIntervalSinceDate:lastLoadTime] < 2.0) {
                return;
            }
            lastLoadTime = now;
            
            [self domainOperate];
        } else {
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
    
    // 检查网络状态 - 改为记录状态而不是直接返回，允许WebView创建和基本设置
    AppDelegate *appDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
    BOOL networkRestricted = appDelegate.networkRestricted;
    if (networkRestricted) {
    }

    // 【性能优化】如果WebView已经预创建，直接使用
    if (self.isWebViewPreCreated && self.webView) {
        
        // 确保WebView已正确添加到视图层级
        if (!self.webView.superview) {
            [self addWebView];
        }
        
        // 确保桥接已设置
        if (!self.isBridgeReady) {
            [self setupUnifiedJavaScriptBridge];
        }
        
        // 检查是否已有有效内容，避免重复加载
        if ([self hasValidWebViewContent]) {
            return;
        }
        
        // 检查是否需要加载HTML内容
        if (self.htmlStr && self.htmlStr.length > 0) {
            [self optimizedLoadHTMLContent];
        } else if (self.pinDataStr && self.pinDataStr.length > 0) {
            [self optimizedLoadHTMLContent];
        } else {
            // 等待domainOperate完成后会自动调用加载方法
        }
        
        return;
    }
    
    // 【性能优化】如果WebView未预创建，启动快速创建流程
    if (!self.webView && !self.isWebViewLoading) {
        
        // 标记为正在加载，避免重复创建
        self.isWebViewLoading = YES;
        
        // 使用优化的WebView创建流程
        dispatch_async(dispatch_get_main_queue(), ^{
            // 🚀【性能优化】优先从WebView池获取预热的实例
            XZWebViewPerformanceManager *performanceManager = [XZWebViewPerformanceManager sharedManager];
            WKWebView *pooledWebView = [performanceManager getPrewarmedWebView];
            
            if (pooledWebView) {
                NSLog(@"在局Claude Code[性能优化]+使用预热的WebView");
                self.webView = pooledWebView;
                self.webView.backgroundColor = [UIColor whiteColor];
            } else {
                NSLog(@"在局Claude Code[性能优化]+WebView池为空，创建新实例");
                // 创建优化的WebView配置
                WKWebViewConfiguration *configuration = [self createOptimizedWebViewConfiguration];
                
                // 创建WebView实例
                self.webView = [[WKWebView alloc] initWithFrame:CGRectZero configuration:configuration];
                self.webView.backgroundColor = [UIColor whiteColor];
            }
            
            // 🔧 关键修复：立即设置桥接，确保navigationDelegate不会为nil
            [self setupUnifiedJavaScriptBridge];
            
            // 添加到视图层级
            [self addWebView];
            
            // 重置加载状态
            self.isWebViewLoading = NO;
            self.isWebViewPreCreated = YES;
            
            
            // 检查是否需要加载HTML内容
            if (self.htmlStr && self.htmlStr.length > 0) {
                [self optimizedLoadHTMLContent];
            } else if (self.pinDataStr && self.pinDataStr.length > 0) {
                [self optimizedLoadHTMLContent];
            } else {
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
        // 在局Claude Code[KVO崩溃修复]+使用标志位防止重复移除
        if (self.isKVORegistered) {
            @try {
                [self.webView removeObserver:self forKeyPath:@"estimatedProgress"];
                [self.webView removeObserver:self forKeyPath:@"title"];
                self.isKVORegistered = NO;
                NSLog(@"在局Claude Code[KVO崩溃修复]+已移除KVO观察者");
            } @catch (NSException *exception) {
                NSLog(@"在局Claude Code[KVO崩溃修复]+移除KVO观察者异常: %@", exception);
            }
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
    if (self.userContentController) {
        // 移除所有用户脚本
        [self.userContentController removeAllUserScripts];
        
        // 注意：只有在添加了scriptMessageHandler时才需要移除
        // 当前代码未使用addScriptMessageHandler，所以注释掉以下行
        // [self.userContentController removeScriptMessageHandlerForName:@"consoleLog"];
        
        self.userContentController = nil;
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
    if ([[XZiOSVersionManager sharedManager] isiOS14Later]) {
        configuration.defaultWebpagePreferences.allowsContentJavaScript = YES;
    }
    
    // 配置安全设置，允许混合内容
    if ([[XZiOSVersionManager sharedManager] isSystemVersionGreaterThanOrEqualTo:10.0]) {
        configuration.mediaTypesRequiringUserActionForPlayback = WKAudiovisualMediaTypeNone;
    }
    
    // 允许任意加载（开发环境）
    if ([[XZiOSVersionManager sharedManager] isSystemVersionGreaterThanOrEqualTo:9.0]) {
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
    if ([[XZiOSVersionManager sharedManager] isSystemVersionGreaterThanOrEqualTo:9.0]) {
        self.webView.allowsBackForwardNavigationGestures = NO;
    }
    
    // 配置滚动视图 - 修复iOS 12键盘弹起后布局问题
    if ([[XZiOSVersionManager sharedManager] isSystemVersionGreaterThanOrEqualTo:12.0]) {
        // iOS 12及以上版本使用Automatic，避免键盘弹起后视图不恢复的问题
        self.webView.scrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentAutomatic;
    } else if ([[XZiOSVersionManager sharedManager] isiOS11Later]) {
        // iOS 11使用Never
        self.webView.scrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    } else {
        self.automaticallyAdjustsScrollViewInsets = NO;
    }
    
    // 根据资料建议，添加进度监听
    // 在局Claude Code[KVO崩溃修复]+使用标志位防止重复添加观察者
    if (!self.isKVORegistered) {
        [self.webView addObserver:self forKeyPath:@"estimatedProgress" options:NSKeyValueObservingOptionNew context:NULL];
        [self.webView addObserver:self forKeyPath:@"title" options:NSKeyValueObservingOptionNew context:NULL];
        self.isKVORegistered = YES;
        NSLog(@"在局Claude Code[KVO崩溃修复]+已注册KVO观察者");
    } else {
        NSLog(@"在局Claude Code[KVO崩溃修复]+KVO观察者已存在，跳过重复注册");
    }
    
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
    
    // 配置下拉刷新控件
    __weak UIScrollView *scrollView = self.webView.scrollView;
    
    if (!scrollView) {
        return;
    }
    
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
        
    }
    
    // 设置下拉刷新文本
    [header setTitle:@"下拉刷新" forState:MJRefreshStateIdle];
    [header setTitle:@"释放刷新" forState:MJRefreshStatePulling];
    [header setTitle:@"正在刷新..." forState:MJRefreshStateRefreshing];
    
    // 添加下拉刷新控件
    scrollView.mj_header = header;
    
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
        // 使用XZiOSVersionManager获取统一的状态栏和导航栏高度
        XZiOSVersionManager *versionManager = [XZiOSVersionManager sharedManager];
        CGFloat navBarBottom = versionManager.statusBarHeight + versionManager.navigationBarHeight;
        self.progressView.frame = CGRectMake(0, navBarBottom, self.view.bounds.size.width, 3);
    } else {
        // 如果没有导航栏，放在状态栏下方
        CGFloat statusBarHeight = [[XZiOSVersionManager sharedManager] statusBarHeight];
        self.progressView.frame = CGRectMake(0, statusBarHeight, self.view.bounds.size.width, 3);
    }
    
    // 确保进度条始终在最上层
    [self.view bringSubviewToFront:self.progressView];
    */
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
        
        
        // 彻底刷新页面，让条件页面重新执行状态判断
        if ([AFNetworkReachabilityManager manager].networkReachabilityStatus != AFNetworkReachabilityStatusNotReachable) {
            [self domainOperate];
        } else {
        }
    }];
    // 监听网络权限恢复通知 - 修复Release版本首页空白问题
    [[NSNotificationCenter defaultCenter] addObserverForName:@"NetworkPermissionRestored" object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
        STRONG_SELF;
        if (!self) return;


        // 增加防重复处理机制
        static NSDate *lastNetworkRecoveryTime = nil;
        NSDate *now = [NSDate date];
        if (lastNetworkRecoveryTime && [now timeIntervalSinceDate:lastNetworkRecoveryTime] < 5.0) {
            return;
        }
        lastNetworkRecoveryTime = now;

        // 只对当前显示在窗口中的视图控制器进行操作，且必须是首页
        if (self.isViewLoaded && self.view.window && self.tabBarController.selectedIndex == 0) {
            
            // 1. 重置节流阀，允许重新加载
            lastLoadTime = nil;
            
            // 2. 停止当前加载
            if (self.webView) {
                [self.webView stopLoading];
            }
            
            // 3. 检查页面是否已加载完成（在重置状态之前）
            BOOL wasPageLoaded = self.isLoading;
            BOOL hasValidContent = [self hasValidWebViewContent];
            
            // 4. 重置加载状态
            self.isWebViewLoading = NO;
            self.isLoading = NO;
            
            // 5. 关键修复：如果页面之前已经加载完成或有有效内容，直接触发接口刷新而不是重新加载整个页面
            if (self.webView && (wasPageLoaded || hasValidContent)) {
                NSLog(@"在局Claude Code[网络恢复]+页面已加载，只刷新数据不重新加载页面");
                
                // 触发JavaScript的网络恢复和数据刷新
                NSString *refreshScript = @"(function() {"
                    "try {"
                    "    var result = {};"
                    "    // 通知页面网络已恢复"
                    "    if (typeof app !== 'undefined') {"
                    "        if (typeof app.onNetworkRestore === 'function') {"
                    "            app.onNetworkRestore();"
                    "            result.appNetworkRestore = true;"
                    "        }"
                    "        if (typeof app.refreshData === 'function') {"
                    "            app.refreshData();"
                    "            result.refreshData = true;"
                    "        }"
                    "        if (typeof app.loadHomeData === 'function') {"
                    "            app.loadHomeData();"
                    "            result.loadHomeData = true;"
                    "        }"
                    "    }"
                    "    // 触发全局网络恢复事件"
                    "    if (typeof window.onNetworkAvailable === 'function') {"
                    "        window.onNetworkAvailable();"
                    "        result.windowNetworkAvailable = true;"
                    "    }"
                    "    // 发送网络恢复事件"
                    "    var event = new CustomEvent('networkRestore', {detail: {source: 'networkPermissionRestore'}});"
                    "    window.dispatchEvent(event);"
                    "    result.eventDispatched = true;"
                    "    result.success = true;"
                    "    result.timestamp = new Date().getTime();"
                    "    return JSON.stringify(result);"
                    "} catch(e) {"
                    "    return JSON.stringify({success: false, error: e.message});"
                    "}"
                "})()";
                
                [self safelyEvaluateJavaScript:refreshScript completionHandler:^(id result, NSError *error) {
                    if (error) {
                    } else {
                    }
                }];
                
                return; // 直接返回，不执行重新加载
            }
            
            // 6. 延迟执行加载操作（只有在页面未加载时才执行）
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), 
                dispatch_get_main_queue(), ^{
                // 再次检查是否仍然是首页
                if (self.tabBarController.selectedIndex == 0 && self.pinUrl) {
                    // 如果WebView不存在，会在setupAndLoadWebViewIfNeeded中创建
                    [self setupAndLoadWebViewIfNeeded];
                } else {
                }
            });
        } else {
        }
    }];
    // 监听backToHome通知，用于tab切换
    [[NSNotificationCenter defaultCenter] addObserverForName:@"backToHome" object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
        STRONG_SELF;
        if (!self) {
            return;
        }
        
        
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
                // 先检查是否已有有效内容，避免不必要的重新加载
                if ([self hasValidWebViewContent]) {
                    // 只触发pageShow事件，不重新加载
                    NSDictionary *callJsDic = [CustomHybridProcessor custom_objcCallJsWithFn:@"pageShow" data:nil];
                    [self objcCallJs:callJsDic];
                } else {
                    // 使用performSelector延迟执行，可以被取消
                    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(domainOperate) object:nil];
                    [self performSelector:@selector(domainOperate) withObject:nil afterDelay:0.2];
                }
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


        // 同样调用统一的加载方法。
        // 它内部的检查会防止在已加载的情况下重复执行。
        [self setupAndLoadWebViewIfNeeded];
    }];
}

// 在 XZWKWebViewBaseController.m 中
- (void)setCustomUserAgent {
    // 直接定义一个完整的UserAgent字符串，防止异步等待和死锁的问题
    NSString *customUserAgent = @"Mozilla/5.0 (iPhone; CPU iPhone OS 13_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/13.0 Mobile/15E148 Safari/604.1 XZApp/1.0";
    
    // 直接在主线程上安全地设置它
    // 确保在主线程执行
    if ([NSThread isMainThread]) {
        self.webView.customUserAgent = customUserAgent;
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.webView.customUserAgent = customUserAgent;
        });
    }
}
#pragma mark - WebView Management

- (void)addWebView {
    
    [self.view addSubview:self.webView];
    
    if (self.navigationController.viewControllers.count > 1) {
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
                if ([[XZiOSVersionManager sharedManager] isiOS11Later]) {
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
    if (self.webView.scrollView && !self.webView.scrollView.mj_header) {
        [self setupRefreshControl];
    } else if (self.webView.scrollView.mj_header) {
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
        // 如果约束没有生效，手动设置frame
        CGRect viewBounds = self.view.bounds;
        if (CGRectEqualToRect(viewBounds, CGRectZero)) {
            // 如果view的bounds也是0，使用默认尺寸
            CGSize screenSize = [UIScreen mainScreen].bounds.size;
            viewBounds = CGRectMake(0, 0, screenSize.width, screenSize.height);
        }
        
        // 根据页面类型调整frame
        if (self.navigationController.viewControllers.count > 1) {
            // 内页模式：全屏显示
            self.webView.frame = viewBounds;
        } else {
            // 首页模式：需要考虑TabBar
            if (![[NSUserDefaults standardUserDefaults] boolForKey:@"NoTabBar"]) {
                viewBounds.size.height -= 83; // TabBar高度
            }
            self.webView.frame = viewBounds;
        }
        
    } else {
    }
}

// 统一的JavaScript桥接设置方法（合并原有的三个方法）
- (void)setupUnifiedJavaScriptBridge {
    // 基础检查
    if (!self.webView || ![self.webView isKindOfClass:[WKWebView class]]) {
        return;
    }
    
    if (self.bridge && self.isBridgeReady) {
        return; // 桥接已就绪
    }
    
    // 启用桥接日志
    [WKWebViewJavascriptBridge enableLogging];
    
    // 清理旧的桥接实例
    if (self.bridge) {
        self.bridge = nil;
    }
    
    // 创建新的桥接实例
    self.bridge = [WKWebViewJavascriptBridge bridgeForWebView:self.webView];
    if (!self.bridge) {
        return;
    }
    
    // 设置WebView代理
    [self.bridge setWebViewDelegate:self];
    
    // 注册统一的处理器
    [self registerUnifiedBridgeHandlers];
    
    // 标记桥接已就绪
    self.isBridgeReady = YES;
    
    // JavaScript桥接已就绪，可以执行待处理的脚本
    NSLog(@"在局Claude Code[JavaScript桥接]+桥接初始化完成，可以开始执行JavaScript调用");
}

// 注册统一的桥接处理器
- (void)registerUnifiedBridgeHandlers {
    __weak typeof(self) weakSelf = self;
    
    // 主要的xzBridge处理器
    [self.bridge registerHandler:@"xzBridge" handler:^(id data, WVJBResponseCallback responseCallback) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf) {
            [strongSelf jsCallObjc:data jsCallBack:responseCallback];
        }
    }];
    
    // pageReady处理器
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
        if (responseCallback) {
            responseCallback(@{
                @"success": @YES,
                @"message": @"桥接正常工作",
                @"timestamp": @([[NSDate date] timeIntervalSince1970])
            });
        }
    }];
    
    // 调试处理器
    [self.bridge registerHandler:@"debugLog" handler:^(id data, WVJBResponseCallback responseCallback) {
        if (responseCallback) {
            responseCallback(@{@"received": @YES});
        }
    }];
}



- (void)domainOperate {
    NSLog(@"在局Claude Code[domainOperate]+开始执行domainOperate, pinUrl: %@", self.pinUrl);
    
    // 强化防重复逻辑 - 如果WebView已有有效内容，不要重复加载
    if ([self hasValidWebViewContent]) {
        NSLog(@"在局Claude Code[domainOperate]+WebView已有有效内容，只触发pageShow");
        // 如果已有内容，只触发pageShow事件
        if (self.webView) {
            NSDictionary *callJsDic = [CustomHybridProcessor custom_objcCallJsWithFn:@"pageShow" data:nil];
            [self objcCallJs:callJsDic];
        }
        return;
    }
    
    // 防止频繁调用（与loadHTMLContent共享时间检查），但如果WebView未创建则允许执行
    NSDate *now = [NSDate date];
    if (lastLoadTime && [now timeIntervalSinceDate:lastLoadTime] < 2.0 && self.webView != nil) {
        NSLog(@"在局Claude Code[domainOperate]+防频繁调用拦截，距离上次加载时间: %.2f秒", 
              [now timeIntervalSinceDate:lastLoadTime]);
        return;
    }
    
    // 🔧 新增功能：检查是否为外部网络URL，如果是则直接加载
    if (self.pinUrl && self.pinUrl.length > 0) {
        BOOL isNetworkURL = [self.pinUrl hasPrefix:@"http://"] || [self.pinUrl hasPrefix:@"https://"];
        
        if (isNetworkURL) {
            // 获取应用的主域名
            NSString *appDomain = [[NSUserDefaults standardUserDefaults] objectForKey:@"kUserDefaults_domainStr"];
            BOOL isExternalURL = NO;
            
            if (appDomain && appDomain.length > 0) {
                // 检查URL是否包含应用域名
                BOOL containsAppDomain = [self.pinUrl containsString:appDomain];
                isExternalURL = !containsAppDomain;
                
            } else {
                // 如果没有配置域名，通过常见的外部域名来判断
                NSArray *externalDomains = @[@"m.amap.com", @"map.baidu.com", @"ditu.amap.com", 
                                           @"maps.google.com", @"weixin.qq.com", @"mp.weixin.qq.com"];
                
                for (NSString *domain in externalDomains) {
                    if ([self.pinUrl containsString:domain]) {
                        isExternalURL = YES;
                        break;
                    }
                }
                
            }
            
            if (isExternalURL) {
                
                // 直接加载网络URL
                dispatch_async(dispatch_get_main_queue(), ^{
                    // 确保WebView存在
                    if (!self.webView) {
                        // WebView还没创建，先标记需要加载网络URL，等待viewDidAppear中创建后加载
                        return;
                    }
                    
                    
                    // 确保桥接已建立（网络页面也可能需要桥接）
                    if (!self.bridge) {
                        [self setupUnifiedJavaScriptBridge];
                    }
                    
                    // 重置加载状态
                    self.isWebViewLoading = NO;
                    self.isLoading = NO;
                    
                    // 创建网络请求
                    NSURL *url = [NSURL URLWithString:self.pinUrl];
                    
                    // 🚀【性能优化】为首页URL设置特殊的缓存策略
                    NSURLRequest *request;
                    if ([self.pinUrl containsString:@"zaiju.com/p/home/index/index"]) {
                        NSLog(@"在局Claude Code[性能优化]+检测到首页URL，使用激进缓存策略");
                        // 首页使用缓存优先策略，减少网络请求
                        NSMutableURLRequest *mutableRequest = [NSMutableURLRequest requestWithURL:url];
                        mutableRequest.cachePolicy = NSURLRequestReturnCacheDataElseLoad; // 优先使用缓存，缓存不存在才请求网络
                        mutableRequest.timeoutInterval = 60.0; // 首页超时时间设置为60秒
                        
                        // 添加缓存控制头
                        [mutableRequest setValue:@"max-age=300" forHTTPHeaderField:@"Cache-Control"]; // 缓存5分钟
                        request = [mutableRequest copy];
                    } else {
                        NSLog(@"在局Claude Code[性能优化]+非首页URL，使用默认缓存策略");
                        // 其他页面使用默认缓存策略
                        request = [NSURLRequest requestWithURL:url 
                                            cachePolicy:NSURLRequestUseProtocolCachePolicy 
                                        timeoutInterval:45.0];
                    }
                    
                    // 加载网络URL
                    [self.webView loadRequest:request];
                    
                    
                    // 启动页面加载监控
                    [self startPageLoadMonitor];
                    
                    // 更新时间戳
                    lastLoadTime = [NSDate date];
                });
                
                return; // 直接返回，不继续执行本地HTML加载逻辑
            } else {
            }
        }
    }
    
    
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
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        NSString *filepath = [[BaseFileManager appH5LocailManifesPath] stringByAppendingPathComponent:@"app.html"];
        
        if ([[NSFileManager defaultManager] fileExistsAtPath:filepath]) {
            NSError *error;
            NSString *htmlContent = [NSString stringWithContentsOfURL:[NSURL fileURLWithPath:filepath] encoding:NSUTF8StringEncoding error:&error];
            
            // 回到主线程处理结果
            dispatch_async(dispatch_get_main_queue(), ^{
                if (!error && htmlContent) {
                    self.htmlStr = htmlContent;
                    
                    // 检查WebView是否已经创建
                    if (self.webView) {
                        [self loadHTMLContent];
                    } else {
                        // WebView还没创建，等待viewDidAppear中创建后会自动调用loadHTMLContent
                    }
                } else {
                    self.networkNoteView.hidden = NO;
                }
            });
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                self.networkNoteView.hidden = NO;
            });
        }
    });
}

- (void)loadHTMLContent {
    
    // 【性能优化】优先使用优化的HTML加载方法
    if (self.webView && (self.pinDataStr || [[self class] getCachedHTMLTemplate])) {
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
            [self setupUnifiedJavaScriptBridge];
            
            // 直接尝试加载，不再延迟 - 修复tab切换时dispatch_after不执行的问题
            
            // 添加桥接状态检查
            if (self.bridge) {
                [self performHTMLLoading];
            } else {
                // 如果桥接创建失败，使用performSelector延迟重试（可以被取消）
                [self performSelector:@selector(retryHTMLLoading) withObject:nil afterDelay:0.1];
            }
        } else {
            // 桥接已存在，直接加载
            [self performHTMLLoading];
        }
    } else {
    }
}

// 重试HTML加载的方法
- (void)retryHTMLLoading {
    
    // 应用与CustomHybridProcessor相同的修复逻辑
    if (_isDisappearing) {
        UIApplicationState appState = [[UIApplication sharedApplication] applicationState];
        BOOL isFromExternalApp = (appState == UIApplicationStateActive) && 
                               (self.view.window != nil) && 
                               (self.tabBarController != nil);
        
        if (isFromExternalApp) {
            _isDisappearing = NO;
        } else {
            return;
        }
    }
    
    if (self.bridge) {
        [self performHTMLLoading];
    } else {
    }
}

// 新增方法：执行实际的HTML加载
- (void)performHTMLLoading {
    
    // 添加WebView健康检查和重建机制
    if (![self checkAndRebuildWebViewIfNeeded]) {
        return;
    }
    
    // 🔧 关键修复：在加载HTML前确保WebView frame正确
    if (CGRectIsEmpty(self.webView.frame) || self.webView.frame.size.width == 0) {
        
        // 强制重新添加WebView以修复frame问题
        [self.webView removeFromSuperview];
        [self addWebView];
        
        
        // 如果仍然是0，直接返回，等待布局完成
        if (CGRectIsEmpty(self.webView.frame)) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self performHTMLLoading];
            });
            return;
        }
    }
    
    if (self.pinDataStr && self.pinDataStr.length > 0) {
        // 直接数据模式
        
        if (self.pagetitle) {
            NSLog(@"在局Claude Code[performHTMLLoading]+调用getnavigationBarTitleText，标题: %@", self.pagetitle);
            [self getnavigationBarTitleText:self.pagetitle];
        } else {
            NSLog(@"在局Claude Code[performHTMLLoading]+pagetitle为空，未设置标题");
        }
        
        NSString *allHtmlStr = [self.htmlStr stringByReplacingOccurrencesOfString:@"{{body}}" withString:self.pinDataStr];
        
        if ([self isHaveNativeHeader:self.pinUrl]) {
            allHtmlStr = [allHtmlStr stringByReplacingOccurrencesOfString:@"{{phoneClass}}" withString:isIPhoneXSeries() ? @"iPhoneLiuHai" : @"iPhone"];
        }
        
        
        // 使用manifest目录作为baseURL，确保资源正确加载
        NSString *manifestPath = [BaseFileManager appH5LocailManifesPath];
        NSURL *baseURL = [NSURL fileURLWithPath:manifestPath isDirectory:YES];
        
        
        
        
        // 关键修复：简化dispatch调用，避免Release版本中的嵌套问题
        
        // 验证WebView状态
        if (!self.webView) {
            return;
        }
        
        // 检查WebView的navigation delegate状态并自动修复
        if (!self.webView.navigationDelegate) {
            if (self.bridge) {
                // 🔧 关键修复：重新设置Bridge为navigationDelegate
                self.webView.navigationDelegate = self.bridge;
            } else {
                return;
            }
        } else {
        }
        
        // 确保WebView在window中且有正确frame
        if (!self.webView.superview) {
            return;
        }
        
        
        // 停止任何正在进行的加载
        [self.webView stopLoading];
        
        // 直接数据模式也增加详细的dispatch追踪
        
        static int directDispatchTaskId = 1000;
        int currentDirectTaskId = ++directDispatchTaskId;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            // 检查self和WebView状态
            if (!self || !self.webView) {
                return;
            }
            
            
            // 对于第二个Tab，启动加载监控
            if (self.tabBarController && self.tabBarController.selectedIndex > 0) {
                [self startWebViewLoadingMonitor];
            }
            
            // 直接使用loadHTMLString:baseURL:方法
            
            @try {
                [self.webView loadHTMLString:allHtmlStr baseURL:baseURL];
            } @catch (NSException *exception) {
            }
            
            
            // 启动定时器监控页面加载
            [self startPageLoadMonitor];
            
        });
        
        
        // 直接数据模式也增加fallback机制
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (self && self.webView && !self.isWebViewLoading) {
                
                @try {
                    [self.webView loadHTMLString:allHtmlStr baseURL:baseURL];
                } @catch (NSException *exception) {
                }
            } else {
            }
        });
    } else {
        // 使用CustomHybridProcessor处理
        [CustomHybridProcessor custom_LocialPathByUrlStr:self.pinUrl
                                             templateDic:self.templateDic
                                        componentJsAndCs:self.componentJsAndCs
                                          componentDic:self.componentDic
                                                 success:^(NSString *filePath, NSString *templateStr, NSString *title, BOOL isFileExsit) {
            
            @try {
                if (!self) {
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
                        // 重置标志，允许继续执行
                        self->_isDisappearing = NO;
                    } else {
                        return;
                    }
                }
                if (!self.webView) {
                    return;
                }
                
                [self getnavigationBarTitleText:title];
                
                if (!self.htmlStr) {
                    return;
                }
                if (!templateStr) {
                    templateStr = @"";
                }
                
                NSString *allHtmlStr = [self.htmlStr stringByReplacingOccurrencesOfString:@"{{body}}" withString:templateStr];
                
                if ([self isHaveNativeHeader:self.pinUrl]) {
                    allHtmlStr = [allHtmlStr stringByReplacingOccurrencesOfString:@"{{phoneClass}}" withString:isIPhoneXSeries() ? @"iPhoneLiuHai" : @"iPhone"];
                }
                
                
                // 添加调试：检查body内容是否正确替换
                NSRange bodyRange = [allHtmlStr rangeOfString:@"<div id=\"pageWrapper\">"];
                if (bodyRange.location != NSNotFound) {
                    NSRange endRange = [allHtmlStr rangeOfString:@"</div>" options:0 range:NSMakeRange(bodyRange.location, allHtmlStr.length - bodyRange.location)];
                    if (endRange.location != NSNotFound) {
                        NSString *bodyContent = [allHtmlStr substringWithRange:NSMakeRange(bodyRange.location, endRange.location - bodyRange.location + 6)];
                    }
                }
                
                // 使用manifest目录作为baseURL，确保资源正确加载
                NSString *manifestPath = [BaseFileManager appH5LocailManifesPath];
                NSURL *baseURL = [NSURL fileURLWithPath:manifestPath isDirectory:YES];
                
                
                // 检查是否是首页加载
                
                if (!self.webView) {
                    return;
                }
                
                // 关键修复：简化dispatch调用，避免Release版本中的嵌套问题
                
                // 验证WebView状态
                if (!self.webView) {
                    return;
                }
                
                // 检查WebView的navigation delegate状态并自动修复
                if (!self.webView.navigationDelegate) {
                    if (self.bridge) {
                        // 🔧 关键修复：重新设置Bridge为navigationDelegate
                        self.webView.navigationDelegate = self.bridge;
                    } else {
                        return;
                    }
                } else {
                }
                
                // 确保WebView在window中且有正确frame
                if (!self.webView.superview) {
                    return;
                }
                
                
                // 停止任何正在进行的加载
                [self.webView stopLoading];
                
                // 关键修复：增加dispatch执行追踪，解决Release版本中断问题
                
                
                // 防重复执行检查
                if (self.isLoadingInProgress) {
                    return;
                }
                
                // 标记正在执行中
                self.isLoadingInProgress = YES;
                
                // 添加任务计数器
                static int dispatchTaskId = 0;
                int currentTaskId = ++dispatchTaskId;
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    
                    // 检查self状态
                    if (!self) {
                        return;
                    }
                    
                    // 检查WebView状态
                    if (!self.webView) {
                        return;
                    }
                    
                    
                    // 对于第二个Tab，启动加载监控
                    if (self.tabBarController && self.tabBarController.selectedIndex > 0) {
                        [self startWebViewLoadingMonitor];
                    }
                    
                    
                    // 直接使用loadHTMLString:baseURL:方法
                    
                    @try {
                        [self.webView loadHTMLString:allHtmlStr baseURL:baseURL];
                    } @catch (NSException *exception) {
                    }
                    
                    
                    // 启动定时器监控页面加载
                    [self startPageLoadMonitor];
                    
                    
                    // 解除加载锁定状态（延迟解除，防止时序问题）
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        if (self) {
                            self.isLoadingInProgress = NO;
                        }
                    });
                });
                
                
                // Release版本fallback机制：如果dispatch在短时间内未执行，直接在主线程调用
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    // 检查是否已经成功调用loadHTMLString（通过检查WebView的loading状态）
                    if (self && self.webView && !self.isWebViewLoading) {
                        
                        @try {
                            [self.webView loadHTMLString:allHtmlStr baseURL:baseURL];
                        } @catch (NSException *exception) {
                        }
                        
                        // fallback执行后也解除锁定
                        if (self) {
                            self.isLoadingInProgress = NO;
                        }
                    } else {
                    }
                });
                
                // 延迟测试JavaScript桥接是否正常工作
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    @try {
                        
                        // 更详细的桥接诊断测试
                        NSString *diagnosticJS = @"(function(){"
                            "var result = {"
                                "bridgeExists: typeof WebViewJavascriptBridge !== 'undefined',"
                                "bridgeObject: window.WebViewJavascriptBridge,"
                                "bridgeType: typeof WebViewJavascriptBridge,"
                                "bridgeMethods: window.WebViewJavascriptBridge ? Object.keys(window.WebViewJavascriptBridge) : null,"
                                "windowProps: Object.keys(window).filter(k => k.includes('Bridge') || k.includes('bridge')),"
                                "timestamp: new Date().getTime()"
                            "};"
                            "if (window.WebViewJavascriptBridge && window.WebViewJavascriptBridge.callHandler) {"
                                "try {"
                                    "window.WebViewJavascriptBridge.callHandler('bridgeTest', {test: 'diagnostic'}, function(response) {"
                                        "console.log('桥接测试回调成功:', response);"
                                    "});"
                                    "result.callHandlerTest = 'success';"
                                "} catch(e) {"
                                    "result.callHandlerError = e.message;"
                                "}"
                            "}"
                            "return JSON.stringify(result);"
                        "})()";
                        
                        [self safelyEvaluateJavaScript:diagnosticJS completionHandler:^(id result, NSError *error) {
                            if (error) {
                            } else {
                                
                                // 如果桥接不存在，尝试重新注入
                                if ([result containsString:@"\"bridgeExists\":false"]) {
                                    [self forceReinjectBridge];
                                }
                            }
                        }];
                    } @catch (NSException *bridgeException) {
                    }
                });
                
            } @catch (NSException *exception) {
                
                // 即使发生异常，也要确保UI状态正确
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (self && self.networkNoteView) {
                        self.networkNoteView.hidden = NO;
                    }
                    // 异常情况下也要解除加载锁定
                    if (self) {
                        self.isLoadingInProgress = NO;
                    }
                });
            }
        }];
    }
}

#pragma mark - Navigation

- (void)getnavigationBarTitleText:(NSString *)title {
    
    // 如果标题为空，根据URL尝试提取标题
    if (!title || title.length == 0 || [title isEqualToString:@"(null)"]) {
        NSString *fallbackTitle = @"详情";  // 默认标题
        
        // 尝试从URL中提取更有意义的标题
        if (self.pinUrl) {
            
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
            
        } else {
        }
        
        self.navigationItem.title = fallbackTitle;
        
        // 强制刷新导航栏显示
        [self.navigationController.navigationBar setNeedsLayout];
        [self.navigationController.navigationBar layoutIfNeeded];
    } else {
        self.navigationItem.title = title;
        
        // 强制刷新导航栏显示
        [self.navigationController.navigationBar setNeedsLayout];
        [self.navigationController.navigationBar layoutIfNeeded];
    }
    
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
                    
                    dispatch_async(dispatch_get_main_queue(), ^{
                        // 检查网络状态
                        if (NoReachable) {
                            return;
                        }
                        [[HTMLCache sharedCache] removeObjectForKey:strongSelf.pinUrl];
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
}

- (void)jsCallObjc:(NSDictionary *)jsData jsCallBack:(WVJBResponseCallback)jsCallBack {
    NSDictionary *jsDic = (NSDictionary *)jsData;
    NSString *function = [jsDic objectForKey:@"action"];
    NSDictionary *dataDic = [jsDic objectForKey:@"data"];
    
    
    // 父类只处理基础的action
    if ([function isEqualToString:@"pageReady"]) {
        
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
        }
        
        // 通知页面显示完成 - pageReady完成后立即移除LoadingView，无论网络状态如何
        AppDelegate *appDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
        
        // 获取当前tab索引
        NSInteger currentTabIndex = self.tabBarController ? self.tabBarController.selectedIndex : -1;
        
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
                
                
                // 尝试强制刷新页面内容
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [self safelyEvaluateJavaScript:@"(function(){"
                        "try {"
                            "var result = {};"
                            "result.timestamp = new Date().getTime();"
                            "result.documentReady = document.readyState;"
                            "result.bodyExists = !!document.body;"
                            "result.htmlExists = !!document.documentElement;"
                            ""
                            "// 检查页面基本结构"
                            "if (!document.body) {"
                                "result.error = 'document.body不存在';"
                                "return JSON.stringify(result);"
                            "}"
                            ""
                            "// 强制重新渲染页面"
                            "document.body.style.display = 'none';"
                            "document.body.offsetHeight;" // 强制重排
                            "document.body.style.display = 'block';"
                            "result.displayToggled = true;"
                            ""
                            "// 检查并触发任何可能的页面初始化函数"
                            "if (typeof window.pageInit === 'function') { "
                                "window.pageInit(); "
                                "result.pageInitCalled = true;"
                            "}"
                            "if (typeof window.initPage === 'function') { "
                                "window.initPage(); "
                                "result.initPageCalled = true;"
                            "}"
                            "if (typeof app !== 'undefined' && typeof app.init === 'function') { "
                                "app.init(); "
                                "result.appInitCalled = true;"
                            "}"
                            ""
                            "// 触发resize事件"
                            "window.dispatchEvent(new Event('resize'));"
                            "result.resizeEventDispatched = true;"
                            ""
                            "result.success = true;"
                            "result.message = '页面刷新完成';"
                            "return JSON.stringify(result);"
                        "} catch(e) {"
                            "var errorResult = {"
                                "success: false,"
                                "error: e.message,"
                                "stack: e.stack,"
                                "timestamp: new Date().getTime()"
                            "};"
                            "return JSON.stringify(errorResult);"
                        "}"
                    "})()" completionHandler:^(id result, NSError *error) {
                        if (error) {
                        } else {
                        }
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

// 精简的JavaScript安全执行方法
- (void)safelyEvaluateJavaScript:(NSString *)javaScriptString completionHandler:(void (^ _Nullable)(id _Nullable, NSError * _Nullable))completionHandler {
    // 基础检查
    if (!self.webView || !javaScriptString) {
        if (completionHandler) {
            NSError *error = [NSError errorWithDomain:@"XZWebView" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"WebView不存在或脚本为空"}];
            completionHandler(nil, error);
        }
        return;
    }
    
    // 检查特殊脚本类型
    BOOL isNetworkRecoveryScenario = [javaScriptString containsString:@"onNetworkAvailable"] || 
                                    [javaScriptString containsString:@"onLoadingViewRemoved"] ||
                                    [javaScriptString containsString:@"loadingViewRemoved"] ||
                                    [javaScriptString containsString:@"onNetworkRestore"];
    
    BOOL isEssentialScript = [javaScriptString containsString:@"WebViewJavascriptBridge"] ||
                           [javaScriptString containsString:@"wx.app"] ||
                           [javaScriptString containsString:@"bridgeTest"] ||
                           [javaScriptString containsString:@"typeof app"];
    
    BOOL isInteractiveRestore = [javaScriptString containsString:@"document.body.style.display"] ||
                               [javaScriptString containsString:@"window.dispatchEvent"] ||
                               [javaScriptString containsString:@"reloadOtherPages"] ||
                               [javaScriptString containsString:@"getCurrentPages"] ||
                               [javaScriptString containsString:@"window.scrollTo"] ||
                               [javaScriptString containsString:@"visibilitychange"] ||
                               [javaScriptString containsString:@"document.readyState"] ||
                               [javaScriptString containsString:@"mainElementsCount"];
    
    // 应用状态检查
    UIApplicationState appState = [[UIApplication sharedApplication] applicationState];
    BOOL isAppActive = (appState == UIApplicationStateActive);
    BOOL isControllerActive = self.view.window != nil && !self.view.window.hidden && self.view.superview != nil;
    
    // 判断是否允许执行
    BOOL shouldExecute = isAppActive || isNetworkRecoveryScenario || isEssentialScript || 
                        (isInteractiveRestore && isControllerActive);
    
    if (!shouldExecute && !_isDisappearing) {
        if (completionHandler) {
            NSError *error = [NSError errorWithDomain:@"XZWebView" code:-2 userInfo:@{NSLocalizedDescriptionKey: @"JavaScript执行条件不满足"}];
            completionHandler(nil, error);
        }
        return;
    }
    
    // 处理页面消失的特殊情况
    if (_isDisappearing && !isNetworkRecoveryScenario && !isEssentialScript) {
        // 检查是否为手势返回取消的情况
        BOOL isInteractiveCancelled = self.webView && self.view.window && 
                                     (appState == UIApplicationStateActive || appState == UIApplicationStateInactive);
        if (isInteractiveCancelled) {
            _isDisappearing = NO;
        } else {
            if (completionHandler) {
                NSError *error = [NSError errorWithDomain:@"XZWebView" code:-3 userInfo:@{NSLocalizedDescriptionKey: @"页面正在消失"}];
                completionHandler(nil, error);
            }
            return;
        }
    }
    
    // 主线程执行JavaScript
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!self.webView || (self->_isDisappearing && !isNetworkRecoveryScenario)) {
            if (completionHandler) {
                NSError *error = [NSError errorWithDomain:@"XZWebView" code:-4 userInfo:@{NSLocalizedDescriptionKey: @"WebView已释放或页面已消失"}];
                completionHandler(nil, error);
            }
            return;
        }
        
        // 设置超时保护
        __block BOOL hasCompleted = NO;
        NSTimeInterval timeout = isNetworkRecoveryScenario ? 10.0 : 5.0;
        NSTimer *timeoutTimer = [NSTimer scheduledTimerWithTimeInterval:timeout repeats:NO block:^(NSTimer *timer) {
            if (!hasCompleted && completionHandler) {
                hasCompleted = YES;
                NSError *timeoutError = [NSError errorWithDomain:@"XZWebView" code:-5 userInfo:@{NSLocalizedDescriptionKey: @"JavaScript执行超时"}];
                completionHandler(nil, timeoutError);
            }
        }];
        
        [self->_pendingJavaScriptOperations addObject:timeoutTimer];
        
        // 执行JavaScript
        [self.webView evaluateJavaScript:javaScriptString completionHandler:^(id result, NSError *error) {
            if (hasCompleted) return;
            hasCompleted = YES;
            
            [timeoutTimer invalidate];
            [self->_pendingJavaScriptOperations removeObject:timeoutTimer];
            
            if (completionHandler) {
                // 简化的状态验证
                if (self && (isNetworkRecoveryScenario || !self->_isDisappearing)) {
                    completionHandler(result, error);
                } else {
                    NSError *stateError = [NSError errorWithDomain:@"XZWebView" code:-6 userInfo:@{NSLocalizedDescriptionKey: @"执行完成时状态已变化"}];
                    completionHandler(nil, stateError);
                }
            }
        }];
    });
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
    // 🔧 修复Main Thread Checker错误：UI API必须在主线程调用
    __block BOOL isViewControllerActive = NO;
    if ([NSThread isMainThread]) {
        isViewControllerActive = self.view.window != nil && 
                                !self.view.window.hidden && 
                                self.view.superview != nil;
    } else {
        dispatch_sync(dispatch_get_main_queue(), ^{
            isViewControllerActive = self.view.window != nil && 
                                    !self.view.window.hidden && 
                                    self.view.superview != nil;
        });
    }
    
    if (state != UIApplicationStateActive && !isEssentialAction && !isViewControllerActive) {
        return;
    } else if (state != UIApplicationStateActive && (isEssentialAction || isViewControllerActive)) {
    }
    
    // 确保在主线程执行
    dispatch_async(dispatch_get_main_queue(), ^{
        // 再次检查应用状态 - 已在主线程中
        UIApplicationState currentState = [[UIApplication sharedApplication] applicationState];
        // 在主线程中，可以安全访问UI属性
        BOOL isStillViewControllerActive = self.view.window != nil && 
                                          !self.view.window.hidden && 
                                          self.view.superview != nil;
        
        if (currentState != UIApplicationStateActive && !isEssentialAction && !isStillViewControllerActive) {
            return;
        }
        
        // 检查WebView和Bridge状态
        if (!self.webView || !self.bridge) {
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
    
    // 先检查桥接是否存在
    if (!self.bridge) {
        [self setupUnifiedJavaScriptBridge];
        
        // 如果仍然不存在，延迟重试
        if (!self.bridge) {
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
    
    
    [self safelyEvaluateJavaScript:javascriptCode completionHandler:^(id result, NSError *error) {
        if (result && !error) {
            
            // 在局Claude Code[JavaScript桥接修复]+安全地解析初始化结果
            NSDictionary *resultDict = nil;
            NSError *jsonError = nil;
            
            if ([result isKindOfClass:[NSString class]]) {
                NSData *jsonData = [(NSString *)result dataUsingEncoding:NSUTF8StringEncoding];
                if (jsonData) {
                    resultDict = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&jsonError];
                }
            } else if ([result isKindOfClass:[NSDictionary class]]) {
                resultDict = (NSDictionary *)result;
            }
            
            if (!jsonError && resultDict && [resultDict[@"error"] isEqualToString:@"environment_not_ready"]) {
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [self performJavaScriptBridgeInitialization];
                });
            }
        } else {
        }
    }];
}

// 强制检查并触发pageReady事件的方法
- (void)forceCheckAndTriggerPageReady {
    [self forceCheckAndTriggerPageReadyWithRetryCount:0];
}

// 带重试次数的强制检查页面就绪方法
- (void)forceCheckAndTriggerPageReadyWithRetryCount:(NSInteger)retryCount {
    static const NSInteger MAX_RETRY_COUNT = 5; // 最大重试次数
    
    if (retryCount >= MAX_RETRY_COUNT) {
        NSLog(@"在局Claude Code[强制页面就绪]+已达到最大重试次数(%ld)，停止重试", (long)MAX_RETRY_COUNT);
        return;
    }
    
    // 检查页面是否真正准备就绪
    NSString *checkPageReadyScript = @"(function() {"
        "var result = {};"
        "result.pageLoaded = document.readyState === 'complete';"
        "result.bridgeExists = typeof WebViewJavascriptBridge !== 'undefined';"
        "result.appExists = typeof app !== 'undefined';"
        "result.pageReadyFunctionExists = typeof pageReady !== 'undefined';"
        "result.pageReadyAlreadyCalled = window._pageReadyExecuted === true;"
        "result.bodyContent = document.body ? document.body.innerHTML.length : 0;"
        "result.currentTime = new Date().getTime();"
        "return JSON.stringify(result);"
    "})()";
    
    [self safelyEvaluateJavaScript:checkPageReadyScript completionHandler:^(id result, NSError *error) {
        if (error) {
            return;
        }
        
        
        // 在局Claude Code[JavaScript桥接修复]+安全地解析页面准备状态结果
        NSDictionary *statusDict = nil;
        NSError *jsonError = nil;
        
        if ([result isKindOfClass:[NSString class]]) {
            NSData *jsonData = [(NSString *)result dataUsingEncoding:NSUTF8StringEncoding];
            if (jsonData) {
                statusDict = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&jsonError];
            }
        } else if ([result isKindOfClass:[NSDictionary class]]) {
            statusDict = (NSDictionary *)result;
        }
        
        if (jsonError || !statusDict) {
            NSLog(@"在局Claude Code[强制页面就绪]+检查结果解析失败: %@", jsonError.localizedDescription);
            return;
        }
        
        BOOL pageLoaded = [statusDict[@"pageLoaded"] boolValue];
        BOOL bridgeExists = [statusDict[@"bridgeExists"] boolValue];
        BOOL appExists = [statusDict[@"appExists"] boolValue];
        BOOL pageReadyFunctionExists = [statusDict[@"pageReadyFunctionExists"] boolValue];
        BOOL pageReadyAlreadyCalled = [statusDict[@"pageReadyAlreadyCalled"] boolValue];
        NSInteger bodyContent = [statusDict[@"bodyContent"] integerValue];
        
        
        // 如果pageReady还没有被调用，强制触发
        if (!pageReadyAlreadyCalled && pageLoaded && bridgeExists) {
            
            NSString *forcePageReadyScript = @"(function() {"
                "try {"
                "    window._pageReadyExecuted = true;"
                "    var result = {};"
                "    if (typeof WebViewJavascriptBridge !== 'undefined' && WebViewJavascriptBridge.callHandler) {"
                "        WebViewJavascriptBridge.callHandler('xzBridge', {"
                "            fn: 'pageReady',"
                "            params: {forced: true, source: 'forceCheckAndTriggerPageReady'}"
                "        }, function(response) {"
                "            console.log('强制pageReady回调:', response);"
                "        });"
                "        result.method = 'bridge';"
                "    } else if (typeof pageReady === 'function') {"
                "        pageReady();"
                "        result.method = 'direct';"
                "    } else {"
                "        var event = new CustomEvent('pageReady', {detail: {forced: true}});"
                "        window.dispatchEvent(event);"
                "        result.method = 'event';"
                "    }"
                "    result.success = true;"
                "    result.timestamp = new Date().getTime();"
                "    return JSON.stringify(result);"
                "} catch(e) {"
                "    return JSON.stringify({success: false, error: e.message});"
                "}"
            "})()";
            
            [self safelyEvaluateJavaScript:forcePageReadyScript completionHandler:^(id triggerResult, NSError *triggerError) {
               
                
                // 额外的网络状态检查和触发
                [self scheduleJavaScriptTask:^{
                    [self triggerNetworkRecoveryIfNeeded];
                } afterDelay:0.5];
            }];
        } else if (pageReadyAlreadyCalled) {
            [self triggerNetworkRecoveryIfNeeded];
        } else {
            // 条件不满足，延迟重试（带重试次数控制）
            NSLog(@"在局Claude Code[强制页面就绪]+条件不满足，延迟重试，当前重试次数: %ld", (long)retryCount);
            [self scheduleJavaScriptTask:^{
                [self forceCheckAndTriggerPageReadyWithRetryCount:retryCount + 1];
            } afterDelay:1.0];
        }
    }];
}

// 触发网络恢复检查
- (void)triggerNetworkRecoveryIfNeeded {
    
    NSString *networkRecoveryScript = @"(function() {"
        "try {"
        "    var result = {timestamp: new Date().getTime()};"
        "    if (typeof app !== 'undefined') {"
        "        if (typeof app.onNetworkRestore === 'function') {"
        "            app.onNetworkRestore();"
        "            result.appNetworkRestore = true;"
        "        }"
        "        if (typeof app.retryFailedRequests === 'function') {"
        "            app.retryFailedRequests();"
        "            result.retryRequests = true;"
        "        }"
        "        if (typeof app.init === 'function') {"
        "            app.init();"
        "            result.appInit = true;"
        "        }"
        "    }"
        "    if (typeof window.onNetworkAvailable === 'function') {"
        "        window.onNetworkAvailable();"
        "        result.windowNetworkAvailable = true;"
        "    }"
        "    result.success = true;"
        "    return JSON.stringify(result);"
        "} catch(e) {"
        "    return JSON.stringify({success: false, error: e.message});"
        "}"
    "})()";
    
    [self safelyEvaluateJavaScript:networkRecoveryScript completionHandler:^(id result, NSError *error) {
        
    }];
}

#pragma mark - WKNavigationDelegate

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    
    // 取消页面加载监控器
    if (self.healthCheckTimer) {
        [self.healthCheckTimer invalidate];
        self.healthCheckTimer = nil;
    }
    
    // 隐藏loading指示器
    dispatch_async(dispatch_get_main_queue(), ^{
        // [self.activityIndicatorView stopAnimating]; // 已禁用loading指示器
    });
    
    // 页面加载完成后，再次尝试设置标题
    if (self.pagetitle && self.pagetitle.length > 0) {
        NSLog(@"在局Claude Code[didFinishNavigation]+页面加载完成，设置标题: %@", self.pagetitle);
        [self getnavigationBarTitleText:self.pagetitle];
    }
    
    
    // 在局Claude Code[首次安装优化]+减少JavaScript桥接初始化延迟
    [self scheduleJavaScriptTask:^{
        [self performJavaScriptBridgeInitialization];
        
        // 在局Claude Code[修复输入框双击聚焦问题]+页面加载完成后重新确保输入框聚焦优化
        [self reinjectInputFocusOptimization];
        
        // 关键修复：强制检查并触发pageReady事件（减少延迟）
        [self scheduleJavaScriptTask:^{
            [self forceCheckAndTriggerPageReady];
        } afterDelay:0.3];
    } afterDelay:0.2];
    
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
        
        // 处理待执行的JavaScript任务
        [self processPendingJavaScriptTasks];
        
    } else {
    }
}

- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    NSLog(@"在局Claude Code[WebView导航失败]+导航失败: %@, 错误码: %ld, 错误域: %@", 
          error.localizedDescription, (long)error.code, error.domain);
    
    // 隐藏loading指示器
    dispatch_async(dispatch_get_main_queue(), ^{
        // [self.activityIndicatorView stopAnimating]; // 已禁用loading指示器
        self.progressView.hidden = YES;
        self.progressView.progress = 0.0;
    });
    
    self.networkNoteView.hidden = NO;
}

- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    NSLog(@"在局Claude Code[WebView预加载失败]+预加载失败: %@, 错误码: %ld, 错误域: %@, URL: %@", 
          error.localizedDescription, (long)error.code, error.domain, error.userInfo[NSURLErrorFailingURLErrorKey]);
    
    // 隐藏loading指示器
    dispatch_async(dispatch_get_main_queue(), ^{
        // [self.activityIndicatorView stopAnimating]; // 已禁用loading指示器
        self.progressView.hidden = YES;
        self.progressView.progress = 0.0;
    });
    
    self.networkNoteView.hidden = NO;
}

- (void)webView:(WKWebView *)webView didCommitNavigation:(WKNavigation *)navigation {
   
}

- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(WKNavigation *)navigation {
  
    
    // 取消加载监控定时器（navigation delegate已触发）
    if (self.healthCheckTimer) {
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
        
    });
}

- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    NSURL *url = navigationAction.request.URL;
    NSString *scheme = url.scheme.lowercaseString;
    
    NSLog(@"在局Claude Code[WebView导航请求]+URL: %@, 类型: %ld", 
          url.absoluteString, (long)navigationAction.navigationType);
    
    // 关键：允许WebViewJavascriptBridge的wvjbscheme://连接
    if ([scheme isEqualToString:@"wvjbscheme"]) {
        decisionHandler(WKNavigationActionPolicyAllow);
        return;
    }
    
    // 处理电话客服按钮
    if ([scheme isEqualToString:@"tel"]) {
        // 在iOS 10.0以上使用新的API
        if ([[XZiOSVersionManager sharedManager] isSystemVersionGreaterThanOrEqualTo:10.0]) {
            [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:^(BOOL success) {
                
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
    
    decisionHandler(WKNavigationActionPolicyCancel);
}

#pragma mark - WKUIDelegate

// 在局Claude Code[修复输入框双击聚焦问题]+实现WKUIDelegate方法处理输入框聚焦
- (nullable WKWebView *)webView:(WKWebView *)webView createWebViewWithConfiguration:(WKWebViewConfiguration *)configuration forNavigationAction:(WKNavigationAction *)navigationAction windowFeatures:(WKWindowFeatures *)windowFeatures {
    // 处理新窗口请求，返回nil在当前窗口打开
    if (!navigationAction.targetFrame.isMainFrame) {
        [webView loadRequest:navigationAction.request];
    }
    return nil;
}

- (void)webViewDidClose:(WKWebView *)webView {
    // 处理WebView关闭事件
}

- (void)webView:(WKWebView *)webView runJavaScriptTextInputPanelWithPrompt:(NSString *)prompt defaultText:(nullable NSString *)defaultText initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(NSString * _Nullable result))completionHandler {
    // 处理JavaScript prompt，对输入框聚焦很重要
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"输入" message:prompt preferredStyle:UIAlertControllerStyleAlert];
    
    [alertController addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.text = defaultText;
    }];
    
    [alertController addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        UITextField *textField = alertController.textFields.firstObject;
        completionHandler(textField.text ?: @"");
    }]];
    
    [alertController addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
        completionHandler(nil);
    }]];
    
    [self presentViewController:alertController animated:YES completion:nil];
}

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
            // 在局Claude Code[首次安装优化]+当加载进度达到20%时就开始移除LoadingView，减少用户等待时间
            if (progress >= 0.2 && self.isTabbarShow && [self isShowingOnKeyWindow]) {
                static BOOL hasTriggeredEarlyRemoval = NO;
                if (!hasTriggeredEarlyRemoval) {
                    hasTriggeredEarlyRemoval = YES;
                    NSLog(@"在局Claude Code[首次安装优化]+WebView加载进度达到%.0f%%，提前移除LoadingView", progress * 100);
                    
                    // 发送通知移除LoadingView
                    [[NSNotificationCenter defaultCenter] postNotificationName:@"showTabviewController" object:self];
                    
                    // 直接尝试移除LoadingView
                    AppDelegate *appDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
                    if ([appDelegate respondsToSelector:@selector(removeGlobalLoadingViewWithReason:)]) {
                        [appDelegate removeGlobalLoadingViewWithReason:@"WebView加载进度达到20%"];
                    }
                }
            }
            
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
            // 更新导航栏标题
            self.navigationItem.title = title;
            NSLog(@"在局Claude Code[内页标题自动更新]+从WebView获取标题: %@", title);
        }
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}


#pragma mark - WebView Health Check

// 检查并重建WebView如果需要
- (BOOL)checkAndRebuildWebViewIfNeeded {
    
    // 检查WebView是否存在
    if (!self.webView) {
        [self setupWebView];
        [self addWebView];
        return YES;
    }
    
    // 检查navigation delegate是否正常并自动修复
    if (!self.webView.navigationDelegate) {
        if (self.bridge) {
            // 🔧 关键修复：重新设置Bridge为navigationDelegate
            self.webView.navigationDelegate = self.bridge;
        } else {
            [self setupUnifiedJavaScriptBridge];
        }
    } else {
    }
    
    // 检查WebView是否在视图层级中
    if (!self.webView.superview) {
        [self addWebView];
    }
    
    // 检查WebView的frame是否正常
    if (CGRectIsEmpty(self.webView.frame) || CGRectGetWidth(self.webView.frame) == 0) {
        [self.view setNeedsLayout];
        [self.view layoutIfNeeded];
    }
    
    // 对于第二个Tab，进行特殊的健康检查
    if (self.tabBarController && self.tabBarController.selectedIndex > 0) {
        
        // 设置加载超时监控
        [self startWebViewLoadingMonitor];
    }
    
    return YES;
}

// 启动WebView加载监控
- (void)startWebViewLoadingMonitor {
    
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
    
    // 如果页面正在消失，不处理超时
    if (_isDisappearing) {
        return;
    }
    
    // 检查是否触发了navigation delegate
    NSDate *startTime = objc_getAssociatedObject(self, @selector(startWebViewLoadingMonitor));
    NSTimeInterval elapsed = [[NSDate date] timeIntervalSinceDate:startTime];
    
    
    // 更严格的死亡状态判断
    BOOL isReallyDead = !self.isWebViewLoading && 
                        elapsed > 5.0 && // 增加最小时间要求
                        self.webView && 
                        !self.webView.isLoading && 
                        self.webView.navigationDelegate != nil; // 确保delegate存在
    
    if (isReallyDead) {
        
        // 强制重建WebView
        [self forceRebuildWebViewForDeadState];
    } else {
        
        // 如果不是真正的死亡状态，可以再等待一段时间
        if (elapsed < 10.0) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                if (!self->_isDisappearing && !self.isWebViewLoading) {
                    [self webViewLoadingTimeout];
                }
            });
        }
    }
}

// 统一的WebView重建管理
- (void)rebuildWebView {
    
    // 检查重建条件和限制
    static NSDate *lastRebuildTime = nil;
    NSDate *now = [NSDate date];
    if (lastRebuildTime && [now timeIntervalSinceDate:lastRebuildTime] < 2.0) {
        return;
    }
    lastRebuildTime = now;
    
    // 记录重建原因（用于调试）
    NSArray *callStack = [NSThread callStackSymbols];
    
    // 保存当前状态
    NSString *currentUrl = self.pinUrl;
    NSString *currentData = self.pinDataStr;
    BOOL wasLoading = self.isLoading;
    
    // 步骤1：清理旧的WebView
    [self cleanupWebView];
    
    // 步骤2：重置相关状态
    self.isLoading = NO;
    self.isWebViewLoading = NO;
    self->_retryCount = 0;
    
    // 步骤3：重新创建WebView
    [self setupWebView];
    [self addWebView];
    
    // 步骤4：重新建立JavaScript桥接
    [self setupUnifiedJavaScriptBridge];
    
    // 步骤5：恢复状态
    self.pinUrl = currentUrl;
    self.pinDataStr = currentData;
    
    
    // 步骤6：重新加载内容（延迟执行以确保WebView完全准备好）
    if (wasLoading && currentUrl) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self domainOperate];
        });
    }
}

// 清理WebView的统一方法
- (void)cleanupWebView {
    
    if (self.webView) {
        // 停止加载
        [self.webView stopLoading];
        
        // 移除KVO观察者
        // 在局Claude Code[KVO崩溃修复]+清理WebView时移除观察者
        if (self.isKVORegistered) {
            @try {
                [self.webView removeObserver:self forKeyPath:@"estimatedProgress"];
                [self.webView removeObserver:self forKeyPath:@"title"];
                self.isKVORegistered = NO;
            } @catch (NSException *exception) {
                NSLog(@"在局Claude Code[KVO崩溃修复]+清理时移除KVO异常: %@", exception);
            }
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
    }
    
}


// 验证桥接设置
- (void)verifyBridgeSetup {
    
    if (!self.bridge) {
        return;
    }
    
    // 检查WebView是否正常
    if (!self.webView || ![self.webView isKindOfClass:[WKWebView class]]) {
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
        } else {
            
            // 如果桥接未就绪，尝试手动注入
            NSError *jsonError;
            NSDictionary *resultDict = [NSJSONSerialization JSONObjectWithData:[result dataUsingEncoding:NSUTF8StringEncoding] options:0 error:&jsonError];
            
            if (!jsonError && ![resultDict[@"bridgeReady"] boolValue]) {
                [self injectBridgeScript];
            }
        }
    }];
}

// 手动注入桥接脚本
- (void)injectBridgeScript {
    
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
        } else {
            
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
    
    // 添加循环重建防护机制
    static NSDate *lastForceRebuildTime = nil;
    static NSInteger rebuildCount = 0;
    NSDate *now = [NSDate date];
    
    if (lastForceRebuildTime && [now timeIntervalSinceDate:lastForceRebuildTime] < 10.0) {
        rebuildCount++;
        if (rebuildCount > 3) {
            return;
        }
    } else {
        rebuildCount = 1;
    }
    lastForceRebuildTime = now;
    
    
    // 检查页面是否正在消失（如果正在消失，不应该重建）
    if (_isDisappearing) {
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
    
    
    // 完全清理现有WebView
    if (self.webView) {
        
        // 移除所有观察者
        // 在局Claude Code[KVO崩溃修复]+强制刷新时移除观察者
        if (self.isKVORegistered) {
            @try {
                [self.webView removeObserver:self forKeyPath:@"estimatedProgress"];
                [self.webView removeObserver:self forKeyPath:@"title"];
                self.isKVORegistered = NO;
            } @catch (NSException *exception) {
                NSLog(@"在局Claude Code[KVO崩溃修复]+强制刷新时移除KVO异常: %@", exception);
            }
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
        
    }
    
    // 重置所有状态标志
    self.isWebViewLoading = NO;
    self.isLoading = NO;
    lastLoadTime = nil;
    
    // 延迟创建新的WebView（给系统一点时间清理）
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
        // 创建全新的WebView
        [self setupWebView];
        [self addWebView];
        
        // 重新建立桥接
        [self setupUnifiedJavaScriptBridge];
        
        // 恢复保存的状态
        self.pinUrl = currentUrl;
        self.pinDataStr = currentData;
        self.htmlStr = currentHtml;
        
        
        // 使用不同的加载策略
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            // 统一使用正常加载流程，不区分Tab
            [self performHTMLLoading];
        });
    });
}

// 移除替代加载方法，统一使用正常加载流程


#pragma mark - 页面加载监控

// 页面加载监控方法
- (void)startPageLoadMonitor {
    
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
    
    if (!self.isLoading) {
        
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
        }];
    } else {
    }
}


#pragma mark - Universal Links处理

/**
 * 处理Universal Links导航通知
 * @param notification 通知对象，包含路径信息
 */
- (void)handleUniversalLinkNavigation:(NSNotification *)notification {
    NSString *path = notification.userInfo[@"path"];
    if (!path) {
        return;
    }
    
    
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
    
    // 防止无限重试
    if (retryCount >= 5) {
        return;
    }
    
    // 检查WebView是否已创建并加载完成
    if (!self.webView) {
        // 保存路径，等待WebView创建完成后处理
        objc_setAssociatedObject(self, @"PendingUniversalLinkPath", path, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return;
    }
    
    if (!self.isWebViewLoading) {
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
        [self navigateToUniversalLinkPath:pendingPath];
    }
}

// 首页专用修复方案 - 解决第二次启动JavaScript桥接失败问题
- (void)performHomepageSpecialFix {
    
    // 不再清理桥接，而是检查并确保桥接正常
    if (!self.bridge) {
        [self setupUnifiedJavaScriptBridge];
    } else {
    }
    
    // 延迟执行桥接初始化，给页面加载一些时间
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
        // 执行桥接初始化
        [self performJavaScriptBridgeInitialization];
        
        // 设置后备检查机制
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self performHomepageFallbackCheck];
        });
    });
    
}

// 强制重新注入桥接代码
- (void)forceReinjectBridge {
    
    if (![self.webView isKindOfClass:[WKWebView class]]) {
        return;
    }
    
    WKWebView *wkWebView = (WKWebView *)self.webView;
    
    // 获取桥接JavaScript代码
    NSString *bridgeJSCode = WebViewJavascriptBridge_js();
    if (!bridgeJSCode || bridgeJSCode.length == 0) {
        return;
    }
    
    
    [wkWebView evaluateJavaScript:bridgeJSCode completionHandler:^(id result, NSError *error) {
        if (error) {
        } else {
            
            // 立即验证注入结果
            [wkWebView evaluateJavaScript:@"typeof WebViewJavascriptBridge" completionHandler:^(id checkResult, NSError *checkError) {
                if (checkError) {
                } else {
                    
                    if ([@"object" isEqualToString:checkResult]) {
                        
                        // 重新设置桥接处理器
                        [self registerUnifiedBridgeHandlers];
                        
                        // 再次测试桥接
                        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                            [wkWebView evaluateJavaScript:@"WebViewJavascriptBridge.callHandler('bridgeTest', {test: 'reinject'}, function(response) { console.log('重注入测试成功:', response); })" completionHandler:^(id testResult, NSError *testError) {
                                if (testError) {
                                } else {
                                }
                            }];
                        });
                    } else {
                    }
                }
            }];
        }
    }];
}

// 首页后备检查机制
- (void)performHomepageFallbackCheck {
    
    // 检查JavaScript环境
    [self safelyEvaluateJavaScript:@"typeof window.WebViewJavascriptBridge !== 'undefined'" completionHandler:^(id result, NSError *error) {
        if (error || ![result boolValue]) {
            
            // 最终修复：不能使用window.location.reload()，因为会导致加载baseURL（目录）
            // 应该重新调用domainOperate方法来重新加载HTML内容
            
            dispatch_async(dispatch_get_main_queue(), ^{
                if (self && !self.isWebViewLoading) {
                    [self domainOperate];
                } else {
                }
            });
        } else {
        }
    }];
}

// 确保LoadingView移除完成后再允许数据请求
- (void)ensureLoadingViewRemovedBeforeDataRequests {
    
    AppDelegate *appDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
    
    // 首先直接尝试移除LoadingView（如果还存在）
    if (!appDelegate.isLoadingViewRemoved) {
        [appDelegate removeGlobalLoadingViewWithReason:@"首页pageReady完成"];
    }
    
    // 发送通知确保TabBar控制器也处理LoadingView移除
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
        
        
        if (loadingViewRemoved) {
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
    
    // 步骤1: 设置LoadingView移除标志
    [self safelyEvaluateJavaScript:@"window.loadingViewRemoved = true; 'flag_set'" completionHandler:^(id result, NSError *error) {
    }];
    
    // 步骤2: 尝试调用实际存在的方法触发数据刷新
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self safelyEvaluateJavaScript:@"(function(){if(typeof app!=='undefined'&&typeof app.reloadOtherPages==='function'){app.reloadOtherPages();return 'reload_called';}return 'reload_not_available';})()" completionHandler:^(id result, NSError *error) {
        }];
    });
    
    // 步骤3: 触发loadingViewRemoved事件
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self safelyEvaluateJavaScript:@"window.dispatchEvent(new CustomEvent('loadingViewRemoved')); 'event_dispatched'" completionHandler:^(id result, NSError *error) {
        }];
    });
    
    // 步骤4: 触发页面可见性事件（备用方案）
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self safelyEvaluateJavaScript:@"document.dispatchEvent(new Event('visibilitychange')); 'visibility_event'" completionHandler:^(id result, NSError *error) {
        }];
    });
}

// 交互式转场后的WebView状态恢复
- (void)restoreWebViewStateAfterInteractiveTransition {
    // 防重复执行检查
    NSTimeInterval minRestoreInterval = 1.0; // 最小恢复间隔1秒
    NSDate *now = [NSDate date];
    
    if (self.isRestoreInProgress) {
        return;
    }
    
    if (self.lastRestoreTime && [now timeIntervalSinceDate:self.lastRestoreTime] < minRestoreInterval) {
        return;
    }
    
    // 标记恢复操作开始
    self.isRestoreInProgress = YES;
    self.lastRestoreTime = now;
    
    
    // 🔧 关键修复：重置_isDisappearing标志，允许JavaScript执行
    _isDisappearing = NO;
    
    if (!self.webView) {
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
    
    
    BOOL isAppActive = (appState == UIApplicationStateActive);
    // 修复：对于手势返回取消的场景，即使应用状态为Inactive也应该执行恢复
    BOOL shouldExecuteRestore = isAppActive || [self isShowingOnKeyWindow];
    
    // 🔧 关键修复：交互式转场期间不依赖应用状态，直接检查控制器可见性
    // 手势返回过程中，系统可能错误地报告应用状态为后台，但实际上控制器仍然可见
    // 特别处理：手势返回刚完成时，isShowingOnKeyWindow可能暂时返回false，但控制器实际上是可见的
    BOOL isInNavigationStack = self.navigationController && 
                              [self.navigationController.viewControllers containsObject:self];
    // 🔧 修复Main Thread Checker错误：UI API必须在主线程调用
    __block BOOL hasValidWindow = NO;
    __block BOOL isViewControllerActive = NO;
    if ([NSThread isMainThread]) {
        hasValidWindow = (self.view.window != nil && !self.view.window.hidden);
        isViewControllerActive = hasValidWindow && isInNavigationStack && !self.view.isHidden && self.view.alpha > 0.01;
    } else {
        dispatch_sync(dispatch_get_main_queue(), ^{
            hasValidWindow = (self.view.window != nil && !self.view.window.hidden);
            isViewControllerActive = hasValidWindow && isInNavigationStack && !self.view.isHidden && self.view.alpha > 0.01;
        });
    }
    
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
    
   
    
    // 1. 确保WebView的基本状态正确
    self.webView.hidden = NO;
    self.webView.alpha = 1.0;
    self.webView.userInteractionEnabled = YES;
    
    // 🔧 关键修复：强制WebView重新渲染
    self.webView.backgroundColor = [UIColor whiteColor];
    [self.webView setNeedsDisplay];
    [self.webView setNeedsLayout];
    [self.webView layoutIfNeeded];
    
    // 🔧 修复：确保WebView在正确的层级
    if (self.webView.superview) {
        [self.webView.superview bringSubviewToFront:self.webView];
    }
    
    // 🔧 修复：确保下拉刷新控件存在
    if (self.webView.scrollView && !self.webView.scrollView.mj_header) {
        [self setupRefreshControl];
    }
    
    // 2. 确保WebView在视图层级中的正确位置
    [self.view bringSubviewToFront:self.webView];
    
    // 🔧 强制移除可能的遮挡视图
    for (UIView *subview in self.view.subviews) {
        if (subview != self.webView && subview != self.progressView && subview != self.activityIndicatorView) {
            
            // 如果有可能遮挡WebView的视图，临时隐藏
            if (!subview.hidden && subview.alpha > 0.1 && CGRectIntersectsRect(subview.frame, self.webView.frame)) {
                subview.hidden = YES;
            }
        }
    }
    
    // 🔧 新增：通过UIKit强制重新渲染整个视图层级
    [self.view setNeedsDisplay];
    [self.view setNeedsLayout];
    [self.view layoutIfNeeded];
    
    // 🔧 新增：通过CALayer强制重渲染
    [self.webView.layer setNeedsDisplay];
    [self.webView.layer displayIfNeeded];
    
    // 🔧 新增：检查WebView的内容大小和滚动位置
    if ([self.webView isKindOfClass:[WKWebView class]]) {
        WKWebView *wkWebView = (WKWebView *)self.webView;
       
        
        // 注释掉强制重置滚动位置的代码，避免页面切换时滚动到顶部
        // wkWebView.scrollView.contentOffset = CGPointZero;
        [wkWebView.scrollView setNeedsDisplay];
        [wkWebView.scrollView setNeedsLayout];
        [wkWebView.scrollView layoutIfNeeded];
    }
    
    // 3. 检查并恢复WebView的布局 - 关键修复：强制重新应用约束
    if (CGRectIsEmpty(self.webView.frame) || self.webView.frame.size.width == 0) {
        
        // 强制移除并重新添加WebView以修复约束问题
        [self.webView removeFromSuperview];
        [self addWebView]; // 这个方法会重新设置所有约束
        
        
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
            
            self.webView.frame = targetFrame;
        }
    }
    
    // 4. 统一的JavaScript恢复脚本（合并原有的多个脚本）
    if (shouldExecuteRestoreForced) {
        
        // 合并后的统一恢复脚本
        NSString *unifiedRestoreScript = @"(function() {"
            "try {"
                "console.log('🔧 开始统一页面恢复操作');"
                "var result = { timestamp: Date.now(), actions: [] };"
                ""
                "// 1. 强制显示页面主体"
                "if (document.body) {"
                    "document.body.style.display = 'block';"
                    "document.body.style.visibility = 'visible';"
                    "document.body.style.opacity = '1';"
                    "document.body.style.transform = 'none';"
                    "result.actions.push('body_restored');"
                "}"
                ""
                "// 2. 恢复所有隐藏的元素"
                "var hiddenElements = document.querySelectorAll('*');"
                "var restoredCount = 0;"
                "for (var i = 0; i < hiddenElements.length; i++) {"
                    "var elem = hiddenElements[i];"
                    "if (elem.style.display === 'none' && !elem.classList.contains('hidden')) {"
                        "elem.style.display = 'block';"
                        "restoredCount++;"
                    "}"
                    "if (elem.style.visibility === 'hidden') {"
                        "elem.style.visibility = 'visible';"
                        "restoredCount++;"
                    "}"
                "}"
                "result.elementsRestored = restoredCount;"
                ""
                "// 3. 强制显示主要容器"
                "var containers = document.querySelectorAll('div, section, main, article, .container, .main, .app');"
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
                ""
                "// 4. 移除可能的遮罩层"
                "var masks = document.querySelectorAll('.mask, .overlay, .loading-mask, .modal-backdrop');"
                "for (var i = 0; i < masks.length; i++) {"
                    "if (!masks[i].classList.contains('keep-visible')) {"
                        "masks[i].style.display = 'none';"
                    "}"
                "}"
                "result.masksRemoved = masks.length;"
                ""
                "// 5. 强制重新渲染和重排"
                "if (document.body) {"
                    "document.body.offsetHeight;" // 触发重排
                    "document.body.style.transform = 'translateZ(0)';" // 强制GPU渲染
                    "setTimeout(function() { document.body.style.transform = ''; }, 10);"
                    "result.actions.push('forced_reflow');"
                "}"
                ""
                "// 6. 触发系统事件"
                "if (typeof window.dispatchEvent === 'function') {"
                    "var events = ['resize', 'orientationchange', 'visibilitychange'];"
                    "for (var i = 0; i < events.length; i++) {"
                        "window.dispatchEvent(new Event(events[i]));"
                    "}"
                    "result.actions.push('events_triggered');"
                "}"
                ""
                "// 7. 修复页面可见性状态"
                "if (typeof document.hidden !== 'undefined') {"
                    "try {"
                        "Object.defineProperty(document, 'visibilityState', { value: 'visible', writable: true });"
                        "Object.defineProperty(document, 'hidden', { value: false, writable: true });"
                        "result.actions.push('visibility_fixed');"
                    "} catch(e) { /* 忽略属性设置失败 */ }"
                "}"
                ""
                "// 8. 调用应用级恢复方法"
                "if (typeof app !== 'undefined' && app.loaded && typeof app.refreshPage === 'function') {"
                    "app.refreshPage();"
                    "result.actions.push('app_refresh_called');"
                "}"
                "if (typeof window.onPageShow === 'function') {"
                    "window.onPageShow();"
                    "result.actions.push('onPageShow_called');"
                "}"
                "if (typeof window.pageShow === 'function') {"
                    "window.pageShow();"
                    "result.actions.push('pageShow_called');"
                "}"
                ""
                "// 9. 最终强制滚动以激活页面"
                "window.scrollTo(0, 1);"
                "window.scrollTo(0, 0);"
                "result.actions.push('scroll_activated');"
                ""
                "result.success = true;"
                "console.log('✅ 统一页面恢复完成', result);"
                "return JSON.stringify(result);"
            "} catch(e) {"
                "console.error('❌ 页面恢复失败:', e);"
                "return JSON.stringify({ success: false, error: e.message, timestamp: Date.now() });"
            "}"
        "})()";
        
        [self safelyEvaluateJavaScript:unifiedRestoreScript completionHandler:^(id result, NSError *error) {
            
        }];
    } else {
    }
    
    // 6. 触发pageShow事件（如果页面已经加载完成）
    if (shouldExecuteRestoreForced && self.isWebViewLoading && self.isExist) {
        NSDictionary *callJsDic = [CustomHybridProcessor custom_objcCallJsWithFn:@"pageShow" data:nil];
        [self objcCallJs:callJsDic];
    } else {
    }
    
    // 7. 确保ScrollView可以正常滚动
    if ([self.webView isKindOfClass:[WKWebView class]]) {
        WKWebView *wkWebView = (WKWebView *)self.webView;
        wkWebView.scrollView.scrollEnabled = YES;
        wkWebView.scrollView.userInteractionEnabled = YES;
    }
    
    
    // 延迟执行统一的WebView恢复操作
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self performWebViewRecovery];
    });
}

// 统一的WebView快速修复机制（替代多个冗余方法）
- (void)performWebViewRecovery {
    if (_isDisappearing || !self.webView) {
        return;
    }
    
    // 检查控制器状态
    BOOL isInNavigationStack = self.navigationController && 
                              [self.navigationController.viewControllers containsObject:self];
    __block BOOL hasValidWindow = NO;
    if ([NSThread isMainThread]) {
        hasValidWindow = (self.view.window != nil && !self.view.window.hidden);
    } else {
        dispatch_sync(dispatch_get_main_queue(), ^{
            hasValidWindow = (self.view.window != nil && !self.view.window.hidden);
        });
    }
    
    if (!isInNavigationStack || !hasValidWindow) {
        return;
    }
    
    // 统一的JavaScript恢复脚本
    NSString *recoveryScript = @"(function(){"
        "try {"
            "var result = { timestamp: Date.now(), actions: [] };"
            "if (document.body) {"
                "document.body.style.display = 'block';"
                "document.body.style.visibility = 'visible';"
                "document.body.style.opacity = '1';"
                "document.body.style.transform = 'none';"
                "result.actions.push('body_restored');"
            "}"
            "var containers = document.querySelectorAll('main, .main, #main, .app, #app, .container, #container');"
            "for (var i = 0; i < containers.length; i++) {"
                "containers[i].style.display = 'block';"
                "containers[i].style.visibility = 'visible';"
                "containers[i].style.opacity = '1';"
            "}"
            "var masks = document.querySelectorAll('.mask, .overlay, .loading-mask');"
            "for (var i = 0; i < masks.length; i++) {"
                "masks[i].style.display = 'none';"
            "}"
            "if (document.body) {"
                "document.body.offsetHeight;"
                "window.dispatchEvent(new Event('resize'));"
                "result.actions.push('layout_recalculated');"
            "}"
            "if (typeof app !== 'undefined' && app.loaded && typeof app.refreshPage === 'function') {"
                "app.refreshPage();"
                "result.actions.push('app_refresh_called');"
            "}"
            "window.scrollTo(0, 1); window.scrollTo(0, 0);"
            "result.success = true;"
            "return JSON.stringify(result);"
        "} catch(e) {"
            "return JSON.stringify({success: false, error: e.message});"
        "}"
    "})()";
    
    [self safelyEvaluateJavaScript:recoveryScript completionHandler:nil];
}





#pragma mark - 性能优化方法实现

/**
 * 预加载HTML模板 - 应用启动时调用，缓存HTML模板到内存
 * 优化目标：减少每次页面加载时的文件I/O操作，提升100ms加载速度
 */
+ (void)preloadHTMLTemplates {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        
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
                    
                } else {
                }
            } else {
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
    
}

/**
 * 立即创建WebView - 专门为首页优化
 * 在viewDidLoad中同步创建，减少延迟
 */
- (void)createWebViewImmediately {
    if (self.webView || self.isWebViewPreCreated) {
        return;
    }
    
    NSLog(@"在局Claude Code[性能优化]+开始立即创建WebView");
    
    // 🚀【性能优化】优先从WebView池获取预热的实例
    XZWebViewPerformanceManager *performanceManager = [XZWebViewPerformanceManager sharedManager];
    WKWebView *pooledWebView = [performanceManager getPrewarmedWebView];
    
    if (pooledWebView) {
        NSLog(@"在局Claude Code[性能优化]+使用预热的WebView（viewDidLoad）");
        self.webView = pooledWebView;
        self.webView.backgroundColor = [UIColor whiteColor];
    } else {
        NSLog(@"在局Claude Code[性能优化]+WebView池为空，创建新实例（viewDidLoad）");
        // 创建优化的WebView配置
        WKWebViewConfiguration *configuration = [self createOptimizedWebViewConfiguration];
        
        // 创建WebView实例
        self.webView = [[WKWebView alloc] initWithFrame:CGRectZero configuration:configuration];
        self.webView.backgroundColor = [UIColor whiteColor];
    }
    
    // 🔧 关键修复：立即设置桥接，确保navigationDelegate不会为nil
    [self setupUnifiedJavaScriptBridge];
    
    // 添加到视图层级
    [self addWebView];
    
    // 标记为已预创建
    self.isWebViewPreCreated = YES;
    
    NSLog(@"在局Claude Code[性能优化]+WebView创建完成（viewDidLoad）");
    
    // 如果已经有URL，可以开始加载
    if (self.pinUrl && self.pinUrl.length > 0) {
        NSLog(@"在局Claude Code[性能优化]+检测到pinUrl，准备domainOperate: %@", self.pinUrl);
        // 延迟一点执行，确保视图层级完全建立
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self domainOperate];
        });
    }
}

/**
 * 预创建WebView - 在viewDidLoad中异步调用
 * 优化目标：减少WebView创建时间，提升首次显示速度100ms
 */
- (void)preCreateWebViewIfNeeded {
    if (self.isWebViewPreCreated || self.webView) {
        return; // 已经预创建或者已存在
    }
    
    
    // 异步预创建，避免阻塞主线程
    NSBlockOperation *preCreateOperation = [NSBlockOperation blockOperationWithBlock:^{
        // 切换到主线程创建WebView（UI操作必须在主线程）
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            if (self.webView || self.isWebViewPreCreated) {
                return; // 避免重复创建
            }
            
            
            // 创建WebView配置
            WKWebViewConfiguration *configuration = [self createOptimizedWebViewConfiguration];
            
            // 创建WebView实例
            self.webView = [[WKWebView alloc] initWithFrame:CGRectZero configuration:configuration];
            self.webView.backgroundColor = [UIColor whiteColor];
            self.webView.hidden = YES; // 预创建时隐藏
            
            // 🔧 关键修复：立即设置桥接，确保navigationDelegate不会为nil
            [self setupUnifiedJavaScriptBridge];
            
            // 标记为已预创建
            self.isWebViewPreCreated = YES;
            
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
    if ([[XZiOSVersionManager sharedManager] isiOS14Later]) {
        configuration.defaultWebpagePreferences.allowsContentJavaScript = YES;
    }
    
    // 媒体配置
    if ([[XZiOSVersionManager sharedManager] isSystemVersionGreaterThanOrEqualTo:10.0]) {
        configuration.mediaTypesRequiringUserActionForPlayback = WKAudiovisualMediaTypeNone;
    }
    
    if ([[XZiOSVersionManager sharedManager] isSystemVersionGreaterThanOrEqualTo:9.0]) {
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
    
    // 在局Claude Code[修复输入框双击聚焦问题]+注入极致敏感的输入框轻触聚焦优化JavaScript
    NSString *inputFocusOptimizationScript = @""
    "(function() {"
    "    "
    "    // 全局标志，避免重复处理"
    "    if (window.inputFocusOptimized) {"
    "        return;"
    "    }"
    "    window.inputFocusOptimized = true;"
    "    "
    "    // 极致敏感输入框聚焦处理 - 移除所有延迟"
    "    function extremelySensitiveFocus(inputElement, eventType) {"
    "        if (!inputElement || inputElement.disabled || inputElement.readOnly) {"
    "            return false;"
    "        }"
    "        "
    "        var tagName = inputElement.tagName.toUpperCase();"
    "        if (tagName !== 'INPUT' && tagName !== 'TEXTAREA') {"
    "            return false;"
    "        }"
    "        "
    "        try {"
    "            "
    "            // 🔥 关键修改1：立即多次调用focus()，确保生效"
    "            inputElement.focus();"
    "            inputElement.focus(); // 双重保险"
    "            "
    "            // 🔥 关键修改2：强制点击激活（模拟用户重点击）"
    "            if (eventType === 'touchstart' || eventType === 'touchend') {"
    "                var clickEvent = new MouseEvent('click', {"
    "                    bubbles: true,"
    "                    cancelable: true,"
    "                    view: window,"
    "                    detail: 1"
    "                });"
    "                inputElement.dispatchEvent(clickEvent);"
    "            }"
    "            "
    "            // 🔥 关键修改3：强制触发所有焦点相关事件"
    "            var events = ['focusin', 'focus'];"
    "            events.forEach(function(eventName) {"
    "                var focusEvent = new FocusEvent(eventName, {"
    "                    bubbles: true,"
    "                    cancelable: false"
    "                });"
    "                inputElement.dispatchEvent(focusEvent);"
    "            });"
    "            "
    "            // 🔥 关键修改4：立即设置光标和选择"
    "            if (inputElement.setSelectionRange && inputElement.type !== 'number' && inputElement.type !== 'email' && inputElement.type !== 'tel') {"
    "                var len = inputElement.value ? inputElement.value.length : 0;"
    "                inputElement.setSelectionRange(len, len);"
    "            }"
    "            "
    "            // 🔥 关键修改5：强制属性设置"
    "            inputElement.setAttribute('data-focused', 'true');"
    "            "
    "            // 🔥 关键修改6：使用requestAnimationFrame确保DOM更新"
    "            requestAnimationFrame(function() {"
    "                inputElement.focus();"
    "            });"
    "            "
    "            return true;"
    "        } catch(e) {"
    "            return false;"
    "        }"
    "    }"
    "    "
    "    // 极致敏感事件处理函数 - 放宽触发条件"
    "    function handleExtremelySensitiveTouch(e) {"
    "        var target = e.target;"
    "        var inputElement = null;"
    "        "
    "        // 🔥 关键修改7：更激进的输入框查找策略"
    "        if (target.tagName === 'INPUT' || target.tagName === 'TEXTAREA') {"
    "            inputElement = target;"
    "        } else {"
    "            // 查找各种可能的输入框位置"
    "            inputElement = target.closest('input, textarea');"
    "            "
    "            if (!inputElement) {"
    "                inputElement = target.querySelector('input, textarea');"
    "            }"
    "            "
    "            // 🔥 关键修改8：扩展到更大的搜索半径"
    "            if (!inputElement) {"
    "                var containers = ['div', 'form', 'label', 'span', 'p', 'li', 'td', 'th'];"
    "                for (var j = 0; j < containers.length; j++) {"
    "                    var container = target.closest(containers[j]);"
    "                    if (container) {"
    "                        var inputs = container.querySelectorAll('input:not([type=hidden]):not([type=submit]):not([type=button]), textarea');"
    "                        if (inputs.length > 0) {"
    "                            // 简化逻辑：直接选择第一个可见的输入框"
    "                            for (var k = 0; k < inputs.length; k++) {"
    "                                var input = inputs[k];"
    "                                var style = window.getComputedStyle(input);"
    "                                if (style.display !== 'none' && style.visibility !== 'hidden' && !input.disabled) {"
    "                                    inputElement = input;"
    "                                    break;"
    "                                }"
    "                            }"
    "                            if (inputElement) break;"
    "                        }"
    "                    }"
    "                }"
    "            }"
    "        }"
    "        "
    "        if (inputElement) {"
    "            "
    "            // 🔥 关键修改9：不阻止任何默认行为，让原生处理流程正常执行"
    "            // 移除了所有的preventDefault()和stopPropagation()"
    "            "
    "            // 极致敏感聚焦"
    "            var focusResult = extremelySensitiveFocus(inputElement, e.type);"
    "            "
    "            // 🔥 关键修改10：如果首次聚焦失败，立即重试"
    "            if (!focusResult && e.type === 'touchstart') {"
    "                setTimeout(function() {"
    "                    extremelySensitiveFocus(inputElement, 'retry');"
    "                }, 10); // 极短延迟重试"
    "            }"
    "        }"
    "    }"
    "    "
    "    // 🔥 关键修改11：监听更多触摸事件，提高触发概率"
    "    var touchEvents = ['touchstart', 'touchmove', 'touchend'];"
    "    touchEvents.forEach(function(eventType) {"
    "        document.addEventListener(eventType, handleExtremelySensitiveTouch, {"
    "            capture: true,"
    "            passive: true  // 改为passive以避免阻塞滚动"
    "        });"
    "    });"
    "    "
    "    // 🔥 关键修改12：保留传统事件作为后备，但使用新的处理函数"
    "    var fallbackEvents = ['mousedown', 'click'];"
    "    fallbackEvents.forEach(function(eventType) {"
    "        document.addEventListener(eventType, handleExtremelySensitiveTouch, {"
    "            capture: true,"
    "            passive: true"
    "        });"
    "    });"
    "    "
    "    // 🔥 关键修改13：增强的focusin处理，立即激活"
    "    document.addEventListener('focusin', function(e) {"
    "        var target = e.target;"
    "        if ((target.tagName === 'INPUT' || target.tagName === 'TEXTAREA') && "
    "            !target.disabled && !target.readOnly) {"
    "            "
    "            // 🔥 立即多重focus确保激活"
    "            target.focus();"
    "            target.focus();"
    "            "
    "            // 立即设置光标位置"
    "            if (target.setSelectionRange && target.type !== 'number' && target.type !== 'email' && target.type !== 'tel') {"
    "                var len = target.value ? target.value.length : 0;"
    "                target.setSelectionRange(len, len);"
    "            }"
    "            "
    "            // 设置激活标记"
    "            target.setAttribute('data-focused', 'true');"
    "        }"
    "    }, true);"
    "    "
    "    // 🔥 关键修改14：增强的MutationObserver，为动态输入框添加极致敏感支持"
    "    if (window.MutationObserver) {"
    "        var observer = new MutationObserver(function(mutations) {"
    "            mutations.forEach(function(mutation) {"
    "                if (mutation.type === 'childList') {"
    "                    mutation.addedNodes.forEach(function(node) {"
    "                        if (node.nodeType === 1) {"
    "                            var inputs = node.tagName === 'INPUT' || node.tagName === 'TEXTAREA' ? [node] : node.querySelectorAll('input, textarea');"
    "                            if (inputs.length > 0) {"
    "                                inputs.forEach(function(input) {"
    "                                    if (!input.disabled && !input.readOnly) {"
    "                                        // 🔥 为新输入框添加所有触摸事件"
    "                                        touchEvents.forEach(function(eventType) {"
    "                                            input.addEventListener(eventType, handleExtremelySensitiveTouch, {"
    "                                                capture: true,"
    "                                                passive: true"
    "                                            });"
    "                                        });"
    "                                    }"
    "                                });"
    "                            }"
    "                        }"
    "                    });"
    "                }"
    "            });"
    "        });"
    "        "
    "        observer.observe(document.body || document.documentElement, {"
    "            childList: true,"
    "            subtree: true"
    "        });"
    "    }"
    "    "
    "    // 🔥 关键修改15：页面加载完成后立即激活所有现有输入框"
    "    function activateAllExistingInputs() {"
    "        var allInputs = document.querySelectorAll('input:not([type=hidden]):not([type=submit]):not([type=button]), textarea');"
    "        "
    "        allInputs.forEach(function(input) {"
    "            if (!input.disabled && !input.readOnly) {"
    "                // 预设置优化属性"
    "                input.setAttribute('data-touch-optimized', 'true');"
    "                "
    "                // 添加直接事件监听器（更快响应）"
    "                touchEvents.forEach(function(eventType) {"
    "                    input.addEventListener(eventType, function(e) {"
    "                        extremelySensitiveFocus(input, eventType);"
    "                    }, {"
    "                        capture: true,"
    "                        passive: true"
    "                    });"
    "                });"
    "            }"
    "        });"
    "    }"
    "    "
    "    // 🔥 关键修改16：立即执行 + DOM就绪时再次执行"
    "    activateAllExistingInputs();"
    "    "
    "    if (document.readyState === 'loading') {"
    "        document.addEventListener('DOMContentLoaded', activateAllExistingInputs);"
    "    } else {"
    "        setTimeout(activateAllExistingInputs, 100); // 延迟一点再次激活"
    "    }"
    "    "
    "})();";
    
    WKUserScript *inputFocusScript = [[WKUserScript alloc] 
        initWithSource:inputFocusOptimizationScript
        injectionTime:WKUserScriptInjectionTimeAtDocumentStart
        forMainFrameOnly:NO];
    [self.userContentController addUserScript:inputFocusScript];
    
    // 在局Claude Code[修复输入框双击聚焦问题]+额外在DocumentEnd阶段再次注入，确保覆盖
    NSString *additionalInputFocusScript = @""
    "(function() {"
    "    "
    "    // 覆盖可能存在的输入框处理逻辑"
    "    var originalAddEventListener = EventTarget.prototype.addEventListener;"
    "    EventTarget.prototype.addEventListener = function(type, listener, options) {"
    "        // 如果是输入框相关事件，优先处理我们的逻辑"
    "        if ((type === 'click' || type === 'touchend' || type === 'mousedown') && "
    "            (this.tagName === 'INPUT' || this.tagName === 'TEXTAREA')) {"
    "            "
    "            var enhancedListener = function(e) {"
    "                "
    "                // 立即聚焦"
    "                var target = e.target || e.currentTarget;"
    "                if (target && (target.tagName === 'INPUT' || target.tagName === 'TEXTAREA') && "
    "                    !target.disabled && !target.readOnly) {"
    "                    "
    "                    target.focus();"
    "                    "
    "                    // 延迟再次聚焦确保生效"
    "                    setTimeout(function() {"
    "                        target.focus();"
    "                    }, 10);"
    "                }"
    "                "
    "                // 调用原始监听器"
    "                if (typeof listener === 'function') {"
    "                    listener.call(this, e);"
    "                } else if (listener && typeof listener.handleEvent === 'function') {"
    "                    listener.handleEvent(e);"
    "                }"
    "            };"
    "            "
    "            return originalAddEventListener.call(this, type, enhancedListener, options);"
    "        }"
    "        "
    "        return originalAddEventListener.call(this, type, listener, options);"
    "    };"
    "    "
    "})();";
    
    WKUserScript *additionalScript = [[WKUserScript alloc] 
        initWithSource:additionalInputFocusScript
        injectionTime:WKUserScriptInjectionTimeAtDocumentEnd
        forMainFrameOnly:NO];
    [self.userContentController addUserScript:additionalScript];
    
    return configuration;
}


/**
 * 优化的HTML内容加载方法
 * 使用缓存的模板和异步处理，提升加载性能
 */
- (void)optimizedLoadHTMLContent {
    
    // 防重复调用检查 - 修复闪烁问题
    if (self.isLoadingInProgress) {
        return;
    }
    
    // 检查WebView状态
    if (!self.webView) {
        [self preCreateWebViewIfNeeded];
        
        // 避免无限递归 - 最多重试一次
        static NSInteger retryCount = 0;
        if (retryCount >= 1) {
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
        [self setupUnifiedJavaScriptBridge];
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
        NSString *templatePath = [[BaseFileManager appH5LocailManifesPath] stringByAppendingPathComponent:@"app.html"];
        htmlTemplate = [NSString stringWithContentsOfFile:templatePath encoding:NSUTF8StringEncoding error:nil];
    }
    
    if (!htmlTemplate) {
        return nil;
    }
    
    NSString *bodyContent = @"";
    
    // 处理不同的内容源
    if (self.pinDataStr && self.pinDataStr.length > 0) {
        // 直接数据模式
        bodyContent = self.pinDataStr;
    } else if (self.pinUrl) {
        // URL模式，需要通过CustomHybridProcessor处理
        // 这里暂时返回空内容，实际处理在CustomHybridProcessor中
        return nil;
    }
    
    // 执行模板替换
    NSString *processedHTML = [htmlTemplate stringByReplacingOccurrencesOfString:@"{{body}}" withString:bodyContent];
    
    // iPhone X适配
    if ([self isHaveNativeHeader:self.pinUrl]) {
        NSString *phoneClass = isIPhoneXSeries() ? @"iPhoneLiuHai" : @"iPhone";
        processedHTML = [processedHTML stringByReplacingOccurrencesOfString:@"{{phoneClass}}" withString:phoneClass];
    }
    
    return processedHTML;
}

/**
 * 回退到原有的HTML加载方法
 * 当优化的加载方法失败时使用
 */
- (void)fallbackToOriginalLoadMethod {
    
    // 禁用优化标志，避免无限循环
    static BOOL isInFallback = NO;
    if (isInFallback) {
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
    
    // 检查WebView是否存在
    if (!self.webView) {
        return;
    }
    
    // 检查htmlStr是否是未处理的模板（包含{{body}}占位符）
    if (self.htmlStr && self.htmlStr.length > 0 && ![self.htmlStr containsString:@"{{body}}"]) {
        // 只有当htmlStr是已处理的完整HTML时才直接加载
        NSString *basePath = [BaseFileManager appH5LocailManifesPath];
        NSURL *baseURL = [NSURL fileURLWithPath:basePath];
        [self.webView loadHTMLString:self.htmlStr baseURL:baseURL];
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
        }
        return;
    }
    
    // 对于URL模式，调用原有的完整加载流程
    if (self.pinUrl && self.pinUrl.length > 0) {
        
        // 确保桥接已建立
        if (!self.bridge) {
            [self setupUnifiedJavaScriptBridge];
        }
        
        // 调用原有的完整加载方法
        if (self.bridge) {
            [self performHTMLLoading];
        } else {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self loadHTMLContentWithoutOptimization];
            });
        }
        return;
    }
    
}

/**
 * 加载处理完成的HTML内容到WebView
 * @param htmlContent 处理完成的HTML字符串
 */
- (void)loadProcessedHTMLContent:(NSString *)htmlContent {
    if (!htmlContent || !self.webView) {
        return;
    }
    
    
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
    // 🔧 修复Main Thread Checker错误：UI API必须在主线程调用
    __block BOOL isControllerActive = NO;
    if ([NSThread isMainThread]) {
        isControllerActive = self.view.window != nil && 
                            !self.view.window.hidden && 
                            self.view.superview != nil;
    } else {
        dispatch_sync(dispatch_get_main_queue(), ^{
            isControllerActive = self.view.window != nil && 
                                !self.view.window.hidden && 
                                self.view.superview != nil;
        });
    }
    
    // 检查是否为交互式转场恢复场景
    BOOL isInteractiveRestoreScenario = [self isShowingOnKeyWindow] && 
                                       isControllerActive &&
                                       (self.navigationController.viewControllers.lastObject == self ||
                                        [self.navigationController.viewControllers containsObject:self]);
    
    // 如果是交互式转场恢复场景，即使应用在后台也允许执行关键JavaScript
    if (isInteractiveRestoreScenario) {
        return YES;
    }
    
    // 正常情况下检查应用状态：必须在前台或即将前台
    if (appState == UIApplicationStateBackground) {
        return NO;
    }
    
    // 页面正在消失但需要执行关键JavaScript的情况
    if (_isDisappearing && isControllerActive) {
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
        NSLog(@"在局Claude Code[WebView内容检查]+WebView不存在");
        return NO;
    }
    
    // 如果页面已经标记为存在且已经收到pageReady，认为有效
    if (self.isExist && self.isLoading) {
        NSLog(@"在局Claude Code[WebView内容检查]+页面已存在且已加载: isExist=%@, isLoading=%@", 
              self.isExist ? @"YES" : @"NO", self.isLoading ? @"YES" : @"NO");
        
        // 在局Claude Code[Tab空白修复]+额外检查WebView的视图状态
        if (self.isTabbarShow && self.webView) {
            NSLog(@"在局Claude Code[Tab空白修复]+WebView视图状态检查: hidden=%@, alpha=%.2f, superview=%@", 
                  self.webView.hidden ? @"YES" : @"NO", 
                  self.webView.alpha,
                  self.webView.superview ? @"YES" : @"NO");
            
            // 确保WebView可见
            if (self.webView.hidden || self.webView.alpha < 1.0 || !self.webView.superview) {
                NSLog(@"在局Claude Code[Tab空白修复]+WebView状态异常，强制修复");
                dispatch_async(dispatch_get_main_queue(), ^{
                    self.webView.hidden = NO;
                    self.webView.alpha = 1.0;
                    if (!self.webView.superview) {
                        [self addWebView];
                    }
                    [self.webView setNeedsLayout];
                    [self.webView layoutIfNeeded];
                });
                return NO; // 返回NO触发重新加载
            }
        }
        
        return YES;
    }
    
    // 对于tab页面，需要更严格的检查
    if (self.isTabbarShow) {
        // 检查是否为新创建的控制器（通过检查WebView的URL）
        NSURL *currentURL = self.webView.URL;
        NSString *urlString = currentURL ? currentURL.absoluteString : @"";
        
        // 如果URL为空或about:blank，说明是新创建的控制器或WebView未加载
        if (!currentURL || [urlString isEqualToString:@"about:blank"] || urlString.length == 0) {
            NSLog(@"在局Claude Code[WebView内容检查]+Tab页面WebView未加载: URL=%@", urlString);
            return NO;
        }
        
        // 如果isExist为NO，说明页面还没有收到pageReady事件
        if (!self.isExist) {
            NSLog(@"在局Claude Code[WebView内容检查]+Tab页面未收到pageReady: isExist=NO");
            return NO;
        }
        
        // 如果URL是manifest路径，说明只加载了基础HTML，还需要加载真实内容
        if ([urlString containsString:@"manifest/"]) {
            NSLog(@"在局Claude Code[WebView内容检查]+Tab页面只有基础HTML，需要加载真实内容: URL=%@", urlString);
            return NO;
        }
        
        // 如果URL是有效的网络地址且isExist为YES，认为有效
        if (self.isExist && ([urlString hasPrefix:@"http://"] || [urlString hasPrefix:@"https://"])) {
            NSLog(@"在局Claude Code[WebView内容检查]+Tab页面有效: URL=%@, isExist=YES", urlString);
            return YES;
        }
        
        NSLog(@"在局Claude Code[WebView内容检查]+Tab页面需要重新加载: URL=%@, isExist=%@", 
              urlString, self.isExist ? @"YES" : @"NO");
        return NO;
    }
    
    // 检查URL - 只有当URL完全无效时才返回NO
    NSURL *currentURL = self.webView.URL;
    if (!currentURL) {
        NSLog(@"在局Claude Code[WebView内容检查]+WebView URL为空");
        return NO;
    }
    
    NSString *urlString = currentURL.absoluteString;
    NSLog(@"在局Claude Code[WebView内容检查]+当前URL: %@", urlString);
    
    // 只有当URL是about:blank或者空的时候才认为无效
    if ([urlString isEqualToString:@"about:blank"] || urlString.length == 0) {
        
        // 即使URL是about:blank，如果WebView正在加载，给它一次机会
        if (self.webView.isLoading) {
            return YES;
        }
        
        return NO;
    }
    
    // 检查是否是有效的内容URL（不是file://路径的基础目录）
    if ([urlString hasPrefix:@"file://"] && [urlString hasSuffix:@"/manifest/"]) {
        
        // 如果正在加载或者已经标记为正在加载，认为有效
        if (self.webView.isLoading || self.isWebViewLoading) {
            return YES;
        }
        
        return NO;
    }
    
    // 如果WebView有有效URL，认为有内容
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
    }
    
    return isReturn;
}

// 在局Claude Code[修复输入框双击聚焦问题]+页面加载完成后重新注入输入框聚焦优化
- (void)reinjectInputFocusOptimization {
    NSString *reinjectScript = @""
    "(function() {"
    "    try {"
    "        "
    "        // 检查是否已经注入过"
    "        if (window.inputFocusOptimizedReinjected) {"
    "            return {success: true, message: 'already_injected'};"
    "        }"
    "        window.inputFocusOptimizedReinjected = true;"
    "        "
    "        // 简化的输入框处理函数"
    "        function optimizeInputFocus(input) {"
    "            if (!input || input.disabled || input.readOnly) {"
    "                return false;"
    "            }"
    "            "
    "            // 简化的聚焦处理"
    "            var focusHandler = function(e) {"
    "                try {"
    "                    input.focus();"
    "                    setTimeout(function() {"
    "                        try {"
    "                            if (input && typeof input.focus === 'function') {"
    "                                input.focus();"
    "                            }"
    "                        } catch (err) {}"
    "                    }, 50);"
    "                } catch (err) {"
    "                }"
    "            };"
    "            "
    "            // 安全地添加事件监听器"
    "            try {"
    "                input.addEventListener('click', focusHandler, true);"
    "                input.addEventListener('touchend', focusHandler, true);"
    "                return true;"
    "            } catch (err) {"
    "                return false;"
    "            }"
    "        }"
    "        "
    "        // 处理现有输入框"
    "        var processedCount = 0;"
    "        try {"
    "            var inputs = document.querySelectorAll('input, textarea');"
    "            "
    "            for (var i = 0; i < inputs.length; i++) {"
    "                if (optimizeInputFocus(inputs[i])) {"
    "                    processedCount++;"
    "                }"
    "            }"
    "        } catch (err) {"
    "        }"
    "        "
    "        // 监听动态添加的输入框（使用MutationObserver）"
    "        try {"
    "            if (typeof MutationObserver !== 'undefined') {"
    "                var observer = new MutationObserver(function(mutations) {"
    "                    mutations.forEach(function(mutation) {"
    "                        if (mutation.type === 'childList') {"
    "                            for (var i = 0; i < mutation.addedNodes.length; i++) {"
    "                                var node = mutation.addedNodes[i];"
    "                                if (node.nodeType === 1) {"
    "                                    if (node.tagName === 'INPUT' || node.tagName === 'TEXTAREA') {"
    "                                        optimizeInputFocus(node);"
    "                                    } else if (node.querySelectorAll) {"
    "                                        var newInputs = node.querySelectorAll('input, textarea');"
    "                                        for (var j = 0; j < newInputs.length; j++) {"
    "                                            optimizeInputFocus(newInputs[j]);"
    "                                        }"
    "                                    }"
    "                                }"
    "                            }"
    "                        }"
    "                    });"
    "                });"
    "                observer.observe(document.body, { childList: true, subtree: true });"
    "            }"
    "        } catch (err) {"
    "        }"
    "        "
    "        return {success: true, processed: processedCount};"
    "    } catch (e) {"
    "        return {success: false, error: e.message};"
    "    }"
    "})();";
    
    [self safelyEvaluateJavaScript:reinjectScript completionHandler:^(id result, NSError *error) {
        if (error) {
        } else {
        }
    }];
}

// 在局Claude Code[Tab空白修复]+检查并修复页面可见性问题
- (void)checkAndFixPageVisibility {
    if (!self.webView || _isDisappearing) {
        return;
    }
    
    // 确保WebView基本状态正确
    if (self.webView.hidden || self.webView.alpha < 1.0) {
        NSLog(@"在局Claude Code[页面可见性修复]+WebView基本状态异常，先修复基本状态");
        self.webView.hidden = NO;
        self.webView.alpha = 1.0;
        [self.webView setNeedsLayout];
        [self.webView layoutIfNeeded];
    }
    
    // 通过JavaScript检查页面内容是否真正可见
    NSString *visibilityCheckScript = @"(function() {"
        "try {"
            "var result = {"
                "timestamp: Date.now(),"
                "documentReady: document.readyState,"
                "bodyExists: !!document.body,"
                "bodyVisible: false,"
                "bodyHeight: 0,"
                "bodyDisplay: '',"
                "bodyVisibility: '',"
                "bodyOpacity: '',"
                "hasContent: false,"
                "mainElements: 0,"
                "visibleElements: 0"
            "};"
            
            "if (!document.body) {"
                "result.error = 'document.body不存在';"
                "return JSON.stringify(result);"
            "}"
            
            "// 检查body的基本样式"
            "var computedStyle = window.getComputedStyle(document.body);"
            "result.bodyDisplay = computedStyle.display;"
            "result.bodyVisibility = computedStyle.visibility;"
            "result.bodyOpacity = computedStyle.opacity;"
            "result.bodyHeight = document.body.offsetHeight;"
            "result.bodyVisible = (result.bodyDisplay !== 'none' && result.bodyVisibility !== 'hidden' && parseFloat(result.bodyOpacity) > 0);"
            
            "// 检查是否有实际内容"
            "var textContent = document.body.textContent || document.body.innerText || '';"
            "result.hasContent = textContent.trim().length > 0;"
            
            "// 统计主要元素数量"
            "var mainElements = document.querySelectorAll('div, section, main, article, p, h1, h2, h3, h4, h5, h6');"
            "result.mainElements = mainElements.length;"
            
            "// 统计可见元素数量"
            "var visibleCount = 0;"
            "for (var i = 0; i < mainElements.length; i++) {"
                "var elem = mainElements[i];"
                "var style = window.getComputedStyle(elem);"
                "if (style.display !== 'none' && style.visibility !== 'hidden' && parseFloat(style.opacity) > 0) {"
                    "visibleCount++;"
                "}"
            "}"
            "result.visibleElements = visibleCount;"
            
            "result.needsFix = !result.bodyVisible || result.visibleElements === 0;"
            "result.success = true;"
            "return JSON.stringify(result);"
        "} catch(e) {"
            "return JSON.stringify({success: false, error: e.message, timestamp: Date.now()});"
        "}"
    "})()";
    
    [self safelyEvaluateJavaScript:visibilityCheckScript completionHandler:^(id result, NSError *error) {
        if (error) {
            NSLog(@"在局Claude Code[页面可见性修复]+检查脚本执行失败: %@", error.localizedDescription);
            // 🔧 关键修复：JavaScript检查失败时，直接执行强制页面修复
            NSLog(@"在局Claude Code[页面可见性修复]+JavaScript检查失败，执行强制修复");
            [self performPageVisibilityFix];
            return;
        }
        
        // 在局Claude Code[页面可见性修复]+安全地解析JavaScript返回结果
        NSDictionary *checkResult = nil;
        NSError *jsonError = nil;
        
        if ([result isKindOfClass:[NSString class]]) {
            // 如果返回的是字符串，尝试JSON解析
            NSData *jsonData = [(NSString *)result dataUsingEncoding:NSUTF8StringEncoding];
            if (jsonData) {
                checkResult = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&jsonError];
            }
        } else if ([result isKindOfClass:[NSDictionary class]]) {
            // 如果返回的已经是字典，直接使用
            checkResult = (NSDictionary *)result;
        } else {
            NSLog(@"在局Claude Code[页面可见性修复]+意外的返回类型: %@, 内容: %@", NSStringFromClass([result class]), result);
            return;
        }
        
        if (jsonError || !checkResult) {
            NSLog(@"在局Claude Code[页面可见性修复]+检查结果解析失败: %@", jsonError.localizedDescription);
            return;
        }
        
        NSLog(@"在局Claude Code[页面可见性修复]+检查结果: %@", checkResult);
        
        BOOL needsFix = [checkResult[@"needsFix"] boolValue];
        BOOL hasContent = [checkResult[@"hasContent"] boolValue];
        NSInteger visibleElements = [checkResult[@"visibleElements"] integerValue];
        
        // 如果页面需要修复
        if (needsFix || (!hasContent && visibleElements == 0)) {
            NSLog(@"在局Claude Code[页面可见性修复]+检测到页面显示异常，开始修复");
            [self performPageVisibilityFix];
        } else {
            NSLog(@"在局Claude Code[页面可见性修复]+页面显示正常，无需修复");
        }
    }];
}

// 在局Claude Code[Tab空白修复]+执行页面可见性修复
- (void)performPageVisibilityFix {
    NSString *fixScript = @"(function() {"
        "try {"
            "var result = {timestamp: Date.now(), actions: []};"
            
            "// 1. 强制显示body"
            "if (document.body) {"
                "document.body.style.display = 'block';"
                "document.body.style.visibility = 'visible';"
                "document.body.style.opacity = '1';"
                "document.body.style.height = 'auto';"
                "document.body.style.minHeight = '100vh';"
                "result.actions.push('body_fixed');"
            "}"
            
            "// 2. 修复可能被隐藏的主要容器"
            "var containers = document.querySelectorAll('main, .main, #main, .app, #app, .container, #container, .page, #page');"
            "var fixedContainers = 0;"
            "for (var i = 0; i < containers.length; i++) {"
                "var container = containers[i];"
                "var style = window.getComputedStyle(container);"
                "if (style.display === 'none' || style.visibility === 'hidden' || parseFloat(style.opacity) < 0.1) {"
                    "container.style.display = 'block';"
                    "container.style.visibility = 'visible';"
                    "container.style.opacity = '1';"
                    "fixedContainers++;"
                "}"
            "}"
            "result.fixedContainers = fixedContainers;"
            
            "// 3. 移除可能的loading遮罩"
            "var masks = document.querySelectorAll('.loading, .mask, .overlay, .spinner, .loading-mask, .loading-overlay');"
            "var removedMasks = 0;"
            "for (var i = 0; i < masks.length; i++) {"
                "var mask = masks[i];"
                "if (!mask.classList.contains('keep-visible')) {"
                    "mask.style.display = 'none';"
                    "removedMasks++;"
                "}"
            "}"
            "result.removedMasks = removedMasks;"
            
            "// 4. 检查并修复可能被隐藏的内容元素"
            "var contentElements = document.querySelectorAll('div, section, article, p');"
            "var fixedElements = 0;"
            "for (var i = 0; i < contentElements.length; i++) {"
                "var elem = contentElements[i];"
                "var style = window.getComputedStyle(elem);"
                "if (style.display === 'none' && !elem.classList.contains('hidden') && !elem.classList.contains('d-none')) {"
                    "// 只修复那些不应该被隐藏的元素"
                    "if (elem.textContent && elem.textContent.trim().length > 0) {"
                        "elem.style.display = 'block';"
                        "fixedElements++;"
                    "}"
                "}"
            "}"
            "result.fixedElements = fixedElements;"
            
            "// 5. 强制重新渲染"
            "if (document.body) {"
                "document.body.offsetHeight;" // 触发重排
                "document.body.style.transform = 'translateZ(0)';" // 触发GPU合成
                "setTimeout(function() {"
                    "document.body.style.transform = '';"
                "}, 10);"
                "result.actions.push('forced_rerender');"
            "}"
            
            "// 6. 触发布局相关事件"
            "window.dispatchEvent(new Event('resize'));"
            "window.dispatchEvent(new Event('orientationchange'));"
            "result.actions.push('events_triggered');"
            
            "// 7. 如果有应用级别的刷新方法，调用它"
            "if (typeof app !== 'undefined' && typeof app.refreshDisplay === 'function') {"
                "app.refreshDisplay();"
                "result.actions.push('app_refresh_called');"
            "}"
            
            "result.success = true;"
            "return JSON.stringify(result);"
        "} catch(e) {"
            "return JSON.stringify({success: false, error: e.message, timestamp: Date.now()});"
        "}"
    "})()";
    
    [self safelyEvaluateJavaScript:fixScript completionHandler:^(id result, NSError *error) {
        if (error) {
            NSLog(@"在局Claude Code[页面可见性修复]+修复脚本执行失败: %@", error.localizedDescription);
        } else {
            NSLog(@"在局Claude Code[页面可见性修复]+修复脚本执行完成: %@", result);
        }
        
        // 修复完成后，再次验证页面状态
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self verifyPageVisibilityAfterFix];
        });
    }];
}

// 在局Claude Code[Tab空白修复]+修复后验证页面状态
- (void)verifyPageVisibilityAfterFix {
    NSString *verifyScript = @"(function() {"
        "try {"
            "var result = {"
                "timestamp: Date.now(),"
                "bodyVisible: false,"
                "hasContent: false,"
                "visibleElements: 0"
            "};"
            
            "if (document.body) {"
                "var style = window.getComputedStyle(document.body);"
                "result.bodyVisible = (style.display !== 'none' && style.visibility !== 'hidden' && parseFloat(style.opacity) > 0);"
                
                "var textContent = document.body.textContent || document.body.innerText || '';"
                "result.hasContent = textContent.trim().length > 0;"
                
                "var elements = document.querySelectorAll('div, section, main, article, p');"
                "var visibleCount = 0;"
                "for (var i = 0; i < elements.length; i++) {"
                    "var elem = elements[i];"
                    "var elemStyle = window.getComputedStyle(elem);"
                    "if (elemStyle.display !== 'none' && elemStyle.visibility !== 'hidden' && parseFloat(elemStyle.opacity) > 0) {"
                        "visibleCount++;"
                    "}"
                "}"
                "result.visibleElements = visibleCount;"
            "}"
            
            "result.success = true;"
            "return JSON.stringify(result);"
        "} catch(e) {"
            "return JSON.stringify({success: false, error: e.message});"
        "}"
    "})()";
    
    [self safelyEvaluateJavaScript:verifyScript completionHandler:^(id result, NSError *error) {
        if (error) {
            NSLog(@"在局Claude Code[页面可见性修复]+验证脚本执行失败: %@", error.localizedDescription);
            return;
        }
        
        // 在局Claude Code[页面可见性修复]+安全地解析验证结果
        NSDictionary *verifyResult = nil;
        NSError *jsonError = nil;
        
        if ([result isKindOfClass:[NSString class]]) {
            NSData *jsonData = [(NSString *)result dataUsingEncoding:NSUTF8StringEncoding];
            if (jsonData) {
                verifyResult = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&jsonError];
            }
        } else if ([result isKindOfClass:[NSDictionary class]]) {
            verifyResult = (NSDictionary *)result;
        } else {
            NSLog(@"在局Claude Code[页面可见性修复]+验证返回意外类型: %@", NSStringFromClass([result class]));
            return;
        }
        
        if (jsonError || !verifyResult) {
            NSLog(@"在局Claude Code[页面可见性修复]+验证结果解析失败");
            return;
        }
        
        BOOL bodyVisible = [verifyResult[@"bodyVisible"] boolValue];
        BOOL hasContent = [verifyResult[@"hasContent"] boolValue];
        NSInteger visibleElements = [verifyResult[@"visibleElements"] integerValue];
        
        if (bodyVisible && hasContent && visibleElements > 0) {
            NSLog(@"在局Claude Code[页面可见性修复]+✅ 页面修复成功，当前状态正常");
        } else {
            NSLog(@"在局Claude Code[页面可见性修复]+❌ 页面修复后仍有问题，需要进一步排查");
            // 如果修复后仍有问题，可以考虑重新加载页面
            [self considerPageReload];
        }
    }];
}

// 在局Claude Code[Tab空白修复]+考虑重新加载页面
- (void)considerPageReload {
    // 避免频繁重新加载
    static NSDate *lastReloadTime = nil;
    NSDate *now = [NSDate date];
    if (lastReloadTime && [now timeIntervalSinceDate:lastReloadTime] < 5.0) {
        NSLog(@"在局Claude Code[页面可见性修复]+距离上次重新加载时间过短，跳过");
        return;
    }
    lastReloadTime = now;
    
    NSLog(@"在局Claude Code[页面可见性修复]+页面修复失败，考虑重新加载页面");
    
    // 重置状态并重新加载
    self.isLoading = NO;
    self.isExist = NO;
    
    // 延迟重新加载，给当前操作一些时间完成
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (!self->_isDisappearing && self.webView) {
            NSLog(@"在局Claude Code[页面可见性修复]+执行页面重新加载");
            [self domainOperate];
        }
    });
}

// 检查页面是否正在消失的状态
- (BOOL)isPageDisappearing {
    return _isDisappearing;
}

@end
