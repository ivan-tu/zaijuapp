//
//  AppDelegate.m
//  XZVientiane
//
//  Created by 崔逢举 on 2018/7/29.
//  Copyright © 2018年 崔逢举. All rights reserved.
//

#import "AppDelegate.h"
#import "TCConfig.h"
#import "LoadingView.h"
#import "XZTabBarController.h"
#import "PublicSettingModel.h"
#import "ClientSettingModel.h"
#import "XZWKWebViewBaseController.h" // 导入WebView基类以使用预加载方法
#import "XZWebViewPerformanceManager.h" // WebView性能优化管理器
// 友盟分享相关导入 - 使用正确路径
#import <UMShare/UMShare.h>
#import <UMShare/UMSociallogMacros.h>
#import <UMShare/UMSocialManager.h>
#import <UMShare/UMSocialGlobal.h>
// 创建缺失的头文件或跳过不存在的
// #import "NSUserDefaults+XZUserDefaults.h"  // 如果不存在可以暂时注释
// #import "XZUserDefaultFastDefine.h"        // 如果不存在可以暂时注释
#import "NetworkNoteViewController.h"
#import "WXApi.h"
// 修正支付宝SDK导入
#import <AlipaySDK/AlipaySDK.h>
// 修正为系统框架导入
#import <CoreTelephony/CTCellularData.h>
// 删除重复导入，已通过UserNotifications框架导入
// #import "UNUserNotificationCenter.h"
#import "UMCommon/UMCommon.h"
// 友盟推送相关导入 - 使用新版本UMPush
#import <UMPush/UMessage.h>
// #import "UMCommonLog/UMCommonLogMacros.h"  // 如果路径不对可以注释
// #import "UMCommonLog/UMCommonLogManager.h" // 如果路径不对可以注释  
// 使用CustomHybridProcessor替代HybridManager
#import "Reachability.h"
#import "JHSysAlertUtil.h"
#import <UserNotifications/UserNotifications.h>
// 添加SAMKeychain导入
#import <SAMKeychain/SAMKeychain.h>
// 添加高德地图相关导入
#import <AMapFoundationKit/AMapFoundationKit.h>
#import <AMapLocationKit/AMapLocationKit.h>

@interface AppDelegate () <WXApiDelegate,UNUserNotificationCenterDelegate>

@property (strong, nonatomic) AFNetworkReachabilityManager *internetReachability;  // 统一使用AFNetworkReachabilityManager
@property (strong, nonatomic) XZTabBarController *tabbarVC;
@property (strong, nonatomic) NSDictionary *dataDic;
@property (strong, nonatomic) NSDictionary *appInfoDic;
@property (assign, nonatomic) BOOL isAppConfigured;  // 重命名为更清晰的名称
@property (assign, nonatomic) UIBackgroundTaskIdentifier backgroundTaskIdentifier;
// 高德定位管理器
@property (strong, nonatomic) AMapLocationManager *locationManager;
// 存储通知观察者
@property (strong, nonatomic) id rerequestDataObserver;
// 网络权限弹窗控制
@property (nonatomic, assign) BOOL hasShownNetworkPermissionAlert;
@property (nonatomic, strong) NSDate *lastNetworkAlertDate;
// 初始化状态控制
@property (nonatomic, assign) BOOL hasInitialized;
@property (nonatomic, assign) BOOL isInitializing;

// 方法声明
- (void)showNetworkRestrictedAlert;

@end

@implementation AppDelegate

- (NSDictionary *)appInfoDic {
    if (_appInfoDic == nil) {
        _appInfoDic = [NSDictionary dictionary];
    }
    return _appInfoDic;
}

- (void)dealloc {
    // 移除 block-based 观察者
    if (self.rerequestDataObserver) {
        [[NSNotificationCenter defaultCenter] removeObserver:self.rerequestDataObserver];
        self.rerequestDataObserver = nil;
    }
    
    // 移除其他观察者
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    // 停止网络监控
    [self.internetReachability stopMonitoring];
    self.internetReachability = nil;
    
    // Reachability已被移除，无需停止
    
    // 清理定位管理器
    if (self.locationManager) {
        [self.locationManager stopUpdatingLocation];
        self.locationManager = nil;
    }
}

- (void)addNotif {
    WEAK_SELF;
    // 先移除旧的观察者（如果存在）
    if (self.rerequestDataObserver) {
        [[NSNotificationCenter defaultCenter] removeObserver:self.rerequestDataObserver];
        self.rerequestDataObserver = nil;
    }
    
    // 保存观察者引用，以便后续正确移除
    self.rerequestDataObserver = [[NSNotificationCenter defaultCenter] addObserverForName:@"RerequestData" object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification * _Nonnull note) {
        STRONG_SELF;
        if (!self) {
            return;
        }
        if (self.internetReachability.networkReachabilityStatus == AFNetworkReachabilityStatusNotReachable) {
            return ;
        }
        [self downloadManifestAppsource];
    }];
}

- (AFNetworkReachabilityManager *)internetReachability {
    if (_internetReachability == nil) {
        _internetReachability = [AFNetworkReachabilityManager manager];
    }
    return _internetReachability;
}

// 统一的网络状态监听配置
- (void)configureNetworkMonitoring:(UIApplication *)application launchOptions:(NSDictionary *)launchOptions {
    __weak typeof(self) weakSelf = self;
    [self.internetReachability setReachabilityStatusChangeBlock:^(AFNetworkReachabilityStatus status) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [strongSelf handleNetworkStatusChange:status application:application launchOptions:launchOptions];
        });
    }];
    [self.internetReachability startMonitoring];
}

// 处理网络状态变化
- (void)handleNetworkStatusChange:(AFNetworkReachabilityStatus)status 
                      application:(UIApplication *)application 
                    launchOptions:(NSDictionary *)launchOptions {
    switch (status) {
        case AFNetworkReachabilityStatusNotReachable:
        case AFNetworkReachabilityStatusReachableViaWiFi:
        case AFNetworkReachabilityStatusReachableViaWWAN:
            if (!self.isAppConfigured) {
                [self getInfo_application:application didFinishLaunchingWithOptions:launchOptions];
            }
            break;
        default:
            break;
    }
}


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // 应用启动开始
    
    // 网络监听将在网络权限检查后启动
    
    // 立即创建窗口并设置根视图控制器，避免场景更新超时
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.backgroundColor = [UIColor whiteColor];
    
    // 创建一个临时的根视图控制器来满足iOS要求
    UIViewController *tempRootViewController = [[UIViewController alloc] init];
    tempRootViewController.view.backgroundColor = [UIColor whiteColor];
    self.window.rootViewController = tempRootViewController;
    [self.window makeKeyAndVisible];
    
    // 显示加载界面（使用统一管理）
    [self showGlobalLoadingView];
    
    // 初始化配置数据
    [self locAppInfoData];
    
    // 启动HTML模板预加载优化（后台异步执行，不影响启动速度）
    [XZWKWebViewBaseController preloadHTMLTemplates];
    
    // 初始化WebView性能管理器并预热资源
    [[XZWebViewPerformanceManager sharedManager] preloadWebViewResources];
    
    // 立即初始化TabBar，不等待网络权限检查
    // 直接创建TabBar控制器，避免延迟
    self.tabbarVC = [[XZTabBarController alloc] init];
    self.window.rootViewController = self.tabbarVC;
    [self.tabbarVC reloadTabbarInterface];
    self.hasInitialized = YES;
    
    // 并行检查网络权限，不阻塞初始化
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        //1.获取网络权限 根据权限进行人机交互
        if (__IPHONE_10_0 && !TARGET_IPHONE_SIMULATOR) {
            [self networkStatus:application didFinishLaunchingWithOptions:launchOptions];
        } else {
            //2.2已经开启网络权限 监听网络状态
            dispatch_async(dispatch_get_main_queue(), ^{
                [self addReachabilityManager:application didFinishLaunchingWithOptions:launchOptions];
            });
        }
    });
    
    // 添加超时保护：10秒后如果还没有初始化完成，强制显示界面
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (!self.hasInitialized) {
            
            // 只有在网络正常的情况下才移除LoadingView
            if (!self.networkRestricted) {
                [self removeGlobalLoadingViewWithReason:@"初始化超时，网络正常"];
            } else {
                // 显示网络提示
                [self showNetworkRestrictedAlert];
            }
            
            // 如果TabBarController还没创建，创建一个
            if (!self.tabbarVC || !self.window.rootViewController) {
                self.tabbarVC = [[XZTabBarController alloc] init];
                self.window.rootViewController = self.tabbarVC;
                [self.tabbarVC reloadTabbarInterface];
            }
            
            // 确保窗口可见
            [self.window makeKeyAndVisible];
            
            // 发送通知确保TabBar显示
            [[NSNotificationCenter defaultCenter] postNotificationName:@"showTabviewController" object:nil];
            
            self.hasInitialized = YES;
        }
    });
    
    return YES;
}

