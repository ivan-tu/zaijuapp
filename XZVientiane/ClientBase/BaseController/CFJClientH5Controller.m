//
//  CFJClientH5Controller.m
//  XiangZhanClient
//
//  Created by cuifengju on 2017/10/13.
//  Copyright © 2017年 TuWeiA. All rights reserved.
//
#import "CFJClientH5Controller.h"
#import "WKWebView+XZAddition.h"
#import "HTMLWebViewController.h"
#import "../../ThirdParty/WKWebViewJavascriptBridge/WKWebViewJavascriptBridge.h"
#import <objc/runtime.h>
#import "UIColor+addition.h"
//model
#import "XZOrderModel.h"
#import "ClientSettingModel.h"
//view
#import "UIBarButtonItem+DCBarButtonItem.h"
#import "DCNavSearchBarView.h"
#import "PPBadgeView.h"
#import "CustomTabBar.h"
#import "YBPopupMenu.h"
#import "DHGuidePageHUD.h"
#import "ShowAlertView.h"
#import "UITabBar+badge.h"
//tool
#import "NSString+MD5.h"
#import "WXApi.h"
#import "HTMLCache.h"
#import "UIView+Layout.h"
#import "AppDelegate.h"
#import "SDWebImageManager.h"
#import "UIView+AutoLayout.h"
#import "BaseFileManager.h"
#import "SVStatusHUD.h"
#import <UMShare/UMShare.h>
#import "JHSysAlertUtil.h"
#import "XZPackageH5.h"
#import "MOFSPickerManager.h"
#import "XZIcomoonDefine.h"
#import "ClientNetInterface.h"
#import "ManageCenter.h"
#import <Masonry.h>
#import <QiniuSDK.h>
#import <Photos/Photos.h>
#import "UIImage+tool.h"
#import "JFLocation.h"
#import "LBPhotoBrowserManager.h"
#import "LBAlbumManager.h"
#import "CustomHybridProcessor.h"
#import "NSString+addition.h"
#import <UMCommon/MobClick.h>
#import <AlipaySDK/AlipaySDK.h>
#import <AMapFoundationKit/AMapFoundationKit.h>
#import <AMapLocationKit/AMapLocationKit.h>
//viewController
#import "XZNavigationController.h"
#import "TZImagePickerController.h"
#import "HTMLWebViewController.h"
#import "XZTabBarController.h"
#import "CFJScanViewController.h"
#import "AddressFromMapViewController.h"
#import "JFCityViewController.h"
#import <JavaScriptCore/JavaScriptCore.h>
#import "CustomHybridProcessor.h"
//JSBridge
// TODO: 需要在Xcode中添加以下文件到项目
// #import "JSActionHandlerManager.h"
// #import "XZiOSVersionManager.h"
// #import "XZAuthenticationManager.h"
#define JDomain  [NSString stringWithFormat:@"https://%@",[[NSUserDefaults standardUserDefaults] objectForKey:@"kUserDefaults_domainStr"]]
#define ScreenWidth [UIScreen mainScreen].bounds.size.width
#define TITLES @[@"登录", @"注册"]
#define ICONS  @[@"login",@"regist"]


@interface CFJClientH5Controller ()<TZImagePickerControllerDelegate,YBPopupMenuDelegate,JFLocationDelegate,JFCityViewControllerDelegate>
{
    NSMutableArray *_selectedPhotos;
    NSMutableArray *_selectedAssets;
    BOOL _isSelectOriginalPhoto;
    NSMutableArray *_selectedVideo;
    NSString *_videoPath;
    NSString *bgColor;
    NSString *color;
    AVPlayer *play;
    AVPlayerItem *playItem;
    
    CGFloat _itemWH;
    CGFloat _margin;
}

// 通知观察者数组，用于正确移除
@property (nonatomic, strong) NSMutableArray *notificationObservers;

@property (strong, nonatomic) NSString *orderNum; //订单号，银联支付拿订单号去后台验证是否支付成功
@property (assign, nonatomic) NSInteger lastPosition;
@property (strong, nonatomic) NSArray *viewImageAry;
@property (strong, nonatomic) NSLock *lock;
@property (assign, nonatomic) BOOL leftMessage;
@property (assign, nonatomic) BOOL rightMessage;
@property (assign, nonatomic) BOOL leftShop;
@property (assign, nonatomic) BOOL rightShop;
@property (copy, nonatomic) NSString *backStr;
@property (nonatomic, strong) QNUpCancellationSignal cancelSignal;
@property (nonatomic, assign) BOOL isCancel;
// 恢复定位管理器属性
@property (strong,nonatomic)AMapLocationManager *locationManager;
@property (nonatomic, strong) JFLocation *JFlocationManager;

// 添加回调方法声明
- (void)callBack:(NSString *)type params:(NSDictionary *)params;

@end

// 添加 GeDianUserInfo 类声明
@interface GeDianUserInfo : NSObject
@property (nonatomic, copy) NSString *nickname;
@property (nonatomic, copy) NSString *userId;
@property (nonatomic, copy) NSString *headpic;
@end

@implementation GeDianUserInfo
@end

@implementation CFJClientH5Controller

// 智能检测并处理登录状态变化
- (void)detectAndHandleLoginStateChange:(void(^)(NSDictionary*))completion {
    if (!self.webView || ![self.webView isKindOfClass:[WKWebView class]]) {
        return;
    }
    
    // 确保在主线程检查应用状态
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self detectAndHandleLoginStateChange:completion];
        });
        return;
    }
    
    // 检查应用状态，避免在后台执行JavaScript
    UIApplicationState state = [[UIApplication sharedApplication] applicationState];
    if (state != UIApplicationStateActive) {
        NSLog(@"在局[CFJClientH5] 应用不在前台，跳过登录状态检测");
        return;
    }
    
    // 检查页面是否正在显示
    if (![self isShowingOnKeyWindow]) {
        NSLog(@"在局[CFJClientH5] 页面不在显示，跳过登录状态检测");
        return;
    }
    
    WKWebView *wkWebView = (WKWebView *)self.webView;
    
    // 使用安全的JavaScript执行方法
    [self safelyEvaluateJavaScript:@"(function(){ try { return app.session.get('userSession') || ''; } catch(e) { return ''; } })()" 
                completionHandler:^(id jsUserSession, NSError *error) {
        
        if (error) {
            NSLog(@"在局[CFJClientH5] 检测登录状态失败: %@", error);
            return;
        }
        
        // 获取iOS端的登录状态
        BOOL iosLoginState = [[NSUserDefaults standardUserDefaults] boolForKey:@"isLogin"];
        BOOL jsHasSession = jsUserSession && [jsUserSession isKindOfClass:[NSString class]] && [(NSString*)jsUserSession length] > 0;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            // 再次检查应用状态
            UIApplicationState currentState = [[UIApplication sharedApplication] applicationState];
            if (currentState != UIApplicationStateActive) {
                return;
            }
            
            if (jsHasSession && !iosLoginState) {
                // JS有session但iOS端未登录 -> 执行登录逻辑
                [self syncLoginState];
            } else if (!jsHasSession && iosLoginState) {
                // JS无session但iOS端已登录 -> 执行退出登录逻辑  
                [self syncLogoutState];
            }
        });
    }];
}

// 同步登录状态
- (void)syncLoginState {
    // 设置iOS端登录状态
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"isLogin"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    // 清除HTML缓存，确保页面能正确刷新
    [[HTMLCache sharedCache] removeAllCache];
    
    // 执行登录成功后的处理
    dispatch_async(dispatch_get_main_queue(), ^{
        // 跳转到首页并选中第一个tab
        if (self.tabBarController && [self.tabBarController isKindOfClass:[UITabBarController class]]) {
            self.tabBarController.selectedIndex = 0;
            
            // 发送backToHome通知
            NSDictionary *setDic = @{@"selectNumber": @"0"};
            [[NSNotificationCenter defaultCenter] postNotificationName:@"backToHome" object:setDic];
        }
    });
}

// 同步退出登录状态
- (void)syncLogoutState {
    // 设置iOS端退出登录状态
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"isLogin"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    // 清除HTML缓存和Cookie，确保页面能正确刷新
    [[HTMLCache sharedCache] removeAllCache];
    [WKWebView cookieDeleteAllCookie];
    
    // 重置所有tab页面到初始状态，清除内页导航历史
    [self resetAllTabsToInitialState];
    
    //隐藏底部角标
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.tabBarController.tabBar hideBadgeOnItemIndex:3];
    });
    [[NSUserDefaults standardUserDefaults] setInteger:0 forKey:@"clinetMessageNum"];
    [[NSUserDefaults standardUserDefaults] setInteger:0 forKey:@"shoppingCartNum"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    // 执行退出登录后的处理
    dispatch_async(dispatch_get_main_queue(), ^{
        // 跳转到首页并选中第一个tab
        if (self.tabBarController && [self.tabBarController isKindOfClass:[UITabBarController class]]) {
            self.tabBarController.selectedIndex = 0;
            
            // 发送backToHome通知
            NSDictionary *setDic = @{@"selectNumber": @"0"};
            [[NSNotificationCenter defaultCenter] postNotificationName:@"backToHome" object:setDic];
        }
    });
}

// 重置所有tab页面到初始状态，清除内页导航历史
- (void)resetAllTabsToInitialState {
    if (!self.tabBarController) {
        return;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        NSArray *viewControllers = self.tabBarController.viewControllers;
        
        for (NSInteger i = 0; i < viewControllers.count; i++) {
            UIViewController *viewController = viewControllers[i];
            
            // 如果是导航控制器，pop到根视图控制器
            if ([viewController isKindOfClass:[UINavigationController class]]) {
                UINavigationController *navController = (UINavigationController *)viewController;
                if (navController.viewControllers.count > 1) {
                    [navController popToRootViewControllerAnimated:NO];
                }
            }
            // 如果是WebView控制器，重置其状态
            else if ([viewController isKindOfClass:[CFJClientH5Controller class]] || 
                     [viewController respondsToSelector:@selector(webView)]) {
                [self resetWebViewControllerState:viewController];
            }
        }
    });
}

// 重置WebView控制器状态
- (void)resetWebViewControllerState:(UIViewController *)controller {
    if (![controller respondsToSelector:@selector(webView)]) {
        return;
    }
    
    WKWebView *webView = [controller performSelector:@selector(webView)];
    if (!webView || ![webView isKindOfClass:[WKWebView class]]) {
        return;
    }
    
    // 停止当前加载
    [webView stopLoading];
    
    // 清理JavaScript状态和存储
    [webView evaluateJavaScript:@"try { localStorage.clear(); sessionStorage.clear(); if(window.app && window.app.storage) { window.app.storage.clear(); } } catch(e) {}" completionHandler:nil];
    
    // 重新加载页面
    if ([controller respondsToSelector:@selector(domainOperate)]) {
        [controller performSelector:@selector(domainOperate)];
    }
}

- (NSLock *)lock {
    if (_lock == nil) {
        _lock = [[NSLock alloc]init];
    }
    return _lock;
}

- (void)dealloc {
    // 移除所有通知观察者
    if (self.notificationObservers) {
        for (id observer in self.notificationObservers) {
            [[NSNotificationCenter defaultCenter] removeObserver:observer];
        }
        [self.notificationObservers removeAllObjects];
    }
    
    // 移除传统方式添加的观察者
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)addNotif {
    WEAK_SELF;
    
    // 初始化观察者数组
    if (!self.notificationObservers) {
        self.notificationObservers = [NSMutableArray array];
    }
    
    // 支付结果通知
    id observer1 = [[NSNotificationCenter defaultCenter] addObserverForName:@"payresultnotif" object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
        STRONG_SELF;
        [self handlePayResult:note.object];
    }];
    [self.notificationObservers addObject:observer1];
    
    // 微信支付通知
    id observer2 = [[NSNotificationCenter defaultCenter] addObserverForName:@"weixinPay" object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
        STRONG_SELF;
        [self handleweixinPayResult:note.object];
    }];
    [self.notificationObservers addObject:observer2];
    
    // 监听微信分享结果
    id observer3 = [[NSNotificationCenter defaultCenter] addObserverForName:@"wechatShareResult" object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
        STRONG_SELF;
        [self handleWechatShareResult:note.object];
    }];
    [self.notificationObservers addObject:observer3];
    
    // 监听网络状态变化
    id observer4 = [[NSNotificationCenter defaultCenter] addObserverForName:AFNetworkingReachabilityDidChangeNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
        STRONG_SELF;
        if (!self) return;
        
        AFNetworkReachabilityStatus status = [[[note userInfo] objectForKey:AFNetworkingReachabilityNotificationStatusItem] integerValue];
        NSLog(@"在局🔄 [CFJClientH5Controller] 网络状态变化: %ld", (long)status);
        
        // 如果网络从不可用变为可用
        if (status != AFNetworkReachabilityStatusNotReachable) {
            NSLog(@"在局🔄 [CFJClientH5Controller] 网络恢复，通知JavaScript重试");
            // 通知JavaScript网络已恢复，让它重试失败的请求
            // 步骤1: 设置网络恢复标志
            [self safelyEvaluateJavaScript:@"window.networkRestored = true; 'flag_set'" completionHandler:^(id result, NSError *error) {
                NSLog(@"在局🔧 [网络恢复-步骤1] 设置标志: %@", result ?: error.localizedDescription);
            }];
            
            // 步骤2: 尝试使用实际存在的方法触发页面重新加载
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self safelyEvaluateJavaScript:@"(function(){"
                    "if (typeof app !== 'undefined' && typeof app.reloadOtherPages === 'function') {"
                        "app.reloadOtherPages(); return 'reloadOtherPages_called';"
                    "} else if (typeof app !== 'undefined' && typeof app.getCurrentPages === 'function') {"
                        "app.getCurrentPages(); return 'getCurrentPages_called';"
                    "} else {"
                        "return 'no_suitable_method_found';"
                    "}"
                "})()" completionHandler:^(id result, NSError *error) {
                    NSLog(@"在局🔧 [网络恢复-步骤2] 方法调用: %@", result ?: error.localizedDescription);
                }];
            });
            
            // 步骤3: 触发页面事件
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self safelyEvaluateJavaScript:@"document.dispatchEvent(new Event('visibilitychange')); 'event_dispatched'" completionHandler:^(id result, NSError *error) {
                    NSLog(@"在局🔧 [网络恢复-步骤3] 事件触发: %@", result ?: error.localizedDescription);
                }];
            });
            
            // 额外延迟1秒后再次尝试触发数据加载，以防第一次调用时页面还未完全准备好
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                // 步骤1: 尝试重新加载页面数据
                [self safelyEvaluateJavaScript:@"(function(){if(typeof app!=='undefined'&&typeof app.reloadOtherPages==='function'){app.reloadOtherPages();return 'reload_called';}return 'reload_not_available';})()" completionHandler:^(id result, NSError *error) {
                    NSLog(@"在局🔧 [延迟加载-步骤1] 重新加载: %@", result ?: error.localizedDescription);
                }];
                
                // 步骤2: 触发页面事件
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [self safelyEvaluateJavaScript:@"document.dispatchEvent(new Event('visibilitychange')); window.dispatchEvent(new Event('focus')); 'events_fired'" completionHandler:^(id result, NSError *error) {
                        NSLog(@"在局🔧 [延迟加载-步骤2] 事件触发: %@", result ?: error.localizedDescription);
                    }];
                });
                
                // 步骤3: 模拟用户滚动交互
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [self safelyEvaluateJavaScript:@"window.scrollTo(0, 1); window.scrollTo(0, 0); 'scroll_triggered'" completionHandler:^(id result, NSError *error) {
                        NSLog(@"在局🔧 [延迟加载-步骤3] 滚动触发: %@", result ?: error.localizedDescription);
                    }];
                });
            });
        }
    }];
    [self.notificationObservers addObject:observer4];
    
    id observer5 = [[NSNotificationCenter defaultCenter] addObserverForName:@"HideTabBarNotif" object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
        STRONG_SELF;
        [UIView animateWithDuration:0.5 animations:^{
            UIView *qrView = [self.view viewWithTag:1001];
            qrView.frame = CGRectMake(15, [UIScreen mainScreen].bounds.size.height, 40, 40);
        }];
    }];
    [self.notificationObservers addObject:observer5];
    
    id observer6 = [[NSNotificationCenter defaultCenter] addObserverForName:@"ShowTabBarNotif" object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
        STRONG_SELF;
        [UIView animateWithDuration:0.5 animations:^{
            UIView *qrView = [self.view viewWithTag:1001];
            qrView.frame = CGRectMake(15, [UIScreen mainScreen].bounds.size.height - 100, 40, 40);
        }];
    }];
    [self.notificationObservers addObject:observer6];
    
    //变更消息数量
    id observer7 = [[NSNotificationCenter defaultCenter] addObserverForName:@"changeMessageNum" object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
        STRONG_SELF;
        UIViewController *VC = [self currentViewController];
        if ([VC isEqual:self]) {
            NSInteger num = [[NSUserDefaults standardUserDefaults] integerForKey:@"clinetMessageNum"];
            if (num) {
                //设置底部角标
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.tabBarController.tabBar showBadgeOnItemIndex:3 withNum:num];
                });
            }
            else {
                //隐藏底部角标
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.tabBarController.tabBar hideBadgeOnItemIndex:3];
                });
            }
        }
    }];
    [self.notificationObservers addObject:observer7];
    
    //刷新页面触发请求
    id observer8 = [[NSNotificationCenter defaultCenter] addObserverForName:@"reloadMessage" object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
        STRONG_SELF;
        UIViewController *VC = [self currentViewController];
        if ([VC isEqual:self]) {
            if (NoReachable) {
                return;
            }
        }
    }];
    [self.notificationObservers addObject:observer8];
    
    //返回到首页
    id observer9 = [[NSNotificationCenter defaultCenter] addObserverForName:@"backToHome" object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
        STRONG_SELF;
        UIViewController *VC = [self currentViewController];
        if ([VC isEqual:self]) {
            if (self.presentingViewController) {
                [self dismissViewControllerAnimated:NO completion:^{
                    if ([VC isEqual:self]) {
                        NSDictionary *dic = note.object;
                        NSInteger number = [[dic objectForKey:@"selectNumber"] integerValue];
                        AppDelegate *delegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
                        XZTabBarController *tab = (XZTabBarController *)delegate.window.rootViewController;
                        tab.selectedIndex = number;
                    }
                }];
            } else {
                if ([VC isEqual:self]) {
                    NSDictionary *dic = note.object;
                    NSInteger number = [[dic objectForKey:@"selectNumber"] integerValue];
                    AppDelegate *delegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
                    XZTabBarController *tab = (XZTabBarController *)delegate.window.rootViewController;
                    tab.selectedIndex = number;
                }
            }
        }
    }];
    [self.notificationObservers addObject:observer9];
}

- (void)loadView {
    self.webView.backgroundColor = [UIColor whiteColor];
    //     self.webView.opaque = NO;
    //    self.webView.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"Moon.png"]];
    [super loadView];
}


#pragma mark 调用js弹出属性窗口

// 配置导航栏颜色
- (void)configureNavigationBarColors {
    // 确保导航栏不透明
    self.navigationController.navigationBar.translucent = NO;
    
    // 配置导航栏颜色
    if (bgColor && bgColor.length > 0) {
        UIColor *navBarColor = [UIColor colorWithHexString:bgColor];
        self.navigationController.navigationBar.barTintColor = navBarColor;
        
        // 配置文字和按钮颜色
        UIColor *tintColor = nil;
        if (color && color.length > 0) {
            tintColor = [UIColor colorWithHexString:color];
        } else {
            // 根据背景色自动选择合适的前景色
            tintColor = [self shouldUseLightContentForColor:navBarColor] ? [UIColor whiteColor] : [UIColor blackColor];
        }
        
        self.navigationController.navigationBar.tintColor = tintColor;
        self.navigationController.navigationBar.titleTextAttributes = @{
            NSForegroundColorAttributeName: tintColor
        };
    } else {
        // 默认样式：淡灰色背景+黑色文字
        UIColor *defaultBarColor = [UIColor colorWithRed:0.97 green:0.97 blue:0.97 alpha:1.0];
        self.navigationController.navigationBar.barTintColor = defaultBarColor;
        self.navigationController.navigationBar.tintColor = [UIColor blackColor];
        self.navigationController.navigationBar.titleTextAttributes = @{
            NSForegroundColorAttributeName: [UIColor blackColor]
        };
    }
}


// 判断背景颜色是否应该使用浅色内容
- (BOOL)shouldUseLightContentForColor:(UIColor *)color {
    if (!color) return NO;
    
    CGFloat red, green, blue, alpha;
    if ([color getRed:&red green:&green blue:&blue alpha:&alpha]) {
        // 计算亮度 (使用标准的亮度公式)
        CGFloat brightness = (red * 0.299 + green * 0.587 + blue * 0.114);
        return brightness < 0.5; // 如果背景较暗，使用浅色内容
    }
    return NO;
}

// 隐藏导航栏底部黑线的辅助方法
- (void)hideNavigationBarBottomLine {
    // 隐藏导航条黑线 - 兼容不同iOS版本
    if (@available(iOS 13.0, *)) {
        UINavigationBarAppearance *appearance = self.navigationController.navigationBar.standardAppearance;
        if (appearance) {
            appearance.shadowColor = [UIColor clearColor];
            self.navigationController.navigationBar.standardAppearance = appearance;
            self.navigationController.navigationBar.scrollEdgeAppearance = appearance;
        }
    } else {
        // iOS 13以下版本的处理方式
        if (self.navigationController && self.navigationController.navigationBar && 
            self.navigationController.navigationBar.subviews.count > 0 && 
            [self.navigationController.navigationBar.subviews[0] subviews].count > 0) {
            self.navigationController.navigationBar.subviews[0].subviews[0].hidden = YES;
        }
    }
}

// 配置WebView圆角的辅助方法
- (void)configureWebViewCornerRadius {
    if (self.webView && !(self.pushType == isPushNormal)) {
        // 设置WebView圆角
        self.webView.layer.cornerRadius = 15.0f;
        self.webView.layer.masksToBounds = YES;
    }
}

// 更新导航栏Badge的辅助方法
- (void)updateNavigationBarBadges {
    // 更新消息Badge
    if (self.leftMessage || self.rightMessage) {
        NSInteger messageNum = [[NSUserDefaults standardUserDefaults] integerForKey:@"clinetMessageNum"];
        if (self.leftMessage && self.navigationItem.leftBarButtonItem) {
            [self.navigationItem.leftBarButtonItem pp_addBadgeWithNumber:messageNum];
        }
        if (self.rightMessage && self.navigationItem.rightBarButtonItem) {
            [self.navigationItem.rightBarButtonItem pp_addBadgeWithNumber:messageNum];
        }
    }
    
    // 更新购物车Badge
    if (self.leftShop || self.rightShop) {
        NSInteger shopNum = [[NSUserDefaults standardUserDefaults] integerForKey:@"shoppingCartNum"];
        if (self.leftShop && self.navigationItem.leftBarButtonItem) {
            [self.navigationItem.leftBarButtonItem pp_addBadgeWithNumber:shopNum];
        }
        if (self.rightShop && self.navigationItem.rightBarButtonItem) {
            [self.navigationItem.rightBarButtonItem pp_addBadgeWithNumber:shopNum];
        }
    }
}

// 交互式转场后恢复WebView状态
- (void)restoreWebViewStateAfterInteractiveTransition {
    NSLog(@"在局🔄 [CFJClientH5Controller] 恢复交互式转场后的WebView状态");
    
    // 检查是否是Tab切换导致的调用
    BOOL isTabSwitch = NO;
    if (self.tabBarController) {
        UIViewController *selectedVC = self.tabBarController.selectedViewController;
        if (selectedVC == self.navigationController && 
            self.navigationController.viewControllers.count == 1 &&
            self.navigationController.topViewController == self) {
            isTabSwitch = YES;
        }
    }
    
    if (isTabSwitch) {
        NSLog(@"在局ℹ️ [CFJClientH5Controller] 检测到Tab切换，跳过交互式转场恢复");
        return;
    }
    
    NSLog(@"在局🔧 [CFJClientH5Controller] 修复前 - 准备调用父类方法重置_isDisappearing");
    
    // 🔧 关键修复：重置_isDisappearing标志，允许JavaScript执行
    // 通过父类的方法来重置这个私有变量
    [super restoreWebViewStateAfterInteractiveTransition];
    
    NSLog(@"在局✅ [CFJClientH5Controller] 修复后 - 父类方法已调用，_isDisappearing应该已重置");
    
    if (!self.webView) {
        return;
    }
    
    // 确保WebView可见并可交互
    self.webView.hidden = NO;
    self.webView.alpha = 1.0;
    self.webView.userInteractionEnabled = YES;
    
    // 触发JavaScript事件，通知页面重新显示
    [self safelyEvaluateJavaScript:@"(function(){\
        if (typeof window.onPageRestore === 'function') {\
            window.onPageRestore();\
        }\
        var event = new CustomEvent('pageRestore');\
        window.dispatchEvent(event);\
        return '页面状态已恢复';\
    })()" completionHandler:^(id result, NSError *error) {
        if (result) {
            NSLog(@"在局✅ [CFJClientH5Controller] 页面状态恢复通知: %@", result);
        }
    }];
}

