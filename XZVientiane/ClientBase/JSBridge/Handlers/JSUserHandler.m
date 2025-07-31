//
//  JSUserHandler.m
//  XZVientiane
//
//  处理用户相关的JS调用
//

#import "JSUserHandler.h"
#import "CFJClientH5Controller.h"
#import "HTMLCache.h"
#import "WKWebView+XZAddition.h"
// TODO: 需要在Xcode中添加XZAuthenticationManager文件
// #import "XZAuthenticationManager.h"

@implementation JSUserHandler

- (NSArray<NSString *> *)supportedActions {
    return @[@"userLogin", @"userLogout", @"weixinLogin"];
}

- (void)handleAction:(NSString *)action 
              data:(id)data 
        controller:(UIViewController *)controller
          callback:(JSActionCallbackBlock)callback {
    
    // 保存回调
    if ([controller respondsToSelector:@selector(setWebviewBackCallBack:)]) {
        [controller performSelector:@selector(setWebviewBackCallBack:) withObject:callback];
    }
    
    if ([action isEqualToString:@"userLogin"]) {
        [self handleUserLogin:data controller:controller];
    } else if ([action isEqualToString:@"userLogout"]) {
        [self handleUserLogout:data controller:controller];
    } else if ([action isEqualToString:@"weixinLogin"]) {
        [self handleWeixinLogin:controller];
    }
}

#pragma mark - 用户操作处理

- (void)handleUserLogin:(id)data controller:(UIViewController *)controller {
    NSDictionary *dataDic = (NSDictionary *)data;
    
    // 调用登录接口
    if ([controller isKindOfClass:[CFJClientH5Controller class]]) {
        CFJClientH5Controller *cfController = (CFJClientH5Controller *)controller;
        [cfController RequestWithJsDic:dataDic type:@"1"];
    }
    
    // TODO: 需要在Xcode中添加XZAuthenticationManager文件后启用
    /*
    // 创建用户信息对象
    XZUserInfo *userInfo = [[XZUserInfo alloc] init];
    
    // 从data中提取用户信息（根据实际返回的数据结构调整）
    if ([dataDic objectForKey:@"userId"]) {
        userInfo.userId = [dataDic objectForKey:@"userId"];
    }
    if ([dataDic objectForKey:@"nickname"]) {
        userInfo.nickname = [dataDic objectForKey:@"nickname"];
    }
    if ([dataDic objectForKey:@"token"]) {
        userInfo.token = [dataDic objectForKey:@"token"];
    }
    if ([dataDic objectForKey:@"headpic"]) {
        userInfo.headpic = [dataDic objectForKey:@"headpic"];
    }
    if ([dataDic objectForKey:@"phone"]) {
        userInfo.phone = [dataDic objectForKey:@"phone"];
    }
    
    // 处理IM数据
    NSDictionary *imData = [dataDic objectForKey:@"imData"];
    if (imData) {
        userInfo.extraInfo = @{@"imData": imData};
    }
    
    // 使用统一的认证管理器登录
    [[XZAuthenticationManager sharedManager] loginWithUserInfo:userInfo completion:^(BOOL success, NSString *errorMessage) {
        if (success) {
            // 登录成功后的处理
            dispatch_async(dispatch_get_main_queue(), ^{
                // 刷新所有页面
                [[NSNotificationCenter defaultCenter] postNotificationName:@"RefreshOtherAllVCNotif" object:controller];
                
                // 跳转到首页并选中第一个tab
                if (controller.tabBarController) {
                    controller.tabBarController.selectedIndex = 0;
                    
                    // 发送backToHome通知
                    NSDictionary *setDic = @{@"selectNumber": @"0"};
                    [[NSNotificationCenter defaultCenter] postNotificationName:@"backToHome" object:setDic];
                }
            });
        } else {
            NSLog(@"在局❌ [用户登录] 登录失败: %@", errorMessage);
        }
    }];
    */
    
    // 临时保留原有逻辑
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"isLogin"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    // 清除HTML缓存，确保页面能正确刷新
    [[HTMLCache sharedCache] removeAllCache];
    
    // 处理IM数据
    NSDictionary *imData = [dataDic objectForKey:@"imData"];
    if (imData) {
        // 这里可以处理IM相关的用户信息
    }
    
    // 登录成功后的处理
    dispatch_async(dispatch_get_main_queue(), ^{
        // 刷新所有页面
        [[NSNotificationCenter defaultCenter] postNotificationName:@"RefreshOtherAllVCNotif" object:controller];
        
        // 跳转到首页并选中第一个tab
        if (controller.tabBarController) {
            controller.tabBarController.selectedIndex = 0;
            
            // 发送backToHome通知
            NSDictionary *setDic = @{@"selectNumber": @"0"};
            [[NSNotificationCenter defaultCenter] postNotificationName:@"backToHome" object:setDic];
        }
    });
}

