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
// #import <HybridSDK/HybridManager.h>  // 已废弃，使用CustomHybridProcessor替代
// NSLog(@"在局 🔧 [AppDelegate] 优化权限使用说明文案完成");
#import "Reachability.h"
#import "JHSysAlertUtil.h"
#import <UserNotifications/UserNotifications.h>
// 添加SAMKeychain导入
#import <SAMKeychain/SAMKeychain.h>
// 添加高德地图相关导入
#import <AMapFoundationKit/AMapFoundationKit.h>
#import <AMapLocationKit/AMapLocationKit.h>

@interface AppDelegate () <WXApiDelegate,UNUserNotificationCenterDelegate>

@property (strong, nonatomic) Reachability *reachability;
@property (strong, nonatomic) AFNetworkReachabilityManager *internetReachability;
@property (strong, nonatomic) XZTabBarController *tabbarVC;
@property (strong, nonatomic) NSDictionary *dataDic;
@property (strong, nonatomic) NSDictionary *appInfoDic;
@property (assign, nonatomic) BOOL mallConfigModel;
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
    
    // 停止Reachability
    [self.reachability stopNotifier];
    self.reachability = nil;
    
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

- (Reachability *)reachability {
    if (_reachability == nil) {
        _reachability = [Reachability reachabilityForInternetConnection];
    }
    return _reachability;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    NSLog(@"在局🚀🚀🚀 [AppDelegate] ========== 应用启动开始 ==========");
    NSLog(@"在局🚀 [AppDelegate] Bundle ID: %@", [[NSBundle mainBundle] bundleIdentifier]);
    NSLog(@"在局🚀 [AppDelegate] 应用版本: %@", [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"]);
    NSLog(@"在局🚀 [AppDelegate] Build版本: %@", [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"]);
    NSLog(@"在局🚀 [AppDelegate] iOS版本: %@", [[UIDevice currentDevice] systemVersion]);
    NSLog(@"在局🚀 [AppDelegate] 设备型号: %@", [[UIDevice currentDevice] model]);
    NSLog(@"在局🚀 [AppDelegate] didFinishLaunchingWithOptions 参数: %@", launchOptions);
    
    // 启动网络监听
    NSLog(@"在局📡 [AppDelegate] 开始启动网络监听器...");
    [self.reachability startNotifier];
    
    // 立即创建窗口并设置根视图控制器，避免场景更新超时
    NSLog(@"在局🪟 [AppDelegate] 创建主窗口...");
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.backgroundColor = [UIColor whiteColor];
    
    // 创建一个临时的根视图控制器来满足iOS要求
    NSLog(@"在局🎯 [AppDelegate] 创建临时根视图控制器...");
    UIViewController *tempRootViewController = [[UIViewController alloc] init];
    tempRootViewController.view.backgroundColor = [UIColor whiteColor];
    self.window.rootViewController = tempRootViewController;
    [self.window makeKeyAndVisible];
    NSLog(@"在局✅ [AppDelegate] 窗口已显示");
    
    // 显示加载界面
    NSLog(@"在局⏳ [AppDelegate] 创建LoadingView...");
    LoadingView *loadingView = [[LoadingView alloc] initWithFrame:self.window.bounds];
    loadingView.tag = 2001;
    [self.window addSubview:loadingView];
    NSLog(@"在局✅ [AppDelegate] LoadingView已添加到窗口");
    
    // 初始化配置数据
    NSLog(@"在局🔧 [AppDelegate] 初始化配置数据...");
    [self locAppInfoData];
    
    // 立即初始化TabBar，不等待网络权限检查
    NSLog(@"在局🚀 [AppDelegate] 立即初始化TabBar...");
    // 直接创建TabBar控制器，避免延迟
    self.tabbarVC = [[XZTabBarController alloc] init];
    self.window.rootViewController = self.tabbarVC;
    [self.tabbarVC reloadTabbarInterface];
    self.hasInitialized = YES;
    
    // 并行检查网络权限，不阻塞初始化
    NSLog(@"在局📡 [AppDelegate] 并行检查网络权限...");
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
            NSLog(@"在局 ⚠️ [AppDelegate] 初始化超时，检查网络状态");
            
            // 只有在网络正常的情况下才移除LoadingView
            if (!self.networkRestricted) {
                NSLog(@"在局 ⚠️ [AppDelegate] 网络正常，强制移除LoadingView");
                UIView *loadingView = [self.window viewWithTag:2001];
                if (loadingView) {
                    [loadingView removeFromSuperview];
                }
            } else {
                NSLog(@"在局 ⚠️ [AppDelegate] 网络受限，保持LoadingView显示");
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
    NSLog(@"在局📦 [AppDelegate] downloadManifestAppsource 开始");
    
    // 如果已经初始化或正在初始化，跳过
    if (self.hasInitialized || self.isInitializing) {
        NSLog(@"在局⚠️ [AppDelegate] downloadManifestAppsource - 已经初始化，跳过");
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
    //   定位超时时间，最低2s，此处设置为2s
    self.locationManager.locationTimeout = 2;
    //   逆地理请求超时时间，最低2s，此处设置为2s
    self.locationManager.reGeocodeTimeout = 2;
    [self.locationManager requestLocationWithReGeocode:YES completionBlock:^(CLLocation *location, AMapLocationReGeocode *regeocode, NSError *error) {
        if (error) {
            NSLog(@"在局 locError:{%ld - %@};", (long)error.code, error.localizedDescription);
            
            if (error.code == AMapLocationErrorLocateFailed) {
                return;
            }
        }
        NSLog(@"在局 location:%@", location);
        
        if (regeocode) {
            NSLog(@"在局 reGeocode:%@", regeocode);
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
    NSLog(@"在局 %s", __func__);
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo {
    NSLog(@"在局 %s", __func__);
    
    // 友盟推送 - 处理远程通知
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
    NSLog(@"在局 🔔 [AppDelegate] 应用即将失去活跃状态");
    
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
        NSLog(@"在局⚠️ 后台任务即将超时，立即结束");
        if (self.backgroundTaskIdentifier != UIBackgroundTaskInvalid) {
            [[UIApplication sharedApplication] endBackgroundTask:self.backgroundTaskIdentifier];
            self.backgroundTaskIdentifier = UIBackgroundTaskInvalid;
        }
    }];
    
    // 严格遵守2秒后台执行时间限制，提前100ms结束以确保安全
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.9 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (self.backgroundTaskIdentifier != UIBackgroundTaskInvalid) {
            NSLog(@"在局✅ 后台任务正常结束");
            [[UIApplication sharedApplication] endBackgroundTask:self.backgroundTaskIdentifier];
            self.backgroundTaskIdentifier = UIBackgroundTaskInvalid;
        }
    });
}


- (void)applicationDidBecomeActive:(UIApplication *)application {
    // 应用进入前台时检查是否需要初始化
    if (!self.hasInitialized && !self.isInitializing && self.window) {
        NSLog(@"在局 applicationDidBecomeActive - 重新尝试初始化");
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
        NSLog(@"在局 deviceToken1:%@", strToken);
        [[NSUserDefaults standardUserDefaults] setObject:strToken forKey:User_ChannelId];
        [[NSUserDefaults standardUserDefaults] synchronize];
    } else {
        NSString *token = [NSString
                           stringWithFormat:@"%@",deviceToken];
        token = [token stringByReplacingOccurrencesOfString:@"<" withString:@""];
        token = [token stringByReplacingOccurrencesOfString:@">" withString:@""];
        token = [token stringByReplacingOccurrencesOfString:@" " withString:@""];
        NSLog(@"在局 deviceToken2 is: %@", token);
        [[NSUserDefaults standardUserDefaults] setObject:token forKey:User_ChannelId];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    
    
//    [ManageCenter requestMessageNumber:^(id aResponseObject, NSError *anError) {
//        [[NSNotificationCenter defaultCenter] postNotificationName:@"changeMessageNum" object:nil];
//    }];
}

- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error {
    NSLog(@"在局 RegisterForRemoteNotificationsError:%@",error);
}

#pragma mark - 微信QQ授权回调方法 -

-(void) onReq:(BaseReq*)request {
    NSLog(@"在局 微信支付");
}

-(void) onResp:(BaseResp*)response {
    NSLog(@"在局 🔔 [微信回调] 收到响应: %@, 错误码: %d", NSStringFromClass([response class]), response.errCode);
    
    if([response isKindOfClass:[PayResp class]]) {
        PayResp *res = (PayResp *)response;
        NSLog(@"在局 💰 [微信支付回调] 错误码: %d", res.errCode);
        switch (res.errCode) {
            case WXSuccess:
            {
                NSLog(@"在局 ✅ [微信支付] 支付成功");
                [[NSNotificationCenter defaultCenter] postNotificationName:@"weixinPay" object:@"true"];
            }
                break;
            default:
            {
                NSLog(@"在局 ❌ [微信支付] 支付失败或取消，错误码: %d", res.errCode);
                [[NSNotificationCenter defaultCenter] postNotificationName:@"weixinPay" object:@"false"];
            }
                break;
        }
        return;
    }
    
    // 处理微信分享回调
    if([response isKindOfClass:[SendMessageToWXResp class]]) {
        SendMessageToWXResp *resp = (SendMessageToWXResp *)response;
        NSLog(@"在局 📤 [微信分享回调] 错误码: %d", resp.errCode);
        
        NSString *resultMessage = @"";
        BOOL shareSuccess = NO;
        
        switch (resp.errCode) {
            case WXSuccess:
                NSLog(@"在局 ✅ [微信分享] 分享成功");
                resultMessage = @"分享成功";
                shareSuccess = YES;
                break;
            case WXErrCodeCommon:
                NSLog(@"在局 ❌ [微信分享] 普通错误类型");
                resultMessage = @"分享失败";
                break;
            case WXErrCodeUserCancel:
                NSLog(@"在局 ⚠️ [微信分享] 用户点击取消并返回");
                resultMessage = @"分享已取消";
                break;
            case WXErrCodeSentFail:
                NSLog(@"在局 ❌ [微信分享] 发送失败");
                resultMessage = @"分享发送失败";
                break;
            case WXErrCodeAuthDeny:
                NSLog(@"在局 ❌ [微信分享] 授权失败");
                resultMessage = @"微信授权失败";
                break;
            case WXErrCodeUnsupport:
                NSLog(@"在局 ❌ [微信分享] 微信不支持");
                resultMessage = @"微信版本过低";
                break;
            default:
                NSLog(@"在局 ❌ [微信分享] 未知错误，错误码: %d", resp.errCode);
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
    
    NSLog(@"在局 ⚠️ [微信回调] 未处理的响应类型: %@", NSStringFromClass([response class]));
}

#pragma mark -  回调

- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenURLOptionsKey, id> *)options {
    NSLog(@"在局 🔗 [URL回调] 收到URL: %@, scheme: %@, host: %@", url.absoluteString, url.scheme, url.host);
    
    //6.3的新的API调用，是为了兼容国外平台(例如:新版facebookSDK,VK等)的调用[如果用6.2的api调用会没有回调],对国内平台没有影响。
    BOOL result = [[UMSocialManager defaultManager]  handleOpenURL:url options:options];
    
    NSLog(@"在局 📤 [UMSocialManager] 处理结果: %@", result ? @"成功" : @"失败");
    
    if (!result) {
        //银联和支付宝支付返回结果
        if ([url.host isEqualToString:@"safepay"] || [url.host isEqualToString:@"platformapi"] || [url.host isEqualToString:@"uppayresult"]) {
            NSLog(@"在局 💳 [支付回调] 检测到支付相关URL");
            [[NSNotificationCenter defaultCenter] postNotificationName:@"payresultnotif" object:url];
            return YES;
        }
        else if ( [url.host isEqualToString:@"pay"]) {
            NSLog(@"在局 💰 [微信支付] 检测到微信支付回调");
            return [WXApi handleOpenURL:url delegate:self];
        }
        
    }
    NSDictionary *dic = @{
        @"result" : @(result),
        @"urlhost" : url.host ? url.host : @"",
    };
    NSLog(@"在局 📢 [通知发送] 发送分享结果通知: %@", dic);
    [[NSNotificationCenter defaultCenter] postNotificationName:@"shareresultnotif" object:dic];
    return result;
}


- (void)getAppInfo {
    NSLog(@"在局🎯 [AppDelegate] getAppInfo 开始");
    
    // 防止重复初始化
    if (self.hasInitialized || self.isInitializing) {
        NSLog(@"在局⚠️ [AppDelegate] getAppInfo - 已经初始化或正在初始化，跳过");
        // 如果TabBar已经创建，只需要发送显示通知
        if (self.tabbarVC) {
            [[NSNotificationCenter defaultCenter] postNotificationName:@"showTabviewController" object:nil];
        }
        return;
    }
    
    self.isInitializing = YES;
    
    // 检查窗口是否存在
    if (!self.window) {
        NSLog(@"在局 getAppInfo - 窗口不存在，放弃初始化");
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
    NSLog(@"在局🎯 [AppDelegate] 发送showTabviewController通知");
    [[NSNotificationCenter defaultCenter] postNotificationName:@"showTabviewController" object:nil];
}

//获取分享和推送的设置信息
- (void)getSharePushInfo {
    // 在后台线程读取文件，避免阻塞主线程
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSData *JSONData = [NSData dataWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"shareInfo" ofType:@"json"]];
        NSDictionary *dataDic = [NSJSONSerialization JSONObjectWithData:JSONData options:NSJSONReadingAllowFragments error:nil];
        self.dataDic = [dataDic objectForKey:@"data"];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self publicSetting:self.dataDic];
        });
    });
}

- (void)reloadByTabbarController {
    NSLog(@"在局🔄 [AppDelegate] reloadByTabbarController 开始");
    
    // 检查tabbarVC是否存在
    if (!self.tabbarVC) {
        NSLog(@"在局 reloadByTabbarController - tabbarVC不存在，创建新实例");
        self.tabbarVC = [[XZTabBarController alloc] initWithNibName:nil bundle:nil];
        
        // 确保在主线程设置根视图控制器
        if ([NSThread isMainThread]) {
            self.window.rootViewController = self.tabbarVC;
            NSLog(@"在局 reloadByTabbarController - 设置TabBar为根视图控制器");
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                self.window.rootViewController = self.tabbarVC;
                NSLog(@"在局 reloadByTabbarController - 设置TabBar为根视图控制器");
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
                NSLog(@"在局 reloadByTabbarController - tabbarVC没有reloadTabbarInterface方法");
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
    [UMSocialGlobal shareInstance].universalLinkDic = @{@(UMSocialPlatformType_WechatSession):@"https://hi3.tuiya.cc/",
                                                        @(UMSocialPlatformType_QQ):@""
    };
    [[UMSocialManager defaultManager] setPlaform:UMSocialPlatformType_WechatSession appKey:[[PublicSettingModel sharedInstance] weiXin_AppID] appSecret:[[PublicSettingModel sharedInstance] weiXin_AppSecret] redirectURL:nil];
    
    [WXApi registerApp:[[PublicSettingModel sharedInstance] weiXin_AppID] universalLink:@"https://hi3.tuiya.cc/"];
    
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

    NSLog(@"在局 userActivity : %@",userActivity.webpageURL.description);
    return YES;
}

/*
 CTCellularData在iOS9之前是私有类，权限设置是iOS10开始的，所以App Store审核没有问题
 获取网络权限状态
 */
- (void)networkStatus:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    NSLog(@"在局📡 [AppDelegate] networkStatus 开始检查网络权限");
    WEAK_SELF;
    if (@available(iOS 9.0, *)) {
        // 创建一个信号量，确保权限检查完成后再继续
        dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
        __block BOOL hasReceivedCallback = NO;
        
        // 确保在后台线程执行
        void (^checkBlock)(void) = ^{
            //2.根据权限执行相应的交互
            CTCellularData *cellularData = [[CTCellularData alloc] init];
        /*
         此函数会在网络权限改变时再次调用
         */
        cellularData.cellularDataRestrictionDidUpdateNotifier = ^(CTCellularDataRestrictedState state) {
            STRONG_SELF;
            
            // 标记已收到回调
            if (!hasReceivedCallback) {
                hasReceivedCallback = YES;
                dispatch_semaphore_signal(semaphore);
            }
            
            // 防止在短时间内重复弹窗
            if (self.lastNetworkAlertDate && 
                [[NSDate date] timeIntervalSinceDate:self.lastNetworkAlertDate] < 30.0) {
                return;
            }
            
            switch (state) {
                case kCTCellularDataRestricted: {
                    NSLog(@"在局⚠️ [AppDelegate] 网络权限受限");
                    
                    // 设置标记，表示网络受限
                    self.networkRestricted = YES;
                    
                    // 使用弱引用避免循环引用
                    __weak typeof(self) weakSelf = self;
                    
                    // 只在首次授权时才弹出提示
                    if ([self isFirstAuthorizationNetwork]) {
                        // 确保在主线程弹出提示
                        dispatch_async(dispatch_get_main_queue(), ^{
                            __strong typeof(weakSelf) strongSelf = weakSelf;
                            if (!strongSelf) return;
                            
                            // 记录弹窗时间
                            strongSelf.lastNetworkAlertDate = [NSDate date];
                            strongSelf.hasShownNetworkPermissionAlert = YES;
                            
                            [JHSysAlertUtil presentAlertViewWithTitle:@"温馨提示" 
                                message:@"若要网络功能正常使用,您可以在'设置'中为此应用打开网络权限" 
                                cancelTitle:@"设置" 
                                defaultTitle:@"好" 
                                distinct:NO 
                                cancel:^{
                                    NSURL *url = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
                                    if ([[UIApplication sharedApplication] canOpenURL:url]) {
                                        if (@available(iOS 10.0, *)) {
                                            [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
                                        } else {
                                            [[UIApplication sharedApplication] openURL:url];
                                        }
                                    }
                                } 
                                confirm:^{
                                    // 用户选择"好"，延迟初始化避免立即执行
                                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                                        __strong typeof(weakSelf) strongSelf2 = weakSelf;
                                        if (strongSelf2 && strongSelf2.window) {
                                            [strongSelf2 addReachabilityManager:application didFinishLaunchingWithOptions:launchOptions];
                                        }
                                    });
                                }];
                        });
                    } else {
                        // 非首次，延迟初始化
                        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                            __strong typeof(weakSelf) strongSelf = weakSelf;
                            if (strongSelf && strongSelf.window) {
                                [strongSelf addReachabilityManager:application didFinishLaunchingWithOptions:launchOptions];
                            }
                        });
                    }
                    break;
                }
                case kCTCellularDataNotRestricted: {
                    NSLog(@"在局✅ [AppDelegate] 网络权限已开启");
                    // 重置标志
                    self.hasShownNetworkPermissionAlert = NO;
                    self.networkRestricted = NO;
                    
                    __weak typeof(self) weakSelf = self;
                    // 延迟执行，确保权限状态已经完全更新
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        __strong typeof(weakSelf) strongSelf = weakSelf;
                        if (strongSelf && strongSelf.window) {
                            //2.2已经开启网络权限 监听网络状态
                            [strongSelf addReachabilityManager:application didFinishLaunchingWithOptions:launchOptions];
                            
                            // 网络权限恢复后，移除LoadingView
                            UIView *loadingView = [strongSelf.window viewWithTag:2001];
                            if (loadingView) {
                                NSLog(@"在局🎯 [AppDelegate] 网络权限恢复，移除LoadingView");
                                [UIView animateWithDuration:0.3 animations:^{
                                    loadingView.alpha = 0.0;
                                } completion:^(BOOL finished) {
                                    [loadingView removeFromSuperview];
                                    NSLog(@"在局✅ [AppDelegate] LoadingView移除完成");
                                }];
                            }
                            
                            // 修复权限授予后首页空白问题 - 主动触发首页加载
                            [strongSelf triggerFirstTabLoadIfNeeded];
                            
                            // 网络权限恢复，强制重新初始化首页
                            NSLog(@"在局🔥 [AppDelegate] 网络权限恢复，强制重新初始化首页");
                            
                            // 发送全局通知，告知所有页面网络权限已恢复
                            [[NSNotificationCenter defaultCenter] postNotificationName:@"NetworkPermissionRestored" object:nil];
                            
                            // 延迟执行，确保UI已经完全准备好
                            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                                if (strongSelf.tabbarVC) {
                                    UINavigationController *nav = strongSelf.tabbarVC.viewControllers.firstObject;
                                    if ([nav isKindOfClass:[UINavigationController class]]) {
                                        UIViewController *vc = nav.viewControllers.firstObject;
                                        
                                        NSLog(@"在局🔍 [AppDelegate] 找到首页控制器: %@", NSStringFromClass([vc class]));
                                        
                                        // 多重检查和恢复机制
                                        if ([vc respondsToSelector:@selector(domainOperate)]) {
                                            NSLog(@"在局🔄 [AppDelegate] 方法1: 触发domainOperate重新加载");
                                            [vc performSelector:@selector(domainOperate)];
                                        }
                                        
                                        // 注意：不要调用 [webView reload]
                                        // 因为WebView是通过loadHTMLString:baseURL:加载的
                                        // reload会尝试加载baseURL（manifest目录），导致"file is directory"错误
                                        
                                        // 最后备用方案：强制重新初始化WebView
                                        if ([vc respondsToSelector:@selector(reloadWebViewContent)]) {
                                            NSLog(@"在局🔄 [AppDelegate] 方法3: 调用reloadWebViewContent");
                                            [vc performSelector:@selector(reloadWebViewContent)];
                                        }
                                    }
                                }
                            });
                        }
                    });
                    break;
                }
                case kCTCellularDataRestrictedStateUnknown: {
                    NSLog(@"在局❓ [AppDelegate] 网络权限未知");
                    //2.3未知情况 （还没有遇到推测是有网络但是连接不正常的情况下）
                    // 不再重复调用getAppInfo，因为已经在启动时调用过了
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self addReachabilityManager:application didFinishLaunchingWithOptions:launchOptions];
                    });
                    break;
                }
                    
                default:
                    break;
            }
        };
    };
    
    // 执行检查
    checkBlock();
    
    // 在后台线程等待权限回调，设置超时时间为2秒
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        dispatch_time_t timeout = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC));
        long result = dispatch_semaphore_wait(semaphore, timeout);
        
        if (result != 0) {
            // 超时处理，假设网络权限已开启
            NSLog(@"在局⏱️ [AppDelegate] 网络权限检查超时，假设权限已开启");
            dispatch_async(dispatch_get_main_queue(), ^{
                [self addReachabilityManager:application didFinishLaunchingWithOptions:launchOptions];
            });
        }
    });
    
    } // 结束 if (@available(iOS 9.0, *))
}