// 优化WebView加载逻辑的辅助方法
- (void)optimizeWebViewLoading {
    NSLog(@"在局🚀 [WebView优化] 开始优化WebView加载");
    
    // 如果WebView还没有创建，立即创建
    if (!self.webView && self.pinUrl && self.pinUrl.length > 0) {
        NSLog(@"在局🚀 [WebView优化] WebView未创建，立即执行domainOperate");
        [self domainOperate];
        return;
    }
    
    // 如果WebView已经存在，检查是否需要重新加载
    if (self.webView) {
        // 检查WebView的当前状态
        NSString *currentURL = self.webView.URL ? self.webView.URL.absoluteString : @"";
        
        // 如果WebView是空的或者只加载了baseURL，需要重新加载
        if ([currentURL isEqualToString:@"about:blank"] || 
            [currentURL containsString:@"manifest/"] || 
            currentURL.length == 0) {
            NSLog(@"在局🚀 [WebView优化] 检测到WebView状态异常: %@，重新加载", currentURL);
            [self domainOperate];
        } else {
            NSLog(@"在局✅ [WebView优化] WebView状态正常: %@", currentURL);
        }
    }
}

- (void)viewDidAppear:(BOOL)animated {
    
    [super viewDidAppear:animated];
    
    // 使用优化的WebView加载逻辑
    if (!self.isWebViewLoading && !self.isLoading) {
        [self optimizeWebViewLoading];
    }
    
    if (self.isCheck) {
        self.isCheck = NO;
        //        dispatch_async(dispatch_get_global_queue(0, 0), ^{
        //            //版本更新提示
        //        });
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            //版本更新提示
            [[XZPackageH5 sharedInstance] checkVersion];

        });
    }
    if (self.removePage.length) {
        NSMutableArray *marr = [[NSMutableArray alloc]initWithArray:self.navigationController.viewControllers];
        for (CFJClientH5Controller *vc in marr) {
            if ([vc.webViewDomain containsString:self.removePage]) {
                [marr removeObject:vc];
                break;
            }
        }
        self.navigationController.viewControllers = marr;
    }
    //友盟页面统计
    NSString* cName = [NSString stringWithFormat:@"%@",self.navigationItem.title, nil];
    [MobClick beginLogPageView:cName];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    
    self.isCancel = YES;
    if (self.cancelSignal) {
        self.cancelSignal();
    }
    
    // 检查是否正在被pop（包括手势返回）
    NSArray *viewControllers = self.navigationController.viewControllers;//获取当前的视图控制其
    if ([viewControllers indexOfObject:self] == NSNotFound) {
        NSLog(@"在局 🔄 [CFJClientH5Controller] 检测到页面正在被移除（可能是手势返回）");
        
        // 检查是否正在进行交互式转场
        BOOL isInteractiveTransition = NO;
        if ([self.navigationController isKindOfClass:NSClassFromString(@"XZNavigationController")]) {
            // 使用KVC安全地检查交互式转场状态
            @try {
                NSNumber *isInteractiveValue = [self.navigationController valueForKey:@"isInteractiveTransition"];
                isInteractiveTransition = [isInteractiveValue boolValue];
            } @catch (NSException *exception) {
                NSLog(@"在局⚠️ [CFJClientH5Controller] 无法检查交互式转场状态: %@", exception.reason);
            }
        }
        
        NSLog(@"在局🔍 [CFJClientH5Controller] 交互式转场状态: %@", isInteractiveTransition ? @"YES" : @"NO");
        
        //页面卸载
        NSDictionary *callJsDic = [CustomHybridProcessor custom_objcCallJsWithFn:@"pageUnload" data:nil];
        [self objcCallJs:callJsDic];
        
        // 只有在非交互式转场时才立即清理WebView资源
        if (!isInteractiveTransition && self.navigationController.viewControllers.count > 0 && self.pinUrl && self.pinUrl.length > 0) {
            NSLog(@"在局 🧹 [CFJClientH5Controller] 清理内页WebView资源（非交互式转场）");
            // 停止加载
            if (self.webView) {
                [self.webView stopLoading];
                self.webView.navigationDelegate = nil;
            }
        } else if (isInteractiveTransition) {
            NSLog(@"在局⏳ [CFJClientH5Controller] 交互式转场中，延迟清理WebView资源");
            // 交互式转场中，延迟清理以免干扰动画
            // 优化：减少延迟时间，从0.8秒改为0.5秒
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                // 转场完成后再检查是否需要清理
                NSArray *currentViewControllers = self.navigationController.viewControllers;
                NSUInteger selfIndex = [currentViewControllers indexOfObject:self];
                
                if (selfIndex == NSNotFound) {
                    NSLog(@"在局 🧹 [CFJClientH5Controller] 延迟清理内页WebView资源");
                    if (self.webView) {
                        [self.webView stopLoading];
                        self.webView.navigationDelegate = nil;
                    }
                    
                    // 🔧 新增功能：手势返回时的tab栏显示控制
                    [self handleTabBarVisibilityAfterPopGesture];
                } else {
                    NSLog(@"在局✅ [CFJClientH5Controller] 交互式转场被取消，保留WebView资源");
                    // 转场被取消，确保WebView状态正常
                    if (self.webView) {
                        self.webView.hidden = NO;
                        self.webView.alpha = 1.0;
                        self.webView.userInteractionEnabled = YES;
                        
                        // 触发WebView状态恢复
                        [self restoreWebViewStateAfterInteractiveTransition];
                    }
                }
            });
        }
    }
    else {
        //页面隐藏
        NSDictionary *callJsDic = [CustomHybridProcessor custom_objcCallJsWithFn:@"pageHide" data:nil];
        [self objcCallJs:callJsDic];
    }
    //友盟页面统计
    NSString* cName = [NSString stringWithFormat:@"%@",self.navigationItem.title, nil];
    [MobClick endLogPageView:cName];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    NSLog(@"在局 🌑 [CFJClientH5Controller] viewDidDisappear - tabIndex: %ld, url: %@", 
          (long)self.tabBarController.selectedIndex, self.pinUrl);
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    if (self.isCheck) {
        self.JFlocationManager = [[JFLocation alloc] init];
        _JFlocationManager.delegate = self;
    }
    
    // 设置导航栏配置
    [self setNavMessage];
    [self addNotif];
    self.view.backgroundColor = [UIColor tyBgViewColor];
    
    switch (self.pushType) {
        case isPushPresent:
        {
            self.view.backgroundColor = [UIColor clearColor];
            [self.webView mas_remakeConstraints:^(MASConstraintMaker *make) {
                make.left.equalTo(self.view);
                make.right.equalTo(self.view);
                make.bottom.equalTo(self.view);
                make.top.equalTo(self.view).offset(200);
            }];
        }
            break;
        case isPushAlert:
        {
            self.view.backgroundColor = [UIColor clearColor];
            [self.webView setBackgroundColor:[UIColor clearColor]];
            [self.webView  setOpaque:NO];
            [self.webView mas_remakeConstraints:^(MASConstraintMaker *make) {
                make.left.equalTo(self.view);
                make.right.equalTo(self.view);
                make.bottom.equalTo(self.view);
                make.top.equalTo(self.view).offset(0);
            }];
        }
            break;
            
        default:
            break;
    }
}

- (void)setNavMessage {
    [self setUpNavWithDic:self.navDic];
    
    // 配置导航栏显示/隐藏
    BOOL shouldHide = [self isHaveNativeHeader:self.pinUrl];
    [self.navigationController setNavigationBarHidden:shouldHide animated:NO];
    
    // 更新状态栏样式
    [self setNeedsStatusBarAppearanceUpdate];
}

#pragma mark - 导航条处理

- (void)setUpNavWithDic:(NSDictionary *)dic {
    // 先清空之前的颜色设置，避免复用问题
    color = nil;
    bgColor = nil;
    
    if (self.navigationController.childViewControllers.count >= 1) {
        UIBarButtonItem *backButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"" style:UIBarButtonItemStylePlain target:nil action:nil];
        [self.navigationItem setBackBarButtonItem:backButtonItem];
    }
    
    NSDictionary *Dic = [dic objectForKey:@"nav"];
    color = [dic objectForKey:@"textColor"];
    bgColor = [dic objectForKey:@"navBgcolor"];
    NSDictionary *leftDic = [Dic objectForKey:@"leftItem"];
    NSDictionary *rightDic = [Dic objectForKey:@"rightItem"];
    NSDictionary *middleDic = [Dic objectForKey:@"middleItem"];
    
    // 立即配置导航栏样式
    [self configureNavigationBarColors];
    
    // 隐藏导航条黑线
    [self hideNavigationBarBottomLine];
    
    if (leftDic) {
        if (![[leftDic objectForKey:@"buttonPicture"] length] && ![[leftDic objectForKey:@"text"] length]){
            UIBarButtonItem *backButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"" style:UIBarButtonItemStylePlain target:nil action:nil];
            [self.navigationItem setBackBarButtonItem:backButtonItem];
        } else {
            if (self.navigationController.childViewControllers.count < 2) {
                self.navigationItem.leftBarButtonItem = [UIBarButtonItem leftItemWithDic:leftDic Color:color Target:self action:@selector(leftItemClickWithDic:)];
            }
            if ([[leftDic objectForKey:@"type"] isEqualToString:@"msg"]) {
                self.leftMessage = YES;
                if (self.leftMessage) {
                    NSInteger num = [[NSUserDefaults standardUserDefaults] integerForKey:@"clinetMessageNum"];
                    [self.navigationItem.leftBarButtonItem pp_addBadgeWithNumber:num];
                    // 调整badge大小
                    //    [self.navigationItem.leftBarButtonItem pp_setBadgeHeightPoints:25];
                    // 调整badge的位置
                    [self.navigationItem.leftBarButtonItem pp_moveBadgeWithX:0 Y:4];
                    // 自定义badge的属性: 字体大小/颜色, 背景颜色...(默认系统字体13,白色,背景色为系统badge红色)
                    [self.navigationItem.leftBarButtonItem pp_setBadgeLabelAttributes:^(PPBadgeLabel *badgeLabel) {
                        badgeLabel.backgroundColor = [UIColor redColor];
                        //        badgeLabel.font =  [UIFont systemFontOfSize:13];
                        //        badgeLabel.textColor = [UIColor blueColor];
                    }];
                }
            }
            if ([[leftDic objectForKey:@"type"] isEqualToString:@"shopCart"]) {
                self.leftShop = YES;
                if (self.leftShop) {
                    NSInteger num = [[NSUserDefaults standardUserDefaults] integerForKey:@"shoppingCartNum"];
                    [self.navigationItem.leftBarButtonItem pp_addBadgeWithNumber:num];
                    // 调整badge大小
                    //    [self.navigationItem.leftBarButtonItem pp_setBadgeHeightPoints:25];
                    // 调整badge的位置
                    [self.navigationItem.leftBarButtonItem pp_moveBadgeWithX:0 Y:4];
                    // 自定义badge的属性: 字体大小/颜色, 背景颜色...(默认系统字体13,白色,背景色为系统badge红色)
                    [self.navigationItem.leftBarButtonItem pp_setBadgeLabelAttributes:^(PPBadgeLabel *badgeLabel) {
                        badgeLabel.backgroundColor = [UIColor redColor];
                        //        badgeLabel.font =  [UIFont systemFontOfSize:13];
                        //        badgeLabel.textColor = [UIColor blueColor];
                    }];
                }
            }
            
            
        }
    } else {
        UIBarButtonItem *backButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"" style:UIBarButtonItemStylePlain target:nil action:nil];
        [self.navigationItem setBackBarButtonItem:backButtonItem];
    }
    if (rightDic) {
        self.navigationItem.rightBarButtonItem = [UIBarButtonItem rightItemWithDic:rightDic Color:color Target:self action:@selector(rightItemClickWithDic)];
        if ([[rightDic objectForKey:@"type"] isEqualToString:@"msg"]) {
            self.rightMessage = YES;
            if (self.rightMessage) {
                NSInteger num = [[NSUserDefaults standardUserDefaults] integerForKey:@"clinetMessageNum"];
                [self.navigationItem.rightBarButtonItem pp_addBadgeWithNumber:num];
                // 调整badge大小
                //    [self.navigationItem.leftBarButtonItem pp_setBadgeHeightPoints:25];
                // 调整badge的位置
                [self.navigationItem.rightBarButtonItem pp_moveBadgeWithX: 0 Y:8];
                // 自定义badge的属性: 字体大小/颜色, 背景颜色...(默认系统字体13,白色,背景色为系统badge红色)
                [self.navigationItem.rightBarButtonItem pp_setBadgeLabelAttributes:^(PPBadgeLabel *badgeLabel) {
                    badgeLabel.backgroundColor = [UIColor redColor];
                    //        badgeLabel.font =  [UIFont systemFontOfSize:13];
                    //        badgeLabel.textColor = [UIColor blueColor];
                }];
            }
        }
        if ([[rightDic objectForKey:@"type"] isEqualToString:@"shopCart"]) {
            self.rightShop = YES;
            if (self.rightShop) {
                NSInteger num = [[NSUserDefaults standardUserDefaults] integerForKey:@"shoppingCartNum"];
                [self.navigationItem.rightBarButtonItem pp_addBadgeWithNumber:num];
                // 调整badge大小
                //    [self.navigationItem.leftBarButtonItem pp_setBadgeHeightPoints:25];
                // 调整badge的位置
                [self.navigationItem.rightBarButtonItem pp_moveBadgeWithX: 0 Y:8];
                // 自定义badge的属性: 字体大小/颜色, 背景颜色...(默认系统字体13,白色,背景色为系统badge红色)
                [self.navigationItem.rightBarButtonItem pp_setBadgeLabelAttributes:^(PPBadgeLabel *badgeLabel) {
                    badgeLabel.backgroundColor = [UIColor redColor];
                    //        badgeLabel.font =  [UIFont systemFontOfSize:13];
                    //        badgeLabel.textColor = [UIColor blueColor];
                }];
            }
        }
        
    }
    if (middleDic) {
        if ([[middleDic objectForKey:@"type"] isEqualToString:@"title"]) {
            self.navigationItem.title = [dic objectForKey:@"title"];
        } else {
            DCNavSearchBarView *searchBarVc = [[DCNavSearchBarView alloc] init];
            searchBarVc.placeholdLabel.text = [middleDic objectForKey:@"title"];
            searchBarVc.frame = CGRectMake(60, 25, ScreenWidth - 120, 30);
            searchBarVc.voiceButtonClickBlock = ^{
                NSLog(@"在局搜索点击回调");
            };
            searchBarVc.searchViewBlock = ^{
                NSDictionary *settingDic = [NSKeyedUnarchiver unarchiveObjectWithFile:KNavSettingPath];
                NSString *urlstr = [middleDic objectForKey:@"url"];
                if (urlstr.length) {
                    urlstr = [urlstr containsString:@"http"] ? [middleDic objectForKey:@"url"]  : [NSString stringWithFormat:@"%@%@",JDomain,[middleDic objectForKey:@"url"]];
                }
                NSString *urlWithoutHttp = [[urlstr componentsSeparatedByString:@"://"] safeObjectAtIndex:1];
                NSArray *httpArray = [urlWithoutHttp componentsSeparatedByString:@"/"];
                NSString *adressPath = [httpArray safeObjectAtIndex:1];
                NSDictionary *setting = [NSDictionary dictionary];
                if ([adressPath isEqualToString:@"t"]) {
                    if ([httpArray safeObjectAtIndex:2] &&  [[httpArray safeObjectAtIndex:2] isEqualToString:@"index"]) {
                        setting = [settingDic objectForKey:@"index"];
                    } else {
                        NSString *pjStr = [NSString stringWithFormat:@"/t/%@",[httpArray safeObjectAtIndex:2]];
                        setting = [settingDic objectForKey:pjStr];
                    }
                } else {//需要判断是否拼接有参数
                    if ([adressPath containsString:@".html"]) {
                        NSRange range = [adressPath rangeOfString:@".html"];
                        adressPath = [adressPath substringToIndex:range.location];
                        if ([adressPath containsString:@"?"]) {
                            adressPath = [[adressPath componentsSeparatedByString:@"?"] objectAtIndex:0];
                        }
                        setting = [settingDic objectForKey:adressPath] ;
                    } else {
                        if ([adressPath containsString:@"?"]) {
                            adressPath = [[adressPath componentsSeparatedByString:@"?"] objectAtIndex:0];
                        }
                        setting = [settingDic objectForKey:adressPath] ;
                    }
                }
                if ([[setting objectForKey:@"showTop"] boolValue]) {
                    CFJClientH5Controller *appH5VC = [[CFJClientH5Controller alloc] initWithNibName:nil bundle:nil];
                    appH5VC.webViewDomain = urlstr;
                    appH5VC.navDic = setting;
                    appH5VC.hidesBottomBarWhenPushed = YES;
                    [self.navigationController pushViewController:appH5VC animated:YES];
                } else {
                    NSLog(@"在局暂不处理");
                }
            };
            self.navigationItem.titleView = searchBarVc;
        }
    }
}
//左侧按钮执行方法
- (void)leftItemClickWithDic:(UIButton *)sender{
    NSDictionary *Dic = [self.navDic objectForKey:@"nav"];
    NSDictionary *leftDic = [Dic objectForKey:@"leftItem"];
    NSDictionary *settingDic = [NSKeyedUnarchiver unarchiveObjectWithFile:KNavSettingPath];
    NSString *urlstr = [leftDic objectForKey:@"url"];
    if (urlstr.length) {
        urlstr = [urlstr containsString:@"https"] ? [leftDic objectForKey:@"url"]  : [NSString stringWithFormat:@"%@%@",JDomain,[leftDic objectForKey:@"url"]];
    } else if ([[leftDic objectForKey:@"type"] isEqualToString:@"msg"]) {
        urlstr = [NSString stringWithFormat:@"%@%@",JDomain,@"/p-noticemsg_category.html"];
    } else if ([[leftDic objectForKey:@"type"] isEqualToString:@"shopCart"]) {
        urlstr = [NSString stringWithFormat:@"%@%@",JDomain,@"/p-shop_cart.html"];
    } else if ([[leftDic objectForKey:@"type"] isEqualToString:@"share"]) {
        //执行js方法
        NSDictionary *dic = @{@"sharePic":[leftDic objectForKey:@"sharePic"] ?: @"",@"shareText":[leftDic objectForKey:@"shareText"] ?: @""};
        NSDictionary *callJsDic = [CustomHybridProcessor custom_objcCallJsWithFn:@"headShare" data:dic];
        [self objcCallJs:callJsDic];
        return;
    } else if ([[leftDic objectForKey:@"type"] isEqualToString:@"jsApi"]) {
        //执行js方法
        NSDictionary *callJsDic = [CustomHybridProcessor custom_objcCallJsWithFn:[leftDic objectForKey:@"jsApi"] data:nil];
        [self objcCallJs:callJsDic];
        return;
    } else if ([[leftDic objectForKey:@"type"] isEqualToString:@"backToHome"]) {
        [self.navigationController popToRootViewControllerAnimated:YES];
        NSString *number = [leftDic objectForKey:@"selectNumber"];
        NSDictionary *setDic = @{
            @"selectNumber": number
        };
        dispatch_time_t when = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC));
        dispatch_after(when, dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:@"backToHome" object:setDic];
        });
        return;
    } else if ([[leftDic objectForKey:@"type"] isEqualToString:@"popAlert"]) {
        [YBPopupMenu showRelyOnView:sender titles:TITLES icons:ICONS menuWidth:120 delegate:self];
        return;
    }
    //判断页面是否隐藏头部
    NSString *adressPath = [[urlstr componentsSeparatedByString:[NSString stringWithFormat:@"://%@",MainDomain]] safeObjectAtIndex:1];
    NSDictionary *setting = [NSDictionary dictionary];
    if ([adressPath containsString:@".html"]) {
        NSRange range = [adressPath rangeOfString:@".html"];
        adressPath = [adressPath substringToIndex:range.location];
        if ([adressPath containsString:@"?"]) {
            adressPath = [[adressPath componentsSeparatedByString:@"?"] objectAtIndex:0];
        }
        setting = [settingDic objectForKey:adressPath] ;
    } else {
        if ([adressPath containsString:@"?"]) {
            adressPath = [[adressPath componentsSeparatedByString:@"?"] objectAtIndex:0];
        }
        setting = [settingDic objectForKey:adressPath] ;
    }
    if ([[leftDic objectForKey:@"type"] isEqualToString:@"return"]) {
        if (self.presentingViewController) {
            [self dismissViewControllerAnimated:YES completion:nil];
        } else {
            [self.navigationController popViewControllerAnimated:YES];
        }
    } else if ([[setting objectForKey:@"showTop"] boolValue]) {
        CFJClientH5Controller *appH5VC = [[CFJClientH5Controller alloc] initWithNibName:nil bundle:nil];
        appH5VC.webViewDomain = urlstr;
        appH5VC.navDic = setting;
        appH5VC.hidesBottomBarWhenPushed = YES;
        [self.navigationController pushViewController:appH5VC animated:YES];
    } else {
        NSLog(@"在局暂不处理");
    }
}

//右侧按钮执行方法
- (void)rightItemClickWithDic{
    NSDictionary *Dic = [self.navDic objectForKey:@"nav"];
    NSDictionary *rightDic = [Dic objectForKey:@"rightItem"];
    NSDictionary *settingDic = [NSKeyedUnarchiver unarchiveObjectWithFile:KNavSettingPath];
    NSString *urlstr = [rightDic objectForKey:@"url"];
    if (urlstr.length) {
        urlstr = [urlstr containsString:@"http"] ? [rightDic objectForKey:@"url"]  : [NSString stringWithFormat:@"%@%@",JDomain,[rightDic objectForKey:@"url"]];
    } else if ([[rightDic objectForKey:@"type"] isEqualToString:@"msg"]) {
        urlstr = [NSString stringWithFormat:@"%@%@",JDomain,@"/p-noticemsg_category.html"];
    } else if ([[rightDic objectForKey:@"type"] isEqualToString:@"shopCart"]) {
        urlstr = [NSString stringWithFormat:@"%@%@",JDomain,@"/p-shop_cart.html"];
    } else if ([[rightDic objectForKey:@"type"] isEqualToString:@"share"]) {
        //执行js方法
        NSDictionary *dic = @{@"sharePic":[rightDic objectForKey:@"sharePic"] ?: @"",@"shareText":[rightDic objectForKey:@"shareText"] ?: @""};
        NSDictionary *callJsDic = [CustomHybridProcessor custom_objcCallJsWithFn:@"headShare" data:dic];
        [self objcCallJs:callJsDic];
        return;
    } else if ([[rightDic objectForKey:@"type"] isEqualToString:@"jsApi"]) {
        //执行js方法
        NSDictionary *callJsDic = [CustomHybridProcessor custom_objcCallJsWithFn:[rightDic objectForKey:@"jsApi"] data:nil];
        [self objcCallJs:callJsDic];
        return;
    } else if ([[rightDic objectForKey:@"type"] isEqualToString:@"backToHome"]) {
        [self.navigationController popToRootViewControllerAnimated:YES];
        NSString *number = [rightDic objectForKey:@"selectNumber"];
        NSDictionary *setDic = @{
            @"selectNumber": number
        };
        dispatch_time_t when = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC));
        dispatch_after(when, dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:@"backToHome" object:setDic];
        });
        return;
    }
    //判断页面是否隐藏头部
    NSString *adressPath = [[urlstr componentsSeparatedByString:[NSString stringWithFormat:@"://%@",MainDomain]] safeObjectAtIndex:1];
    NSDictionary *setting = [NSDictionary dictionary];
    if ([adressPath containsString:@".html"]) {
        NSRange range = [adressPath rangeOfString:@".html"];
        adressPath = [adressPath substringToIndex:range.location];
        if ([adressPath containsString:@"?"]) {
            adressPath = [[adressPath componentsSeparatedByString:@"?"] objectAtIndex:0];
        }
        setting = [settingDic objectForKey:adressPath] ;
    } else {
        if ([adressPath containsString:@"?"]) {
            adressPath = [[adressPath componentsSeparatedByString:@"?"] objectAtIndex:0];
        }
        setting = [settingDic objectForKey:adressPath] ;
    }
    if ([[setting objectForKey:@"showTop"] boolValue]) {
        CFJClientH5Controller *appH5VC = [[CFJClientH5Controller alloc] initWithNibName:nil bundle:nil];
        appH5VC.webViewDomain = urlstr;
        appH5VC.navDic = setting;
        appH5VC.hidesBottomBarWhenPushed = YES;
        [self.navigationController pushViewController:appH5VC animated:YES];
    } else {
        NSLog(@"在局暂不处理");
    }
}