- (void)downloadManifestAppsource {
    
    // 如果已经初始化或正在初始化，跳过
    if (self.hasInitialized || self.isInitializing) {
        return;
    }
    
    // 直接执行，不再添加LoadingView，因为已经在启动时添加了
    [self getAppInfo];
}


#pragma mark ----首次进入获取定位
- (void)getCurrentPosition {
    // 带逆地理信息的一次定位（返回坐标和地址信息）
    self.locationManager = [[AMapLocationManager alloc] init];
    // 带逆地理信息的一次定位（返回坐标和地址信息）
    [self.locationManager setDesiredAccuracy:kCLLocationAccuracyHundredMeters];
    //   定位超时时间，增加到10秒以提高成功率
    self.locationManager.locationTimeout = 10;
    //   逆地理请求超时时间，增加到8秒
    self.locationManager.reGeocodeTimeout = 8;
    [self.locationManager requestLocationWithReGeocode:YES completionBlock:^(CLLocation *location, AMapLocationReGeocode *regeocode, NSError *error) {
        if (error) {
            
            // 设置默认值，避免完全无定位信息
            NSUserDefaults *Defaults = [NSUserDefaults standardUserDefaults];
            [Defaults setObject:@(0) forKey:@"currentLat"];
            [Defaults setObject:@(0) forKey:@"currentLng"];
            [Defaults setObject:@"定位失败" forKey:@"currentCity"];
            [Defaults setObject:@"请手动选择位置" forKey:@"currentAddress"];
            [Defaults synchronize];
            return;
        }
        // 定位获取成功
        
        if (regeocode) {
            // 逆地理编码成功
        }
        CLLocationCoordinate2D coordinate = location.coordinate;
        NSUserDefaults *Defaults = [NSUserDefaults standardUserDefaults];
        if (coordinate.latitude == 0 && coordinate.longitude == 0) {
            [Defaults setObject:@(0) forKey:@"currentLat"];
            [Defaults setObject:@(0) forKey:@"currentLng"];
            [Defaults setObject:@"请选择" forKey:@"currentCity"];
            [Defaults setObject:@"请选择" forKey:@"currentAddress"];
            return;
        }
        [Defaults setObject:@(coordinate.latitude) forKey:@"currentLat"];
        [Defaults setObject:@(coordinate.longitude) forKey:@"currentLng"];
        // 安全处理regeocode为nil的情况
        NSString *cityName = (regeocode && regeocode.POIName.length > 0) ? regeocode.POIName : @"请选择";
        NSString *addressName = (regeocode && regeocode.formattedAddress.length > 0) ? regeocode.formattedAddress : @"请选择";
        [Defaults setObject:cityName forKey:@"currentCity"];
        [Defaults setObject:addressName forKey:@"currentAddress"];

        [Defaults synchronize];
    }];
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
    // 处理远程通知
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo {
    [UMessage didReceiveRemoteNotification:userInfo];
    
    //    if(![[userInfo class] isSubclassOfClass:[NSDictionary class]] || ![userInfo objectForKey:@"extra"]) {
    //        return;
    //    }
    //    NSString *extraStr = [userInfo objectForKey:@"extra"];
    //    NSDictionary *extraDic = [NSJSONSerialization JSONObjectWithData:[extraStr dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingMutableLeaves error:nil];
    //    NSDictionary *data = @{
    //                           @"id": [extraDic objectForKey:@"id"],
    //                           @"content": [extraDic objectForKey:@"content"],
    //                           @"title": [extraDic objectForKey:@"title"],
    //                           @"addtime": [extraDic objectForKey:@"addtime"],
    //                           @"url": [extraDic objectForKey:@"url"]
    //                           };
    //    NSDictionary *dataDic = @{
    //                              @"num": @(1),
    //                              @"type": [extraDic objectForKey:@"type"],
    //                              @"data": data
    //                              };
    //    NSDictionary *dic = @{
    //                          @"action": @"noticemsg_addMsg",
    //                          @"data": dataDic
    //                          };
}

- (void)applicationWillResignActive:(UIApplication *)application {
    
    // 发送通知让WebView暂停JavaScript执行
    [[NSNotificationCenter defaultCenter] postNotificationName:@"AppWillResignActiveNotification" object:nil];
    
    // 移除了 runUntilDate 调用以避免主线程阻塞
    // WebView会在收到通知后立即处理，无需等待
}

//app将要进入前台
- (void)applicationWillEnterForeground:(UIApplication *)application {
    [[UIApplication sharedApplication] endBackgroundTask: self.backgroundTaskIdentifier];

//    [ManageCenter requestMessageNumber:^(id aResponseObject, NSError *anError) {
//        [[NSNotificationCenter defaultCenter] postNotificationName:@"changeMessageNum" object:nil];
//    }];
}


//app进入后台
- (void)applicationDidEnterBackground:(UIApplication *)application {
    NSInteger num = [[NSUserDefaults standardUserDefaults] integerForKey:@"clinetMessageNum"];
    [UIApplication sharedApplication].applicationIconBadgeNumber = num;
    
    // 发送通知让WebView暂停JavaScript执行
    [[NSNotificationCenter defaultCenter] postNotificationName:@"AppDidEnterBackgroundNotification" object:nil];
    
    self.backgroundTaskIdentifier = [[UIApplication sharedApplication] beginBackgroundTaskWithName:@"deleyTimeTask" expirationHandler:^{
        // 后台任务超时
        if (self.backgroundTaskIdentifier != UIBackgroundTaskInvalid) {
            [[UIApplication sharedApplication] endBackgroundTask:self.backgroundTaskIdentifier];
            self.backgroundTaskIdentifier = UIBackgroundTaskInvalid;
        }
    }];
    
    // 严格遵守2秒后台执行时间限制，提前100ms结束以确保安全
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.9 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (self.backgroundTaskIdentifier != UIBackgroundTaskInvalid) {
            // 后台任务结束
            [[UIApplication sharedApplication] endBackgroundTask:self.backgroundTaskIdentifier];
            self.backgroundTaskIdentifier = UIBackgroundTaskInvalid;
        }
    });
}