- (void)handleUserLogout:(id)data controller:(UIViewController *)controller {
    NSDictionary *dataDic = (NSDictionary *)data;
    
    // 调用退出登录接口
    if ([controller isKindOfClass:[CFJClientH5Controller class]]) {
        CFJClientH5Controller *cfController = (CFJClientH5Controller *)controller;
        [cfController RequestWithJsDic:dataDic type:@"2"];
    }
    
    // TODO: 需要在Xcode中添加XZAuthenticationManager文件后启用
    /*
    // 使用统一的认证管理器退出登录
    [[XZAuthenticationManager sharedManager] logoutWithCompletion:^(BOOL success, NSString *errorMessage) {
        if (success) {
            // 重置所有tab页面到初始状态
            if ([controller isKindOfClass:[CFJClientH5Controller class]]) {
                CFJClientH5Controller *cfController = (CFJClientH5Controller *)controller;
                [cfController resetAllTabsToInitialState];
            }
            
            // 退出登录后的处理
            dispatch_async(dispatch_get_main_queue(), ^{
                // 隐藏底部角标
                [controller.tabBarController.tabBar hideBadgeOnItemIndex:3];
                
                // 刷新所有页面
                [[NSNotificationCenter defaultCenter] postNotificationName:@"RefreshOtherAllVCNotif" object:controller];
                
                // 跳转到首页并选中第一个tab
                if (controller.tabBarController && [controller.tabBarController isKindOfClass:[UITabBarController class]]) {
                    controller.tabBarController.selectedIndex = 0;
                    
                    // 发送backToHome通知
                    NSDictionary *setDic = @{@"selectNumber": @"0"};
                    [[NSNotificationCenter defaultCenter] postNotificationName:@"backToHome" object:setDic];
                }
            });
        } else {
            NSLog(@"在局❌ [用户退出] 退出登录失败: %@", errorMessage);
        }
    }];
    */
    
    // 临时保留原有逻辑
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"isLogin"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    // 清除HTML缓存和Cookie
    [[HTMLCache sharedCache] removeAllCache];
    [WKWebView cookieDeleteAllCookie];
    
    // 重置所有tab页面到初始状态
    if ([controller isKindOfClass:[CFJClientH5Controller class]]) {
        CFJClientH5Controller *cfController = (CFJClientH5Controller *)controller;
        [cfController resetAllTabsToInitialState];
    }
    
    // 隐藏底部角标
    dispatch_async(dispatch_get_main_queue(), ^{
        [controller.tabBarController.tabBar hideBadgeOnItemIndex:3];
    });
    
    [[NSUserDefaults standardUserDefaults] setInteger:0 forKey:@"clinetMessageNum"];
    [[NSUserDefaults standardUserDefaults] setInteger:0 forKey:@"shoppingCartNum"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    // 退出登录后的处理
    dispatch_async(dispatch_get_main_queue(), ^{
        // 刷新所有页面
        [[NSNotificationCenter defaultCenter] postNotificationName:@"RefreshOtherAllVCNotif" object:controller];
        
        // 跳转到首页并选中第一个tab
        if (controller.tabBarController && [controller.tabBarController isKindOfClass:[UITabBarController class]]) {
            controller.tabBarController.selectedIndex = 0;
            
            // 发送backToHome通知
            NSDictionary *setDic = @{@"selectNumber": @"0"};
            [[NSNotificationCenter defaultCenter] postNotificationName:@"backToHome" object:setDic];
        }
    });
}

- (void)handleWeixinLogin:(UIViewController *)controller {
    // 使用微信SDK直接进行授权
    if ([controller isKindOfClass:[CFJClientH5Controller class]]) {
        CFJClientH5Controller *cfController = (CFJClientH5Controller *)controller;
        [cfController performWechatDirectLogin];
    }
}

@end