//页面出现
- (void)viewWillAppear:(BOOL)animated {
    NSLog(@"在局🌟 [CFJClientH5Controller] viewWillAppear开始 - self: %@, pinUrl: %@", self, self.pinUrl);
    
    [super viewWillAppear:animated];
    
    
    // 检查view的状态
    
    // 检查转场协调器 - 移除可能导致问题的动画监听
    if (self.transitionCoordinator) {
    }
    
    // 确保系统的返回手势是启用的
    if (self.navigationController && self.navigationController.viewControllers.count > 1) {
        self.navigationController.interactivePopGestureRecognizer.enabled = YES;
    }
    
    
    // 延迟到viewDidAppear后设置圆角，避免影响Tab切换动画
    if (!(self.pushType == isPushNormal)) {
    }

#pragma mark ----- 隐藏某些页面（延迟到viewDidAppear）
    // 延迟所有UI操作到viewDidAppear，确保Tab切换动画流畅
    
    // TabBar处理也延迟到viewDidAppear
    
    // 添加关键诊断信息
    
    // 检查动画状态
    if (self.navigationController) {
    }
    
    // 检查TabBar控制器状态
    if (self.tabBarController) {
    }
    
    // 强制主线程调度检查
    dispatch_async(dispatch_get_main_queue(), ^{
    });
    
    // 简化流程：不在viewWillAppear中创建WebView，等待viewDidAppear自然调用
    
    
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView{
    int currentPostion = scrollView.contentOffset.y;
    if (currentPostion - self.lastPosition > 25) {
        self.lastPosition = currentPostion;
        if (self.isTabbarShow) {
            [[NSNotificationCenter defaultCenter] postNotificationName:@"HideTabBarNotif" object:nil];
        }
    }
    else if (self.lastPosition - currentPostion > 25)
    {
        self.lastPosition = currentPostion;
        if (self.isTabbarShow) {
            [[NSNotificationCenter defaultCenter] postNotificationName:@"ShowTabBarNotif" object:nil];
        }
    }
}

- (void)handleJavaScriptCall:(NSDictionary *)data completion:(XZWebViewJSCallbackBlock)completion {
    NSDictionary *jsDic = data;
    NSString *function = [jsDic objectForKey:@"action"];
    id dataObject = [jsDic objectForKey:@"data"];  // 使用id类型，不强制转换为字典
    
    NSLog(@"在局🔧 [handleJavaScriptCall] 处理action: %@, data: %@", function, dataObject);
    
    // 统一回调格式化方法
    XZWebViewJSCallbackBlock safeCompletion = ^(NSDictionary *result) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) {
                completion(result);
            }
        });
    };
    
    // 网络请求
    if ([function isEqualToString:@"request"]) {
        // request需要字典类型的数据
        NSDictionary *dataDic = [dataObject isKindOfClass:[NSDictionary class]] ? (NSDictionary *)dataObject : @{};
        [self rpcRequestWithJsDic:dataDic completion:safeCompletion];
        return;
    }
    
    // 原生数据获取
    if ([function isEqualToString:@"nativeGet"]) {
        // nativeGet可以接受任何类型的数据
        [self handleNativeGet:dataObject completion:safeCompletion];
        return;
    }
    
    // 为大部分方法准备字典类型的数据
    NSDictionary *dataDic = [dataObject isKindOfClass:[NSDictionary class]] ? (NSDictionary *)dataObject : @{};
    
    // 微信相关
    if ([function isEqualToString:@"hasWx"]) {
        [self handleHasWx:dataDic completion:safeCompletion];
        return;
    }
    
    // 设备检测
    if ([function isEqualToString:@"isiPhoneX"]) {
        [self handleIsIPhoneX:dataDic completion:safeCompletion];
        return;
    }
    
    // 消息相关
    if ([function isEqualToString:@"readMessage"]) {
        [self handleReadMessage:dataDic completion:safeCompletion];
        return;
    }
    
    // TabBar相关
    if ([function isEqualToString:@"setTabBarBadge"]) {
        [self handleSetTabBarBadge:dataDic completion:safeCompletion];
        return;
    }
    if ([function isEqualToString:@"removeTabBarBadge"]) {
        [self handleRemoveTabBarBadge:dataDic completion:safeCompletion];
        return;
    }
    if ([function isEqualToString:@"showTabBarRedDot"]) {
        [self handleShowTabBarRedDot:dataDic completion:safeCompletion];
        return;
    }
    if ([function isEqualToString:@"hideTabBarRedDot"]) {
        [self handleHideTabBarRedDot:dataDic completion:safeCompletion];
        return;
    }
    
    // 导航相关 - navigateTo需要传递原始的dataObject，不是dataDic
    if ([function isEqualToString:@"navigateTo"]) {
        [self handleNavigateTo:dataObject completion:safeCompletion];
        return;
    }
    if ([function isEqualToString:@"navigateBack"]) {
        [self handleNavigateBack:dataDic completion:safeCompletion];
        return;
    }
    if ([function isEqualToString:@"reLaunch"]) {
        [self handleReLaunch:dataDic completion:safeCompletion];
        return;
    }
    
    // 定位相关
    if ([function isEqualToString:@"getLocation"]) {
        [self handleGetLocation:dataDic completion:safeCompletion];
        return;
    }
    if ([function isEqualToString:@"showLocation"]) {
        [self handleShowLocation:dataDic completion:safeCompletion];
        return;
    }
    if ([function isEqualToString:@"selectLocation"]) {
        [self handleSelectLocation:dataDic completion:safeCompletion];
        return;
    }
    if ([function isEqualToString:@"selectLocationCity"]) {
        [self handleSelectLocationCity:dataDic completion:safeCompletion];
        return;
    }
    
    // 页面生命周期
    if ([function isEqualToString:@"pageShow"]) {
        [self handlePageShow:dataDic completion:safeCompletion];
        return;
    }
    if ([function isEqualToString:@"pageHide"]) {
        [self handlePageHide:dataDic completion:safeCompletion];
        return;
    }
    if ([function isEqualToString:@"pageUnload"]) {
        [self handlePageUnload:dataDic completion:safeCompletion];
        return;
    }
    
    // 工具功能
    if ([function isEqualToString:@"copyLink"]) {
        [self handleCopyLink:dataDic completion:safeCompletion];
        return;
    }
    if ([function isEqualToString:@"share"]) {
        [self handleShare:dataDic completion:safeCompletion];
        return;
    }
    if ([function isEqualToString:@"saveImage"]) {
        [self handleSaveImage:dataDic completion:safeCompletion];
        return;
    }
    
    // 导航栏控制
    if ([function isEqualToString:@"setNavigationBarTitle"]) {
        [self handleSetNavigationBarTitle:dataDic completion:safeCompletion];
        return;
    }
    if ([function isEqualToString:@"hideNavationbar"]) {
        [self handleHideNavigationBar:dataDic completion:safeCompletion];
        return;
    }
    if ([function isEqualToString:@"showNavationbar"]) {
        [self handleShowNavigationBar:dataDic completion:safeCompletion];
        return;
    }
    
    // 第三方登录和支付
    if ([function isEqualToString:@"weixinLogin"]) {
        [self handleWeixinLogin:dataDic completion:safeCompletion];
        return;
    }
    if ([function isEqualToString:@"weixinPay"]) {
        [self handleWeixinPay:dataDic completion:safeCompletion];
        return;
    }
    if ([function isEqualToString:@"aliPay"]) {
        [self handleAliPay:dataDic completion:safeCompletion];
        return;
    }
    
    // 文件操作
    if ([function isEqualToString:@"chooseFile"]) {
        [self handleChooseFile:dataDic completion:safeCompletion];
        return;
    }
    if ([function isEqualToString:@"uploadFile"]) {
        [self handleUploadFile:dataDic completion:safeCompletion];
        return;
    }
    if ([function isEqualToString:@"previewImage"]) {
        [self handlePreviewImage:dataDic completion:safeCompletion];
        return;
    }
    
    // 扫码
    if ([function isEqualToString:@"QRScan"]) {
        [self handleQRScan:dataDic completion:safeCompletion];
        return;
    }
    
    // 用户相关
    if ([function isEqualToString:@"userLogin"]) {
        [self handleUserLogin:dataDic completion:safeCompletion];
        return;
    }
    if ([function isEqualToString:@"userLogout"]) {
        [self handleUserLogout:dataDic completion:safeCompletion];
        return;
    }
    
    // Tab切换
    if ([function isEqualToString:@"switchTab"]) {
        [self handleSwitchTab:dataDic completion:safeCompletion];
        return;
    }
    
    // UI组件
    if ([function isEqualToString:@"showModal"]) {
        [self handleShowModal:dataDic completion:safeCompletion];
        return;
    }
    if ([function isEqualToString:@"showToast"]) {
        [self handleShowToast:dataDic completion:safeCompletion];
        return;
    }
    if ([function isEqualToString:@"showActionSheet"]) {
        [self handleShowActionSheet:dataDic completion:safeCompletion];
        return;
    }
    
    // 选择器
    if ([function isEqualToString:@"areaSelect"]) {
        [self handleAreaSelect:dataDic completion:safeCompletion];
        return;
    }
    if ([function isEqualToString:@"dateSelect"]) {
        [self handleDateSelect:dataDic completion:safeCompletion];
        return;
    }
    if ([function isEqualToString:@"timeSelect"]) {
        [self handleTimeSelect:dataDic completion:safeCompletion];
        return;
    }
    if ([function isEqualToString:@"fancySelect"]) {
        [self handleFancySelect:dataDic completion:safeCompletion];
        return;
    }
    if ([function isEqualToString:@"dateAndTimeSelect"]) {
        [self handleDateAndTimeSelect:dataDic completion:safeCompletion];
        return;
    }
    
    // 其他功能
    if ([function isEqualToString:@"closePresentWindow"]) {
        [self handleClosePresentWindow:dataDic completion:safeCompletion];
        return;
    }
    if ([function isEqualToString:@"changeMessageNum"]) {
        [self handleChangeMessageNum:dataDic completion:safeCompletion];
        return;
    }
    if ([function isEqualToString:@"noticemsg_setNumber"]) {
        [self handleNoticeMessageSetNumber:dataDic completion:safeCompletion];
        return;
    }
    if ([function isEqualToString:@"reloadOtherPages"]) {
        [self handleReloadOtherPages:dataDic completion:safeCompletion];
        return;
    }
    if ([function isEqualToString:@"stopPullDownRefresh"]) {
        [self handleStopPullDownRefresh:dataDic completion:safeCompletion];
        return;
    }
    
    // 未知的action，返回错误
    NSLog(@"在局⚠️ [handleJavaScriptCall] 未处理的action: %@", function);
    safeCompletion(@{
        @"success": @"false",
        @"errorMessage": [NSString stringWithFormat:@"Unknown action: %@", function],
        @"data": @{}
    });
}

#pragma mark - 第三方登录

// 第三方登录授权
// @deprecated 微信登录已迁移到performWechatDirectLogin方法，建议使用新的直接SDK方法
- (void)thirdLogin:(NSDictionary *)dic {
    NSString *type = [dic objectForKey:@"type"];
    
    // 微信登录重定向到新的实现
    if ([type isEqualToString:@"weixin"]) {
        NSLog(@"在局⚠️ [第三方登录] 微信登录已重定向到新的直接SDK实现");
        [self performWechatDirectLogin];
        return;
    }
    
    UMSocialPlatformType snsName = [self thirdPlatform:type];
    if(snsName == UMSocialPlatformType_UnKnown) {
        NSLog(@"在局❌ [第三方登录] 未知的平台类型，退出");
        return;
    }
    NSString *dataType;
    if ([type isEqualToString:@"qq"]) {
        dataType = @"2";
    } else if ([type isEqualToString:@"weibo"]) {
        dataType = @"3";
    }
    NSString *deviceTokenStr = [[NSUserDefaults standardUserDefaults] objectForKey:@"User_ChannelId"];
    deviceTokenStr = deviceTokenStr ? deviceTokenStr : @"";
    
    
    // 添加超时保护机制
    __block BOOL callbackExecuted = NO;
    
    // 设置15秒超时
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(15.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (!callbackExecuted) {
            NSLog(@"在局❌ [第三方登录] UMSocialManager超时未回调，强制返回错误");
            callbackExecuted = YES;
            if (self.webviewBackCallBack) {
                self.webviewBackCallBack(@{
                    @"success": @"false",
                    @"errorMessage": @"第三方登录超时，请重试",
                    @"data": @{}
                });
            }
        }
    });
    
    [[UMSocialManager defaultManager] getUserInfoWithPlatform:snsName currentViewController:self completion:^(id result, NSError *error) {
        if (callbackExecuted) {
            return;
        }
        callbackExecuted = YES;
        
        NSString *message = nil;
        
        if (error) {
            NSLog(@"在局❌ [微信登录] UMSocialManager获取用户信息失败: %@", error);
            message = [NSString stringWithFormat:@"Get info fail:\n%@", error];
            UMSocialLogInfo(@"Get info fail with error %@",error);
            
            // 返回错误给JavaScript
            if (self.webviewBackCallBack) {
                self.webviewBackCallBack(@{
                    @"success": @"false",
                    @"errorMessage": error.localizedDescription ?: @"微信登录失败",
                    @"data": @{}
                });
            }
        }
        else{
            if ([result isKindOfClass:[UMSocialUserInfoResponse class]]) {
                UMSocialUserInfoResponse *resp = result;
                
                NSDictionary *daraDic = @{
                    @"avatarUrl": resp.iconurl ?: @"",
                    @"nickName": resp.name ?: @""
                };
                
                NSDictionary *responseData = @{
                    @"data": @{
                        @"userInfo": daraDic,
                        @"openId": resp.usid ?: @"",
                        @"unionid": resp.unionId.length ? resp.unionId : @"",
                        @"channel": deviceTokenStr
                    },
                    @"success": @"true",
                    @"errorMessage": @""
                };
                
                NSLog(@"在局📤 [微信登录] 向JavaScript返回数据: %@", responseData);
                
                if (self.webviewBackCallBack) {
                    self.webviewBackCallBack(responseData);
                }
            }
            else{
                NSLog(@"在局❌ [微信登录] UMSocialManager返回了无效的结果类型: %@", [result class]);
                message = @"Get info fail";
                
                if (self.webviewBackCallBack) {
                    self.webviewBackCallBack(@{
                        @"success": @"false",
                        @"errorMessage": @"获取微信用户信息失败",
                        @"data": @{}
                    });
                }
            }
        }
    }];
}

// 检查微信应用可用性
- (BOOL)checkWechatAvailabilityWithAction:(NSString *)action {
    // 检查微信是否安装
    if(![WXApi isWXAppInstalled]) {
        NSLog(@"在局❌ [%@] 微信应用未安装", action);
        if (self.webviewBackCallBack) {
            self.webviewBackCallBack([self formatCallbackResponse:action data:@{} success:NO errorMessage:@"您没有安装微信"]);
        }
        return NO;
    }
    
    // 检查微信版本是否支持
    if (![WXApi isWXAppSupportApi]) {
        NSLog(@"在局❌ [%@] 微信版本过低，不支持当前API", action);
        if (self.webviewBackCallBack) {
            self.webviewBackCallBack([self formatCallbackResponse:action data:@{} success:NO errorMessage:@"您的微信版本太低"]);
        }
        return NO;
    }
    
    return YES;
}

// 微信直接登录方法
- (void)performWechatDirectLogin {
    
    // 检查微信可用性
    if (![self checkWechatAvailabilityWithAction:@"weixinLogin"]) {
        return;
    }
    
    // 添加微信授权结果监听
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleWechatAuthResult:)
                                                 name:@"wechatAuthResult"
                                               object:nil];
    
    // 添加超时保护机制
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(15.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf && strongSelf.webviewBackCallBack) {
            NSLog(@"在局❌ [微信直接登录] 授权超时，强制返回错误");
            // 移除监听器
            [[NSNotificationCenter defaultCenter] removeObserver:strongSelf name:@"wechatAuthResult" object:nil];
            // 返回超时错误
            strongSelf.webviewBackCallBack([strongSelf formatCallbackResponse:@"weixinLogin" data:@{} success:NO errorMessage:@"微信登录超时，请重试"]);
            // 清空回调
            strongSelf.webviewBackCallBack = nil;
        }
    });
    
    // 创建微信授权请求
    SendAuthReq *req = [[SendAuthReq alloc] init];
    req.scope = @"snsapi_userinfo";  // 获取用户信息权限
    req.state = [NSString stringWithFormat:@"wechat_login_%ld", (long)[[NSDate date] timeIntervalSince1970]];
    
    // 发送授权请求
    [WXApi sendReq:req completion:^(BOOL success) {
        if (!success) {
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof(weakSelf) strongSelf = weakSelf;
                if (strongSelf && strongSelf.webviewBackCallBack) {
                    // 移除监听器
                    [[NSNotificationCenter defaultCenter] removeObserver:strongSelf name:@"wechatAuthResult" object:nil];
                    strongSelf.webviewBackCallBack([strongSelf formatCallbackResponse:@"weixinLogin" data:@{} success:NO errorMessage:@"微信授权请求发送失败"]);
                    // 清空回调
                    strongSelf.webviewBackCallBack = nil;
                }
            });
        }
    }];
}

// 处理微信授权结果
- (void)handleWechatAuthResult:(NSNotification *)notification {
    
    // 防止重复处理或超时后处理
    if (!self.webviewBackCallBack) {
        return;
    }
    
    // 移除监听器
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"wechatAuthResult" object:nil];
    
    NSDictionary *authResult = notification.object;
    BOOL success = [authResult[@"success"] boolValue];
    
    if (success) {
        NSString *code = authResult[@"code"];
        NSString *state = authResult[@"state"];
        
        // 使用code获取用户信息
        [self fetchWechatUserInfoWithCode:code state:state];
    } else {
        NSLog(@"在局❌ [微信授权结果] 授权失败: %@", authResult[@"errorMessage"]);
        if (self.webviewBackCallBack) {
            // 使用统一的错误格式
            NSString *errorMessage = authResult[@"errorMessage"] ?: @"微信授权失败";
            self.webviewBackCallBack([self formatCallbackResponse:@"weixinLogin" data:@{} success:NO errorMessage:errorMessage]);
            // 清空回调
            self.webviewBackCallBack = nil;
        }
    }
}

// 使用code获取微信用户信息
- (void)fetchWechatUserInfoWithCode:(NSString *)code state:(NSString *)state {
    
    // 获取deviceToken
    NSString *deviceTokenStr = [[NSUserDefaults standardUserDefaults] objectForKey:@"User_ChannelId"];
    deviceTokenStr = deviceTokenStr ? deviceTokenStr : @"";
    
    // 使用code调用微信API获取access_token和用户信息
    [self fetchWechatAccessTokenWithCode:code state:state deviceToken:deviceTokenStr];
}

// 获取微信access_token
- (void)fetchWechatAccessTokenWithCode:(NSString *)code state:(NSString *)state deviceToken:(NSString *)deviceToken {
    
    // 从配置文件动态获取微信开放平台应用信息
    NSDictionary *shareConfig = [self getShareConfig];
    NSString *appId = shareConfig[@"wxAppId"];
    NSString *appSecret = shareConfig[@"wxAppScret"]; // 注意：配置文件中是"wxAppScret"（拼写）
    
    if (!appId || !appSecret) {
        NSLog(@"在局❌ [微信Access Token] 微信配置信息缺失 - AppID: %@, AppSecret: %@", appId ? @"存在" : @"缺失", appSecret ? @"存在" : @"缺失");
        [self returnWechatLoginError:@"微信配置信息缺失"];
        return;
    }
    
    // 构造获取access_token的URL
    NSString *tokenURL = [NSString stringWithFormat:@"https://api.weixin.qq.com/sns/oauth2/access_token?appid=%@&secret=%@&code=%@&grant_type=authorization_code", appId, appSecret, code];
    
    
    // 创建网络请求
    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    manager.responseSerializer = [AFJSONResponseSerializer serializer];
    // 微信API可能返回text/plain类型，需要添加支持
    manager.responseSerializer.acceptableContentTypes = [NSSet setWithObjects:@"application/json", @"text/json", @"text/plain", nil];
    manager.requestSerializer.timeoutInterval = 30;
    
    [manager GET:tokenURL parameters:nil headers:nil progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        
        NSString *accessToken = responseObject[@"access_token"];
        NSString *openId = responseObject[@"openid"];
        NSString *refreshToken = responseObject[@"refresh_token"];
        
        if (accessToken && openId) {
            // 使用access_token获取用户信息
            [self fetchWechatUserInfoWithAccessToken:accessToken openId:openId code:code state:state deviceToken:deviceToken];
        } else {
            NSLog(@"在局❌ [微信Access Token] 响应中缺少access_token或openid");
            [self returnWechatLoginError:@"获取微信授权信息失败"];
        }
        
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        NSLog(@"在局❌ [微信Access Token] 获取access_token失败: %@", error.localizedDescription);
        [self returnWechatLoginError:[NSString stringWithFormat:@"网络请求失败: %@", error.localizedDescription]];
    }];
}

// 获取微信用户详细信息
- (void)fetchWechatUserInfoWithAccessToken:(NSString *)accessToken openId:(NSString *)openId code:(NSString *)code state:(NSString *)state deviceToken:(NSString *)deviceToken {
    
    // 构造获取用户信息的URL
    NSString *userInfoURL = [NSString stringWithFormat:@"https://api.weixin.qq.com/sns/userinfo?access_token=%@&openid=%@&lang=zh_CN", accessToken, openId];
    
    // 创建网络请求
    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    manager.responseSerializer = [AFJSONResponseSerializer serializer];
    // 微信API可能返回text/plain类型，需要添加支持
    manager.responseSerializer.acceptableContentTypes = [NSSet setWithObjects:@"application/json", @"text/json", @"text/plain", nil];
    manager.requestSerializer.timeoutInterval = 30;
    
    [manager GET:userInfoURL parameters:nil headers:nil progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        
        // 解析用户信息
        NSString *nickname = responseObject[@"nickname"] ?: @"";
        NSString *headimgurl = responseObject[@"headimgurl"] ?: @"";
        NSString *unionid = responseObject[@"unionid"] ?: @"";
        
        // 构造完整的返回数据
        NSDictionary *userData = @{
            @"userInfo": @{
                @"avatarUrl": headimgurl,
                @"nickName": nickname
            },
            @"openId": openId,
            @"unionid": unionid,
            @"channel": deviceToken,
            @"code": code,
            @"state": state
        };
        
        NSDictionary *responseData = [self formatCallbackResponse:@"weixinLogin" data:userData success:YES errorMessage:nil];
        
        NSLog(@"在局📤 [微信用户详情] 向JavaScript返回完整数据: %@", responseData);
        
        // 保存微信登录信息到统一认证管理器
        // TODO: 需要在Xcode中添加XZAuthenticationManager文件后启用
        /*
        XZUserInfo *userInfo = [[XZUserInfo alloc] init];
        userInfo.nickname = nickname;
        userInfo.headpic = headimgurl;
        userInfo.openId = openId;
        userInfo.unionId = unionid;
        // 注意：微信登录通常没有直接的userId，可能需要后端返回
        userInfo.extraInfo = @{
            @"code": code ?: @"",
            @"state": state ?: @"",
            @"channel": deviceToken ?: @""
        };
        
        // 保存到认证管理器（暂时不设置token和userId，等待后端返回）
        [[XZAuthenticationManager sharedManager] updateUserInfo:userInfo];
        */
        
        // 等待App进入前台后再执行回调
        [self waitForAppActiveStateAndExecuteCallback:responseData];
        
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        NSLog(@"在局❌ [微信用户详情] 获取用户信息失败: %@", error.localizedDescription);
        [self returnWechatLoginError:[NSString stringWithFormat:@"获取用户信息失败: %@", error.localizedDescription]];
    }];
}

// 返回微信登录错误
- (void)returnWechatLoginError:(NSString *)errorMessage {
    if (self.webviewBackCallBack) {
        NSDictionary *errorResponse = [self formatCallbackResponse:@"weixinLogin" data:@{} success:NO errorMessage:errorMessage];
        [self waitForAppActiveStateAndExecuteCallback:errorResponse];
    }
}

// 获取分享配置信息
- (NSDictionary *)getShareConfig {
    static NSDictionary *shareConfig = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // 从Bundle中读取shareInfo.json配置文件
        NSString *shareInfoPath = [[NSBundle mainBundle] pathForResource:@"shareInfo" ofType:@"json"];
        if (shareInfoPath) {
            NSData *JSONData = [NSData dataWithContentsOfFile:shareInfoPath];
            if (JSONData) {
                NSError *error = nil;
                NSDictionary *jsonDict = [NSJSONSerialization JSONObjectWithData:JSONData options:NSJSONReadingAllowFragments error:&error];
                if (!error && jsonDict[@"data"]) {
                    shareConfig = jsonDict[@"data"];
                } else {
                    NSLog(@"在局❌ [配置加载] 解析shareInfo.json失败: %@", error.localizedDescription);
                }
            } else {
                NSLog(@"在局❌ [配置加载] 无法读取shareInfo.json文件内容");
            }
        } else {
            NSLog(@"在局❌ [配置加载] 找不到shareInfo.json文件");
        }
    });
    
    return shareConfig ?: @{};
}

// 等待App进入前台后执行回调
- (void)waitForAppActiveStateAndExecuteCallback:(NSDictionary *)responseData {
    // 确保在主线程访问UI API
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self waitForAppActiveStateAndExecuteCallback:responseData];
        });
        return;
    }
    
    // 检查App当前状态
    UIApplicationState currentState = [[UIApplication sharedApplication] applicationState];
    
    if (currentState == UIApplicationStateActive) {
        // App已经在前台，直接执行回调
        [self executeWechatLoginCallback:responseData];
    } else {
        NSLog(@"在局⏳ [微信登录调试] App不在前台(状态:%ld)，等待进入前台后执行回调", (long)currentState);
        
        // 监听App进入前台的通知
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(appDidBecomeActiveForWechatCallback:)
                                                     name:UIApplicationDidBecomeActiveNotification
                                                   object:nil];
        
        // 保存响应数据以供后续使用
        objc_setAssociatedObject(self, @"WechatCallbackData", responseData, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        
        // 设置超时保护，10秒后强制执行
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            // 检查是否还有保存的数据（如果已经执行过回调，数据会被清除）
            NSDictionary *savedData = objc_getAssociatedObject(self, @"WechatCallbackData");
            if (savedData && self.webviewBackCallBack) {
                [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidBecomeActiveNotification object:nil];
                [self executeWechatLoginCallback:responseData];
            } else {
            }
        });
    }
}