- (void)applicationDidBecomeActive:(UIApplication *)application {
    // 应用进入前台时检查是否需要初始化
    if (!self.hasInitialized && !self.isInitializing && self.window) {
        // 延迟执行，确保UI完全准备好
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (!self.hasInitialized && !self.isInitializing) {
                [self getAppInfo];
            }
        });
    }
    
    // 恢复网络监控
    if (self.internetReachability && !self.internetReachability.isReachable) {
        [self.internetReachability startMonitoring];
    }
}

- (void)applicationWillTerminate:(UIApplication *)application {
    // 立即结束任何正在进行的后台任务
    if (self.backgroundTaskIdentifier != UIBackgroundTaskInvalid) {
        [[UIApplication sharedApplication] endBackgroundTask:self.backgroundTaskIdentifier];
        self.backgroundTaskIdentifier = UIBackgroundTaskInvalid;
    }
    
    // 仅保存必要的badge数字
    NSInteger num = [[NSUserDefaults standardUserDefaults] integerForKey:@"clinetMessageNum"];
    [UIApplication sharedApplication].applicationIconBadgeNumber = num;
    
    // 不执行任何耗时操作，让应用快速终止
}

// 在 iOS8 系统中，还需要添加这个方法。通过新的 API 注册推送服务
- (void)application:(UIApplication *)application didRegisterUserNotificationSettings:(UIUserNotificationSettings *)notificationSettings {
    [application registerForRemoteNotifications];
}

- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
    // 友盟推送 - 注册设备Token
    [UMessage registerDeviceToken:deviceToken];
    [UMessage setAutoAlert:NO];
    if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 13) {
        if (![deviceToken isKindOfClass:[NSData class]]) {
            //记录获取token失败的描述
            return;
        }
        const unsigned *tokenBytes = (const unsigned *)[deviceToken bytes];
        NSString *strToken = [NSString stringWithFormat:@"%08x%08x%08x%08x%08x%08x%08x%08x",
                              ntohl(tokenBytes[0]), ntohl(tokenBytes[1]), ntohl(tokenBytes[2]),
                              ntohl(tokenBytes[3]), ntohl(tokenBytes[4]), ntohl(tokenBytes[5]),
                              ntohl(tokenBytes[6]), ntohl(tokenBytes[7])];
        // Device token获取成功
        [[NSUserDefaults standardUserDefaults] setObject:strToken forKey:User_ChannelId];
        [[NSUserDefaults standardUserDefaults] synchronize];
    } else {
        NSString *token = [NSString
                           stringWithFormat:@"%@",deviceToken];
        token = [token stringByReplacingOccurrencesOfString:@"<" withString:@""];
        token = [token stringByReplacingOccurrencesOfString:@">" withString:@""];
        token = [token stringByReplacingOccurrencesOfString:@" " withString:@""];
        // Device token获取成功
        [[NSUserDefaults standardUserDefaults] setObject:token forKey:User_ChannelId];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    
    
//    [ManageCenter requestMessageNumber:^(id aResponseObject, NSError *anError) {
//        [[NSNotificationCenter defaultCenter] postNotificationName:@"changeMessageNum" object:nil];
//    }];
}

- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error {
    // 推送注册失败
}

#pragma mark - 微信QQ授权回调方法 -

-(void) onReq:(BaseReq*)request {
    // 微信请求回调
}

-(void) onResp:(BaseResp*)response {
    
    if([response isKindOfClass:[PayResp class]]) {
        PayResp *res = (PayResp *)response;
        switch (res.errCode) {
            case WXSuccess:
            {
                [[NSNotificationCenter defaultCenter] postNotificationName:@"weixinPay" object:@"true"];
            }
                break;
            default:
            {
                [[NSNotificationCenter defaultCenter] postNotificationName:@"weixinPay" object:@"false"];
            }
                break;
        }
        return;
    }
    
    // 处理微信登录授权回调
    if([response isKindOfClass:[SendAuthResp class]]) {
        SendAuthResp *authResp = (SendAuthResp *)response;
        
        NSDictionary *authResult = nil;
        switch (authResp.errCode) {
            case WXSuccess:
                authResult = @{
                    @"success": @"true",
                    @"code": authResp.code ?: @"",
                    @"state": authResp.state ?: @"",
                    @"errorMessage": @""
                };
                break;
            case WXErrCodeUserCancel:
                authResult = @{
                    @"success": @"false", 
                    @"errorMessage": @"用户取消授权",
                    @"data": @{}
                };
                break;
            case WXErrCodeAuthDeny:
                authResult = @{
                    @"success": @"false", 
                    @"errorMessage": @"微信授权被拒绝", 
                    @"data": @{}
                };
                break;
            default:
                authResult = @{
                    @"success": @"false", 
                    @"errorMessage": [NSString stringWithFormat:@"微信登录失败(%d)", authResp.errCode],
                    @"data": @{}
                };
                break;
        }
        
        // 发送登录授权结果通知
        [[NSNotificationCenter defaultCenter] postNotificationName:@"wechatAuthResult" object:authResult];
        return;
    }
    
    // 处理微信分享回调
    if([response isKindOfClass:[SendMessageToWXResp class]]) {
        SendMessageToWXResp *resp = (SendMessageToWXResp *)response;
        
        NSString *resultMessage = @"";
        BOOL shareSuccess = NO;
        
        switch (resp.errCode) {
            case WXSuccess:
                resultMessage = @"分享成功";
                shareSuccess = YES;
                break;
            case WXErrCodeCommon:
                resultMessage = @"分享失败";
                break;
            case WXErrCodeUserCancel:
                resultMessage = @"分享已取消";
                break;
            case WXErrCodeSentFail:
                resultMessage = @"分享发送失败";
                break;
            case WXErrCodeAuthDeny:
                resultMessage = @"微信授权失败";
                break;
            case WXErrCodeUnsupport:
                resultMessage = @"微信版本过低";
                break;
            default:
                resultMessage = [NSString stringWithFormat:@"分享失败(%d)", resp.errCode];
                break;
        }
        
        // 发送分享结果通知
        NSDictionary *shareResult = @{
            @"success": shareSuccess ? @"true" : @"false",
            @"errorCode": @(resp.errCode),
            @"errorMessage": resultMessage
        };
        [[NSNotificationCenter defaultCenter] postNotificationName:@"wechatShareResult" object:shareResult];
        return;
    }
    
}

#pragma mark -  回调

- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenURLOptionsKey, id> *)options {
    
    //6.3的新的API调用，是为了兼容国外平台(例如:新版facebookSDK,VK等)的调用[如果用6.2的api调用会没有回调],对国内平台没有影响。
    BOOL result = [[UMSocialManager defaultManager]  handleOpenURL:url options:options];
    
    // UMSocialManager处理URL回调
    
    if (!result) {
        //银联和支付宝支付返回结果
        if ([url.host isEqualToString:@"safepay"] || [url.host isEqualToString:@"platformapi"] || [url.host isEqualToString:@"uppayresult"]) {
            // 支付回调处理
            [[NSNotificationCenter defaultCenter] postNotificationName:@"payresultnotif" object:url];
            return YES;
        }
        else if ( [url.host isEqualToString:@"pay"]) {
            // 微信支付回调处理
            return [WXApi handleOpenURL:url delegate:self];
        }
        
    }
    NSDictionary *dic = @{
        @"result" : @(result),
        @"urlhost" : url.host ? url.host : @"",
    };
    // 发送分享结果通知
    [[NSNotificationCenter defaultCenter] postNotificationName:@"shareresultnotif" object:dic];
    return result;
}


- (void)getAppInfo {
    
    // 防止重复初始化
    if (self.hasInitialized || self.isInitializing) {
        // 如果TabBar已经创建，只需要发送显示通知
        if (self.tabbarVC) {
            [[NSNotificationCenter defaultCenter] postNotificationName:@"showTabviewController" object:nil];
        }
        return;
    }
    
    self.isInitializing = YES;
    
    // 检查窗口是否存在
    if (!self.window) {
        self.isInitializing = NO;
        return;
    }
    
    //标明是否带底部当好条
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"NoTabBar"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    // 如果TabBar已经存在，直接完成初始化
    if (self.tabbarVC) {
        self.hasInitialized = YES;
        self.isInitializing = NO;
        [[NSNotificationCenter defaultCenter] postNotificationName:@"showTabviewController" object:nil];
        return;
    }
    
    // 否则创建TabBar
    [self reloadByTabbarController];
    self.hasInitialized = YES;
    self.isInitializing = NO;
    
    // 立即触发TabBar显示通知
    [[NSNotificationCenter defaultCenter] postNotificationName:@"showTabviewController" object:nil];
}

//获取分享和推送的设置信息
- (void)getSharePushInfo {
    [self loadConfigurationFile:@"shareInfo" completion:^(NSDictionary *dataDic) {
        self.dataDic = [dataDic objectForKey:@"data"];
        [self publicSetting:self.dataDic];
    }];
}

- (void)reloadByTabbarController {
    
    // 检查tabbarVC是否存在
    if (!self.tabbarVC) {
        self.tabbarVC = [[XZTabBarController alloc] initWithNibName:nil bundle:nil];
        
        // 确保在主线程设置根视图控制器
        if ([NSThread isMainThread]) {
            self.window.rootViewController = self.tabbarVC;
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                self.window.rootViewController = self.tabbarVC;
            });
        }
    }
    
    // 使用弱引用避免循环引用
    __weak typeof(self) weakSelf = self;
    
    // 确保在主线程执行
    void (^reloadBlock)(void) = ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf && strongSelf.tabbarVC) {
            // 检查是否有reloadTabbarInterface方法
            if ([strongSelf.tabbarVC respondsToSelector:@selector(reloadTabbarInterface)]) {
                [strongSelf.tabbarVC reloadTabbarInterface];
            } else {
            }
        }
    };
    
    if ([NSThread isMainThread]) {
        reloadBlock();
    } else {
        dispatch_async(dispatch_get_main_queue(), reloadBlock);
    }
}
//给分享、支付所有的账号赋值
- (void)publicSetting:(NSDictionary *)dic {
    [[PublicSettingModel sharedInstance] setAppSiteId:[ClientSettingModel sharedInstance].AppSiteId];
    if (![[dic class] isSubclassOfClass:[NSDictionary class]]) {
        return;
    }
    [[PublicSettingModel sharedInstance] setUmeng_appkey:[dic objectForKey:@"pushAppKey"]];
    [[PublicSettingModel sharedInstance] setWeiBo_AppKey:[dic objectForKey:@"wbAppId"]];
    [[PublicSettingModel sharedInstance] setWeiBo_AppSecret:[dic objectForKey:@"wbAppScret"]];
    [[PublicSettingModel sharedInstance] setWeiBo_URL:[dic objectForKey:@"wbUrl"]];
    NSString *wxAppId ;
    if ([dic objectForKey:@"wxAppId"]) {
        wxAppId = [dic objectForKey:@"wxAppId"];
    }
    if (!wxAppId || wxAppId.length == 0) {
        wxAppId = [[dic objectForKey:@"wxpayApp"] objectForKey:@"APPID"];
    }
    NSString *wxAppSecret ;
    if ([dic objectForKey:@"wxAppScret"]) {
        wxAppSecret = [dic objectForKey:@"wxAppScret"];
    }
    if (!wxAppSecret || wxAppSecret.length == 0) {
        wxAppSecret = [[dic objectForKey:@"wxpayApp"] objectForKey:@"APPID"];
    }
    [[PublicSettingModel sharedInstance] setWeiXin_AppID:wxAppId];
    [[PublicSettingModel sharedInstance] setWeiXin_AppSecret:wxAppSecret];
    
    NSDictionary *payDic = [dic objectForKey:@"wxpayApp"];
    [[PublicSettingModel sharedInstance] setWeiXin_Key:[payDic objectForKey:@"KEY"]];
    [[PublicSettingModel sharedInstance] setWeiXin_Partnerid:[payDic objectForKey:@"MCHID"]];
    
    [[PublicSettingModel sharedInstance] setQq_AppId:[dic objectForKey:@"qqAppId"]];
    [[PublicSettingModel sharedInstance] setQq_AppKey:[dic objectForKey:@"qqAppScret"]];
    
    [self socialShare];
}