/**
 实时检查当前网络状态
 */
- (void)addReachabilityManager:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
    // 防止重复初始化
    if (self.mallConfigModel) {
        return;
    }
    
    //这个可以放在需要侦听的页面
    //    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(afNetworkStatusChanged:) name:AFNetworkingReachabilityDidChangeNotification object:nil];
    __weak typeof(self) weakSelf = self;
    [self.internetReachability setReachabilityStatusChangeBlock:^(AFNetworkReachabilityStatus status) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        
        // 确保在主线程执行
        dispatch_async(dispatch_get_main_queue(), ^{
            switch (status) {
                case AFNetworkReachabilityStatusNotReachable:{
                    NSLog(@"在局 网络不通：%@",@(status) );
                    [strongSelf getInfo_application:application didFinishLaunchingWithOptions:launchOptions];
                    break;
                }
                case AFNetworkReachabilityStatusReachableViaWiFi:{
                    NSLog(@"在局 网络通过WIFI连接：%@",@(status));
                    if (!strongSelf.mallConfigModel) {
                        [strongSelf getInfo_application:application didFinishLaunchingWithOptions:launchOptions];
                    }
                    break;
                }
                case AFNetworkReachabilityStatusReachableViaWWAN:{
                    NSLog(@"在局 网络通过无线连接：%@",@(status) );
                    if (!strongSelf.mallConfigModel) {
                        [strongSelf getInfo_application:application didFinishLaunchingWithOptions:launchOptions];
                    }
                    break;
                }
                default:
                    break;
            }
        });
    }];
    [self.internetReachability startMonitoring];  //开启网络监视器；
}