// App进入前台时的回调处理
- (void)appDidBecomeActiveForWechatCallback:(NSNotification *)notification {
    
    // 移除监听器
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidBecomeActiveNotification object:nil];
    
    // 获取保存的响应数据
    NSDictionary *responseData = objc_getAssociatedObject(self, @"WechatCallbackData");
    if (responseData) {
        [self executeWechatLoginCallback:responseData];
        // 清理保存的数据
        objc_setAssociatedObject(self, @"WechatCallbackData", nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    } else {
        NSLog(@"在局❌ [微信登录调试] 没有找到保存的响应数据");
    }
}

// 执行微信登录回调
- (void)executeWechatLoginCallback:(NSDictionary *)responseData {
    
    if (self.webviewBackCallBack) {
        self.webviewBackCallBack(responseData);
        
        // 清空回调，防止重复调用
        self.webviewBackCallBack = nil;
    } else {
        NSLog(@"在局❌ [微信登录调试] webviewBackCallBack为空，无法返回数据！");
    }
}

//清除授权
- (void)cancelThirdAuthorize:(NSDictionary *)dic {
    NSString *type = [dic objectForKey:@"type"];
    NSInteger snsName = [self thirdPlatform:type];
    if((snsName = UMSocialPlatformType_UnKnown)) {
        return;
    }
}
//通过URL获取图片
- (UIImage *)getImageFromURL:(NSString *)fileURL {
    UIImage * result;
    NSData * data = [NSData dataWithContentsOfURL:[NSURL URLWithString:fileURL]];
    result = [UIImage imageWithData:data];
    return result;
}
- (void)saveImageToPhotos:(UIImage *)savedImage
{
    
    UIImageWriteToSavedPhotosAlbum(savedImage, self, @selector(image:didFinishSavingWithError:contextInfo:), NULL);
    
}

//指定回调方法
- (void)image: (UIImage *) image didFinishSavingWithError: (NSError *) error contextInfo: (void *) contextInfo
{
    if(error != NULL){
        if (self.webviewBackCallBack) {
            self.webviewBackCallBack(
                                     @{@"data":@"",
                                       @"success":@"failure",
                                       @"errorMessage":@""
                                     });        }
    }else{
        if (self.webviewBackCallBack) {
            self.webviewBackCallBack(
                                     @{@"data":@"",
                                       @"success":@"true",
                                       @"errorMessage":@""
                                     });        }
        
    }
}

//第三方分享
- (void)shareContent:(NSDictionary *)dic presentedVC:(UIViewController *)vc {
    NSString *type = [dic objectForKey:@"type"];
    NSInteger shareType = [[dic objectForKey:@"shareType"] integerValue];
    
    NSLog(@"在局🔄 [分享开始] 类型: %@, shareType: %ld, 数据: %@", type, (long)shareType, dic);
    
    if ([type isEqualToString:@"copy"]) {
        //复制内容到粘贴板
        UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
        pasteboard.string = [dic objectForKey:@"url"];;
        [SVStatusHUD showWithMessage:@"复制链接成功"];
        
        // 给JavaScript端回调成功结果
        if (self.webviewBackCallBack) {
            self.webviewBackCallBack(@{
                @"success": @"true",
                @"data": @{},
                @"errorMessage": @""
            });
        }
        return;
    }
    else {
        UMSocialPlatformType snsName = [self thirdPlatform:type];
        if(snsName == UMSocialPlatformType_UnKnown) {
            NSLog(@"在局❌ [分享失败] 未知的平台类型: %@", type);
            if (self.webviewBackCallBack) {
                self.webviewBackCallBack(@{
                    @"success": @"false",
                    @"data": @{},
                    @"errorMessage": @"不支持的分享平台"
                });
            }
            return;
        }
        
        // 检查微信是否安装
        if (snsName == UMSocialPlatformType_WechatSession || snsName == UMSocialPlatformType_WechatTimeLine) {
            if (![WXApi isWXAppInstalled]) {
                NSLog(@"在局❌ [分享失败] 微信未安装");
                [SVStatusHUD showWithMessage:@"请先安装微信应用"];
                if (self.webviewBackCallBack) {
                    self.webviewBackCallBack(@{
                        @"success": @"false",
                        @"data": @{},
                        @"errorMessage": @"微信未安装"
                    });
                }
                return;
            }
            
            if (![WXApi isWXAppSupportApi]) {
                NSLog(@"在局❌ [分享失败] 微信版本过低");
                [SVStatusHUD showWithMessage:@"微信版本过低，请升级"];
                if (self.webviewBackCallBack) {
                    self.webviewBackCallBack(@{
                        @"success": @"false",
                        @"data": @{},
                        @"errorMessage": @"微信版本过低"
                    });
                }
                return;
            }
        }
        
        
        // 对于微信分享，使用直接的WXApi方法避免UMSocialManager的openURL问题
        if (snsName == UMSocialPlatformType_WechatSession || snsName == UMSocialPlatformType_WechatTimeLine) {
            if (shareType == 1) {
                [self shareDirectMiniProgramToWeChat:dic toTimeline:(snsName == UMSocialPlatformType_WechatTimeLine)];
            } else {
                [self shareDirectWebPageToWeChat:dic toTimeline:(snsName == UMSocialPlatformType_WechatTimeLine)];
            }
        }
        else {
            // 其他平台继续使用UMSocialManager
            if (snsName == UMSocialPlatformType_WechatSession && shareType == 1) {
                [self shareMiniProgramToPlatformType:snsName dataDic:dic];
            }
            else {
                [self shareWebPageToPlatformType:snsName dataDic:dic];
            }
        }
    }
}
//分享小程序
- (void)shareMiniProgramToPlatformType:(UMSocialPlatformType)platformType dataDic:(NSDictionary *)dataDic
{
    NSString *titleStr = [dataDic objectForKey:@"title"];
    NSString *shareText = [dataDic objectForKey:@"content"];
    NSString *imgStr = [dataDic objectForKey:@"img"];
    NSString *url = [dataDic objectForKey:@"url"];
    NSString *userName = [dataDic objectForKey:@"wxid"];;
    NSString *pagePath = [dataDic objectForKey:@"pagePath"];
    
    
    //创建分享消息对象
    UMSocialMessageObject *messageObject = [UMSocialMessageObject messageObject];
    UMShareMiniProgramObject *shareObject = [UMShareMiniProgramObject shareObjectWithTitle:titleStr descr:shareText thumImage:imgStr];
    shareObject.webpageUrl = url;
    shareObject.userName = userName;
    shareObject.path = pagePath;
    //打开注释hdImageData展示高清大图
    UIImage *img = [self getImageFromURL:imgStr];
    NSData *newData = [UIImage compressImage:img toByte:131072];
    shareObject.hdImageData = newData;
    //发布版小程序
    shareObject.miniProgramType = UShareWXMiniProgramTypeRelease;
    messageObject.shareObject = shareObject;
    
    [[UMSocialManager defaultManager] shareToPlatform:platformType messageObject:messageObject currentViewController:self completion:^(id data, NSError *error) {
        if (error) {
            NSLog(@"在局❌ [小程序分享失败] 错误: %@", error.localizedDescription);
            UMSocialLogInfo(@"************Share fail with error %@*********",error);
            
            // 回调JavaScript端分享失败
            if (self.webviewBackCallBack) {
                self.webviewBackCallBack(@{
                    @"success": @"false",
                    @"data": @{},
                    @"errorMessage": error.localizedDescription ?: @"分享失败"
                });
            }
        }
        else{
            if ([data isKindOfClass:[UMSocialShareResponse class]]) {
                UMSocialShareResponse *resp = data;
                //分享结果消息
                UMSocialLogInfo(@"response message is %@",resp.message);
                //第三方原始返回的数据
                UMSocialLogInfo(@"response originalResponse data is %@",resp.originalResponse);
                
            }else{
                UMSocialLogInfo(@"response data is %@",data);
            }
            
            // 回调JavaScript端分享成功
            if (self.webviewBackCallBack) {
                self.webviewBackCallBack(@{
                    @"success": @"true",
                    @"data": @{},
                    @"errorMessage": @""
                });
            }
        }
    }];
}
//分享网页
- (void)shareWebPageToPlatformType:(UMSocialPlatformType)platformType dataDic:(NSDictionary *)dataDic
{
    NSString *titleStr = [dataDic objectForKey:@"title"];
    NSString *shareText = [dataDic objectForKey:@"content"];
    NSString *imgStr = [dataDic objectForKey:@"img"];
    NSString *url = [dataDic objectForKey:@"url"];
    
    NSString *platformName = @"未知平台";
    switch (platformType) {
        case UMSocialPlatformType_WechatSession:
            platformName = @"微信好友";
            break;
        case UMSocialPlatformType_WechatTimeLine:
            platformName = @"微信朋友圈";
            break;
        case UMSocialPlatformType_QQ:
            platformName = @"QQ";
            break;
        case UMSocialPlatformType_Sina:
            platformName = @"微博";
            break;
        default:
            break;
    }
    
    NSLog(@"在局🌐 [网页分享] 开始分享到 %@，标题: %@, URL: %@", platformName, titleStr, url);
    
    //创建分享消息对象
    UMSocialMessageObject *messageObject = [UMSocialMessageObject messageObject];
    //创建网页内容对象
    UMShareWebpageObject *shareObject = [UMShareWebpageObject shareObjectWithTitle:titleStr descr:shareText thumImage:imgStr];
    //设置网页地址
    shareObject.webpageUrl = url;
    //分享消息对象设置分享内容对象
    messageObject.shareObject = shareObject;
    
    //调用分享接口
    [[UMSocialManager defaultManager] shareToPlatform:platformType messageObject:messageObject currentViewController:self completion:^(id data, NSError *error) {
        if (error) {
            NSLog(@"在局❌ [网页分享失败] 平台: %@, 错误: %@", platformName, error.localizedDescription);
            UMSocialLogInfo(@"************Share fail with error %@*********",error);
            
            // 回调JavaScript端分享失败
            if (self.webviewBackCallBack) {
                self.webviewBackCallBack(@{
                    @"success": @"false",
                    @"data": @{},
                    @"errorMessage": error.localizedDescription ?: @"分享失败"
                });
            }
        }else{
            if ([data isKindOfClass:[UMSocialShareResponse class]]) {
                UMSocialShareResponse *resp = data;
                //分享结果消息
                UMSocialLogInfo(@"response message is %@",resp.message);
                //第三方原始返回的数据
                UMSocialLogInfo(@"response originalResponse data is %@",resp.originalResponse);
                
            }else{
                UMSocialLogInfo(@"response data is %@",data);
            }
            
            // 回调JavaScript端分享成功
            if (self.webviewBackCallBack) {
                self.webviewBackCallBack(@{
                    @"success": @"true",
                    @"data": @{},
                    @"errorMessage": @""
                });
            }
        }
    }];
}

#pragma mark - 直接微信分享方法 (避免UMSocialManager的openURL问题)

// 直接分享网页到微信
- (void)shareDirectWebPageToWeChat:(NSDictionary *)dic toTimeline:(BOOL)toTimeline {
    NSString *titleStr = [dic objectForKey:@"title"];
    NSString *shareText = [dic objectForKey:@"content"];
    NSString *imgStr = [dic objectForKey:@"img"];
    NSString *url = [dic objectForKey:@"url"];
    
    NSString *targetName = toTimeline ? @"朋友圈" : @"好友";
    
    // 创建多媒体消息结构体
    WXMediaMessage *message = [WXMediaMessage message];
    message.title = titleStr;
    message.description = shareText;
    
    // 创建网页数据对象
    WXWebpageObject *webPageObject = [WXWebpageObject object];
    webPageObject.webpageUrl = url;
    message.mediaObject = webPageObject;
    
    // 异步加载缩略图
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSData *imageData = nil;
        if (imgStr && imgStr.length > 0) {
            imageData = [NSData dataWithContentsOfURL:[NSURL URLWithString:imgStr]];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (imageData) {
                // 压缩图片到32KB以下
                UIImage *image = [UIImage imageWithData:imageData];
                NSData *compressedData = [UIImage compressImage:image toByte:32768];
                message.thumbData = compressedData;
            }
            
            // 创建发送请求
            SendMessageToWXReq *req = [[SendMessageToWXReq alloc] init];
            req.bText = NO;
            req.message = message;
            req.scene = toTimeline ? WXSceneTimeline : WXSceneSession;
            
            // 发送到微信
            [WXApi sendReq:req completion:^(BOOL success) {
                
                // 注意：这里的success只表示调用成功，真正的分享结果会在WXApiDelegate回调中处理
                if (!success) {
                    if (self.webviewBackCallBack) {
                        self.webviewBackCallBack(@{
                            @"success": @"false",
                            @"data": @{},
                            @"errorMessage": @"微信分享调用失败"
                        });
                    }
                }
                // 成功调用的情况下，等待用户操作结果回调
            }];
        });
    });
}

// 直接分享小程序到微信
- (void)shareDirectMiniProgramToWeChat:(NSDictionary *)dic toTimeline:(BOOL)toTimeline {
    NSString *titleStr = [dic objectForKey:@"title"];
    NSString *shareText = [dic objectForKey:@"content"];
    NSString *imgStr = [dic objectForKey:@"img"];
    NSString *url = [dic objectForKey:@"url"];
    NSString *userName = [dic objectForKey:@"wxid"];
    NSString *pagePath = [dic objectForKey:@"pagePath"];
    
    NSString *targetName = toTimeline ? @"朋友圈" : @"好友";
    
    // 创建多媒体消息结构体
    WXMediaMessage *message = [WXMediaMessage message];
    message.title = titleStr;
    message.description = shareText;
    
    // 创建小程序对象
    WXMiniProgramObject *miniProgramObject = [WXMiniProgramObject object];
    miniProgramObject.webpageUrl = url;
    miniProgramObject.userName = userName;
    miniProgramObject.path = pagePath;
    miniProgramObject.miniProgramType = WXMiniProgramTypeRelease; // 正式版
    message.mediaObject = miniProgramObject;
    
    // 异步加载缩略图
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSData *imageData = nil;
        if (imgStr && imgStr.length > 0) {
            imageData = [NSData dataWithContentsOfURL:[NSURL URLWithString:imgStr]];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (imageData) {
                // 压缩图片到128KB以下
                UIImage *image = [UIImage imageWithData:imageData];
                NSData *compressedData = [UIImage compressImage:image toByte:131072];
                message.thumbData = compressedData;
            }
            
            // 创建发送请求
            SendMessageToWXReq *req = [[SendMessageToWXReq alloc] init];
            req.bText = NO;
            req.message = message;
            req.scene = toTimeline ? WXSceneTimeline : WXSceneSession;
            
            // 发送到微信
            [WXApi sendReq:req completion:^(BOOL success) {
                
                if (!success) {
                    if (self.webviewBackCallBack) {
                        self.webviewBackCallBack(@{
                            @"success": @"false",
                            @"data": @{},
                            @"errorMessage": @"微信小程序分享调用失败"
                        });
                    }
                }
            }];
        });
    });
}

//根据web传过来的类型对第三方平台类型赋值
- (UMSocialPlatformType )thirdPlatform:(NSString *)type {
    UMSocialPlatformType snsName;
    if ([type isEqualToString:@"weibo"]) {
        snsName = UMSocialPlatformType_Sina;
    } else if ([type isEqualToString:@"weixin"]) {
        snsName = UMSocialPlatformType_WechatSession;
    } else if ([type isEqualToString:@"moments"]) {
        snsName = UMSocialPlatformType_WechatTimeLine;
    }
    else if ([type isEqualToString:@"qq"]) {
        snsName = UMSocialPlatformType_QQ;
    } else if ([type isEqualToString:@"qqZone"]) {
        snsName = UMSocialPlatformType_Qzone;
    }
    else if ([type isEqualToString:@"twitter"]) {
        snsName = UMSocialPlatformType_Twitter;
    } else if ([type isEqualToString:@"facebook"]) {
        snsName = UMSocialPlatformType_Facebook;
    } else if ([type isEqualToString:@"message"]) {
        snsName = UMSocialPlatformType_Sms;
    }
    else {
        snsName = UMSocialPlatformType_UnKnown;
    }
    return snsName;
}

//支付
- (void)payRequest:(NSDictionary *)dic withPayType:(NSString *)payType{
    /*scheme修改
     info—url types里面进行修改
     PublicSetting.plist里面修改
     */
    NSString *appScheme = [[PublicSettingModel sharedInstance] app_Scheme];
    //支付宝
    if ([payType isEqualToString:@"alipay"]) {
        NSString *sign = [dic objectForKey:@"data"];
        if (!sign || sign.length <= 0) {
            NSLog(@"在局支付宝支付信息出错");
            return;
        }
        [[AlipaySDK defaultService] payOrder:sign fromScheme:appScheme callback:^(NSDictionary *resultDic) {
        }];
    }
    //微信
    else if ([payType isEqualToString:@"weixin"]) {
        NSLog(@"在局🔧 [微信支付] 开始处理微信支付请求，原始数据: %@", dic);
        
        // 兼容两种数据格式：嵌套在data字段中的 和 直接的支付参数
        NSDictionary *messageDic = [dic objectForKey:@"data"];
        if (!messageDic || ![messageDic isKindOfClass:[NSDictionary class]]) {
            // 如果没有data字段，则直接使用dic作为支付参数
            messageDic = dic;
            NSLog(@"在局🔧 [微信支付] 使用直接参数格式");
        } else {
            NSLog(@"在局🔧 [微信支付] 使用嵌套参数格式");
        }
        
        NSLog(@"在局🔧 [微信支付] 处理的支付参数: %@", messageDic);
        
        if (messageDic && [messageDic isKindOfClass:[NSDictionary class]]) {
            // 检查微信是否可用
            if(![WXApi isWXAppInstalled]) {
                NSLog(@"在局❌ [微信支付] 微信应用未安装");
                if (self.webviewBackCallBack) {
                    self.webviewBackCallBack(@{
                        @"success": @"false",
                        @"errorMessage": @"请先安装微信应用"
                    });
                }
                return;
            }
            if (![WXApi isWXAppSupportApi]) {
                NSLog(@"在局❌ [微信支付] 微信版本过低，不支持支付");
                if (self.webviewBackCallBack) {
                    self.webviewBackCallBack(@{
                        @"success": @"false", 
                        @"errorMessage": @"微信版本过低，请升级微信"
                    });
                }
                return;
            }
            
            // 创建支付请求
            PayReq *request = [[PayReq alloc] init];
            
            // 类型安全的参数提取
            id partnerIdObj = [messageDic objectForKey:@"partnerid"];
            request.partnerId = [partnerIdObj isKindOfClass:[NSString class]] ? (NSString *)partnerIdObj : [NSString stringWithFormat:@"%@", partnerIdObj];
            
            request.prepayId = [messageDic objectForKey:@"prepayid"];
            request.package = [messageDic objectForKey:@"package"];
            request.nonceStr = [messageDic objectForKey:@"noncestr"];
            
            // 时间戳类型安全转换
            id timestampObj = [messageDic objectForKey:@"timestamp"];
            if ([timestampObj isKindOfClass:[NSString class]]) {
                request.timeStamp = (UInt32)[(NSString *)timestampObj integerValue];
            } else if ([timestampObj isKindOfClass:[NSNumber class]]) {
                request.timeStamp = (UInt32)[(NSNumber *)timestampObj unsignedIntValue];
            } else {
                request.timeStamp = 0;
            }
            
            NSLog(@"在局🔧 [微信支付] 支付参数设置 - partnerId:%@, prepayId:%@, package:%@, nonceStr:%@, timeStamp:%u", 
                  request.partnerId, request.prepayId, request.package, request.nonceStr, (unsigned int)request.timeStamp);
            
            // 验证必要参数
            if (!request.partnerId || !request.prepayId || !request.package || !request.nonceStr || request.timeStamp == 0) {
                NSLog(@"在局❌ [微信支付] 支付参数不完整");
                if (self.webviewBackCallBack) {
                    self.webviewBackCallBack(@{
                        @"success": @"false",
                        @"errorMessage": @"支付参数不完整"
                    });
                }
                return;
            }
            
            // 重新计算签名（确保签名正确）
            NSString *appid = [[PublicSettingModel sharedInstance] weiXin_AppID];
            NSString *stringA = [NSString stringWithFormat:@"appid=%@&noncestr=%@&package=%@&partnerid=%@&prepayid=%@&timestamp=%u",
                               appid, request.nonceStr, request.package, request.partnerId, request.prepayId, (unsigned int)request.timeStamp];
            NSString *appKey = [[PublicSettingModel sharedInstance] weiXin_Key];
            NSString *stringSignTemp = [NSString stringWithFormat:@"%@&key=%@", stringA, appKey];
            NSString *sign = [stringSignTemp MD5];
            request.sign = [sign uppercaseString];
            
            NSLog(@"在局🔧 [微信支付] 签名计算 - 原字符串: %@", stringA);
            NSLog(@"在局🔧 [微信支付] 签名计算 - 最终签名: %@", request.sign);
            
            // 发送支付请求
            [WXApi sendReq:request completion:^(BOOL success) {
                NSLog(@"在局🔧 [微信支付] 支付请求发送结果: %@", success ? @"成功" : @"失败");
                if (!success && self.webviewBackCallBack) {
                    self.webviewBackCallBack(@{
                        @"success": @"false",
                        @"errorMessage": @"微信支付调用失败"
                    });
                }
            }];
        } else {
            NSLog(@"在局❌ [微信支付] 支付参数格式错误");
            if (self.webviewBackCallBack) {
                self.webviewBackCallBack(@{
                    @"success": @"false",
                    @"errorMessage": @"支付参数格式错误"
                });
            }
        }
    }
}


- (void)handlePayResult:(NSURL *)resultUrl {
    NSURL *url = resultUrl;
    __block NSString *payResultStr = @"";
    if ([url.host isEqualToString:@"safepay"] || [url.host isEqualToString:@"platformapi"]) {
        [[AlipaySDK defaultService] processOrderWithPaymentResult:url standbyCallback:^(NSDictionary *resultDic) {
            //由于在跳转支付宝客户端支付的过程中，商户app在后台很可能被系统kill了，所以pay接口的callback就会失效，请商户对standbyCallback返回的回调结果进行处理,就是在这个方法里面处理跟callback一样的逻辑
            if ([[[resultDic objectForKey:@"resultStatus"] class] isSubclassOfClass:[NSNull class]]) {
                payResultStr = @"failure";
            }
            if([[resultDic objectForKey:@"resultStatus"] integerValue] == 9000){
                payResultStr = @"success";
            }
            else {
                payResultStr = @"failure";
            }
        }];
    }
    else {
        if ([url.absoluteString isEqualToString:@"success"]) {
            payResultStr = @"success";
        }
        else {
            payResultStr = @"failure";
        }
    }
    
    if ([url.host isEqualToString:@"uppayresult"] && ![payResultStr isEqualToString:@"failure"]) {
        return;
    }
    //通知h5支付结果
    NSDictionary *payresult = @{@"payresult" : payResultStr};
    
    if (self.webviewBackCallBack) {
        if ([[payresult objectForKey:@"payresult"] isEqualToString:@"success"]) {
            self.webviewBackCallBack(@{
                                       @"success":@"true",
                                       @"errorMassage":@""
                                       });
        }
        else {
            self.webviewBackCallBack(@{
                                       @"success":@"false",
                                       @"errorMassage":@""
                                       });
            
        }
    }
}
//微信支付回调
- (void)handleweixinPayResult:(NSString *)success {
    if (self.webviewBackCallBack) {
        self.webviewBackCallBack(@{
                                   @"success":success,
                                   @"errorMassage":@""
                                   });
    }
}

// 处理微信分享结果
- (void)handleWechatShareResult:(NSDictionary *)result {
    NSLog(@"在局📨 [处理微信分享结果] 收到通知: %@", result);
    
    if (self.webviewBackCallBack) {
        // 直接将分享结果回调给JavaScript端
        self.webviewBackCallBack(@{
            @"success": [result objectForKey:@"success"] ?: @"false",
            @"data": @{},
            @"errorMessage": [result objectForKey:@"errorMessage"] ?: @"分享失败"
        });
        
        // 清除回调，避免重复调用
        self.webviewBackCallBack = nil;
    }
}