- (void)socialShare {
    //设置友盟社会化组件appkey
    NSString *UMENG_APPKEY = [[PublicSettingModel sharedInstance] umeng_appkey];
    //友盟推送  如果分享应用和推送应用是一个，则注册的appkey是一样的
    if (UMENG_APPKEY && UMENG_APPKEY.length > 0) {
        // 友盟推送初始化 - 使用新版本API
        [UMessage registerForRemoteNotificationsWithLaunchOptions:nil Entity:nil completionHandler:^(BOOL granted, NSError * _Nullable error) {
        if (granted) {
            NSLog(@"在局 友盟推送注册成功");
        } else {
            NSLog(@"在局 友盟推送注册失败: %@", error);
        }
    }];
        [UMConfigure initWithAppkey:UMENG_APPKEY channel:@"App Store"];
        
        //iOS10必须加下面这段代码。
        UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
        center.delegate=self;
        UNAuthorizationOptions types10=UNAuthorizationOptionBadge|UNAuthorizationOptionAlert|UNAuthorizationOptionSound;
        [center requestAuthorizationWithOptions:types10 completionHandler:^(BOOL granted, NSError * _Nullable error) {
            if (granted) {
                //点击允许
            } else {
                //点击不允许
            }
        }];
        //如果你期望使用交互式(只有iOS 8.0及以上有)的通知，请参考下面注释部分的初始化代码
        UIMutableUserNotificationAction *action1 = [[UIMutableUserNotificationAction alloc] init];
        action1.identifier = @"action1_identifier";
        action1.title=@"打开应用";
        action1.activationMode = UIUserNotificationActivationModeForeground;//当点击的时候启动程序
        
        UIMutableUserNotificationAction *action2 = [[UIMutableUserNotificationAction alloc] init];  //第二按钮
        action2.identifier = @"action2_identifier";
        action2.title=@"忽略";
        action2.activationMode = UIUserNotificationActivationModeBackground;//当点击的时候不启动程序，在后台处理
        action2.authenticationRequired = YES;//需要解锁才能处理，如果action.activationMode = UIUserNotificationActivationModeForeground;则这个属性被忽略；
        action2.destructive = YES;
        UIMutableUserNotificationCategory *actionCategory1 = [[UIMutableUserNotificationCategory alloc] init];
        actionCategory1.identifier = @"category1";//这组动作的唯一标示
        [actionCategory1 setActions:@[action1,action2] forContext:(UIUserNotificationActionContextDefault)];
        NSSet *categories = [NSSet setWithObjects:actionCategory1, nil];
        
        // iOS 10+通知分类配置（项目最低支持iOS 15.0，无需iOS 8兼容）
        UNNotificationAction *tenaction1 = [UNNotificationAction actionWithIdentifier:@"tenaction1_identifier" title:@"打开应用" options:UNNotificationActionOptionForeground];
        
        UNNotificationAction *tenaction2 = [UNNotificationAction actionWithIdentifier:@"tenaction2_identifier" title:@"忽略" options:UNNotificationActionOptionForeground];
        
        //UNNotificationCategoryOptionNone
        //UNNotificationCategoryOptionCustomDismissAction  清除通知被触发会走通知的代理方法
        //UNNotificationCategoryOptionAllowInCarPlay       适用于行车模式
        UNNotificationCategory *tencategory1 = [UNNotificationCategory categoryWithIdentifier:@"tencategory1" actions:@[tenaction2,tenaction1]   intentIdentifiers:@[] options:UNNotificationCategoryOptionCustomDismissAction];
        NSSet *tencategories = [NSSet setWithObjects:tencategory1, nil];
        [center setNotificationCategories:tencategories];
        //        UIUserNotificationSettings *userSettings = [UIUserNotificationSettings settingsForTypes:UIUserNotificationTypeBadge|UIUserNotificationTypeSound|UIUserNotificationTypeAlert categories:nil];
        //        [UMessage registerRemoteNotificationAndUserNotificationSettings:userSettings];
#if DEBUG
        // 友盟推送调试日志 - 新版本SDK通过UMConfigure统一管理日志
        // [UMessage setLogEnabled:YES]; // 此方法在新版本SDK中已移除
#endif
    }
    if (UMENG_APPKEY) {
        [UMConfigure initWithAppkey:UMENG_APPKEY channel:@"App Store"];
    }
    //打开调试log的开关
#if DEBUG
    [UMConfigure setLogEnabled:YES];
#endif
    //设置微信AppId，设置分享url，默认使用友盟的网址
    [UMSocialGlobal shareInstance].universalLinkDic = @{@(UMSocialPlatformType_WechatSession):@"https://zaiju.com/app/",
                                                        @(UMSocialPlatformType_QQ):@""
    };
    [[UMSocialManager defaultManager] setPlaform:UMSocialPlatformType_WechatSession appKey:[[PublicSettingModel sharedInstance] weiXin_AppID] appSecret:[[PublicSettingModel sharedInstance] weiXin_AppSecret] redirectURL:nil];
    
    [WXApi registerApp:[[PublicSettingModel sharedInstance] weiXin_AppID] universalLink:@"https://zaiju.com/app/"];
    
    // 打开新浪微博的SSO开关
    [[UMSocialManager defaultManager] setPlaform:UMSocialPlatformType_Sina appKey:[[PublicSettingModel sharedInstance] weiBo_AppKey] appSecret:[[PublicSettingModel sharedInstance] weiBo_AppSecret] redirectURL:@"https://sns.whalecloud.com/sina2/callback"];
    
    //设置分享到QQ空间的应用Id，和分享url 链接
    [[UMSocialManager defaultManager] setPlaform:UMSocialPlatformType_QQ appKey:[[PublicSettingModel sharedInstance] qq_AppId]/*设置QQ平台的appID*/  appSecret:nil redirectURL:nil];
    
}

//iOS10新增：处理前台收到通知的代理方法
-(void)userNotificationCenter:(UNUserNotificationCenter *)center willPresentNotification:(UNNotification *)notification withCompletionHandler:(void (^)(UNNotificationPresentationOptions))completionHandler API_AVAILABLE(ios(10.0)){
    NSDictionary * userInfo = notification.request.content.userInfo;
    if([notification.request.trigger isKindOfClass:[UNPushNotificationTrigger class]]) {
        //应用处于前台时的远程推送接受
        //关闭友盟自带的弹出框
        [UMessage setAutoAlert:NO];
        //必须加这句代码
        [UMessage didReceiveRemoteNotification:userInfo];
        NSDictionary *aps = [userInfo valueForKey:@"aps"];
        NSInteger num = [[aps valueForKey:@"badge"] integerValue];
        [[NSUserDefaults standardUserDefaults] setInteger:num forKey:@"clinetMessageNum"];
        [[NSUserDefaults standardUserDefaults]synchronize];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"changeMessageNum" object:nil];
    } else{
        //应用处于前台时的本地推送接受
    }
    //当应用处于前台时提示设置，需要哪个可以设置哪一个
    completionHandler(UNNotificationPresentationOptionSound|UNNotificationPresentationOptionBadge|UNNotificationPresentationOptionAlert);
}

//iOS10新增：处理后台点击通知的代理方法
-(void)userNotificationCenter:(UNUserNotificationCenter *)center didReceiveNotificationResponse:(UNNotificationResponse *)response withCompletionHandler:(void (^)(void))completionHandler API_AVAILABLE(ios(10.0)){
    NSDictionary * userInfo = response.notification.request.content.userInfo;
    if([response.notification.request.trigger isKindOfClass:[UNPushNotificationTrigger class]]) {
        //应用处于后台时的远程推送接受
        //必须加这句代码
        [UMessage didReceiveRemoteNotification:userInfo];
        
    } else{
        //应用处于后台时的本地推送接受
    }
    
}

-(BOOL)application:(UIApplication *)application continueUserActivity:(NSUserActivity *)userActivity restorationHandler:(void (^)(NSArray * _Nullable))restorationHandler{
    
    
    // 处理Universal Links
    if ([userActivity.activityType isEqualToString:NSUserActivityTypeBrowsingWeb]) {
        NSURL *url = userActivity.webpageURL;
        if (url) {
            
            // 处理Universal Link
            BOOL handled = [self handleUniversalLink:url];
            if (handled) {
                return YES;
            } else {
                return NO;
            }
        } else {
            return NO;
        }
    }
    
    return NO;
}

/*
 CTCellularData在iOS9之前是私有类，权限设置是iOS10开始的，所以App Store审核没有问题
 获取网络权限状态
 */
- (void)networkStatus:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    if (@available(iOS 9.0, *)) {
        [self checkNetworkPermissionWithApplication:application launchOptions:launchOptions];
    } else {
        // iOS 9.0 以下直接初始化
        [self addReachabilityManager:application didFinishLaunchingWithOptions:launchOptions];
    }
}

