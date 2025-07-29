//
//  CFJWebViewBaseController.m
//  XiangZhanBase
//
//  Created by cuifengju on 2017/10/13.
//  Copyright © 2017年 TuWeiA. All rights reserved.
//

#import "CFJWebViewBaseController.h"
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
#import <Masonry.h>
#import <MJRefresh.h>
#import "XZPackageH5.h"
#import "LoadingView.h"
#import "CustomHybridProcessor.h"

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
@interface CFJWebViewBaseController ()<WKNavigationDelegate,UIScrollViewDelegate>
{
    __block int timeout; //倒计时时间
}
@property (strong, nonatomic) NSString *htmlStr;
@property (strong, nonatomic) NSString *appsourceBasePath;
@property (strong, nonatomic) UIButton *networkNoteBt;
@property (strong, nonatomic) UIView *networkNoteView;
@property (strong, nonatomic) NSLock *timerlock;

@property (strong,nonatomic)UIActivityIndicatorView *activityIndicatorView;

/** 上次选中的索引(或者控制器) */
@property (nonatomic, assign) NSInteger lastSelectedIndex;
@property (nonatomic, assign) BOOL isLoading;
@property (nonatomic, assign) BOOL isActive;
@property (nonatomic, strong) dispatch_source_t timer;

@property (strong, nonatomic) NSMutableDictionary *dataDic;

@end