#pragma mark - TZImagePickerController
- (void)pushTZImagePickerControllerWithDic:(NSDictionary *)dataDic {
    NSString *maxCount = [dataDic objectForKey:@"count"];
    if ([maxCount integerValue] <= 0) {
        return;
    }
    TZImagePickerController *imagePickerVc = [[TZImagePickerController alloc] initWithMaxImagesCount:maxCount.integerValue columnNumber:4 delegate:self pushPhotoPickerVc:YES];
    // imagePickerVc.navigationBar.translucent = NO;
    
#pragma mark - 五类个性化设置，这些参数都可以不传，此时会走默认设置
    imagePickerVc.isSelectOriginalPhoto = _isSelectOriginalPhoto;
    imagePickerVc.allowTakePicture = YES; // 在内部显示拍照按钮
    imagePickerVc.allowTakeVideo = NO;   // 在内部显示拍视频按
    imagePickerVc.videoMaximumDuration = 10; // 视频最大拍摄时间
    [imagePickerVc setUiImagePickerControllerSettingBlock:^(UIImagePickerController *imagePickerController) {
        imagePickerController.videoQuality = UIImagePickerControllerQualityTypeHigh;
    }];
    
    // imagePickerVc.photoWidth = 1000;
    
    // 2. Set the appearance
    // 2. 在这里设置imagePickerVc的外观
    // if (iOS8Later) {
    // imagePickerVc.navigationBar.barTintColor = [UIColor greenColor];
    // }
    // imagePickerVc.oKButtonTitleColorDisabled = [UIColor lightGrayColor];
    // imagePickerVc.oKButtonTitleColorNormal = [UIColor greenColor];
    // imagePickerVc.navigationBar.translucent = NO;
    imagePickerVc.iconThemeColor = [UIColor colorWithRed:31 / 255.0 green:185 / 255.0 blue:34 / 255.0 alpha:1.0];
    imagePickerVc.showPhotoCannotSelectLayer = YES;
    imagePickerVc.cannotSelectLayerColor = [[UIColor whiteColor] colorWithAlphaComponent:0.8];
    __weak typeof(imagePickerVc)weakImagePickerVc = imagePickerVc;
    [imagePickerVc setPhotoPickerPageUIConfigBlock:^(UICollectionView *collectionView, UIView *bottomToolBar, UIButton *previewButton, UIButton *originalPhotoButton, UILabel *originalPhotoLabel, UIButton *doneButton, UIImageView *numberImageView, UILabel *numberLabel, UIView *divideLine) {
        [doneButton setTitleColor:weakImagePickerVc.oKButtonTitleColorNormal forState:UIControlStateNormal];
    }];
    /*
     [imagePickerVc setAssetCellDidSetModelBlock:^(TZAssetCell *cell, UIImageView *imageView, UIImageView *selectImageView, UILabel *indexLabel, UIView *bottomView, UILabel *timeLength, UIImageView *videoImgView) {
     cell.contentView.clipsToBounds = YES;
     cell.contentView.layer.cornerRadius = cell.contentView.tz_width * 0.5;
     }];
     */
    
    // 3. Set allow picking video & photo & originalPhoto or not
    // 3. 设置是否可以选择视频/图片/原图
    if ([[dataDic objectForKey:@"mimeType"] isEqualToString:@"video"]) {
        imagePickerVc.allowPickingVideo = YES;
        imagePickerVc.allowPickingImage = NO;
    }
    else {
        imagePickerVc.allowPickingVideo = NO;
        imagePickerVc.allowPickingImage = YES;
    }
    imagePickerVc.allowPickingOriginalPhoto = YES;
    imagePickerVc.allowPickingGif = NO;
    imagePickerVc.allowPickingMultipleVideo = NO; // 是否可以多选视频
    
    // 4. 照片排列按修改时间升序
    imagePickerVc.sortAscendingByModificationDate = YES;
    
    // imagePickerVc.minImagesCount = 3;
    // imagePickerVc.alwaysEnableDoneBtn = YES;
    
    // imagePickerVc.minPhotoWidthSelectable = 3000;
    // imagePickerVc.minPhotoHeightSelectable = 2000;
    
    /// 5. Single selection mode, valid when maxImagesCount = 1
    /// 5. 单选模式,maxImagesCount为1时才生效
    imagePickerVc.showSelectBtn = NO;
    imagePickerVc.allowCrop = NO;
    imagePickerVc.needCircleCrop =NO;
    // 设置竖屏下的裁剪尺寸
    NSInteger left = 30;
    NSInteger widthHeight = self.view.tz_width - 2 * left;
    NSInteger top = (self.view.tz_height - widthHeight) / 2;
    imagePickerVc.cropRect = CGRectMake(left, top, widthHeight, widthHeight);
    // 设置横屏下的裁剪尺寸
    // imagePickerVc.cropRectLandscape = CGRectMake((self.view.tz_height - widthHeight) / 2, left, widthHeight, widthHeight);
    /*
     [imagePickerVc setCropViewSettingBlock:^(UIView *cropView) {
     cropView.layer.borderColor = [UIColor redColor].CGColor;
     cropView.layer.borderWidth = 2.0;
     }];*/
    
    //imagePickerVc.allowPreview = NO;
    // 自定义导航栏上的返回按钮
    /*
     [imagePickerVc setNavLeftBarButtonSettingBlock:^(UIButton *leftButton){
     [leftButton setImage:[UIImage imageNamed:@"back"] forState:UIControlStateNormal];
     [leftButton setImageEdgeInsets:UIEdgeInsetsMake(0, -10, 0, 20)];
     }];
     imagePickerVc.delegate = self;
     */
    
    //设置状态栏风格
    imagePickerVc.statusBarStyle = UIStatusBarStyleLightContent;
    
    // 设置是否显示图片序号
    imagePickerVc.showSelectedIndex = YES;
    // 设置首选语言 / Set preferred language
    // imagePickerVc.preferredLanguage = @"zh-Hans";
    
    // 设置languageBundle以使用其它语言 / Set languageBundle to use other language
    // imagePickerVc.languageBundle = [NSBundle bundleWithPath:[[NSBundle mainBundle] pathForResource:@"tz-ru" ofType:@"lproj"]];
    
#pragma mark - 到这里为止
    
    // You can get the photos by block, the same as by delegate.
    // 你可以通过block或者代理，来得到用户选择的照片.
    [imagePickerVc setDidFinishPickingPhotosHandle:^(NSArray<UIImage *> *photos, NSArray *assets, BOOL isSelectOriginalPhoto) {
        
    }];
    
    [self presentViewController:imagePickerVc animated:YES completion:nil];
}

#pragma mark - TZImagePickerControllerDelegate

/// User click cancel button
/// 用户点击了取消
- (void)tz_imagePickerControllerDidCancel:(TZImagePickerController *)picker {
    NSLog(@"在局=====================用户点击了取消");
}

// 这个照片选择器会自己dismiss，当选择器dismiss的时候，会执行下面的代理方法
// 如果isSelectOriginalPhoto为YES，表明用户选择了原图
// 你可以通过一个asset获得原图，通过这个方法：[[TZImageManager manager] getOriginalPhotoWithAsset:completion:]
// photos数组里的UIImage对象，默认是828像素宽，你可以通过设置photoWidth属性的值来改变它
- (void)imagePickerController:(TZImagePickerController *)picker didFinishPickingPhotos:(NSArray<UIImage *> *)photos sourceAssets:(NSArray *)assets isSelectOriginalPhoto:(BOOL)isSelectOriginalPhoto infos:(NSArray<NSDictionary *> *)infos {
    _isSelectOriginalPhoto = isSelectOriginalPhoto;
    _selectedAssets = [assets mutableCopy];
    if (!_isSelectOriginalPhoto) {
        _selectedPhotos = [NSMutableArray arrayWithArray:photos];
        NSMutableArray *dataArray = [NSMutableArray arrayWithCapacity:0];
        for (NSInteger i = 0; i < _selectedPhotos.count; i++) {
            UIImage *image = _selectedPhotos[i];
            NSData *imageData = UIImagePNGRepresentation(image);
            NSDictionary *dic = @{@"name":[NSString stringWithFormat:@"%ld",(long)i],
                                  @"size":[self getBytesFromDataLength:imageData.length],
                                  @"type":@"image/jpeg",
                                  @"lastModified":@""
            };
            [dataArray addObject:dic];
        }
        if (self.webviewBackCallBack) {
            // 使用新的格式化方法，返回JavaScript端期望的格式
            NSDictionary *response = [self formatCallbackResponse:@"chooseFile" 
                                                           data:dataArray 
                                                        success:YES 
                                                   errorMessage:nil];
            self.webviewBackCallBack(response);
        }
    } else {
        // 3. 获取原图的示例，这样一次性获取很可能会导致内存飙升，建议获取1-2张，消费和释放掉，再获取剩下的
        __block NSMutableArray *originalPhotos = [NSMutableArray array];
        __block NSInteger finishCount = 0;
        for (NSInteger i = 0; i < assets.count; i++) {
            [originalPhotos addObject:@1];
        }
        for (NSInteger i = 0; i < assets.count; i++) {
            PHAsset *asset = assets[i];
            WEAK_SELF;
            [[TZImageManager manager] getOriginalPhotoWithAsset:asset completion:^(UIImage *photo, NSDictionary *info) {
                STRONG_SELF;
                finishCount += 1;
                [originalPhotos replaceObjectAtIndex:i withObject:photo];
                if (finishCount >= assets.count) {
                    NSLog(@"在局All finished.");
                    self->_selectedPhotos = originalPhotos;
                    NSMutableArray *dataArray = [NSMutableArray arrayWithCapacity:0];
                    for (NSInteger i = 0; i < self->_selectedPhotos.count; i++) {
                        UIImage *image = self->_selectedPhotos[i];
                        NSData *imageData = UIImagePNGRepresentation(image);
                        NSDictionary *dic = @{@"name":[NSString stringWithFormat:@"%ld",(long)i],
                                              @"size":[self getBytesFromDataLength:imageData.length],
                                              @"type":@"image/jpeg",
                                              @"lastModified":@""
                        };
                        [dataArray addObject:dic];
                    }
                    if (self.webviewBackCallBack) {
                        // 使用新的格式化方法，返回JavaScript端期望的格式
                        NSDictionary *response = [self formatCallbackResponse:@"chooseFile" 
                                                                       data:dataArray 
                                                                    success:YES 
                                                               errorMessage:nil];
                        self.webviewBackCallBack(response);
                    }
                }
            }];
        }
    }
}

// If user picking a video, this callback will be called.
// If system version > iOS8,asset is kind of PHAsset class, else is ALAsset class.
// 如果用户选择了一个视频，下面的handle会被执行
// 如果系统版本大于iOS8，asset是PHAsset类的对象，否则是ALAsset类的对象
- (void)imagePickerController:(TZImagePickerController *)picker didFinishPickingVideo:(UIImage *)coverImage sourceAssets:(PHAsset *)asset {
    // open this code to send video / 打开这段代码发送视频
    [[TZImageManager manager] getVideoOutputPathWithAsset:asset presetName:AVAssetExportPreset640x480 success:^(NSString *outputPath) {
        NSLog(@"在局视频导出到本地完成,沙盒路径为:%@",outputPath);
        // Export completed, send video here, send by outputPath or NSData
        // 导出完成，在这里写上传代码，通过路径或者通过NSData上传
        NSData *data = [NSData dataWithContentsOfFile:outputPath options:(NSDataReadingUncached) error:nil];
        NSMutableArray *dataArray = [NSMutableArray arrayWithCapacity:0];
        NSDictionary *dic = @{@"name":[NSString stringWithFormat:@"%d",0],
                              @"size":[self getBytesFromDataLength:data.length],
                              @"type":@"video/mpeg",
                              @"lastModified":@""
        };
        [dataArray addObject:dic];
        if (self.webviewBackCallBack) {
            self.webviewBackCallBack(
                                     @{@"data":dataArray,
                                       @"success":@"true",
                                       @"errorMessage":@""
                                     }
                                     );
        }
        self->_selectedVideo = [NSMutableArray arrayWithCapacity:1];
        [self->_selectedVideo addObject:data];
        self-> _videoPath = outputPath;
    } failure:^(NSString *errorMessage, NSError *error) {
        NSLog(@"在局视频导出失败:%@,error:%@",errorMessage, error);
    }];
    // _collectionView.contentSize = CGSizeMake(0, ((_selectedPhotos.count + 2) / 3 ) * (_margin + _itemWH));
}

// If user picking a gif image, this callback will be called.
// 如果用户选择了一个gif图片，下面的handle会被执行
- (void)imagePickerController:(TZImagePickerController *)picker didFinishPickingGifImage:(UIImage *)animatedImage sourceAssets:(PHAsset *)asset {
    _selectedPhotos = [NSMutableArray arrayWithArray:@[animatedImage]];
}

// Decide album show or not't
// 决定相册显示与否
- (BOOL)isAlbumCanSelect:(NSString *)albumName result:(PHFetchResult *)result {
    /*
     if ([albumName isEqualToString:@"个人收藏"]) {
     return NO;
     }
     if ([albumName isEqualToString:@"视频"]) {
     return NO;
     }*/
    return YES;
}

// Decide asset show or not't
// 决定asset显示与否
- (BOOL)isAssetCanSelect:(PHAsset *)asset {
    /*
     if (iOS8Later) {
     PHAsset *phAsset = asset;
     switch (phAsset.mediaType) {
     case PHAssetMediaTypeVideo: {
     // 视频时长
     // NSTimeInterval duration = phAsset.duration;
     return NO;
     } break;
     case PHAssetMediaTypeImage: {
     // 图片尺寸
     if (phAsset.pixelWidth > 3000 || phAsset.pixelHeight > 3000) {
     // return NO;
     }
     return YES;
     } break;
     case PHAssetMediaTypeAudio:
     return NO;
     break;
     case PHAssetMediaTypeUnknown:
     return NO;
     break;
     default: break;
     }
     } else {
     ALAsset *alAsset = asset;
     NSString *alAssetType = [[alAsset valueForProperty:ALAssetPropertyType] stringValue];
     if ([alAssetType isEqualToString:ALAssetTypeVideo]) {
     // 视频时长
     // NSTimeInterval duration = [[alAsset valueForProperty:ALAssetPropertyDuration] doubleValue];
     return NO;
     } else if ([alAssetType isEqualToString:ALAssetTypePhoto]) {
     // 图片尺寸
     CGSize imageSize = alAsset.defaultRepresentation.dimensions;
     if (imageSize.width > 3000) {
     // return NO;
     }
     return YES;
     } else if ([alAssetType isEqualToString:ALAssetTypeUnknown]) {
     return NO;
     }
     }*/
    return YES;
}

#pragma mark ----- 获取当前显示控制器

- (UIViewController*) findBestViewController:(UIViewController*)vc {
    
    if (vc.presentedViewController) {
        
        // Return presented view controller
        return [self findBestViewController:vc.presentedViewController];
        
    } else if ([vc isKindOfClass:[UISplitViewController class]]) {
        
        // Return right hand side
        UISplitViewController* svc = (UISplitViewController*) vc;
        if (svc.viewControllers.count > 0) {
            return [self findBestViewController:svc.viewControllers.lastObject];
        } else {
            return vc;
        }
        
    } else if ([vc isKindOfClass:[UINavigationController class]]) {
        
        // Return top view
        UINavigationController* svc = (UINavigationController*) vc;
        if (svc.viewControllers.count > 0) {
            return [self findBestViewController:svc.topViewController];
        } else {
            return vc;
        }
    } else if ([vc isKindOfClass:[UITabBarController class]]) {
        
        // Return visible view
        UITabBarController* svc = (UITabBarController*) vc;
        if (svc.viewControllers.count > 0) {
            return [self findBestViewController:svc.selectedViewController];
        }
        else {
            return vc;
        }
        
    } else {
        // Unknown view controller type, return last child view controller
        return vc;
        
    }
    
}

- (UIViewController*) currentViewController {
    
    // 确保在主线程访问UI API
    if (![NSThread isMainThread]) {
        __block UIViewController *result = nil;
        dispatch_sync(dispatch_get_main_queue(), ^{
            result = [self currentViewController];
        });
        return result;
    }
    
    // Find best view controller
    UIViewController* viewController = [UIApplication sharedApplication].keyWindow.rootViewController;
    return [self findBestViewController:viewController];
    
}

//字符串转日期格式
- (NSDate *)stringToDate:(NSString *)dateString withDateFormat:(NSString *)format {
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:format];
    
    NSDate *date = [dateFormatter dateFromString:dateString];
    return date;
}

//将世界时间转化为中国区时间
- (NSDate *)worldTimeToChina:(NSDate *)date {
    NSTimeZone *timeZone = [NSTimeZone systemTimeZone];
    NSInteger interval = [timeZone secondsFromGMTForDate:date];
    NSDate *localeDate = [date  dateByAddingTimeInterval:interval];
    return localeDate;
}

//判断是否开启定位权限
- (BOOL)isLocationServiceOpen {
    if ([ CLLocationManager authorizationStatus] == kCLAuthorizationStatusDenied) {
        return NO;
    } else
        return YES;
}

#pragma mark -------- 设置状态条

- (UIStatusBarStyle)preferredStatusBarStyle {
    NSString *statusBarTextColor = [[NSUserDefaults standardUserDefaults] objectForKey:@"StatusBarTextColor"];
    NSString *bgcolor = [self.navDic objectForKey:@"navBgcolor"];
    
    // 如果导航栏被隐藏（如首页），默认使用黑色状态栏文字
    if ([self isHaveNativeHeader:self.pinUrl]) {
        return UIStatusBarStyleDefault;  // 黑色文字
    }
    
    if ([bgcolor isEqualToString:@"#FFFFFF"] || [bgcolor isEqualToString:@"white"]) {
        return UIStatusBarStyleDefault;
    }
    if ([statusBarTextColor isEqualToString:@"#000000"] || [statusBarTextColor isEqualToString:@"black"]) {
        return UIStatusBarStyleDefault;
    } else {
        return UIStatusBarStyleLightContent;
    }
}

//隐藏导航
- (void)hideNavatinBar {
    [self.navigationController setNavigationBarHidden:YES animated:YES];
    [self.webView mas_updateConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.view);
        make.right.equalTo(self.view);
        make.bottom.equalTo(self.view);
        // TODO: 需要在Xcode中添加XZiOSVersionManager文件后使用
        // make.top.equalTo(self.view.mas_top).offset([XZiOSVersionManager sharedManager].statusBarHeight);
        make.top.equalTo(self.view.mas_top).offset(20); // 临时使用固定值
    }];
    [self.view layoutIfNeeded];
}

//显示导航
- (void)showNavatinBar {
    [self.navigationController setNavigationBarHidden:NO animated:YES];
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"NoTabBar"]) {
        [self.webView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.left.equalTo(self.view);
            make.right.equalTo(self.view);
            make.bottom.equalTo(self.view).offset(49);
            make.top.equalTo(self.view);
        }];
    } else {
        [self.webView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.left.equalTo(self.view);
            make.right.equalTo(self.view);
            make.bottom.equalTo(self.view);
            make.top.equalTo(self.view);
        }];
        
    }
    [self.view layoutIfNeeded];
}

#pragma mark - YBPopupMenuDelegate

- (void)ybPopupMenu:(YBPopupMenu *)ybPopupMenu didSelectedAtIndex:(NSInteger)index {
    //YBPopupMenu  代理方法
}

//播放完成回调
- (void)playerItemDidReachEnd {
    NSDictionary *callJsDic = [CustomHybridProcessor custom_objcCallJsWithFn:@"playEnd" data:nil];
    [self objcCallJs:callJsDic];
}

#pragma mark   2.0  方法

// 重写父类的rpcRequestWithJsDic方法
- (void)rpcRequestWithJsDic:(NSDictionary *)dataDic completion:(void(^)(id result))completion {
    [self rpcRequestWithJsDic:dataDic jsCallBack:completion];
}

//2.0  request方法执行请求
- (void)rpcRequestWithJsDic:(NSDictionary *)dataDic
                 jsCallBack:(XZWebViewJSCallbackBlock)jsCallBack {
    
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
            if (jsCallBack) {
                // 获取服务器响应数据
                NSDictionary *serverResponse = responseObject;
                
                // 检查服务器响应的成功状态
                BOOL isSuccess = NO;
                NSNumber *codeValue = [serverResponse objectForKey:@"code"];
                if (codeValue && [codeValue intValue] == 0) {
                    isSuccess = YES;
                }
                
                // 使用formatCallbackResponse方法保持格式一致
                NSDictionary *jsResponse = [self formatCallbackResponse:@"request" 
                                                                  data:serverResponse 
                                                               success:isSuccess 
                                                          errorMessage:[serverResponse objectForKey:@"errorMessage"] ?: @""];
                
                jsCallBack(jsResponse);
            }
        } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
            if (jsCallBack) {
                // 使用formatCallbackResponse方法保持格式一致
                NSDictionary *errorResponse = [self formatCallbackResponse:@"request" 
                                                                      data:@{} 
                                                                   success:NO 
                                                              errorMessage:error.localizedDescription ?: @"网络请求失败"];
                jsCallBack(errorResponse);
            }
        }];
    });
}

//2.0登录/退出调用方法
- (void)RequestWithJsDic:(NSDictionary *)dataDic type:(NSString *)type{
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
        AFSecurityPolicy *securityPolicy =  [AFSecurityPolicy defaultPolicy];
        // 客户端是否信任非法证书
        securityPolicy.allowInvalidCertificates = YES;
        // 是否在证书域字段中验证域名
        securityPolicy.validatesDomainName = NO;
        manager.securityPolicy = securityPolicy;
        manager.responseSerializer = [AFJSONResponseSerializer serializer];
        manager.requestSerializer = [AFHTTPRequestSerializer serializer];
        manager.requestSerializer.timeoutInterval = 45;
        //CFJ新加
        manager.responseSerializer.acceptableContentTypes = [NSSet setWithObjects:@"application/json", @"text/plain", @"text/javascript", @"text/json", @"text/html", nil];
        NSDictionary *header = [dataDic objectForKey:@"header"];
        for (NSString *key in [header allKeys]) {
            [manager.requestSerializer setValue:[header objectForKey:key] forHTTPHeaderField:key];
        }
        NSString *deviceTokenStr = [[NSUserDefaults standardUserDefaults] objectForKey:@"User_ChannelId"];
        deviceTokenStr = deviceTokenStr ? deviceTokenStr : @"";
        NSDictionary *parameters = @{@"from":@"1",
                                     @"type":type,
                                     @"channel":deviceTokenStr};
        NSLog(@"在局xxxxgetloginLinkUrl:%@",[CustomHybridProcessor custom_getloginLinkUrl]);
        [manager POST:[CustomHybridProcessor custom_getloginLinkUrl] parameters:parameters headers:nil progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nonnull responseObject) {
            NSLog(@"在局成功");
        } failure:^(NSURLSessionDataTask * _Nonnull task, NSError * _Nonnull error) {
            NSLog(@"在局失败");
        }];
    });
}

#pragma mark ------ 七牛上传

- (void)QiNiuUploadImageWithData:(NSDictionary *)datadic{
    // 修复：nameIndex实际上是文件名，不是数组索引
    // 我们需要找到对应的文件索引，或者使用第一个文件（单文件上传场景）
    NSInteger index = 0; // 默认使用第一个文件
    NSString *nameIndex = [datadic objectForKey:@"nameIndex"];
    
    // 如果nameIndex是数字字符串，则使用它作为索引
    if (nameIndex && [nameIndex rangeOfCharacterFromSet:[[NSCharacterSet decimalDigitCharacterSet] invertedSet]].location == NSNotFound) {
        NSInteger providedIndex = [nameIndex integerValue];
        if (providedIndex >= 0 && providedIndex < _selectedAssets.count) {
            index = providedIndex;
        }
    }
    
    // 安全检查：确保索引在有效范围内
    if (index >= _selectedAssets.count || index >= _selectedPhotos.count) {
        index = 0;
    }
    
    NSString *qiniuToken = [datadic objectForKey:@"token"];
    PHAsset *asset = _selectedAssets[index];
    UIImage *image = _selectedPhotos[index];
    WEAK_SELF;
    self.isCancel = NO;
    self.cancelSignal = ^BOOL {
        STRONG_SELF;
        return self.isCancel;
    };
    QNUploadOption *opt = [[QNUploadOption alloc] initWithMime:nil progressHandler:^(NSString *key, float percent) {
        STRONG_SELF;
        dispatch_async(dispatch_get_main_queue(), ^{
            // 修复：确保进度值是数字类型，且字段名匹配JavaScript端期望
            NSInteger percentValue = (NSInteger)(percent * 100);
            
            NSDictionary *data = @{@"progress": @(percentValue)};  // 使用NSNumber而不是字符串
            NSDictionary *callJsDic = [CustomHybridProcessor custom_objcCallJsWithFn:@"uploadFile" data:data];
            [self objcCallJs:callJsDic];
        });
    } params:nil checkCrc:NO cancellationSignal:self.cancelSignal];
    NSData *data;
    if ([[datadic objectForKey:@"type"] isEqualToString:@"video/mpeg"]) {
        data = [_selectedVideo objectAtIndex:0];
        [self QiNiuUploadData:data andAsset:asset qiniuToken:qiniuToken option:opt isVideo:YES];
        
    } else {
        data = [UIImage compressImage:image toByte:1024 * 1024 * 2.0];
        [self QiNiuUploadData:data andAsset:asset qiniuToken:qiniuToken option:opt isVideo:NO];
        
    }
}

- (void)QiNiuUploadData:(NSData *)imgData andAsset:(PHAsset *)asset qiniuToken:(NSString *)qiniuToken option:(QNUploadOption *)opt isVideo:(BOOL)isVideo{
    
    // 使用PHAssetResource获取文件名，这是公开API
    NSString *extensions = @"jpg"; // 默认扩展名
    NSArray<PHAssetResource *> *resources = [PHAssetResource assetResourcesForAsset:asset];
    if (resources.count > 0) {
        PHAssetResource *resource = resources.firstObject;
        NSString *originalFilename = resource.originalFilename;
        extensions = [[originalFilename pathExtension] lowercaseString];
    } else {
    }
    
    // 如果是视频且无法获取扩展名，使用mp4
    if (isVideo && extensions.length == 0) {
        extensions = @"mp4";
    }
    
    NSString *fileName = [NSString stringWithFormat:@"%@.%@",[self getFileName],extensions];
    WEAK_SELF;
    [[QNUploadManager sharedInstanceWithConfiguration:nil] putData:imgData key:fileName token:qiniuToken complete:^(QNResponseInfo *info, NSString *key, NSDictionary *resp) {
        if (![[resp class] isSubclassOfClass:[NSDictionary class]]) {
            return ;
        }
        STRONG_SELF;
        dispatch_async(dispatch_get_main_queue(), ^{
            // 修复：上传完成时只发送key，不发送progress
            NSDictionary *data = @{@"key": key ?: @""};
            NSDictionary *callJsDic = [CustomHybridProcessor custom_objcCallJsWithFn:@"uploadFile" data:data];
            [self objcCallJs:callJsDic];
            if (isVideo) {
                NSFileManager *fileManager = [NSFileManager defaultManager];
                if (self->_videoPath) {
                    [fileManager removeItemAtPath:self->_videoPath error:nil];
                }
            }
        });
    } option:opt];
}