// 检查网络权限（iOS 9.0+）
- (void)checkNetworkPermissionWithApplication:(UIApplication *)application launchOptions:(NSDictionary *)launchOptions {
    WEAK_SELF;
    NSLog(@"在局Claude Code[网络权限]+开始检查网络权限, 时间: %@", [NSDate date]);
    
    // 创建信号量确保权限检查完成后再继续
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    __block BOOL hasReceivedCallback = NO;
    
    void (^checkBlock)(void) = ^{
        CTCellularData *cellularData = [[CTCellularData alloc] init];
        cellularData.cellularDataRestrictionDidUpdateNotifier = ^(CTCellularDataRestrictedState state) {
            STRONG_SELF;
            NSLog(@"在局Claude Code[网络权限]+收到网络权限回调, 状态: %ld, 时间: %@", (long)state, [NSDate date]);
            
            // 标记已收到回调
            if (!hasReceivedCallback) {
                hasReceivedCallback = YES;
                dispatch_semaphore_signal(semaphore);
            }
            
            [self handleNetworkPermissionState:state application:application launchOptions:launchOptions];
        };
    };
    
    // 执行检查
    checkBlock();
    
    // 后台线程等待权限回调，超时2秒
    [self waitForNetworkPermissionWithApplication:application launchOptions:launchOptions semaphore:semaphore];
}

// 处理网络权限状态
- (void)handleNetworkPermissionState:(CTCellularDataRestrictedState)state 
                         application:(UIApplication *)application 
                       launchOptions:(NSDictionary *)launchOptions {
    
    // 防止短时间内重复弹窗
    if ([self shouldSkipNetworkAlert]) {
        return;
    }
    
    switch (state) {
        case kCTCellularDataRestricted:
            [self handleNetworkRestricted:application launchOptions:launchOptions];
            break;
            
        case kCTCellularDataNotRestricted:
            [self handleNetworkNotRestricted:application launchOptions:launchOptions];
            break;
            
        case kCTCellularDataRestrictedStateUnknown:
            [self handleNetworkStateUnknown:application launchOptions:launchOptions];
            break;
            
        default:
            break;
    }
}

// 处理网络受限状态
- (void)handleNetworkRestricted:(UIApplication *)application launchOptions:(NSDictionary *)launchOptions {
    self.networkRestricted = YES;
    
    if ([self isFirstAuthorizationNetwork]) {
        [self showNetworkPermissionAlert:application launchOptions:launchOptions];
    } else {
        [self delayedInitialization:application launchOptions:launchOptions delay:0.3];
    }
}

// 处理网络不受限状态
- (void)handleNetworkNotRestricted:(UIApplication *)application launchOptions:(NSDictionary *)launchOptions {
    self.hasShownNetworkPermissionAlert = NO;
    BOOL wasRestricted = self.networkRestricted;
    self.networkRestricted = NO;
    
    
    [self delayedInitialization:application launchOptions:launchOptions delay:0.3];
    
    // 从受限状态恢复时的特殊处理
    if (wasRestricted) {
        [self handleNetworkRecovery];
    }
}

// 处理网络状态未知
- (void)handleNetworkStateUnknown:(UIApplication *)application launchOptions:(NSDictionary *)launchOptions {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self addReachabilityManager:application didFinishLaunchingWithOptions:launchOptions];
    });
}

// 显示网络权限提示弹窗
- (void)showNetworkPermissionAlert:(UIApplication *)application launchOptions:(NSDictionary *)launchOptions {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.lastNetworkAlertDate = [NSDate date];
        self.hasShownNetworkPermissionAlert = YES;
        
        __weak typeof(self) weakSelf = self;
        [JHSysAlertUtil presentAlertViewWithTitle:@"温馨提示" 
            message:@"若要网络功能正常使用,您可以在'设置'中为此应用打开网络权限" 
            cancelTitle:@"设置" 
            defaultTitle:@"好" 
            distinct:NO 
            cancel:^{
                [weakSelf openAppSettings];
            } 
            confirm:^{
                [weakSelf delayedInitialization:application launchOptions:launchOptions delay:0.5];
            }];
    });
}

// 网络恢复后的处理
- (void)handleNetworkRecovery {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"在局Claude Code[网络恢复]+开始处理网络恢复");
        if (!self.isLoadingViewRemoved) {
            [self removeGlobalLoadingViewWithReason:@"网络权限从受限恢复"];
        }
        
        [self triggerFirstTabLoadIfNeeded];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"NetworkPermissionRestored" object:nil];
        
        // 延迟触发首页重新加载
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self triggerHomePageReload];
        });
    });
}

// 延迟初始化
- (void)delayedInitialization:(UIApplication *)application 
                launchOptions:(NSDictionary *)launchOptions 
                        delay:(NSTimeInterval)delay {
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf && strongSelf.window) {
            [strongSelf addReachabilityManager:application didFinishLaunchingWithOptions:launchOptions];
        }
    });
}

// 等待网络权限回调
- (void)waitForNetworkPermissionWithApplication:(UIApplication *)application 
                                  launchOptions:(NSDictionary *)launchOptions
                                      semaphore:(dispatch_semaphore_t)semaphore {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSLog(@"在局Claude Code[网络权限]+开始等待网络权限回调, 超时时间: 2秒");
        dispatch_time_t timeout = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC));
        long result = dispatch_semaphore_wait(semaphore, timeout);
        
        if (result != 0) {
            NSLog(@"在局Claude Code[网络权限]+等待超时, 假设网络权限已开启, 时间: %@", [NSDate date]);
            // 超时处理，假设网络权限已开启
            dispatch_async(dispatch_get_main_queue(), ^{
                [self addReachabilityManager:application didFinishLaunchingWithOptions:launchOptions];
            });
        } else {
            NSLog(@"在局Claude Code[网络权限]+收到网络权限回调信号, 时间: %@", [NSDate date]);
        }
    });
}

// 检查是否应该跳过网络提示
- (BOOL)shouldSkipNetworkAlert {
    return self.lastNetworkAlertDate && 
           [[NSDate date] timeIntervalSinceDate:self.lastNetworkAlertDate] < 30.0;
}

// 打开应用设置
- (void)openAppSettings {
    NSURL *url = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
    if ([[UIApplication sharedApplication] canOpenURL:url]) {
        if (@available(iOS 10.0, *)) {
            [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
        } else {
            [[UIApplication sharedApplication] openURL:url];
        }
    }
}

// 触发首页重新加载
- (void)triggerHomePageReload {
    if (self.tabbarVC) {
        UINavigationController *nav = self.tabbarVC.viewControllers.firstObject;
        if ([nav isKindOfClass:[UINavigationController class]]) {
            UIViewController *vc = nav.viewControllers.firstObject;
            
            if ([vc respondsToSelector:@selector(domainOperate)]) {
                [vc performSelector:@selector(domainOperate)];
            }
            
            if ([vc respondsToSelector:@selector(reloadWebViewContent)]) {
                [vc performSelector:@selector(reloadWebViewContent)];
            }
        }
    }
}

/**
 实时检查当前网络状态
 */
- (void)addReachabilityManager:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // 防止重复初始化
    if (self.isAppConfigured && self.internetReachability) {
        [self restartNetworkMonitoringIfNeeded];
        return;
    }
    
    [self configureNetworkMonitoring:application launchOptions:launchOptions];
}