@implementation CFJWebViewBaseController
- (NSMutableDictionary *)templateDic {
    if (_templateDic == nil) {
        _templateDic = [NSMutableDictionary dictionaryWithCapacity:1];
    }
    return _templateDic;
}
- (NSMutableArray *)ComponentJsAndCs {
    if (_ComponentJsAndCs == nil) {
        _ComponentJsAndCs = [NSMutableArray arrayWithCapacity:0];
    }
    return _ComponentJsAndCs;
}
- (NSMutableDictionary *)ComponentDic {
    if (_ComponentDic == nil) {
        _ComponentDic = [NSMutableDictionary dictionaryWithCapacity:0];
    }
    return _ComponentDic;
}
- (NSMutableDictionary *)dataDic {
    if (_dataDic == nil) {
        _dataDic = [NSMutableDictionary dictionaryWithCapacity:0];
    }
    return _dataDic;
}
- (NSDictionary *)nextPageData {
    if (_nextPageData == nil) {
        _nextPageData = [NSDictionary dictionary];
    }
    return _nextPageData;
}
- (NSLock *)timerlock {
    if (_timerlock == nil) {
        _timerlock = [[NSLock alloc]init];
    }
    return _timerlock;
}
- (WKWebView *)webView {
    if (_webView == nil) {
        WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
        config.mediaTypesRequiringUserActionForPlayback = WKAudiovisualMediaTypeNone;
        _webView = [[WKWebView alloc] initWithFrame:CGRectZero configuration:config];
        _webView.navigationDelegate = self;
        _webView.scrollView.delegate = self;
        _webView.scrollView.scrollsToTop = YES;
        _webView.scrollView.showsVerticalScrollIndicator = NO;
        _webView.scrollView.showsHorizontalScrollIndicator = NO;
        _webView.scrollView.bounces = YES;
        _webView.scrollView.decelerationRate = UIScrollViewDecelerationRateNormal;
    }
    return _webView;
}
- (UIView *)networkNoteView {
    if (_networkNoteView == nil) {
        _networkNoteView = [[UIView alloc]initWithFrame:CGRectMake(0, 20, ScreenWidth, 44)];
        _networkNoteView.backgroundColor = [UIColor colorWithHexString:
                                            [[NSUserDefaults standardUserDefaults] objectForKey:@"StatusBarBackgroundColor"]];
    }
    return _networkNoteView;
}
- (UIActivityIndicatorView *)activityIndicatorView {
    if (_activityIndicatorView == nil) {
        _activityIndicatorView = [[UIActivityIndicatorView alloc] initWithFrame:CGRectMake(0, 0, 50, 50)];
        [_activityIndicatorView setCenter:self.view.center];
        [_activityIndicatorView setActivityIndicatorViewStyle:UIActivityIndicatorViewStyleGray];    }
    return _activityIndicatorView;
}
- (void)dealloc
{
    _webView.navigationDelegate = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - App Lifecycle Methods

- (void)appWillTerminate:(NSNotification *)notification {
    NSLog(@"在局🔔 [CFJWebView] 应用即将终止，停止所有JavaScript执行");
    
    // 立即停止所有WebView活动
    if (self.webView) {
        // 停止加载
        [self.webView stopLoading];
        
        // 清空页面，防止JavaScript继续执行
        [self.webView loadHTMLString:@"<html><body></body></html>" baseURL:nil];
        
        // 清理JavaScript桥接
        if ([self respondsToSelector:@selector(bridge)]) {
            id bridge = [self valueForKey:@"bridge"];
            if (bridge && [bridge respondsToSelector:@selector(reset)]) {
                [bridge performSelector:@selector(reset)];
            }
        }
        
        // 设置WebView为nil以释放资源
        self.webView.navigationDelegate = nil;
        self.webView.UIDelegate = nil;
        self.webView = nil;
    }
}

- (void)appDidEnterBackground:(NSNotification *)notification {
    NSLog(@"在局🔔 [CFJWebView] 应用进入后台，暂停JavaScript执行");
    
    // 只停止加载，不要执行新的JS
    if (self.webView) {
        [self.webView stopLoading];
    }
    
    if (self.timer) {
        dispatch_source_cancel(self.timer);
        self.timer = nil;
    }
}

- (void)appWillResignActive:(NSNotification *)notification {
    NSLog(@"在局🔔 [CFJWebView] 应用即将失去活跃状态，暂停所有JavaScript执行");
    
    // 只停止加载，不要执行新的JS
    if (self.webView) {
        [self.webView stopLoading];
    }
    
    // 如果定时器仍然存在，取消它
    if (self.timer) {
        dispatch_source_cancel(self.timer);
        self.timer = nil;
    }
}

- (void)addNotifi {
    WEAK_SELF;
    //RefreshAllVCNotif 客户端登陆成功或者退出成功以后刷新其他页面
    [[NSNotificationCenter defaultCenter] addObserverForName:@"RefreshOtherAllVCNotif" object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification * _Nonnull note) {
        STRONG_SELF;
        UIViewController *vc = note.object;
        if (self == vc) {
            return ;
        }
        [self domainOperate];
    }];
#pragma mark ---CFJ新加
    [[NSNotificationCenter defaultCenter] addObserverForName:@"refreshCurrentViewController" object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification * _Nonnull note) {
        STRONG_SELF;
        if (self.lastSelectedIndex == self.tabBarController.selectedIndex && [self isShowingOnKeyWindow] && self.isWebViewLoading) {
            if ([AFNetworkReachabilityManager manager].networkReachabilityStatus == AFNetworkReachabilityStatusNotReachable) {
                return;
            }
            //TODO 暂时注释
            //            [[HTMLCache sharedCache] removeObjectForKey:self.webViewDomain];
            //            [self domainOperate];
            if ([self.webView.scrollView.mj_header isRefreshing]) {
                [self.webView.scrollView.mj_header endRefreshing];
            }
            [self.webView.scrollView.mj_header beginRefreshing];
        }
        // 记录这一次选中的索引
        self.lastSelectedIndex = self.tabBarController.selectedIndex;
    }];
}
- (void)viewDidLoad {
    [super viewDidLoad];
    
    // 添加应用生命周期通知监听
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appWillTerminate:) name:@"AppWillTerminateNotification" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidEnterBackground:) name:@"AppDidEnterBackgroundNotification" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appWillResignActive:) name:@"AppWillResignActiveNotification" object:nil];
    
    // 修复iOS 12键盘弹起后布局问题
    NSLog(@"在局 🔧 [CFJWebViewBaseController] 修复iOS 12键盘布局问题");
    if (@available(iOS 12.0, *)) {
        // iOS 12及以上版本使用Automatic，避免键盘弹起后视图不恢复的问题
        self.webView.scrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentAutomatic;
        NSLog(@"在局 ✅ [CFJWebViewBaseController] iOS 12+使用UIScrollViewContentInsetAdjustmentAutomatic");
    } else if (@available(iOS 11.0, *)) {
        // iOS 11使用Never
        self.webView.scrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
        NSLog(@"在局 ✅ [CFJWebViewBaseController] iOS 11使用UIScrollViewContentInsetAdjustmentNever");
    } else {
        self.automaticallyAdjustsScrollViewInsets = NO;
    }
    __weak UIScrollView *scrollView = self.webView.scrollView;
    MJRefreshNormalHeader *header = [MJRefreshNormalHeader headerWithRefreshingTarget:self refreshingAction:@selector(loadNewData)];
    //    header.stateLabel.textColor = [UIColor whiteColor];
    // 隐藏时间
    header.lastUpdatedTimeLabel.hidden = YES;
    // 隐藏状态
    // header.stateLabel.hidden = YES;
    // 添加下拉刷新控件
    scrollView.mj_header= header;