- (NSString *)getFileName {
    NSTimeInterval interval = [[NSDate date] timeIntervalSince1970];
    int y = (arc4random() % 10000) + 11111;
    NSString *file = [NSString stringWithFormat:@"%.f%d",interval,y];
    return file;
}

//根据链接获取角标
- (NSInteger)getIndexByUrl:(NSString *)currentUrl :(NSArray *)urls {
    return  [urls indexOfObject:currentUrl] ? [urls indexOfObject:currentUrl] : 0;
}

//获取图片大小
- (NSString *)getBytesFromDataLength:(NSInteger)dataLength {
    NSString *bytes;
    bytes = [NSString stringWithFormat:@"%ld",(long)dataLength];
    return bytes;
}

#pragma mark - JFCityViewControllerDelegate

- (void)cityName:(NSString *)name cityCode:(id)code {
    NSLog(@"在局🔧 [地区选择回调] 收到城市选择: name=%@, code=%@ (类型:%@)", name, code, [code class]);
    NSLog(@"在局🔍 [地区选择回调] webviewBackCallBack存在: %@", self.webviewBackCallBack ? @"是" : @"否");
    
    // 类型安全检查和转换
    NSString *safeCode = nil;
    if (code) {
        if ([code isKindOfClass:[NSString class]]) {
            safeCode = (NSString *)code;
        } else if ([code isKindOfClass:[NSNumber class]]) {
            safeCode = [(NSNumber *)code stringValue];
            NSLog(@"在局🔧 [地区选择回调] NSNumber转换为NSString: %@ -> %@", code, safeCode);
        } else {
            safeCode = [NSString stringWithFormat:@"%@", code];
            NSLog(@"在局🔧 [地区选择回调] 其他类型转换为NSString: %@ -> %@", code, safeCode);
        }
    }
    
    // 类型安全检查和转换 - 确保name也是字符串类型
    NSString *safeName = nil;
    if (name) {
        if ([name isKindOfClass:[NSString class]]) {
            safeName = name;
        } else {
            safeName = [NSString stringWithFormat:@"%@", name];
            NSLog(@"在局🔧 [地区选择回调] name转换为NSString: %@ -> %@", name, safeName);
        }
    }
    
    // 保存选择的城市到本地存储
    if (safeName && safeName.length > 0) {
        [[NSUserDefaults standardUserDefaults] setObject:safeName forKey:@"SelectCity"];
        [[NSUserDefaults standardUserDefaults] setObject:safeName forKey:@"currentCity"];
        [[NSUserDefaults standardUserDefaults] setObject:safeName forKey:@"locationCity"]; // 同时更新locationCity
        if (safeCode && safeCode.length > 0) {
            [[NSUserDefaults standardUserDefaults] setObject:safeCode forKey:@"currentCityCode"];
        }
        [[NSUserDefaults standardUserDefaults] synchronize];
        NSLog(@"在局💾 [地区选择回调] 已保存城市信息: %@-%@", safeName, safeCode);
    }
    
    if (self.webviewBackCallBack) {
        // 为不同的JavaScript调用提供不同的返回格式
        // areaSelect: 返回 cityTitle 和 cityCode
        // selectLocationCity: 返回 name 和 code
        
        NSDictionary *areaSelectData = @{@"cityTitle": safeName ?: @"", @"cityCode": safeCode ?: @""};
        NSDictionary *citySelectData = @{@"name": safeName ?: @"", @"code": safeCode ?: @"", @"city": safeName ?: @""};
        
        // 默认使用areaSelect格式，同时支持selectLocationCity格式
        NSDictionary *response = [self formatCallbackResponse:@"areaSelect" 
                                                         data:areaSelectData 
                                                      success:YES 
                                                 errorMessage:nil];
        
        // 添加额外的城市信息供兼容
        NSMutableDictionary *mutableResponse = [response mutableCopy];
        NSMutableDictionary *mutableData = [mutableResponse[@"data"] mutableCopy];
        [mutableData addEntriesFromDictionary:citySelectData];
        mutableResponse[@"data"] = mutableData;
        
        NSLog(@"在局🔧 [地区选择回调] 准备返回数据: %@", mutableResponse);
        
        // 在返回回调数据之前，先设置JavaScript端的存储
        if (safeName && safeName.length > 0) {
            NSString *jsCode = [NSString stringWithFormat:@"app.storage.set('areaname', '%@')", safeName];
            [self safelyEvaluateJavaScript:jsCode completionHandler:^(id result, NSError *error) {
                if (error) {
                    NSLog(@"在局⚠️ [地区选择回调] 设置areaname存储失败: %@", error.localizedDescription);
                } else {
                    NSLog(@"在局✅ [地区选择回调] 已设置areaname存储: %@", safeName);
                }
            }];
        }
        
        self.webviewBackCallBack(mutableResponse);
        self.webviewBackCallBack = nil; // 清空回调防止重复调用
    } else {
        NSLog(@"在局⚠️ [地区选择回调] webviewBackCallBack为空，无法返回数据");
    }
    
    // 自动关闭城市选择页面
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.navigationController && self.navigationController.viewControllers.count > 1) {
            [self.navigationController popViewControllerAnimated:YES];
            NSLog(@"在局✅ [地区选择回调] 已自动关闭城市选择页面");
        }
    });
    
    // 发送城市变更通知，让其他页面知道城市已变更
    [[NSNotificationCenter defaultCenter] postNotificationName:@"CityChanged" object:@{@"cityName": safeName ?: @"", @"cityCode": safeCode ?: @""}];
}

#pragma mark --- JFLocationDelegate

//定位中...
- (void)locating {
    NSLog(@"在局定位中...");
}

//定位成功
- (void)currentLocation:(NSDictionary *)locationDictionary {
    NSString *city = [locationDictionary valueForKey:@"City"];
    NSString *currentLat = [locationDictionary valueForKey:@"currentLat"];
    NSString *currentLng = [locationDictionary valueForKey:@"currentLng"];
    [KCURRENTCITYINFODEFAULTS setObject:city forKey:@"locationCity"];
    [KCURRENTCITYINFODEFAULTS setObject:city forKey:@"SelectCity"];
    [KCURRENTCITYINFODEFAULTS setObject:currentLat forKey:@"currentLat"];
    [KCURRENTCITYINFODEFAULTS setObject:currentLng forKey:@"currentLng"];
    [KCURRENTCITYINFODEFAULTS synchronize];
}

/// 拒绝定位
- (void)refuseToUsePositioningSystem:(NSString *)message {
    NSLog(@"在局%@",message);
}

/// 定位失败
- (void)locateFailure:(NSString *)message {
    NSLog(@"在局%@",message);
}

//处理定位原生头部
- (void)location {
    NSString *title = [[[NSUserDefaults standardUserDefaults] objectForKey:@"currentCity"] length] ? [[NSUserDefaults standardUserDefaults] objectForKey:@"currentCity"] : @"请选择";
    self.navigationItem.leftBarButtonItem = [UIBarButtonItem leftItemWithtitle:title Color:@"#000000" Target:self action:@selector(selectLocation:)];
}

//处理扫描二维码
- (void)QrScan {
    self.navigationItem.rightBarButtonItem = [UIBarButtonItem rightItemTarget:self action:@selector(QrScanAction:)];
}

- (void)QrScanAction:(UIButton *)sender {
    CFJScanViewController *qrVC = [[CFJScanViewController alloc]init];
    qrVC.hidesBottomBarWhenPushed = YES;
    [self.navigationController pushViewController:qrVC animated:YES];
}

//判断是否开启定位权限
- (BOOL)isHaveNativeHeader:(NSString *)url{
    NSLog(@"在局🔍 [isHaveNativeHeader] 检查URL: %@", url ?: @"nil");
    NSLog(@"在局🔍 [isHaveNativeHeader] ulrArray: %@", [XZPackageH5 sharedInstance].ulrArray);
    BOOL shouldHide = [[XZPackageH5 sharedInstance].ulrArray containsObject:url];
    NSLog(@"在局🔍 [isHaveNativeHeader] 结果: %@", shouldHide ? @"YES - 隐藏导航栏" : @"NO - 显示导航栏");
    return shouldHide;
}

- (void)handleJsCallNative:(NSDictionary *)jsDic {
    NSString *function = [jsDic objectForKey:@"function"];
    NSDictionary *dataDic = [jsDic objectForKey:@"data"];
    NSString *callbackId = [jsDic objectForKey:@"callbackId"];
    
    // 将回调适配为新的格式
    XZWebViewJSCallbackBlock callback = ^(id responseData) {
        if (callbackId) {
                         NSString *jsCode = [NSString stringWithFormat:@"window.xzBridgeCallbackHandler('%@', %@)", 
                                callbackId, [self jsonStringFromObject:responseData]];
            [self callJavaScript:jsCode completion:nil];
        }
    };
    
    //保存图片
    if ([function isEqualToString:@"saveImage"]) {
        self.webviewBackCallBack = callback;
        PHAuthorizationStatus author = [PHPhotoLibrary authorizationStatus];
        if (author == kCLAuthorizationStatusRestricted || author ==kCLAuthorizationStatusDenied){
            //无权限
            NSString *tips = [NSString stringWithFormat:@"请在设备的设置-隐私-照片选项中，允许应用访问你的照片"];
            [JHSysAlertUtil presentAlertViewWithTitle:@"温馨提示" message:tips confirmTitle:@"确定" handler:nil];
            return;
        }
        else {
            NSString *imageStr = dataDic[@"filePath"];
            [self saveImageToPhotos:[self getImageFromURL:imageStr]];
        }
    }
    
    //关闭模态弹窗
    if ([function isEqualToString:@"closePresentWindow"]) {
        [self dismissViewControllerAnimated:YES completion:nil];
        return;
    }
    
    //更换页面标题
    if ([function isEqualToString:@"setNavigationBarTitle"]) {
        NSString *newTitle = [dataDic objectForKey:@"title"];
        dispatch_async(dispatch_get_main_queue(), ^{
            self.navigationItem.title = newTitle;
        });
        return;
    }
    if ([function isEqualToString:@"weixinLogin"]) {
        self.webviewBackCallBack = callback;
        [self thirdLogin:@{@"type":@"weixin"}];
    }
    //微信支付
    if ([function isEqualToString:@"weixinPay"]) {
        self.webviewBackCallBack = callback;
        [self payRequest:jsDic withPayType:@"weixin"];
    }
    //支付宝支付
    if ([function isEqualToString:@"aliPay"]) {
        self.webviewBackCallBack = callback;
        [self payRequest:jsDic withPayType:@"alipay"];
    }
    //选择文件
    if ([function isEqualToString:@"chooseFile"]) {
        self.webviewBackCallBack = callback;
        [self pushTZImagePickerControllerWithDic:dataDic];
    }
    //上传文件
    if ([function isEqualToString:@"uploadFile"]) {
        [self QiNiuUploadImageWithData:dataDic];
    }
    //扫描二维码
    if ([function isEqualToString:@"QRScan"]) {
        CFJScanViewController *qrVC = [[CFJScanViewController alloc]init];
        qrVC.hidesBottomBarWhenPushed = YES;
        [self.navigationController pushViewController:qrVC animated:YES];
        return;
    }
#pragma mark ----CFJ修改浏览图片
    if ([function isEqualToString:@"previewImage"]) {
        self.viewImageAry = [dataDic objectForKey:@"urls"];
        NSInteger currentIndex = [self getIndexByUrl:[dataDic objectForKey:@"current"] : self.viewImageAry];
        [[LBPhotoBrowserManager defaultManager] showImageWithURLArray:self.viewImageAry fromImageViewFrames:nil selectedIndex:currentIndex imageViewSuperView:self.view];
        [[[LBPhotoBrowserManager.defaultManager addLongPressShowTitles:@[@"保存",@"取消"]] addTitleClickCallbackBlock:^(UIImage *image, NSIndexPath *indexPath, NSString *title, BOOL isGif, NSData *gifImageData) {
            LBPhotoBrowserLog(@"%@",title);
            if(![title isEqualToString:@"保存"]) return;
            if (!isGif) {
                [[LBAlbumManager shareManager] saveImage:image];
            }
            else {
                [[LBAlbumManager shareManager] saveGifImageWithData:gifImageData];
            }
        }]addPhotoBrowserWillDismissBlock:^{
            LBPhotoBrowserLog(@"即将销毁");
        }];
    }
    //登录
    if ([function isEqualToString:@"userLogin"]) {
        [self RequestWithJsDic:dataDic type:@"1"];
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"isLogin"];
        [[NSUserDefaults standardUserDefaults]synchronize];
    }
    //退出登录
    if ([function isEqualToString:@"userLogout"]) {
        [self RequestWithJsDic:dataDic type:@"2"];
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"isLogin"];
        [[NSUserDefaults standardUserDefaults]synchronize];
    }
    
    //返回首层页面
    if ([function isEqualToString:@"switchTab"]) {
        [self.navigationController popToRootViewControllerAnimated:YES];
        NSString *number  =[[XZPackageH5 sharedInstance] getNumberWithLink:(NSString *)dataDic];
        NSDictionary *setDic = @{
            @"selectNumber": number
        };
        [[NSNotificationCenter defaultCenter] postNotificationName:@"switchTab" object:setDic];
    }
}

// 添加回调方法实现
- (void)callBack:(NSString *)type params:(NSDictionary *)params {
    if (self.webviewBackCallBack) {
        self.webviewBackCallBack(@{
            @"type": type,
            @"data": params,
            @"success": @"true",
            @"errorMessage": @""
        });
    }
}

#pragma mark - Utility Methods

- (NSString *)jsonStringFromObject:(id)object {
    if (!object) return @"null";
    
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:object 
                                                       options:0 
                                                         error:&error];
    if (error) {
        NSLog(@"在局JSON serialization error: %@", error.localizedDescription);
        return @"{}";
    }
    
    return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
}

// 重写父类的jsCallObjc方法，调用子类的业务逻辑
- (void)jsCallObjc:(NSDictionary *)jsData jsCallBack:(WVJBResponseCallback)jsCallBack {
    NSString *action = jsData[@"action"];
    
    
    // 定义子类特有的action列表 (注意：不包括pageReady，它由父类处理)
    NSSet *childActions = [NSSet setWithArray:@[
        @"request", @"nativeGet", @"hasWx", @"isiPhoneX", @"readMessage", @"setTabBarBadge", 
        @"removeTabBarBadge", @"showTabBarRedDot", @"hideTabBarRedDot", @"navigateTo", @"getLocation",
        @"pageShow", @"pageHide", @"pageUnload", @"showLocation", @"changeMessageNum",
        @"copyLink", @"share", @"saveImage", @"closePresentWindow", @"setNavigationBarTitle",
        @"weixinLogin", @"weixinPay", @"aliPay", @"chooseFile", @"uploadFile", @"QRScan",
        @"previewImage", @"userLogin", @"userLogout", @"switchTab", @"hideNavationbar",
        @"showNavationbar", @"noticemsg_setNumber", @"showModal", @"showToast", @"selectLocation",
        @"selectLocationCity", @"navigateBack", @"reLaunch", @"showActionSheet", @"areaSelect",
        @"dateSelect", @"timeSelect", @"fancySelect", @"dateAndTimeSelect",
        @"reloadOtherPages", @"stopPullDownRefresh"
    ]];
    
    // 如果是子类特有的action，直接调用子类处理
    if ([childActions containsObject:action]) {
        [self handleJavaScriptCall:jsData completion:^(id result) {
            if (jsCallBack) {
                jsCallBack(result);
            }
        }];
        return;
    }
    
    // 否则调用父类处理
    [super jsCallObjc:jsData jsCallBack:jsCallBack];
}

// 保留原有的completion方法作为兼容
- (void)jsCallObjc:(NSDictionary *)jsData completion:(void(^)(id result))completion {
    [self jsCallObjc:jsData jsCallBack:^(id responseData) {
        if (completion) {
            completion(responseData);
        }
    }];
}

#pragma mark - 回调数据格式化

/**
 * 统一的回调数据格式化方法
 * 解决OC端多包一层data导致的多端兼容性问题
 */
- (NSDictionary *)formatCallbackResponse:(NSString *)apiType data:(id)data success:(BOOL)success errorMessage:(NSString *)errorMessage {
    if (!errorMessage) {
        errorMessage = @"";
    }
    
    id formattedData = nil;
    
    if ([apiType isEqualToString:@"showModal"]) {
        // showModal类型：JavaScript端期望 {confirm: true/false, cancel: true/false}
        formattedData = @{
            @"confirm": data[@"confirm"] ?: @"false",
            @"cancel": data[@"cancel"] ?: @"false"
        };
    } else if ([apiType isEqualToString:@"showActionSheet"]) {
        // showActionSheet类型：JavaScript端期望 {tapIndex: number}
        formattedData = @{
            @"tapIndex": data[@"tapIndex"] ?: @(-1)
        };
    } else if ([apiType isEqualToString:@"fancySelect"]) {
        // 自定义选择器类型：JavaScript端期望 {value: string, code: string}
        formattedData = @{
            @"value": data[@"value"] ?: @"",
            @"code": data[@"code"] ?: @""
        };
    } else if ([apiType isEqualToString:@"areaSelect"] || [apiType isEqualToString:@"selectLocationCity"]) {
        // 地区选择类型：支持多种返回格式
        NSMutableDictionary *areaData = [NSMutableDictionary dictionary];
        
        // 获取城市名称和代码
        NSString *cityName = data[@"cityTitle"] ?: data[@"name"] ?: @"";
        NSString *cityCode = data[@"cityCode"] ?: data[@"code"] ?: @"";
        
        // 支持 cityTitle/cityCode 格式
        if (cityName.length > 0) {
            areaData[@"cityTitle"] = cityName;
            areaData[@"name"] = cityName;
            areaData[@"city"] = cityName;
            
            // JavaScript组件期望的格式：省-市-区，但我们只有城市，所以重复城市名
            // 例如："北京" -> "北京-北京-北京"
            areaData[@"value"] = [NSString stringWithFormat:@"%@-%@-%@", cityName, cityName, cityName];
        }
        
        if (cityCode.length > 0) {
            areaData[@"cityCode"] = cityCode;
            areaData[@"code"] = cityCode;
        }
        
        formattedData = areaData;
    } else if ([apiType isEqualToString:@"chooseFile"]) {
        // 文件选择类型：JavaScript端期望文件列表数组
        formattedData = data ?: @[];
    } else if ([apiType isEqualToString:@"getLocation"]) {
        // 定位类型：支持多种字段名格式
        NSMutableDictionary *locationData = [NSMutableDictionary dictionary];
        
        // 支持 lat/lng 格式
        if (data[@"lat"]) {
            locationData[@"lat"] = data[@"lat"];
            locationData[@"latitude"] = data[@"lat"]; // 兼容格式
        }
        if (data[@"lng"]) {
            locationData[@"lng"] = data[@"lng"];
            locationData[@"longitude"] = data[@"lng"]; // 兼容格式
        }
        if (data[@"city"]) {
            locationData[@"city"] = data[@"city"];
        }
        if (data[@"address"]) {
            locationData[@"address"] = data[@"address"];
        }
        
        // 设置默认值
        if (!locationData[@"lat"]) {
            locationData[@"lat"] = @(0);
            locationData[@"latitude"] = @(0);
        }
        if (!locationData[@"lng"]) {
            locationData[@"lng"] = @(0);
            locationData[@"longitude"] = @(0);
        }
        if (!locationData[@"city"]) {
            locationData[@"city"] = @"";
        }
        if (!locationData[@"address"]) {
            locationData[@"address"] = @"";
        }
        
        formattedData = locationData;
    } else if ([apiType isEqualToString:@"hasWx"]) {
        // 微信检测类型：返回详细状态信息
        formattedData = data ?: @{@"hasWx": @NO, @"supportApi": @NO, @"canUse": @NO};
    } else if ([apiType isEqualToString:@"isiPhoneX"]) {
        // iPhone X检测类型：返回状态信息
        formattedData = data ?: @{@"isiPhoneX": @NO};
    } else if ([apiType isEqualToString:@"nativeGet"]) {
        // nativeGet特殊处理，data字段包含实际内容
        formattedData = data ?: @"";
    } else if ([apiType isEqualToString:@"request"]) {
        // request类型：应用层期望res.data.code，需要额外嵌套一层data
        if ([data isKindOfClass:[NSDictionary class]]) {
            // 获取服务器code值，确保类型正确
            NSNumber *serverCode = [data objectForKey:@"code"];
            NSString *codeString = @"0"; // 默认成功
            
            if (!success) {
                // 如果不成功，使用服务器返回的code
                if (serverCode) {
                    codeString = [serverCode stringValue];
                } else {
                    codeString = @"-1";
                }
            }
            
            // 构造应用层期望的格式，需要嵌套data字段
            formattedData = @{
                @"data": @{
                    @"code": codeString,
                    @"data": [data objectForKey:@"data"] ?: @{},
                    @"errorMessage": [data objectForKey:@"errorMessage"] ?: @""
                }
            };
        } else {
            formattedData = @{
                @"data": @{
                    @"code": success ? @"0" : @"-1",
                    @"data": @{},
                    @"errorMessage": @""
                }
            };
        }
    } else {
        // 其他类型：保持原始数据
        formattedData = data ?: @{};
    }
    
    // 统一返回格式：{success: boolean, data: object, errorMessage: string}
    // 这样JavaScript端的 backData.data 就能正确获取到数据
    // 注意：JavaScript端期望success是字符串"true"/"false"
    return @{
        @"success": success ? @"true" : @"false",
        @"data": formattedData,
        @"errorMessage": errorMessage
    };
}

#pragma mark - JavaScript Action Handlers