// 重启网络监控（如果需要）
- (void)restartNetworkMonitoringIfNeeded {
    if (![self.internetReachability isReachable]) {
        [self.internetReachability stopMonitoring];
        [self.internetReachability startMonitoring];
    }
}

- (void)getInfo_application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.isAppConfigured = YES;
    //获取初始信息
    [self initData];
    
    // 🚀【性能优化】预加载HTML模板和WebView资源
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        NSLog(@"在局Claude Code[性能优化]+开始预加载HTML模板");
        // 预加载HTML模板到内存
        [XZWKWebViewBaseController preloadHTMLTemplates];
        
        // 预热WebView池
        [[XZWebViewPerformanceManager sharedManager] preloadWebViewResources];
        NSLog(@"在局Claude Code[性能优化]+HTML模板和WebView预加载完成");
    });
    
    WEAK_SELF;
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        STRONG_SELF;
        //第三方库初始化
        [self initValueThirdParty:application didFinishLaunchingWithOptions:launchOptions];
    });
    //添加通知
    [self addNotif];
    
    // 修复权限授予后首页空白问题 - 延迟检查并触发首页加载
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self triggerFirstTabLoadIfNeeded];
    });
}

- (void)initValueThirdParty:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // 所有第三方库初始化都在后台线程执行，避免阻塞主线程
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        //高德地图
        // 设置隐私政策配置 - 解决AMapFoundationErrorPrivacyShowUnknow错误
        [AMapServices sharedServices].enableHTTPS = YES;
        // 设置隐私权政策同意状态，这里设置为已同意
        // [[AMapServices sharedServices] setApiKey:@"071329e3bbb36c12947b544db8d20cfa"];	//cc.tuiya.hi3
        [[AMapServices sharedServices] setApiKey:@"5db21be74335137ce5636710c8ea9087"];		//com.zaiju
		
        
        // 使用正确的隐私政策设置API - 必须在AMapLocationManager实例化之前调用
        [AMapLocationManager updatePrivacyShow:AMapPrivacyShowStatusDidShow privacyInfo:AMapPrivacyInfoStatusDidContain];
        [AMapLocationManager updatePrivacyAgree:AMapPrivacyAgreeStatusDidAgree];
        
        [self getCurrentPosition];
        
        // UI更新必须在主线程
        dispatch_async(dispatch_get_main_queue(), ^{
            [self getSharePushInfo];
        });
    });
}

- (void)initData {
    // 在后台线程执行数据初始化，避免阻塞主线程
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self localNavSettingData];
    });
}

//解析本地头部导航配置 json文件
- (void)localNavSettingData {
    [self downloadManifestAppsource];
}

//解析本地appinfo json
- (void)locAppInfoData {
    [self loadConfigurationFile:@"appInfo" completion:^(NSDictionary *dataDic) {
        self.appInfoDic = dataDic;
    }];
}

// 统一的配置文件加载方法
- (void)loadConfigurationFile:(NSString *)fileName completion:(void(^)(NSDictionary *dataDic))completion {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSError *error = nil;
        NSData *JSONData = [NSData dataWithContentsOfFile:[[NSBundle mainBundle] pathForResource:fileName ofType:@"json"]];
        
        if (!JSONData) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(nil);
            });
            return;
        }
        
        NSDictionary *dataDic = [NSJSONSerialization JSONObjectWithData:JSONData options:NSJSONReadingAllowFragments error:&error];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(error ? nil : dataDic);
        });
    });
}

// MARK: 是否是第一次授权使用网络(针对国行iOS10且需要连接移动网络的设备)
- (BOOL)isFirstAuthorizationNetwork {
    NSString *serviceName = [[NSBundle mainBundle] bundleIdentifier];
    NSString *isFirst = [SAMKeychain passwordForService:serviceName account:kSAMKeychainLabelKey];
    if (! isFirst || isFirst.length < 1) {
        [SAMKeychain setPassword:@"FirstAuthorizationNetwork" forService:serviceName account:kSAMKeychainLabelKey];
        return YES;
    } else {
        return NO;
    }
}

// 修复权限授予后首页空白问题 - 检查并触发第一个Tab加载
- (void)triggerFirstTabLoadIfNeeded {
    
    if (!self.tabbarVC) {
        return;
    }
    
    // 获取第一个Tab的ViewController
    if (self.tabbarVC.viewControllers.count > 0) {
        UINavigationController *firstNav = self.tabbarVC.viewControllers[0];
        if ([firstNav isKindOfClass:[UINavigationController class]] && firstNav.viewControllers.count > 0) {
            UIViewController *rootVC = firstNav.viewControllers[0];
            if ([rootVC isKindOfClass:NSClassFromString(@"CFJClientH5Controller")]) {
                // 使用performSelector避免直接依赖
                if ([rootVC respondsToSelector:@selector(isWebViewLoading)] && 
                    [rootVC respondsToSelector:@selector(isLoading)] &&
                    [rootVC respondsToSelector:@selector(pinUrl)] &&
                    [rootVC respondsToSelector:@selector(domainOperate)]) {
                    
                    BOOL isWebViewLoading = [[rootVC valueForKey:@"isWebViewLoading"] boolValue];
                    BOOL isLoading = [[rootVC valueForKey:@"isLoading"] boolValue];
                    NSString *pinUrl = [rootVC valueForKey:@"pinUrl"];
                    
                    if (!isWebViewLoading && !isLoading && pinUrl) {
                        // 添加节流机制，防止重复调用
                        static NSDate *lastTriggerTime = nil;
                        NSDate *now = [NSDate date];
                        if (!lastTriggerTime || [now timeIntervalSinceDate:lastTriggerTime] > 3.0) {
                            [rootVC performSelector:@selector(domainOperate)];
                            lastTriggerTime = now;
                        } else {
                        }
                    } else {
                    }
                }
            }
        }
    }
}

#pragma mark - 网络权限提示

- (void)showNetworkRestrictedAlert {
    // 防止重复弹窗
    if (self.hasShownNetworkPermissionAlert) {
        return;
    }
    
    // 确保在主线程执行
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alert = [UIAlertController 
            alertControllerWithTitle:@"网络权限受限" 
            message:@"请在\"设置-无线局域网\"中为在局App开启\"无线数据\"权限，以正常使用App功能。" 
            preferredStyle:UIAlertControllerStyleAlert];
        
        UIAlertAction *settingAction = [UIAlertAction 
            actionWithTitle:@"去设置" 
            style:UIAlertActionStyleDefault 
            handler:^(UIAlertAction * _Nonnull action) {
                // 跳转到系统设置
                NSURL *url = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
                if ([[UIApplication sharedApplication] canOpenURL:url]) {
                    [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
                }
            }];
        
        UIAlertAction *cancelAction = [UIAlertAction 
            actionWithTitle:@"暂不设置" 
            style:UIAlertActionStyleCancel 
            handler:nil];
        
        [alert addAction:cancelAction];
        [alert addAction:settingAction];
        
        // 获取当前显示的视图控制器
        UIViewController *rootViewController = self.window.rootViewController;
        if (rootViewController) {
            [rootViewController presentViewController:alert animated:YES completion:nil];
            self.hasShownNetworkPermissionAlert = YES;
            self.lastNetworkAlertDate = [NSDate date];
        }
    });
}

#pragma mark - Universal Links处理