//    //初始化上拉刷新控件
//    MJRefreshBackNormalFooter *footer = [MJRefreshBackNormalFooter footerWithRefreshingTarget:self refreshingAction:@selector(loadMoreData)];
//     footer.stateLabel.hidden = YES;
//    //添加上拉刷新控件
//    scrollView.mj_footer = footer;
    [self addNotifi];
    [self addWebView];
    [self.view addSubview:self.activityIndicatorView];
    [_activityIndicatorView startAnimating];
    [self netWorkButton];
    [NSURLProtocol registerClass:[RNCachingURLProtocol class]];
}
- (void)loadNewData{
    NSDictionary *callJsDic = [CustomHybridProcessor custom_objcCallJsWithFn:@"pagePullDownRefresh" data:nil];
    [self objcCallJs:callJsDic];
    if (NoReachable) {
        if ([self.webView.scrollView.mj_header isRefreshing]) {
            [self.webView.scrollView.mj_header endRefreshing];
        }
        return;
    }
}
- (void)loadMoreData {
    NSDictionary *callJsDic = [CustomHybridProcessor custom_objcCallJsWithFn:@"onReachBottom" data:nil];
    [self objcCallJs:callJsDic];
    __weak UIScrollView *scrowview = self.webView.scrollView;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        // 拿到当前的上拉刷新控件，结束刷新状态
        [scrowview.mj_footer endRefreshing];
    });
    if (NoReachable) {
        if ([self.webView.scrollView.mj_footer isRefreshing]) {
            [self.webView.scrollView.mj_footer endRefreshing];
        }
        return;
    }
}
//添加断网,或者网络问题导致页面加载失败的按钮处理
- (void)netWorkButton {
    self.networkNoteBt = [UIButton buttonWithType:UIButtonTypeCustom];
    self.networkNoteBt.frame = CGRectMake(0, 64, [UIScreen mainScreen].bounds.size.width, [UIScreen mainScreen].bounds.size.height - 64);
    [self.networkNoteBt setImage:[UIImage imageNamed:@"network_1242_2016"] forState:UIControlStateNormal];
    [self.networkNoteBt setImage:[UIImage imageNamed:@"network_1242_2016"] forState:UIControlStateHighlighted];
    [self.networkNoteBt addTarget:self action:@selector(networkNoteBtClick) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.networkNoteBt];
    [self.view addSubview:self.networkNoteView];
    self.networkNoteBt.hidden = YES;
    self.networkNoteView.hidden = YES;
}
- (void)networkNoteBtClick {
    if (NoReachable) {
        return ;
    }
    [self.view addSubview:self.activityIndicatorView];
    [_activityIndicatorView startAnimating];
    self.networkNoteBt.hidden = YES;
    self.networkNoteView.hidden = YES;
}
- (void)viewDidAppear:(BOOL)animated {
    // 记录这一次选中的索引
    self.lastSelectedIndex = self.tabBarController.selectedIndex;
//    [self listenToTimer];
}

- (void)viewWillAppear:(BOOL)animated {
    if (self.isExist) {
        NSDictionary *callJsDic = [CustomHybridProcessor custom_objcCallJsWithFn:@"pageShow" data:nil];
        [self objcCallJs:callJsDic];
    }
    self.isExist = YES;
    self.isActive = YES;
}

- (void)viewWillDisappear:(BOOL)animated {
    self.isActive = NO;
    self.lastSelectedIndex = 100;
    // 安全地取消timer，防止野指针
    dispatch_source_t timerToCancel = self.timer;
    if (timerToCancel) {
        self.timer = nil; // 先置空
        dispatch_source_cancel(timerToCancel); // 再取消
    }
    if ([self.webView.scrollView.mj_header isRefreshing]) {
        [self.webView.scrollView.mj_header endRefreshing];
    }
}