// 原生数据获取
- (void)handleNativeGet:(id)data completion:(XZWebViewJSCallbackBlock)completion {
    // 处理两种不同的nativeGet用法
    if ([data isKindOfClass:[NSDictionary class]]) {
        // 情况1：获取设备/应用信息 - data是字典，包含key字段
        NSDictionary *dataDict = (NSDictionary *)data;
        NSString *key = dataDict[@"key"];
        
        if ([key isEqualToString:@"device_info"]) {
            NSDictionary *deviceInfo = @{
                @"platform": @"ios",
                @"version": [UIDevice currentDevice].systemVersion,
                @"model": [UIDevice currentDevice].model,
                @"name": [UIDevice currentDevice].name
            };
            completion([self formatCallbackResponse:@"nativeGet" data:deviceInfo success:YES errorMessage:nil]);
        } else if ([key isEqualToString:@"app_info"]) {
            NSDictionary *appInfo = @{
                @"version": [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"],
                @"bundleId": [[NSBundle mainBundle] bundleIdentifier]
            };
            completion([self formatCallbackResponse:@"nativeGet" data:appInfo success:YES errorMessage:nil]);
        } else {
            completion([self formatCallbackResponse:@"nativeGet" data:@{} success:NO errorMessage:@"不支持的key"]);
        }
    } else if ([data isKindOfClass:[NSString class]]) {
        // 情况2：获取文件内容 - data是文件路径字符串
        NSString *filePath = (NSString *)data;
        NSString *fullPath = [[BaseFileManager appH5LocailManifesPath] stringByAppendingPathComponent:filePath];
        NSString *fileContent = [NSString stringWithContentsOfURL:[NSURL fileURLWithPath:fullPath] encoding:NSUTF8StringEncoding error:nil];
        
        // 确保fileContent不为nil
        if (!fileContent) {
            fileContent = @"";
        }
        
        completion([self formatCallbackResponse:@"nativeGet" data:fileContent success:YES errorMessage:nil]);
    } else {
        // 不支持的数据类型
        completion([self formatCallbackResponse:@"nativeGet" data:@{} success:NO errorMessage:@"不支持的数据类型"]);
    }
}

// 检查是否有微信
- (void)handleHasWx:(NSDictionary *)data completion:(XZWebViewJSCallbackBlock)completion {
    BOOL hasWx = [WXApi isWXAppInstalled];
    BOOL supportApi = [WXApi isWXAppSupportApi];
    
    NSLog(@"在局🔍 [hasWx] 微信安装状态: %@, API支持: %@", hasWx ? @"已安装" : @"未安装", supportApi ? @"支持" : @"不支持");
    
    // 返回JavaScript端期望的数据格式：{status: 1/0}
    // 1表示微信可用，0表示微信不可用
    NSDictionary *wxStatus = @{
        @"status": @(hasWx && supportApi ? 1 : 0)
    };
    
    NSLog(@"在局📤 [hasWx] 向JavaScript返回数据: %@", wxStatus);
    
    completion([self formatCallbackResponse:@"hasWx" data:wxStatus success:YES errorMessage:nil]);
}

// iPhone X检测
- (void)handleIsIPhoneX:(NSDictionary *)data completion:(XZWebViewJSCallbackBlock)completion {
    BOOL isIPhoneX = [self isIPhoneX];
    completion([self formatCallbackResponse:@"isiPhoneX" data:@{@"isiPhoneX": @(isIPhoneX)} success:YES errorMessage:nil]);
}

// 消息已读
- (void)handleReadMessage:(NSDictionary *)data completion:(XZWebViewJSCallbackBlock)completion {
    // 实现消息已读逻辑
    completion([self formatCallbackResponse:@"readMessage" data:@{} success:YES errorMessage:nil]);
}

// TabBar Badge相关
- (void)handleSetTabBarBadge:(NSDictionary *)data completion:(XZWebViewJSCallbackBlock)completion {
    NSString *text = data[@"text"];
    NSNumber *index = data[@"index"];
    
    if (index && text) {
        dispatch_async(dispatch_get_main_queue(), ^{
            UITabBarItem *item = [self.tabBarController.tabBar.items objectAtIndex:index.integerValue];
            item.badgeValue = text;
        });
    }
    completion([self formatCallbackResponse:@"setTabBarBadge" data:@{} success:YES errorMessage:nil]);
}

- (void)handleRemoveTabBarBadge:(NSDictionary *)data completion:(XZWebViewJSCallbackBlock)completion {
    NSNumber *index = data[@"index"];
    
    if (index) {
        dispatch_async(dispatch_get_main_queue(), ^{
            UITabBarItem *item = [self.tabBarController.tabBar.items objectAtIndex:index.integerValue];
            item.badgeValue = nil;
        });
    }
    completion([self formatCallbackResponse:@"removeTabBarBadge" data:@{} success:YES errorMessage:nil]);
}

- (void)handleShowTabBarRedDot:(NSDictionary *)data completion:(XZWebViewJSCallbackBlock)completion {
    NSNumber *index = data[@"index"];
    
    if (index) {
        dispatch_async(dispatch_get_main_queue(), ^{
            UITabBarItem *item = [self.tabBarController.tabBar.items objectAtIndex:index.integerValue];
            item.badgeValue = @"";
        });
    }
    completion([self formatCallbackResponse:@"showTabBarRedDot" data:@{} success:YES errorMessage:nil]);
}

- (void)handleHideTabBarRedDot:(NSDictionary *)data completion:(XZWebViewJSCallbackBlock)completion {
    NSNumber *index = data[@"index"];
    
    if (index) {
        dispatch_async(dispatch_get_main_queue(), ^{
            UITabBarItem *item = [self.tabBarController.tabBar.items objectAtIndex:index.integerValue];
            item.badgeValue = nil;
        });
    }
    completion([self formatCallbackResponse:@"hideTabBarRedDot" data:@{} success:YES errorMessage:nil]);
}

// 导航相关
- (void)handleNavigateTo:(id)data completion:(XZWebViewJSCallbackBlock)completion {
    NSString *url = nil;
    
    // 处理不同的数据格式
    if ([data isKindOfClass:[NSString class]]) {
        // 如果data本身就是字符串URL
        url = (NSString *)data;
        NSLog(@"在局🔧 [navigateTo] 接收到字符串格式URL: %@", url);
    } else if ([data isKindOfClass:[NSDictionary class]]) {
        // 如果data是字典，从中提取url
        url = data[@"url"];
        NSLog(@"在局🔧 [navigateTo] 从字典中提取URL: %@", url);
    } else {
        NSLog(@"在局❌ [navigateTo] 未知的数据格式: %@", [data class]);
    }
    
    if (url && url.length > 0) {
        // 检查URL格式，确保它是完整的URL
        NSString *finalUrl = url;
        if (![url hasPrefix:@"http://"] && ![url hasPrefix:@"https://"]) {
            // 如果不是完整URL，尝试拼接域名
            NSString *domain = [[NSUserDefaults standardUserDefaults] objectForKey:@"kUserDefaults_domainStr"];
            if (domain && domain.length > 0) {
                finalUrl = [NSString stringWithFormat:@"https://%@%@", domain, [url hasPrefix:@"/"] ? url : [@"/" stringByAppendingString:url]];
                NSLog(@"在局🔧 [navigateTo] 拼接后的URL: %@", finalUrl);
            }
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            // 检查是否需要使用特殊的导航配置
            NSDictionary *settingDic = [NSKeyedUnarchiver unarchiveObjectWithFile:KNavSettingPath];
            NSString *adressPath = [[finalUrl componentsSeparatedByString:[NSString stringWithFormat:@"://%@", [[NSUserDefaults standardUserDefaults] objectForKey:@"kUserDefaults_domainStr"]]] lastObject];
            
            if (adressPath) {
                // 处理.html后缀和参数
                if ([adressPath containsString:@".html"]) {
                    NSRange range = [adressPath rangeOfString:@".html"];
                    adressPath = [adressPath substringToIndex:range.location];
                }
                if ([adressPath containsString:@"?"]) {
                    adressPath = [[adressPath componentsSeparatedByString:@"?"] objectAtIndex:0];
                }
                
                NSDictionary *setting = [settingDic objectForKey:adressPath];
                
                CFJClientH5Controller *webVC = [[CFJClientH5Controller alloc] init];
                webVC.webViewDomain = finalUrl; // 使用webViewDomain而不是pinUrl
                webVC.pinUrl = finalUrl;
                
                if (setting && [[setting objectForKey:@"showTop"] boolValue]) {
                    webVC.navDic = setting;
                }
                
                webVC.hidesBottomBarWhenPushed = YES;
                [self.navigationController pushViewController:webVC animated:YES];
                
                NSLog(@"在局✅ [navigateTo] 成功导航到: %@", finalUrl);
            } else {
                // 如果无法解析路径，直接使用URL
                CFJClientH5Controller *webVC = [[CFJClientH5Controller alloc] init];
                webVC.webViewDomain = finalUrl;
                webVC.pinUrl = finalUrl;
                webVC.hidesBottomBarWhenPushed = YES;
                [self.navigationController pushViewController:webVC animated:YES];
                
                NSLog(@"在局✅ [navigateTo] 直接导航到: %@", finalUrl);
            }
        });
        completion([self formatCallbackResponse:@"navigateTo" data:@{} success:YES errorMessage:nil]);
    } else {
        NSLog(@"在局❌ [navigateTo] URL为空或无效");
        completion([self formatCallbackResponse:@"navigateTo" data:@{} success:NO errorMessage:@"URL不能为空"]);
    }
}

- (void)handleNavigateBack:(NSDictionary *)data completion:(XZWebViewJSCallbackBlock)completion {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.navigationController popViewControllerAnimated:YES];
    });
    completion([self formatCallbackResponse:@"navigateBack" data:@{} success:YES errorMessage:nil]);
}

- (void)handleReLaunch:(NSDictionary *)data completion:(XZWebViewJSCallbackBlock)completion {
    NSString *url = data[@"url"];
    
    if (url && url.length > 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            // 返回到根视图控制器并加载新URL
            [self.navigationController popToRootViewControllerAnimated:NO];
            self.pinUrl = url;
            [self domainOperate];
        });
        completion([self formatCallbackResponse:@"reLaunch" data:@{} success:YES errorMessage:nil]);
    } else {
        completion([self formatCallbackResponse:@"reLaunch" data:@{} success:NO errorMessage:@"URL不能为空"]);
    }
}

// 定位相关
- (void)handleGetLocation:(NSDictionary *)data completion:(XZWebViewJSCallbackBlock)completion {
    NSLog(@"在局🔧 [getLocation] 开始处理定位请求，参数: %@", data);
    
    // 检查是否需要强制重新定位
    BOOL forceRefresh = [data[@"refresh"] boolValue];
    NSLog(@"在局🔍 [getLocation] 是否强制刷新: %@", forceRefresh ? @"是" : @"否");
    
    // 检查定位权限
    CLAuthorizationStatus authStatus = [CLLocationManager authorizationStatus];
    NSLog(@"在局🔍 [getLocation] 当前定位权限状态: %d", authStatus);
    
    if (authStatus == kCLAuthorizationStatusDenied || authStatus == kCLAuthorizationStatusRestricted) {
        NSLog(@"在局❌ [getLocation] 定位权限被拒绝");
        completion([self formatCallbackResponse:@"getLocation" data:@{} success:NO errorMessage:@"定位权限未开启，请到设置中允许定位权限"]);
        return;
    }
    
    // 尝试获取已存储的定位信息
    NSString *currentLat = [[NSUserDefaults standardUserDefaults] objectForKey:@"currentLat"];
    NSString *currentLng = [[NSUserDefaults standardUserDefaults] objectForKey:@"currentLng"];
    NSString *city = [[NSUserDefaults standardUserDefaults] objectForKey:@"locationCity"];
    
    NSLog(@"在局🔍 [getLocation] 缓存定位信息 - Lat: %@, Lng: %@, City: %@", currentLat, currentLng, city);
    
    if (!forceRefresh && currentLat && currentLng && city && [currentLat length] > 0 && [currentLng length] > 0) {
        // 如果有缓存的定位信息且不是强制刷新，直接返回
        NSDictionary *locationData = @{
            @"lat": @([currentLat doubleValue]),
            @"lng": @([currentLng doubleValue]),
            @"city": city,
            @"address": city
        };
        NSLog(@"在局✅ [getLocation] 返回缓存的定位信息: %@", locationData);
        completion([self formatCallbackResponse:@"getLocation" data:locationData success:YES errorMessage:nil]);
    } else {
        // 需要重新定位
        if (forceRefresh) {
            NSLog(@"在局🔍 [getLocation] 强制刷新，开始重新定位");
        } else {
            NSLog(@"在局🔍 [getLocation] 缓存信息不完整，需要重新定位");
        }
        
        if (authStatus == kCLAuthorizationStatusNotDetermined) {
            NSLog(@"在局⚠️ [getLocation] 定位权限未确定，请求权限");
            // 创建临时的位置管理器来请求权限
            CLLocationManager *tempManager = [[CLLocationManager alloc] init];
            [tempManager requestWhenInUseAuthorization];
            
            // 延迟返回，让用户有时间授权
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                completion([self formatCallbackResponse:@"getLocation" data:@{} success:NO errorMessage:@"请允许应用获取位置权限"]);
            });
            return;
        }
        
        // 初始化定位管理器
        if (!self.locationManager) {
            self.locationManager = [[AMapLocationManager alloc] init];
        }
        
        // 设置基本参数
        self.locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters;
        self.locationManager.locationTimeout = 15; // 增加定位超时时间
        self.locationManager.reGeocodeTimeout = 10; // 增加逆地理编码超时时间
        
        // 单次定位，使用block避免回调冲突
        [self.locationManager requestLocationWithReGeocode:YES completionBlock:^(CLLocation *location, AMapLocationReGeocode *regeocode, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (error) {
                    NSLog(@"在局❌ [getLocation] 定位失败: %@", error.localizedDescription);
                    
                    // 根据错误类型提供更具体的错误信息
                    NSString *errorMsg = @"定位失败，请重试";
                    if (error.code == kCLErrorLocationUnknown) {
                        errorMsg = @"无法获取位置信息，请检查网络连接";
                    } else if (error.code == kCLErrorDenied) {
                        errorMsg = @"定位权限被拒绝，请在设置中开启";
                    } else if (error.code == kCLErrorNetwork) {
                        errorMsg = @"网络错误，请检查网络连接";
                    }
                    
                    completion([self formatCallbackResponse:@"getLocation" data:@{} success:NO errorMessage:errorMsg]);
                } else if (!location) {
                    NSLog(@"在局❌ [getLocation] 定位对象为空");
                    completion([self formatCallbackResponse:@"getLocation" data:@{} success:NO errorMessage:@"无法获取位置信息"]);
                } else {
                    NSString *lat = [NSString stringWithFormat:@"%.6f", location.coordinate.latitude];
                    NSString *lng = [NSString stringWithFormat:@"%.6f", location.coordinate.longitude];
                    NSString *cityName = regeocode.city ?: @"未知城市";
                    NSString *address = regeocode.formattedAddress ?: cityName;
                    
                    // 保存定位信息
                    [[NSUserDefaults standardUserDefaults] setObject:lat forKey:@"currentLat"];
                    [[NSUserDefaults standardUserDefaults] setObject:lng forKey:@"currentLng"];
                    [[NSUserDefaults standardUserDefaults] setObject:cityName forKey:@"locationCity"];
                    [[NSUserDefaults standardUserDefaults] synchronize];
                    
                    NSDictionary *locationData = @{
                        @"lat": @(location.coordinate.latitude),
                        @"lng": @(location.coordinate.longitude),
                        @"city": cityName,
                        @"address": address
                    };
                    
                    NSLog(@"在局✅ [getLocation] 定位成功: %@", locationData);
                    completion([self formatCallbackResponse:@"getLocation" data:locationData success:YES errorMessage:nil]);
                }
            });
        }];
    }
}

- (void)handleShowLocation:(NSDictionary *)data completion:(XZWebViewJSCallbackBlock)completion {
    // 实现显示地图位置
    completion([self formatCallbackResponse:@"showLocation" data:@{} success:YES errorMessage:nil]);
}

- (void)handleSelectLocation:(NSDictionary *)data completion:(XZWebViewJSCallbackBlock)completion {
    NSLog(@"在局🔧 [selectLocation] 开始处理位置选择: %@", data);
    
    // 保存回调
    self.webviewBackCallBack = completion;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        // 创建地图位置选择控制器
        AddressFromMapViewController *mapVC = [[AddressFromMapViewController alloc] init];
        mapVC.hidesBottomBarWhenPushed = YES;
        
        // 如果有当前位置信息，设置默认位置
        NSString *currentLat = [[NSUserDefaults standardUserDefaults] objectForKey:@"currentLat"];
        NSString *currentLng = [[NSUserDefaults standardUserDefaults] objectForKey:@"currentLng"];
        
        if (currentLat && currentLng) {
            // 设置地图的初始位置（如果 AddressFromMapViewController 支持的话）
            NSLog(@"在局🔍 [selectLocation] 设置初始位置: %@, %@", currentLat, currentLng);
        }
        
        [self.navigationController pushViewController:mapVC animated:YES];
        
        NSLog(@"在局✅ [selectLocation] 已打开地图位置选择页面");
    });
}

- (void)handleSelectLocationCity:(NSDictionary *)data completion:(XZWebViewJSCallbackBlock)completion {
    NSLog(@"在局🔧 [selectLocationCity] 开始处理城市选择: %@", data);
    
    // 保存回调
    self.webviewBackCallBack = completion;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        // 创建城市选择控制器
        JFCityViewController *cityVC = [[JFCityViewController alloc] init];
        cityVC.delegate = self;
        cityVC.hidesBottomBarWhenPushed = YES;
        
        // 如果有当前城市信息，可以设置默认选中
        NSString *currentCity = [[NSUserDefaults standardUserDefaults] objectForKey:@"locationCity"];
        if (currentCity && currentCity.length > 0) {
            NSLog(@"在局🔍 [selectLocationCity] 当前城市: %@", currentCity);
        }
        
        [self.navigationController pushViewController:cityVC animated:YES];
        
        NSLog(@"在局✅ [selectLocationCity] 已打开城市选择页面");
    });
}

// 页面生命周期
- (void)handlePageShow:(NSDictionary *)data completion:(XZWebViewJSCallbackBlock)completion {
    completion([self formatCallbackResponse:@"pageShow" data:@{} success:YES errorMessage:nil]);
}

- (void)handlePageHide:(NSDictionary *)data completion:(XZWebViewJSCallbackBlock)completion {
    completion([self formatCallbackResponse:@"pageHide" data:@{} success:YES errorMessage:nil]);
}

- (void)handlePageUnload:(NSDictionary *)data completion:(XZWebViewJSCallbackBlock)completion {
    completion([self formatCallbackResponse:@"pageUnload" data:@{} success:YES errorMessage:nil]);
}

// 工具功能
- (void)handleCopyLink:(NSDictionary *)data completion:(XZWebViewJSCallbackBlock)completion {
    NSLog(@"在局🔧 [handleCopyLink] 处理复制链接请求，数据: %@", data);
    
    // 兼容多种字段名：content, url, link, text
    NSString *content = data[@"content"] ?: data[@"url"] ?: data[@"link"] ?: data[@"text"];
    
    NSLog(@"在局🔧 [handleCopyLink] 提取的复制内容: %@", content);
    
    if (content && content.length > 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
            pasteboard.string = content;
            NSLog(@"在局✅ [handleCopyLink] 内容已复制到剪贴板: %@", content);
        });
        completion([self formatCallbackResponse:@"copyLink" data:@{} success:YES errorMessage:nil]);
    } else {
        NSLog(@"在局❌ [handleCopyLink] 复制内容为空");
        completion([self formatCallbackResponse:@"copyLink" data:@{} success:NO errorMessage:@"复制内容不能为空"]);
    }
}

- (void)handleShare:(NSDictionary *)data completion:(XZWebViewJSCallbackBlock)completion {
    self.webviewBackCallBack = completion;
    [self shareContent:data presentedVC:self];
}

- (void)handleSaveImage:(NSDictionary *)data completion:(XZWebViewJSCallbackBlock)completion {
    NSLog(@"在局🔧 [handleSaveImage] 处理保存图片请求，数据: %@", data);
    
    // 保存回调以供 saveImageToPhotos 的完成回调使用
    self.webviewBackCallBack = completion;
    
    // 检查相册权限
    PHAuthorizationStatus author = [PHPhotoLibrary authorizationStatus];
    if (author == kCLAuthorizationStatusRestricted || author == kCLAuthorizationStatusDenied) {
        NSLog(@"在局❌ [handleSaveImage] 相册权限被拒绝");
        NSString *tips = @"请在设备的设置-隐私-照片选项中，允许应用访问你的照片";
        [JHSysAlertUtil presentAlertViewWithTitle:@"温馨提示" message:tips confirmTitle:@"确定" handler:nil];
        
        // 返回权限错误
        completion([self formatCallbackResponse:@"saveImage" data:@{} success:NO errorMessage:@"相册权限未开启"]);
        return;
    }
    
    // 获取图片路径，兼容多种字段名
    NSString *imageStr = data[@"filePath"] ?: data[@"url"] ?: data[@"imageUrl"] ?: data[@"src"];
    
    NSLog(@"在局🔧 [handleSaveImage] 提取的图片URL: %@", imageStr);
    
    if (!imageStr || imageStr.length == 0) {
        NSLog(@"在局❌ [handleSaveImage] 图片路径为空");
        completion([self formatCallbackResponse:@"saveImage" data:@{} success:NO errorMessage:@"图片路径不能为空"]);
        return;
    }
    
    // 从URL获取图片并保存
    UIImage *image = [self getImageFromURL:imageStr];
    if (image) {
        NSLog(@"在局🔧 [handleSaveImage] 开始保存图片到相册");
        [self saveImageToPhotos:image];
    } else {
        NSLog(@"在局❌ [handleSaveImage] 无法从URL获取图片");
        completion([self formatCallbackResponse:@"saveImage" data:@{} success:NO errorMessage:@"无法获取图片"]);
    }
}

// 导航栏控制
- (void)handleSetNavigationBarTitle:(NSDictionary *)data completion:(XZWebViewJSCallbackBlock)completion {
    NSString *title = data[@"title"];
    
    if (title) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.navigationItem.title = title;
        });
    }
    completion([self formatCallbackResponse:@"setNavigationBarTitle" data:@{} success:YES errorMessage:nil]);
}

- (void)handleHideNavigationBar:(NSDictionary *)data completion:(XZWebViewJSCallbackBlock)completion {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.navigationController setNavigationBarHidden:YES animated:YES];
    });
    completion([self formatCallbackResponse:@"hideNavationbar" data:@{} success:YES errorMessage:nil]);
}

- (void)handleShowNavigationBar:(NSDictionary *)data completion:(XZWebViewJSCallbackBlock)completion {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.navigationController setNavigationBarHidden:NO animated:YES];
    });
    completion([self formatCallbackResponse:@"showNavationbar" data:@{} success:YES errorMessage:nil]);
}

// 第三方登录和支付
- (void)handleWeixinLogin:(NSDictionary *)data completion:(XZWebViewJSCallbackBlock)completion {
    self.webviewBackCallBack = completion;
    [self performWechatDirectLogin];
}

- (void)handleWeixinPay:(NSDictionary *)data completion:(XZWebViewJSCallbackBlock)completion {
    self.webviewBackCallBack = completion;
    [self payRequest:data withPayType:@"weixin"];
}

- (void)handleAliPay:(NSDictionary *)data completion:(XZWebViewJSCallbackBlock)completion {
    self.webviewBackCallBack = completion;
    [self payRequest:data withPayType:@"alipay"];
}

// 文件操作
- (void)handleChooseFile:(NSDictionary *)data completion:(XZWebViewJSCallbackBlock)completion {
    self.webviewBackCallBack = completion;
    [self pushTZImagePickerControllerWithDic:data];
}

- (void)handleUploadFile:(NSDictionary *)data completion:(XZWebViewJSCallbackBlock)completion {
    [self QiNiuUploadImageWithData:data];
    completion([self formatCallbackResponse:@"uploadFile" data:@{} success:YES errorMessage:nil]);
}

- (void)handlePreviewImage:(NSDictionary *)data completion:(XZWebViewJSCallbackBlock)completion {
    NSLog(@"在局🔧 [handlePreviewImage] 处理图片预览请求，数据: %@", data);
    
    // 获取图片URL数组
    NSArray *imageUrls = data[@"urls"];
    if (!imageUrls || ![imageUrls isKindOfClass:[NSArray class]] || imageUrls.count == 0) {
        NSLog(@"在局❌ [handlePreviewImage] 图片URL数组为空或格式错误");
        completion([self formatCallbackResponse:@"previewImage" data:@{} success:NO errorMessage:@"图片URL数组不能为空"]);
        return;
    }
    
    // 获取当前显示的图片URL
    NSString *currentImageUrl = data[@"current"];
    NSInteger currentIndex = 0;
    
    if (currentImageUrl && currentImageUrl.length > 0) {
        currentIndex = [self getIndexByUrl:currentImageUrl :imageUrls];
        NSLog(@"在局🔧 [handlePreviewImage] 当前图片索引: %ld", (long)currentIndex);
    }
    
    // 保存图片数组到实例变量
    self.viewImageAry = imageUrls;
    
    NSLog(@"在局🔧 [handlePreviewImage] 开始显示图片浏览器，图片数量: %ld", (long)imageUrls.count);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        // 显示图片浏览器
        [[LBPhotoBrowserManager defaultManager] showImageWithURLArray:imageUrls 
                                                   fromImageViewFrames:nil 
                                                         selectedIndex:currentIndex 
                                                   imageViewSuperView:self.view];
        
        // 添加长按保存功能
        [[[LBPhotoBrowserManager.defaultManager addLongPressShowTitles:@[@"保存", @"取消"]] 
          addTitleClickCallbackBlock:^(UIImage *image, NSIndexPath *indexPath, NSString *title, BOOL isGif, NSData *gifImageData) {
            NSLog(@"在局🔧 [handlePreviewImage] 长按操作: %@", title);
            if (![title isEqualToString:@"保存"]) return;
            
            if (!isGif) {
                [[LBAlbumManager shareManager] saveImage:image];
            } else {
                [[LBAlbumManager shareManager] saveGifImageWithData:gifImageData];
            }
        }] addPhotoBrowserWillDismissBlock:^{
            NSLog(@"在局🔧 [handlePreviewImage] 图片浏览器即将关闭");
        }];
    });
    
    // 图片预览是异步操作，立即返回成功
    completion([self formatCallbackResponse:@"previewImage" data:@{} success:YES errorMessage:nil]);
}

// 扫码
- (void)handleQRScan:(NSDictionary *)data completion:(XZWebViewJSCallbackBlock)completion {
    dispatch_async(dispatch_get_main_queue(), ^{
        CFJScanViewController *qrVC = [[CFJScanViewController alloc] init];
        qrVC.hidesBottomBarWhenPushed = YES;
        [self.navigationController pushViewController:qrVC animated:YES];
    });
    completion([self formatCallbackResponse:@"QRScan" data:@{} success:YES errorMessage:nil]);
}

// 用户相关
- (void)handleUserLogin:(NSDictionary *)data completion:(XZWebViewJSCallbackBlock)completion {
    // 实现用户登录逻辑
    completion([self formatCallbackResponse:@"userLogin" data:@{} success:YES errorMessage:nil]);
}

- (void)handleUserLogout:(NSDictionary *)data completion:(XZWebViewJSCallbackBlock)completion {
    // 实现用户登出逻辑
    completion([self formatCallbackResponse:@"userLogout" data:@{} success:YES errorMessage:nil]);
}

// Tab切换
- (void)handleSwitchTab:(NSDictionary *)data completion:(XZWebViewJSCallbackBlock)completion {
    NSNumber *index = data[@"index"];
    
    if (index) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.tabBarController.selectedIndex = index.integerValue;
        });
        completion([self formatCallbackResponse:@"switchTab" data:@{} success:YES errorMessage:nil]);
    } else {
        completion([self formatCallbackResponse:@"switchTab" data:@{} success:NO errorMessage:@"缺少index参数"]);
    }
}

// UI组件
- (void)handleShowModal:(NSDictionary *)data completion:(XZWebViewJSCallbackBlock)completion {
    NSString *title = data[@"title"];
    NSString *content = data[@"content"];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:title 
                                                                      message:content 
                                                               preferredStyle:UIAlertControllerStyleAlert];
        
        UIAlertAction *confirmAction = [UIAlertAction actionWithTitle:@"确定" 
                                                               style:UIAlertActionStyleDefault 
                                                             handler:^(UIAlertAction *action) {
            completion([self formatCallbackResponse:@"showModal" data:@{@"confirm": @YES} success:YES errorMessage:nil]);
        }];
        
        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消" 
                                                              style:UIAlertActionStyleCancel 
                                                            handler:^(UIAlertAction *action) {
            completion([self formatCallbackResponse:@"showModal" data:@{@"confirm": @NO} success:YES errorMessage:nil]);
        }];
        
        [alert addAction:confirmAction];
        [alert addAction:cancelAction];
        [self presentViewController:alert animated:YES completion:nil];
    });
}