- (void)getInfo_application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.mallConfigModel = YES;
    //获取初始信息
    [self initData];
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
        [[AMapServices sharedServices] setApiKey:@"071329e3bbb36c12947b544db8d20cfa"];
        
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
    // 将文件读取移到后台线程，避免阻塞主线程
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSError *error = nil;
        NSData *JSONData = [NSData dataWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"appInfo" ofType:@"json"]];
        if (!JSONData) {
            NSLog(@"在局 locAppInfoData - 无法读取appInfo.json文件");
            return;
        }
        
        NSDictionary *dataDic = [NSJSONSerialization JSONObjectWithData:JSONData options:NSJSONReadingAllowFragments error:&error];
        if (error) {
            NSLog(@"在局 locAppInfoData - JSON解析错误: %@", error.localizedDescription);
            return;
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            self.appInfoDic = dataDic;
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
    NSLog(@"在局 🔍 [AppDelegate] 检查首页是否需要加载");
    
    if (!self.tabbarVC) {
        NSLog(@"在局 ⚠️ [AppDelegate] TabBarController不存在，跳过");
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
                        NSLog(@"在局 🚨 [AppDelegate] 检测到首页未加载，主动触发加载");
                        [rootVC performSelector:@selector(domainOperate)];
                    } else {
                        NSLog(@"在局 ✅ [AppDelegate] 首页已加载或正在加载中");
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

@end