- (void)listenToTimer {
    if (self.networkNoteView.hidden) {
        if (self.timer) {
            dispatch_source_cancel(self.timer);
            self.timer = nil;
        }
        dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
        self.timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0,queue);
        dispatch_source_set_timer(_timer,dispatch_walltime(NULL, 0),1.0*NSEC_PER_SEC, 0); //每秒执行
        // 增加超时时间以适应Release版本的优化
        timeout = 10;
        dispatch_source_set_event_handler(_timer, ^{
            if(self->timeout<=0){ //倒计时结束，关闭
                if (self.isLoading) {
                    dispatch_source_cancel(self->_timer);
                }
                else {
                    WEAK_SELF;
                    dispatch_async(dispatch_get_main_queue(), ^{
                        STRONG_SELF;
                        if (NoReachable) {
                            return;
                        }
                        [[HTMLCache sharedCache] removeObjectForKey:self.webViewDomain];
                        [self domainOperate];
                    });
                }
            }
            else{
                if (self.isLoading) {
                    dispatch_source_cancel(self->_timer);
                }
                else {
                    self->timeout--;
                }
            }
        });
        dispatch_resume(_timer);
    }
    
}
- (void)addWebView {
    [self.view addSubview:self.webView];
    if (self.navigationController.viewControllers.count > 1) {
            [self.webView mas_makeConstraints:^(MASConstraintMaker *make) {
                make.left.equalTo(self.view);
                make.right.equalTo(self.view);
                make.bottom.equalTo(self.view);
                make.top.equalTo(self.view);
            }];
    }
    else {
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"NoTabBar"]) {
            //如果没有tabbar,将tabbar的frame设为0
            self.tabBarController.tabBar.frame
            = CGRectZero;
            [self.webView mas_makeConstraints:^(MASConstraintMaker *make) {
                make.left.equalTo(self.view);
                make.right.equalTo(self.view);
                make.bottom.equalTo(self.view);
                make.top.equalTo(self.view);
            }];
        }
        else {
            [self.webView mas_makeConstraints:^(MASConstraintMaker *make) {
                make.left.equalTo(self.view);
                make.right.equalTo(self.view);
                if (@available(iOS 11.0, *)) {
                    make.bottom.equalTo(self.view.mas_safeAreaLayoutGuideBottom);
                }
                else {
                    make.bottom.equalTo(self.view);
                }
                make.top.equalTo(self.view);
            }];
        }
    }
}

//加载本地静态路径
- (void)loadAppHtml {
    if (self.htmlStr) {
        if (self.pinDataStr) {
            if (self.pagetitle) {
                [self getnavigationBarTitleText:self.pagetitle];
            }
            NSString *allHtmlStr;
            allHtmlStr = [self.htmlStr stringByReplacingOccurrencesOfString:@"{{body}}" withString:self.pinDataStr];
            
            if ([self isHaveNativeHeader:self.pinUrl]) {
                allHtmlStr = [allHtmlStr stringByReplacingOccurrencesOfString:@"{{phoneClass}}" withString:isIPhoneXSeries() ? @"iPhoneLiuHai" : @"iPhone"];
            }
            [self.webView loadHTMLString:allHtmlStr baseURL:[HTMLCache sharedCache].noHtmlBaseUrl];
        } else {
//            [[HybridManager shareInstance] LocialPathByUrlStr:self.pinUrl templateDic:self.templateDic templateStr:self.templateStr componentJsAndCs:self.ComponentJsAndCs componentDic:self.ComponentDic success:^(NSString * _Nonnull filePath, NSString * _Nonnull templateStr, NSString * _Nonnull title, BOOL isFileExsit) {
//                [self getnavigationBarTitleText:title];
//                NSString *allHtmlStr;
//                NSLog(@"在局xxxhtmlStr: %@",self.htmlStr);
//                NSLog(@"在局xxxtemplateStr: %@",templateStr);
//                NSLog(@"在局xxxfilePath: %@",filePath);
//                allHtmlStr = [self.htmlStr stringByReplacingOccurrencesOfString:@"{{body}}" withString:templateStr];
//                
//                NSLog(@"在局xxxpinUrl: %@",self.pinUrl);
//                NSLog(@"在局xxxallHtmlStr: %@",allHtmlStr);
//                if ([self isHaveNativeHeader:self.pinUrl]) {
//                    allHtmlStr = [allHtmlStr stringByReplacingOccurrencesOfString:@"{{phoneClass}}" withString:isIPhoneXSeries() ? @"iPhoneLiuHai" : @"iPhone"];
//                    NSLog(@"在局xxxallHtmlStr: %@",allHtmlStr);
//                }
//                [self.webView loadHTMLString:allHtmlStr baseURL:[HTMLCache sharedCache].noHtmlBaseUrl];
//            }];
            NSLog(@"在局页面地址：%@",self.pinUrl);
            [CustomHybridProcessor custom_LocialPathByUrlStr:self.pinUrl
                                                 templateDic:self.templateDic
                                            componentJsAndCs:self.ComponentJsAndCs
                                              componentDic:self.ComponentDic
                                                   success:^(NSString * _Nonnull filePath, NSString * _Nonnull templateStr, NSString * _Nonnull title, BOOL isFileExsit) {
                
                [self getnavigationBarTitleText:title];
                NSString *allHtmlStr;
                allHtmlStr = [self.htmlStr stringByReplacingOccurrencesOfString:@"{{body}}" withString:templateStr];

                if ([self isHaveNativeHeader:self.pinUrl]) {
                    allHtmlStr = [allHtmlStr stringByReplacingOccurrencesOfString:@"{{phoneClass}}" withString:isIPhoneXSeries() ? @"iPhoneLiuHai" : @"iPhone"];
                }
                
                [self.webView loadHTMLString:allHtmlStr baseURL:[HTMLCache sharedCache].noHtmlBaseUrl];
            }];
        }
        //注意，一个webview bridge只能有一次，否则失败
        if (!self.bridge) {
            [self loadWebBridge];
        }
        self.isWebViewLoading = NO;
    }
}