- (void)handleShowToast:(NSDictionary *)data completion:(XZWebViewJSCallbackBlock)completion {
    NSLog(@"在局🔧 [handleShowToast] 处理显示Toast请求，数据: %@", data);
    
    // 兼容多种字段名：title, message, text, content
    NSString *message = data[@"title"] ?: data[@"message"] ?: data[@"text"] ?: data[@"content"];
    
    // 获取显示时长，默认2秒
    NSNumber *durationNumber = data[@"duration"];
    NSTimeInterval duration = durationNumber ? [durationNumber doubleValue] / 1000.0 : 2.0; // JS传毫秒，转换为秒
    
    // 获取Toast类型
    NSString *icon = data[@"icon"];
    
    NSLog(@"在局🔧 [handleShowToast] Toast内容: %@, 时长: %.1f秒, 图标: %@", message, duration, icon);
    
    if (message && message.length > 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([icon isEqualToString:@"success"]) {
                // 成功图标 - 使用绿色对勾图标
                UIImage *successImage = [UIImage imageNamed:@"success"] ?: [self createSuccessIcon];
                [SVStatusHUD showWithImage:successImage status:message duration:duration];
            } else if ([icon isEqualToString:@"error"] || [icon isEqualToString:@"fail"]) {
                // 错误图标 - 使用红色错误图标
                UIImage *errorImage = [UIImage imageNamed:@"error"] ?: [self createErrorIcon];
                [SVStatusHUD showWithImage:errorImage status:message duration:duration];
            } else if ([icon isEqualToString:@"loading"]) {
                // 加载状态 - 只显示文字，不需要图标
                [SVStatusHUD showWithMessage:message];
                // 加载状态需要手动关闭，设置定时器
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(duration * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    // SVStatusHUD没有dismiss方法，显示空消息来清除
                    [SVStatusHUD showWithMessage:@""];
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        // 通过显示空白来隐藏
                        [SVStatusHUD showWithImage:nil status:@"" duration:0.1];
                    });
                });
            } else {
                // 默认显示普通消息 - 由于没有duration参数的方法，显示后延时隐藏
                [SVStatusHUD showWithMessage:message];
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(duration * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [SVStatusHUD showWithImage:nil status:@"" duration:0.1];
                });
            }
            
            NSLog(@"在局✅ [handleShowToast] Toast已显示");
        });
        completion([self formatCallbackResponse:@"showToast" data:@{} success:YES errorMessage:nil]);
    } else {
        NSLog(@"在局❌ [handleShowToast] Toast消息为空");
        completion([self formatCallbackResponse:@"showToast" data:@{} success:NO errorMessage:@"Toast消息不能为空"]);
    }
}

- (void)handleShowActionSheet:(NSDictionary *)data completion:(XZWebViewJSCallbackBlock)completion {
    NSArray *itemList = data[@"itemList"];
    
    if (itemList && itemList.count > 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            UIAlertController *actionSheet = [UIAlertController alertControllerWithTitle:nil 
                                                                                 message:nil 
                                                                          preferredStyle:UIAlertControllerStyleActionSheet];
            
            for (NSInteger i = 0; i < itemList.count; i++) {
                NSString *title = itemList[i];
                UIAlertAction *action = [UIAlertAction actionWithTitle:title 
                                                               style:UIAlertActionStyleDefault 
                                                             handler:^(UIAlertAction *action) {
                    completion([self formatCallbackResponse:@"showActionSheet" data:@{@"tapIndex": @(i)} success:YES errorMessage:nil]);
                }];
                [actionSheet addAction:action];
            }
            
            UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消" 
                                                                  style:UIAlertActionStyleCancel 
                                                                handler:^(UIAlertAction *action) {
                completion([self formatCallbackResponse:@"showActionSheet" data:@{@"tapIndex": @(-1)} success:YES errorMessage:nil]);
            }];
            [actionSheet addAction:cancelAction];
            
            [self presentViewController:actionSheet animated:YES completion:nil];
        });
    } else {
        completion([self formatCallbackResponse:@"showActionSheet" data:@{} success:NO errorMessage:@"itemList不能为空"]);
    }
}

// 选择器
- (void)handleAreaSelect:(NSDictionary *)data completion:(XZWebViewJSCallbackBlock)completion {
    NSLog(@"在局🔧 [areaSelect] 开始处理地区选择: %@", data);
    
    // 保存回调
    self.webviewBackCallBack = completion;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        // 创建地区选择控制器
        JFCityViewController *cityVC = [[JFCityViewController alloc] init];
        cityVC.delegate = self;
        cityVC.hidesBottomBarWhenPushed = YES;
        
        // 如果有预设的名称，可以在这里设置
        NSString *currentName = data[@"name"];
        if (currentName && currentName.length > 0) {
            // 这里可以设置当前选中的城市名称
            NSLog(@"在局🔍 [areaSelect] 当前预设城市: %@", currentName);
        }
        
        [self.navigationController pushViewController:cityVC animated:YES];
    });
}

- (void)handleDateSelect:(NSDictionary *)data completion:(XZWebViewJSCallbackBlock)completion {
    NSLog(@"在局🔧 [handleDateSelect] 处理日期选择请求，数据: %@", data);
    
    // 解析参数
    NSString *title = data[@"title"] ?: @"选择日期";
    NSString *minDate = data[@"minDate"];
    NSString *maxDate = data[@"maxDate"];
    NSString *current = data[@"current"];
    
    // 日期格式化器
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd"];
    
    // 设置最小和最大日期
    NSDate *minimumDate = nil;
    NSDate *maximumDate = nil;
    NSDate *currentDate = [NSDate date];
    
    if (minDate && minDate.length > 0) {
        minimumDate = [dateFormatter dateFromString:minDate];
    }
    if (maxDate && maxDate.length > 0) {
        maximumDate = [dateFormatter dateFromString:maxDate];
    }
    if (current && current.length > 0) {
        NSDate *parsedDate = [dateFormatter dateFromString:current];
        if (parsedDate) {
            currentDate = parsedDate;
        }
    }
    
    NSLog(@"在局🔧 [handleDateSelect] 参数解析 - 标题:%@, 最小日期:%@, 最大日期:%@, 当前日期:%@", 
          title, minimumDate, maximumDate, currentDate);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[MOFSPickerManager shareManger] showDatePickerWithTitle:title
                                                     cancelTitle:@"取消"
                                                     commitTitle:@"确定"
                                                       firstDate:currentDate
                                                         minDate:minimumDate
                                                         maxDate:maximumDate
                                                  datePickerMode:UIDatePickerModeDate
                                                             tag:1001
                                                     commitBlock:^(NSDate *date) {
            NSString *selectedDate = [dateFormatter stringFromDate:date];
            NSLog(@"在局✅ [handleDateSelect] 用户选择日期: %@", selectedDate);
            
            NSDictionary *resultData = @{
                @"date": selectedDate,
                @"value": selectedDate
            };
            completion([self formatCallbackResponse:@"dateSelect" data:resultData success:YES errorMessage:nil]);
        } cancelBlock:^{
            NSLog(@"在局🔧 [handleDateSelect] 用户取消选择");
            completion([self formatCallbackResponse:@"dateSelect" data:@{} success:NO errorMessage:@"用户取消选择"]);
        }];
    });
}

- (void)handleTimeSelect:(NSDictionary *)data completion:(XZWebViewJSCallbackBlock)completion {
    NSLog(@"在局🔧 [handleTimeSelect] 处理时间选择请求，数据: %@", data);
    
    // 解析参数
    NSString *title = data[@"title"] ?: @"选择时间";
    NSString *current = data[@"current"];
    
    // 时间格式化器
    NSDateFormatter *timeFormatter = [[NSDateFormatter alloc] init];
    [timeFormatter setDateFormat:@"HH:mm"];
    
    // 设置当前时间
    NSDate *currentTime = [NSDate date];
    if (current && current.length > 0) {
        // 尝试解析传入的时间
        NSDate *parsedTime = [timeFormatter dateFromString:current];
        if (parsedTime) {
            // 将解析的时间设置到今天
            NSCalendar *calendar = [NSCalendar currentCalendar];
            NSDateComponents *timeComponents = [calendar components:(NSCalendarUnitHour | NSCalendarUnitMinute) fromDate:parsedTime];
            NSDateComponents *todayComponents = [calendar components:(NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay) fromDate:[NSDate date]];
            
            [todayComponents setHour:timeComponents.hour];
            [todayComponents setMinute:timeComponents.minute];
            [todayComponents setSecond:0];
            
            currentTime = [calendar dateFromComponents:todayComponents];
        }
    }
    
    NSLog(@"在局🔧 [handleTimeSelect] 参数解析 - 标题:%@, 当前时间:%@", title, [timeFormatter stringFromDate:currentTime]);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[MOFSPickerManager shareManger] showDatePickerWithTitle:title
                                                     cancelTitle:@"取消"
                                                     commitTitle:@"确定"
                                                       firstDate:currentTime
                                                         minDate:nil
                                                         maxDate:nil
                                                  datePickerMode:UIDatePickerModeTime
                                                             tag:1002
                                                     commitBlock:^(NSDate *date) {
            NSString *selectedTime = [timeFormatter stringFromDate:date];
            NSLog(@"在局✅ [handleTimeSelect] 用户选择时间: %@", selectedTime);
            
            NSDictionary *resultData = @{
                @"time": selectedTime,
                @"value": selectedTime
            };
            completion([self formatCallbackResponse:@"timeSelect" data:resultData success:YES errorMessage:nil]);
        } cancelBlock:^{
            NSLog(@"在局🔧 [handleTimeSelect] 用户取消选择");
            completion([self formatCallbackResponse:@"timeSelect" data:@{} success:NO errorMessage:@"用户取消选择"]);
        }];
    });
}

- (void)handleFancySelect:(NSDictionary *)data completion:(XZWebViewJSCallbackBlock)completion {
    NSLog(@"在局🔧 [handleFancySelect] 处理自定义选择器请求，数据: %@", data);
    
    // 解析参数
    NSString *title = data[@"title"] ?: @"请选择";
    NSArray *range = data[@"range"];
    NSString *value = data[@"value"];
    
    // 验证数据源
    if (!range || ![range isKindOfClass:[NSArray class]] || range.count == 0) {
        NSLog(@"在局❌ [handleFancySelect] 数据源为空或格式错误");
        completion([self formatCallbackResponse:@"fancySelect" data:@{} success:NO errorMessage:@"选择器数据源不能为空"]);
        return;
    }
    
    // 处理数据源，确保都是字符串
    NSMutableArray *dataSource = [NSMutableArray array];
    for (id item in range) {
        if ([item isKindOfClass:[NSString class]]) {
            [dataSource addObject:item];
        } else if ([item isKindOfClass:[NSDictionary class]]) {
            // 如果是对象，尝试获取text或label字段
            NSDictionary *itemDict = (NSDictionary *)item;
            NSString *text = itemDict[@"text"] ?: itemDict[@"label"] ?: itemDict[@"name"] ?: [itemDict description];
            [dataSource addObject:text];
        } else {
            // 其他类型转为字符串
            [dataSource addObject:[NSString stringWithFormat:@"%@", item]];
        }
    }
    
    NSLog(@"在局🔧 [handleFancySelect] 参数解析 - 标题:%@, 数据源数量:%ld, 默认值:%@", 
          title, (long)dataSource.count, value);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[MOFSPickerManager shareManger] showPickerViewWithDataArray:dataSource
                                                                 tag:1003
                                                               title:title
                                                         cancelTitle:@"取消"
                                                         commitTitle:@"确定"
                                                         commitBlock:^(NSString *selectedString) {
            NSLog(@"在局✅ [handleFancySelect] 用户选择: %@", selectedString);
            
            // 找到选中项在原数据中的索引和对应的原始数据
            NSInteger selectedIndex = [dataSource indexOfObject:selectedString];
            id originalItem = (selectedIndex != NSNotFound && selectedIndex < range.count) ? range[selectedIndex] : selectedString;
            
            NSDictionary *resultData;
            if ([originalItem isKindOfClass:[NSDictionary class]]) {
                // 如果原始数据是字典，返回完整的字典信息
                NSMutableDictionary *result = [NSMutableDictionary dictionaryWithDictionary:(NSDictionary *)originalItem];
                result[@"value"] = selectedString;
                result[@"index"] = @(selectedIndex);
                resultData = result;
            } else {
                // 如果是字符串或其他类型，返回标准格式
                resultData = @{
                    @"value": selectedString,
                    @"index": @(selectedIndex),
                    @"text": selectedString
                };
            }
            
            completion([self formatCallbackResponse:@"fancySelect" data:resultData success:YES errorMessage:nil]);
        } cancelBlock:^{
            NSLog(@"在局🔧 [handleFancySelect] 用户取消选择");
            completion([self formatCallbackResponse:@"fancySelect" data:@{} success:NO errorMessage:@"用户取消选择"]);
        }];
    });
}

- (void)handleDateAndTimeSelect:(NSDictionary *)data completion:(XZWebViewJSCallbackBlock)completion {
    NSLog(@"在局🔧 [handleDateAndTimeSelect] 处理日期时间选择请求，数据: %@", data);
    
    // 解析参数
    NSString *title = data[@"title"] ?: @"选择日期时间";
    NSString *minDateTime = data[@"minDate"];
    NSString *maxDateTime = data[@"maxDate"];
    NSString *current = data[@"current"];
    
    // 日期时间格式化器
    NSDateFormatter *dateTimeFormatter = [[NSDateFormatter alloc] init];
    [dateTimeFormatter setDateFormat:@"yyyy-MM-dd HH:mm"];
    
    // 设置最小和最大日期时间
    NSDate *minimumDate = nil;
    NSDate *maximumDate = nil;
    NSDate *currentDateTime = [NSDate date];
    
    if (minDateTime && minDateTime.length > 0) {
        minimumDate = [dateTimeFormatter dateFromString:minDateTime];
    }
    if (maxDateTime && maxDateTime.length > 0) {
        maximumDate = [dateTimeFormatter dateFromString:maxDateTime];
    }
    if (current && current.length > 0) {
        NSDate *parsedDateTime = [dateTimeFormatter dateFromString:current];
        if (parsedDateTime) {
            currentDateTime = parsedDateTime;
        }
    }
    
    NSLog(@"在局🔧 [handleDateAndTimeSelect] 参数解析 - 标题:%@, 最小日期:%@, 最大日期:%@, 当前日期:%@", 
          title, minimumDate, maximumDate, currentDateTime);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[MOFSPickerManager shareManger] showDatePickerWithTitle:title
                                                     cancelTitle:@"取消"
                                                     commitTitle:@"确定"
                                                       firstDate:currentDateTime
                                                         minDate:minimumDate
                                                         maxDate:maximumDate
                                                  datePickerMode:UIDatePickerModeDateAndTime
                                                             tag:1004
                                                     commitBlock:^(NSDate *date) {
            NSString *selectedDateTime = [dateTimeFormatter stringFromDate:date];
            NSLog(@"在局✅ [handleDateAndTimeSelect] 用户选择日期时间: %@", selectedDateTime);
            
            // 分别获取日期和时间部分
            NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
            [dateFormatter setDateFormat:@"yyyy-MM-dd"];
            NSString *dateOnly = [dateFormatter stringFromDate:date];
            
            NSDateFormatter *timeFormatter = [[NSDateFormatter alloc] init];
            [timeFormatter setDateFormat:@"HH:mm"];
            NSString *timeOnly = [timeFormatter stringFromDate:date];
            
            NSDictionary *resultData = @{
                @"datetime": selectedDateTime,
                @"date": dateOnly,
                @"time": timeOnly,
                @"value": selectedDateTime
            };
            completion([self formatCallbackResponse:@"dateAndTimeSelect" data:resultData success:YES errorMessage:nil]);
        } cancelBlock:^{
            NSLog(@"在局🔧 [handleDateAndTimeSelect] 用户取消选择");
            completion([self formatCallbackResponse:@"dateAndTimeSelect" data:@{} success:NO errorMessage:@"用户取消选择"]);
        }];
    });
}

// 其他功能
- (void)handleClosePresentWindow:(NSDictionary *)data completion:(XZWebViewJSCallbackBlock)completion {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self dismissViewControllerAnimated:YES completion:nil];
    });
    completion([self formatCallbackResponse:@"closePresentWindow" data:@{} success:YES errorMessage:nil]);
}

- (void)handleChangeMessageNum:(NSDictionary *)data completion:(XZWebViewJSCallbackBlock)completion {
    // 实现消息数量改变
    completion([self formatCallbackResponse:@"changeMessageNum" data:@{} success:YES errorMessage:nil]);
}

- (void)handleNoticeMessageSetNumber:(NSDictionary *)data completion:(XZWebViewJSCallbackBlock)completion {
    // 实现通知消息数量设置
    completion([self formatCallbackResponse:@"noticemsg_setNumber" data:@{} success:YES errorMessage:nil]);
}

- (void)handleReloadOtherPages:(NSDictionary *)data completion:(XZWebViewJSCallbackBlock)completion {
    // 实现重新加载其他页面
    completion([self formatCallbackResponse:@"reloadOtherPages" data:@{} success:YES errorMessage:nil]);
}

- (void)handleStopPullDownRefresh:(NSDictionary *)data completion:(XZWebViewJSCallbackBlock)completion {
    NSLog(@"在局🔧 [stopPullDownRefresh] 开始处理停止下拉刷新");
    
    dispatch_async(dispatch_get_main_queue(), ^{
        // 先立即回调成功，避免JavaScript端等待超时
        completion([self formatCallbackResponse:@"stopPullDownRefresh" data:@{} success:YES errorMessage:nil]);
        
        // 1. 停止原生MJRefresh下拉刷新控件
        @try {
            if (self.webView && [self.webView respondsToSelector:@selector(scrollView)]) {
                UIScrollView *scrollView = [self.webView performSelector:@selector(scrollView)];
                if (scrollView && [scrollView respondsToSelector:@selector(mj_header)]) {
                    id mj_header = [scrollView valueForKey:@"mj_header"];
                    if (mj_header) {
                        NSNumber *isRefreshing = [mj_header valueForKey:@"isRefreshing"];
                        if (isRefreshing && [isRefreshing boolValue]) {
                            [mj_header performSelector:@selector(endRefreshing) withObject:nil];
                            NSLog(@"在局✅ [stopPullDownRefresh] 原生MJRefresh控件已停止");
                        } else {
                            NSLog(@"在局ℹ️ [stopPullDownRefresh] 原生MJRefresh控件未在刷新状态");
                        }
                    }
                }
            }
        } @catch (NSException *exception) {
            NSLog(@"在局⚠️ [stopPullDownRefresh] 停止原生控件异常: %@", exception.reason);
        }
        
        // 2. 处理JavaScript端的下拉刷新元素
        if (self.webView) {
            // 使用最简化的方案：直接调用WebView的evaluateJavaScript
            NSString *simpleJS = @"(function(){try{var e=document.querySelectorAll('.pull-refresh,.pulltorefresh,.loading,.refresh-indicator');for(var i=0;i<e.length;i++)e[i].style.display='none';document.body.scrollTop=0;document.documentElement.scrollTop=0;window.app&&(window.app.isRefreshing=false);return 'success'}catch(t){return 'error:'+t.message}})()";
            
            [(WKWebView *)self.webView evaluateJavaScript:simpleJS completionHandler:^(id result, NSError *error) {
                if (error) {
                    NSLog(@"在局⚠️ [stopPullDownRefresh] JavaScript处理失败: %@", error.localizedDescription);
                } else {
                    NSLog(@"在局✅ [stopPullDownRefresh] JavaScript处理成功: %@", result);
                }
            }];
        } else {
            NSLog(@"在局⚠️ [stopPullDownRefresh] WebView为nil");
        }
    });
}

// 辅助方法：创建成功图标
- (UIImage *)createSuccessIcon {
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(20, 20), NO, 0.0);
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    // 绘制绿色圆形背景
    CGContextSetFillColorWithColor(context, [UIColor colorWithRed:0.0 green:0.8 blue:0.0 alpha:1.0].CGColor);
    CGContextFillEllipseInRect(context, CGRectMake(0, 0, 20, 20));
    
    // 绘制白色对勾
    CGContextSetStrokeColorWithColor(context, [UIColor whiteColor].CGColor);
    CGContextSetLineWidth(context, 2.0);
    CGContextMoveToPoint(context, 5, 10);
    CGContextAddLineToPoint(context, 8, 13);
    CGContextAddLineToPoint(context, 15, 6);
    CGContextStrokePath(context);
    
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

// 辅助方法：创建错误图标
- (UIImage *)createErrorIcon {
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(20, 20), NO, 0.0);
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    // 绘制红色圆形背景
    CGContextSetFillColorWithColor(context, [UIColor colorWithRed:1.0 green:0.2 blue:0.2 alpha:1.0].CGColor);
    CGContextFillEllipseInRect(context, CGRectMake(0, 0, 20, 20));
    
    // 绘制白色X
    CGContextSetStrokeColorWithColor(context, [UIColor whiteColor].CGColor);
    CGContextSetLineWidth(context, 2.0);
    CGContextMoveToPoint(context, 6, 6);
    CGContextAddLineToPoint(context, 14, 14);
    CGContextMoveToPoint(context, 14, 6);
    CGContextAddLineToPoint(context, 6, 14);
    CGContextStrokePath(context);
    
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

// 辅助方法：检查是否是iPhone X系列
- (BOOL)isIPhoneX {
    // 确保在主线程访问UI API
    if (![NSThread isMainThread]) {
        __block BOOL result = NO;
        dispatch_sync(dispatch_get_main_queue(), ^{
            result = [self isIPhoneX];
        });
        return result;
    }
    
    if (@available(iOS 11.0, *)) {
        UIWindow *window = [UIApplication sharedApplication].delegate.window;
        if (window.safeAreaInsets.bottom > 0) {
            return YES;
        }
    }
    return NO;
}

// 🔧 新增方法：处理手势返回后的tab栏显示控制
- (void)handleTabBarVisibilityAfterPopGesture {
    NSLog(@"在局🔧 [handleTabBarVisibilityAfterPopGesture] 开始处理手势返回后的tab栏显示控制");
    
    // 确保在主线程执行
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self handleTabBarVisibilityAfterPopGesture];
        });
        return;
    }
    
    // 检查导航控制器是否存在
    if (!self.navigationController) {
        NSLog(@"在局⚠️ [handleTabBarVisibilityAfterPopGesture] navigationController不存在");
        return;
    }
    
    // 获取当前导航栈中的视图控制器
    NSArray *currentViewControllers = self.navigationController.viewControllers;
    NSLog(@"在局🔍 [handleTabBarVisibilityAfterPopGesture] 当前导航栈数量: %ld", (long)currentViewControllers.count);
    
    // 检查是否回到了根视图控制器（首页）
    BOOL isBackToRootViewController = (currentViewControllers.count <= 1);
    
    if (isBackToRootViewController) {
        NSLog(@"在局✅ [handleTabBarVisibilityAfterPopGesture] 检测到回到首页，显示tab栏");
        
        // 检查tabBarController是否存在
        if (self.tabBarController) {
            // 显示tab栏
            if (self.tabBarController.tabBar.hidden) {
                NSLog(@"在局🔧 [handleTabBarVisibilityAfterPopGesture] tab栏当前隐藏，正在显示");
                [UIView animateWithDuration:0.3 animations:^{
                    self.tabBarController.tabBar.hidden = NO;
                    self.tabBarController.tabBar.transform = CGAffineTransformIdentity;
                }];
            } else {
                NSLog(@"在局ℹ️ [handleTabBarVisibilityAfterPopGesture] tab栏已经显示");
            }
            
            // 确保根视图控制器的tabbar属性正确设置
            if (currentViewControllers.count > 0) {
                UIViewController *rootVC = currentViewControllers.firstObject;
                if ([rootVC respondsToSelector:@selector(setHidesBottomBarWhenPushed:)]) {
                    [rootVC setValue:@NO forKey:@"hidesBottomBarWhenPushed"];
                    NSLog(@"在局🔧 [handleTabBarVisibilityAfterPopGesture] 已重置根视图控制器的hidesBottomBarWhenPushed为NO");
                }
            }
        } else {
            NSLog(@"在局⚠️ [handleTabBarVisibilityAfterPopGesture] tabBarController不存在");
        }
    } else {
        NSLog(@"在局ℹ️ [handleTabBarVisibilityAfterPopGesture] 未回到首页（导航栈数量: %ld），保持tab栏隐藏状态", (long)currentViewControllers.count);
        
        // 确保tab栏保持隐藏状态
        if (self.tabBarController && !self.tabBarController.tabBar.hidden) {
            NSLog(@"在局🔧 [handleTabBarVisibilityAfterPopGesture] tab栏当前显示，正在隐藏");
            [UIView animateWithDuration:0.3 animations:^{
                self.tabBarController.tabBar.hidden = YES;
            }];
        }
    }
    
    NSLog(@"在局✅ [handleTabBarVisibilityAfterPopGesture] tab栏显示控制处理完成");
}


@end