/**
 * 处理Universal Link URL
 * @param url 接收到的URL
 * @return 是否成功处理
 */
- (BOOL)handleUniversalLink:(NSURL *)url {
    
    // 验证域名
    NSString *host = url.host;
    if (![host isEqualToString:@"zaiju.com"] && ![host isEqualToString:@"hi3.tuiya.cc"]) {
        return NO;
    }
    
    // 解析路径
    NSString *path = url.path;
    
    // 检查是否是微信回调，如果是则转换为URL Scheme调用
    // 匹配所有微信回调：/app/wx开头且包含微信AppID的路径都是微信回调
    NSString *wxAppID = [[PublicSettingModel sharedInstance] weiXin_AppID];
    if ([path hasPrefix:@"/app/wx"] && wxAppID && [path containsString:wxAppID]) {
        
        // 直接使用原始URL调用微信SDK，因为微信SDK内部会处理Universal Link
        // 手动调用微信SDK处理Universal Link
        dispatch_async(dispatch_get_main_queue(), ^{
            NSUserActivity *userActivity = [[NSUserActivity alloc] initWithActivityType:NSUserActivityTypeBrowsingWeb];
            userActivity.webpageURL = url;
            
            BOOL handled = [WXApi handleOpenUniversalLink:userActivity delegate:self];
            
            if (!handled) {
                // 如果Universal Link处理失败，回退到URL Scheme
                NSString *wxScheme = [NSString stringWithFormat:@"%@://platformapi/startapp", wxAppID];
                if (url.query && url.query.length > 0) {
                    wxScheme = [wxScheme stringByAppendingFormat:@"?%@", url.query];
                }
                NSURL *wxSchemeURL = [NSURL URLWithString:wxScheme];
                [WXApi handleOpenURL:wxSchemeURL delegate:self];
            }
        });
        
        return YES; // 表示我们已经处理了这个URL
    }
    
    // 检查是否是app路径
    if ([path hasPrefix:@"/app/"]) {
        return [self handleAppPath:path withQuery:url.query];
    }
    
    return NO;
}

/**
 * 处理app内路径
 * @param path URL路径部分
 * @param query URL查询参数
 * @return 是否成功处理
 */
- (BOOL)handleAppPath:(NSString *)path withQuery:(NSString *)query {
    
    // 移除/app/前缀
    NSString *appPath = [path substringFromIndex:5]; // 移除"/app/"
    NSArray *pathComponents = [appPath componentsSeparatedByString:@"/"];
    
    // 解析查询参数
    NSDictionary *queryParams = [self parseQueryString:query];
    
    // 等待app完全初始化
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self navigateToPath:pathComponents withParams:queryParams];
    });
    
    return YES;
}

/**
 * 解析查询字符串
 * @param queryString 查询字符串
 * @return 参数字典
 */
- (NSDictionary *)parseQueryString:(NSString *)queryString {
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    
    if (queryString && queryString.length > 0) {
        NSArray *pairs = [queryString componentsSeparatedByString:@"&"];
        for (NSString *pair in pairs) {
            NSArray *keyValue = [pair componentsSeparatedByString:@"="];
            if (keyValue.count == 2) {
                NSString *key = [keyValue[0] stringByRemovingPercentEncoding];
                NSString *value = [keyValue[1] stringByRemovingPercentEncoding];
                if (key && value) {
                    params[key] = value;
                }
            }
        }
    }
    
    return params;
}

/**
 * 导航到指定路径
 * @param pathComponents 路径组件数组
 * @param params 参数字典
 */
- (void)navigateToPath:(NSArray *)pathComponents withParams:(NSDictionary *)params {
    
    // 确保TabBar控制器存在
    if (!self.tabbarVC) {
        return;
    }
    
    // 构建完整路径用于传递给WebView
    NSString *fullPath = [@"/app/" stringByAppendingString:[pathComponents componentsJoinedByString:@"/"]];
    
    // 添加查询参数
    if (params.count > 0) {
        NSMutableArray *queryPairs = [NSMutableArray array];
        for (NSString *key in params) {
            [queryPairs addObject:[NSString stringWithFormat:@"%@=%@", key, params[key]]];
        }
        fullPath = [fullPath stringByAppendingFormat:@"?%@", [queryPairs componentsJoinedByString:@"&"]];
    }
    
    
    // 通知WebView处理路由
    dispatch_async(dispatch_get_main_queue(), ^{
        [self notifyWebViewWithPath:fullPath];
    });
}

/**
 * 通知WebView处理路由
 * @param path 完整路径
 */
- (void)notifyWebViewWithPath:(NSString *)path {
    
    // 发送通知给当前活跃的WebView控制器
    [[NSNotificationCenter defaultCenter] postNotificationName:@"UniversalLinkNavigation" 
                                                        object:nil 
                                                      userInfo:@{@"path": path}];
    
    // 如果app在后台，需要激活到前台
    if ([UIApplication sharedApplication].applicationState != UIApplicationStateActive) {
    }
}

#pragma mark - LoadingView统一管理

- (void)showGlobalLoadingView {
    if (self.globalLoadingView || self.isLoadingViewRemoved) {
        return;
    }
    
    LoadingView *loadingView = [[LoadingView alloc] initWithFrame:self.window.bounds];
    loadingView.tag = 2001;
    [self.window addSubview:loadingView];
    
    // 保存引用
    self.globalLoadingView = loadingView;
    self.isLoadingViewRemoved = NO;
    
}

- (void)removeGlobalLoadingViewWithReason:(NSString *)reason {
    
    if (self.isLoadingViewRemoved) {
        return;
    }
    
    // 标记为已移除，防止重复移除
    self.isLoadingViewRemoved = YES;
    
    UIView *loadingView = [self findGlobalLoadingView];
    if (loadingView) {
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [UIView animateWithDuration:0.3 animations:^{
                loadingView.alpha = 0.0;
            } completion:^(BOOL finished) {
                [loadingView removeFromSuperview];
                self.globalLoadingView = nil;
            }];
        });
    } else {
        self.globalLoadingView = nil;
    }
}

- (UIView *)findGlobalLoadingView {
    return [self findViewWithTag:2001 cacheInProperty:@"globalLoadingView"];
}

// 统一的视图查找方法
- (UIView *)findViewWithTag:(NSInteger)tag cacheInProperty:(NSString *)propertyName {
    // 优先返回缓存的引用
    if (propertyName) {
        UIView *cachedView = [self valueForKey:propertyName];
        if (cachedView && cachedView.superview) {
            return cachedView;
        }
    }
    
    // 在keyWindow中查找
    UIView *targetView = [[UIApplication sharedApplication].keyWindow viewWithTag:tag];
    if (targetView) {
        if (propertyName) [self setValue:targetView forKey:propertyName];
        return targetView;
    }
    
    // 在delegate的window中查找
    targetView = [self.window viewWithTag:tag];
    if (targetView) {
        if (propertyName) [self setValue:targetView forKey:propertyName];
        return targetView;
    }
    
    // 在所有window中查找
    NSArray *windows = [UIApplication sharedApplication].windows;
    for (UIWindow *window in windows) {
        targetView = [window viewWithTag:tag];
        if (targetView) {
            if (propertyName) [self setValue:targetView forKey:propertyName];
            return targetView;
        }
    }
    
    return nil;
}

@end