//获取标题
- (void)getnavigationBarTitleText:(NSString *)title {
    self.navigationItem.title = title;
}

- (void)loadWebBridge {
#ifdef DEBUG
    [WKWebViewJavascriptBridge enableLogging];
#endif
    
    WEAK_SELF;
    self.bridge = [WKWebViewJavascriptBridge bridgeForWebView:self.webView];
    [self.bridge setWebViewDelegate:self];
    [self.bridge registerHandler:@"xzBridge" handler:^(id data, WVJBResponseCallback responseCallback) {
        STRONG_SELF;
        if ([data isKindOfClass:[NSDictionary class]]) {
            [self jsCallObjc:data jsCallBack:responseCallback];
        }
    }];
}

- (void)domainOperate {
    NSLog(@"在局 🔧 [CFJWebViewBaseController] 优化domainOperate - 使用异步文件I/O");
    self.isLoading = NO;
//    [self listenToTimer];
    
    // 在后台队列异步读取HTML文件，避免阻塞主线程
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        NSLog(@"在局 🚀 [CFJWebViewBaseController] 开始异步读取HTML文件");
        
        NSString *filepath = [[BaseFileManager appH5LocailManifesPath] stringByAppendingPathComponent:@"app.html"];
        if ([[NSFileManager defaultManager] fileExistsAtPath:filepath]) {
            NSError *error;
            NSString *htmlContent = [NSString stringWithContentsOfURL:[NSURL fileURLWithPath:filepath] encoding:NSUTF8StringEncoding error:&error];
            
            // 回到主线程处理结果
            dispatch_async(dispatch_get_main_queue(), ^{
                if (!error && htmlContent) {
                    NSLog(@"在局 ✅ [CFJWebViewBaseController] HTML文件读取成功");
                    self.htmlStr = htmlContent;
                    [self loadAppHtml];
                } else {
                    NSLog(@"在局 ❌ [CFJWebViewBaseController] 读取HTML文件失败: %@", error.localizedDescription);
                }
            });
        } else {
            NSLog(@"在局 ❌ [CFJWebViewBaseController] HTML文件不存在: %@", filepath);
        }
    });
}

- (void)jsCallObjc:(id)jsData jsCallBack:(WVJBResponseCallback)jsCallBack {
    
    NSDictionary *jsDic = (NSDictionary *)jsData;
    NSString *function = [jsDic objectForKey:@"action"];
    NSDictionary *dataDic = [jsDic objectForKey:@"data"];
    
    
    if ([function isEqualToString:@"request"]) {
        NSString *deviceTokenStr = [[NSUserDefaults standardUserDefaults] objectForKey:@"User_ChannelId"];
        deviceTokenStr = deviceTokenStr ? deviceTokenStr : @"";
        
        [self rpcRequestWithJsDic:dataDic jsCallBack:jsCallBack];
    }
    
    //刷新侧边栏
    if ([function isEqualToString:@"freshLeftSide"]) {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"refreshSlideH5Notif" object:nil];
    }
    
    if ([function isEqualToString:@"backAndFresh"]) {
        CFJWebViewBaseController *vc = [self.navigationController.viewControllers safeObjectAtIndex:self.navigationController.viewControllers.count - 2];
        [[HTMLCache sharedCache] removeObjectForKey:vc.webViewDomain];
        [vc domainOperate];
        if (self.navigationController.viewControllers.count >= 2) {
            [self.navigationController popViewControllerAnimated:YES];
        }
        else {
            [self dismissViewControllerAnimated:YES completion:nil];
        }
    }
    
    if ([function isEqualToString:@"backAndCall"]) {
        CFJWebViewBaseController *vc = [self.navigationController.viewControllers safeObjectAtIndex:self.navigationController.viewControllers.count - 2];
        NSDictionary *callJsDic = [CustomHybridProcessor custom_objcCallJsWithFn:[dataDic objectForKey:@"action"] data:[dataDic objectForKey:@"data"]];
        [vc objcCallJs:callJsDic];
        if (self.navigationController.viewControllers.count >= 2) {
            [self.navigationController popViewControllerAnimated:YES];
        }
        else {
            [self dismissViewControllerAnimated:YES completion:nil];
        }
    }
    
    if ([function isEqualToString:@"backTab"]) {
        if (self.navigationController.viewControllers.count >= 2) {
            [self.navigationController popViewControllerAnimated:YES];
        }
        else {
            [self dismissViewControllerAnimated:YES completion:nil];
        }
    }
    if ([function isEqualToString:@"reload"]) {
        if (NoReachable) {
            return;
        }
        [[HTMLCache sharedCache] removeObjectForKey:self.webViewDomain];
        [self domainOperate];
    }
    
    if ([function isEqualToString:@"pay"]) {
        self.webviewBackCallBack = jsCallBack;
        [self payRequest:dataDic];
    }
    
    if ([function isEqualToString:@"preloadPages"]) {
        //如果网络不畅通，不缓存；
        if (NoReachable) {
            return;
        }
        //TODO 处理预加载
        NSArray *urls = [dataDic objectForKey:@"urls"];
        for (NSString *url in urls) {
            //如果缓存中有，取得缓存数据，不再从网络加载
            NSString *htmlStr = [[HTMLCache sharedCache] objectForKey:url];
            if (htmlStr) {
                continue;
            }
            else if (Wifi) {
                WEAK_SELF;
                dispatch_async(dispatch_get_global_queue(0, 0), ^(void) {
                    STRONG_SELF;
                    [self preloadHtmlBodyWithUrl:url :htmlStr];
                });
            }
            else {
                continue;
            }
        }
    }
    if ([function isEqualToString:@"userSignin"]) {
        //刷新其他页面
        [[HTMLCache sharedCache] removeAllCache];
        [[NSUserDefaults standardUserDefaults] setObject:dataDic[@"loginUid"] forKey:@"loginUid"];
        [[NSUserDefaults standardUserDefaults] setObject:dataDic[@"userName"] forKey:@"userName"];
        [[NSUserDefaults standardUserDefaults] setObject:dataDic[@"userPhone"] forKey:@"userPhone"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"RefreshOtherAllVCNotif" object:self];
    }
    if ([function isEqualToString:@"pageReady"]) {
        self.isLoading = YES;
        if ([self.webView.scrollView.mj_header isRefreshing]) {
            [self.webView.scrollView.mj_header endRefreshing];
        }
        if (_activityIndicatorView) {
            [self.activityIndicatorView stopAnimating];
            [self.activityIndicatorView removeFromSuperview];
        }
    }
    if ([function isEqualToString:@"userSignout"]) {
        //清除cookie、刷新其他页面
        [[HTMLCache sharedCache] removeAllCache];
        [WKWebView cookieDeleteAllCookie];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"RefreshOtherAllVCNotif" object:self];
        //退出后firstLoadMessageWindow标志设为no 并且杀掉聊天页面
        [[NSNotificationCenter defaultCenter] postNotificationName:@"stopImH5ViewController" object:nil];
        [[NSUserDefaults standardUserDefaults] setInteger:0 forKey:@"clinetMessageNum"];
        [[NSUserDefaults standardUserDefaults] setInteger:0 forKey:@"shoppingCartNum"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    
    //显示消息框
    if ([function isEqualToString:@"showMessageBox"]) {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"jsShowMessageBox" object:nil];
    }
#pragma mark ===== 2.0方法
    if ([function isEqualToString:@"stopPullDownRefresh"]) {
        if ([self.webView.scrollView.mj_header isRefreshing]) {
            [self.webView.scrollView.mj_header endRefreshing];
        }
    }
    //隐藏消息框
    //    if ([function isEqualToString:@"hideMessageBox"]) {
    //        [[NSNotificationCenter defaultCenter] postNotificationName:@"jsHideMessageBox" object:nil];
    //    }
    
    ///显示隐藏左右侧边栏
    if ([function isEqualToString:@"showLeftSide"]) {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"showLeftSideNotif" object:nil];
    }
    
    if ([function isEqualToString:@"hideLeftSide"]) {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"hideLeftSideNotif" object:nil];
    }
    
    if ([function isEqualToString:@"showRightSide"]) {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"showRightSideNotif" object:nil];
    }
    
    if ([function isEqualToString:@"hideRightSide"]) {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"hideRightSideNotif" object:nil];
    }
    
    ///显示隐藏底部tabbar
    if ([function isEqualToString:@"hideBottomNavbar"]) {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"HideTabBarNotif" object:nil];
    }
    
    if ([function isEqualToString:@"showBottomNavbar"]) {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"ShowTabBarNotif" object:nil];
    }
    
    //设置消息数字
    if ([function isEqualToString:@"setMessageNum"]) {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"setMessageNum" object:dataDic];
    }
    
    //打开消息窗口
    if ([function isEqualToString:@"openMessageWindow"]) {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"openMessageWindow" object:nil];
    }
    
    //关闭消息窗口
    if ([function isEqualToString:@"closeMessageWindow"]) {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"closeMessageWindow" object:nil];
    }
    
    //清除缓存
    if ([function isEqualToString:@"clearCache"]) {
        [[HTMLCache sharedCache] removeAllCache];
        jsCallBack(@{@"result":@"success"});
    }
    
    //复制发送的内容
    if ([function isEqualToString:@"copy"]) {
        [NSString copyLink:[dataDic objectForKey:@"content"]];
        jsCallBack(@{@"result":@"success"});
    }
    
    if ([function isEqualToString:@"loadMessageWindow"]) {
        BOOL firstLoadMessageWindow = [[NSUserDefaults standardUserDefaults] boolForKey:@"firstLoadMessageWindow"];
        if (!firstLoadMessageWindow) {
            [[NSNotificationCenter defaultCenter] postNotificationName:@"loadMessageWindow" object:nil];
        }
    }
}

- (void)preloadHtmlBodyWithUrl:(NSString *)url :(NSString *)oldStr {
    if (self.isActive) {
        AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
        manager.responseSerializer = [AFHTTPResponseSerializer serializer];
        manager.requestSerializer = [AFHTTPRequestSerializer serializer];
        if(ISIPAD) {
            [manager.requestSerializer setValue:@"iospad" forHTTPHeaderField:@"from"];
        } else {
            [manager.requestSerializer setValue:@"ios" forHTTPHeaderField:@"from"];
        }
        [manager.requestSerializer setValue:[[NSUserDefaults standardUserDefaults]
                                             objectForKey:@"User_Token_String"] forHTTPHeaderField:@"AUTHORIZATION"];
        manager.requestSerializer.timeoutInterval = 5;
        url = [url stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
        if (!url) {
            return;
        }
        // WKWebView 使用 WKHTTPCookieStore 管理 cookies
        [manager GET:url parameters:nil headers:nil progress:nil success:^(NSURLSessionDataTask *task, id responseObject) {
            NSString *newHtmlStr = [[NSString alloc] initWithData:responseObject encoding:NSUTF8StringEncoding];
            if (newHtmlStr && ![oldStr isEqualToString:newHtmlStr]) {
                [[HTMLCache sharedCache] cacheHtml:newHtmlStr key:url];
            }
//            NSArray *storageCookieAry = [NSHTTPCookieStorage sharedHTTPCookieStorage].cookies;
        } failure:^(NSURLSessionDataTask *task, NSError *error) {
        }];
    }
}



#pragma mark - WKNavigationDelegate -
- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(WKNavigation *)navigation {
    
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    if (!self.isWebViewLoading) {
        // 先在keyWindow中查找，再在主窗口中查找LoadingView
        UIView *loadingView = [[UIApplication sharedApplication].keyWindow viewWithTag:2001];
        if (!loadingView) {
            UIWindow *mainWindow = [UIApplication sharedApplication].delegate.window;
            loadingView = [mainWindow viewWithTag:2001];
        }
        
        if (loadingView && [self isShowingOnKeyWindow]) {
            if (![[NSUserDefaults standardUserDefaults] boolForKey:@"isFirst"]) {
                [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"isFirst"];
            }
            else {
                // 使用找到的loadingView的父视图
                UIView *parentView = loadingView.superview;
                [parentView bringSubviewToFront:loadingView];
            }
            

            [[NSNotificationCenter defaultCenter] postNotificationName:@"showTabviewController" object:self];
        }
        [self.webView evaluateJavaScript:@"document.documentElement.style.webkitUserSelect='none';" completionHandler:nil];
        [self.webView evaluateJavaScript:@"document.documentElement.style.webkitTouchCallout='none';" completionHandler:nil];
        self.isWebViewLoading = YES;
    }
    
}

- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    NSLog(@"在局webview error delegate : %@",error.description);
}

- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    decisionHandler(WKNavigationActionPolicyAllow);
}
#pragma mark - objcCallJs
- (void)objcCallJs:(NSDictionary *)dic {
    [_bridge callHandler:@"xzBridge" data:dic responseCallback:^(id responseData) {
        NSLog(@"在局WebView和JS交互桥建立: %@", responseData);
    }];
}

#pragma mark - JsCallObjcHttpRequest -
- (void)rpcRequestWithJsDic:(NSDictionary *)dataDic
                 jsCallBack:(WVJBResponseCallback)jsCallBack {
}

- (void)titleLableTapped:(UIGestureRecognizer *)gesture {
    [self.webView.scrollView scrollRectToVisible:CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.height) animated:YES];
}

//具体支付过程子类中实现
- (void)payRequest:(NSDictionary *)payDic {
}

//通知后台打开站点和切换的新站点，后台站点和推送id一一对应
- (void)requestOpenSite:(NSDictionary *)param {
    NSString *siteID = [[NSUserDefaults standardUserDefaults] objectForKey:@"User_OpenedWebSiteID"] ? [[NSUserDefaults standardUserDefaults] objectForKey:@"User_OpenedWebSiteID"] : @"";
    NSString *userID = [[NSUserDefaults standardUserDefaults] objectForKey:@"User_UserId"] ? [[NSUserDefaults standardUserDefaults] objectForKey:@"User_UserId"] : @"";
    NSString *userToken = [[NSUserDefaults standardUserDefaults] objectForKey:@"User_UserToken"] ? [[NSUserDefaults standardUserDefaults] objectForKey:@"User_UserToken"] : @"";
    NSData *data = [NSJSONSerialization dataWithJSONObject:param
                                                   options:NSJSONWritingPrettyPrinted error:nil];
    NSString *dataJsonStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSDictionary *paramDic = @{
                               @"data" : dataJsonStr,
                               @"userid" : userID,
                               @"userToken" : userToken,
                               @"siteId" : siteID
                               };
    NSString *requestUrl = [NSString stringWithFormat:@"%@%@",Domain,@"/message/appLoginWebsite"];
    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    manager.responseSerializer = [AFHTTPResponseSerializer serializer];
//    manager.requestSerializer = [AFHTTPRequestSerializer serializer];
    manager.requestSerializer = [AFJSONRequestSerializer serializer];
    if(ISIPAD) {
        [manager.requestSerializer setValue:@"iospad" forHTTPHeaderField:@"from"];
    } else {
        [manager.requestSerializer setValue:@"ios" forHTTPHeaderField:@"from"];
    }

    manager.requestSerializer.timeoutInterval = 45;
    [manager.requestSerializer setValue:[[NSUserDefaults standardUserDefaults] objectForKey:@"User_Token_String"] forHTTPHeaderField:@"AUTHORIZATION"];
    [manager POST:requestUrl parameters:paramDic headers:nil progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nonnull responseObject) {
        
        NSString *str = [[NSString alloc] initWithData:responseObject encoding:NSUTF8StringEncoding];
        NSLog(@"在局responseObject:%@",str);
    } failure:^(NSURLSessionDataTask * _Nonnull task, NSError * _Nonnull error) {
        
    }];
}


/** * 判断一个控件是否真正显示在主窗口 */
- (BOOL)isShowingOnKeyWindow {
    // 主窗口
    UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
    // 以主窗口左上角为坐标原点, 计算self的矩形框
    CGRect newFrame = [keyWindow convertRect:self.view.frame fromView:self.view.superview];
    CGRect winBounds = keyWindow.bounds;
    // 主窗口的bounds 和 self的矩形框 是否有重叠
    BOOL intersects = CGRectIntersectsRect(newFrame, winBounds);
    return !self.view.isHidden && self.view.alpha > 0.01 && self.view.window == keyWindow && intersects;
}
//设置状态条是否隐藏
- (BOOL)prefersStatusBarHidden {
    NSNumber *statusBarStatus = [[NSUserDefaults standardUserDefaults] objectForKey:@"StatusBarStatus"];
    if (statusBarStatus.integerValue == 1) {
        return NO;
    }
    else {
        return YES;
    }
}
#pragma mark -------- 设置状态条
- (UIStatusBarStyle)preferredStatusBarStyle {
    NSString *statusBarTextColor = [[NSUserDefaults standardUserDefaults] objectForKey:@"StatusBarTextColor"];
    if ([statusBarTextColor isEqualToString:@"#000000"] || [statusBarTextColor isEqualToString:@"black"]) {
        return UIStatusBarStyleDefault;
    }
    else {
        return UIStatusBarStyleLightContent;
    }
}

- (BOOL)isHaveNativeHeader:(NSString *)url{
    if ([[XZPackageH5 sharedInstance].ulrArray containsObject:url]) {
        return YES;
    }
    return NO;
}
@end

