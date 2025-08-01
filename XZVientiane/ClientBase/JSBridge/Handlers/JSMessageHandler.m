//
//  JSMessageHandler.m
//  XZVientiane
//
//  处理消息相关的JS调用
//

#import "JSMessageHandler.h"
#import "UITabBar+badge.h"

@implementation JSMessageHandler

- (NSArray<NSString *> *)supportedActions {
    return @[
        @"readMessage",
        @"changeMessageNum",
        @"noticemsg_setNumber",
        @"reloadOtherPages",
        @"dialogBridge",
        @"closePresentWindow"
    ];
}

- (void)handleAction:(NSString *)action 
              data:(id)data 
        controller:(UIViewController *)controller
          callback:(JSActionCallbackBlock)callback {
    
    if ([action isEqualToString:@"readMessage"]) {
        [self handleReadMessage:data controller:controller];
    } else if ([action isEqualToString:@"changeMessageNum"]) {
        [self handleChangeMessageNum:data controller:controller];
    } else if ([action isEqualToString:@"noticemsg_setNumber"]) {
        [self handleNoticemsgSetNumber:data callback:callback];
    } else if ([action isEqualToString:@"reloadOtherPages"]) {
        [self handleReloadOtherPages:controller callback:callback];
    } else if ([action isEqualToString:@"dialogBridge"]) {
        [self handleDialogBridge:data controller:controller];
    } else if ([action isEqualToString:@"closePresentWindow"]) {
        [self handleClosePresentWindow:controller];
    }
}

#pragma mark - 消息处理

- (void)handleReadMessage:(id)data controller:(UIViewController *)controller {
    NSInteger number = [data integerValue];
    
    @synchronized(self) {
        NSInteger num = [[NSUserDefaults standardUserDefaults] integerForKey:@"clinetMessageNum"];
        NSInteger newNum = num - number;
        
        if (newNum > 0) {
            [[NSUserDefaults standardUserDefaults] setInteger:newNum forKey:@"clinetMessageNum"];
            [[NSUserDefaults standardUserDefaults] synchronize];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [controller.tabBarController.tabBar showBadgeOnItemIndex:3 withNum:newNum];
            });
        } else {
            [[NSUserDefaults standardUserDefaults] setInteger:0 forKey:@"clinetMessageNum"];
            [[NSUserDefaults standardUserDefaults] synchronize];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [controller.tabBarController.tabBar hideBadgeOnItemIndex:3];
            });
        }
    }
}

- (void)handleChangeMessageNum:(id)data controller:(UIViewController *)controller {
    NSDictionary *dataDic = (NSDictionary *)data;
    NSInteger number = [[dataDic objectForKey:@"number"] integerValue];
    
    @synchronized(self) {
        NSInteger num = [[NSUserDefaults standardUserDefaults] integerForKey:@"clinetMessageNum"];
        NSInteger newNum = num - number;
        
        if (newNum > 0) {
            [[NSUserDefaults standardUserDefaults] setInteger:newNum forKey:@"clinetMessageNum"];
            [[NSUserDefaults standardUserDefaults] synchronize];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [controller.tabBarController.tabBar showBadgeOnItemIndex:3 withNum:newNum];
            });
        } else {
            [[NSUserDefaults standardUserDefaults] setInteger:0 forKey:@"clinetMessageNum"];
            [[NSUserDefaults standardUserDefaults] synchronize];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [controller.tabBarController.tabBar hideBadgeOnItemIndex:3];
            });
        }
    }
}

- (void)handleNoticemsgSetNumber:(id)data callback:(JSActionCallbackBlock)callback {
    NSDictionary *dataDic = (NSDictionary *)data;
    NSInteger num = [[dataDic objectForKey:@"num"] integerValue];
    
    @synchronized(self) {
        [[NSUserDefaults standardUserDefaults] setInteger:num forKey:@"clinetMessageNum"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    
    if (callback) {
        callback(@{@"success": @"true", @"data": @{}, @"errorMessage": @""});
    }
}

- (void)handleReloadOtherPages:(UIViewController *)controller callback:(JSActionCallbackBlock)callback {
    // 在发送通知前先检查状态
    UIApplicationState state = [[UIApplication sharedApplication] applicationState];
    if (state == UIApplicationStateActive) {
        // 智能检测登录状态变化
        if ([controller respondsToSelector:@selector(detectAndHandleLoginStateChange:)]) {
            [controller performSelector:@selector(detectAndHandleLoginStateChange:) withObject:callback];
        }
        
        [[NSNotificationCenter defaultCenter] postNotificationName:@"RefreshOtherAllVCNotif" object:controller];
    }
    
    if (callback) {
        callback(@{
            @"success": @"true",
            @"data": @{},
            @"errorMessage": @"",
            @"code": @0
        });
    }
}

- (void)handleDialogBridge:(id)data controller:(UIViewController *)controller {
    // 将数据传给上个页面
    // 在局Claude Code[修复未声明选择器警告]+抑制nextPageDataBlock警告
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
    if ([controller respondsToSelector:@selector(nextPageDataBlock)]) {
#pragma clang diagnostic pop
        void (^nextPageDataBlock)(NSDictionary *) = [controller valueForKey:@"nextPageDataBlock"];
        if (nextPageDataBlock) {
            nextPageDataBlock(data);
        }
    }
}

- (void)handleClosePresentWindow:(UIViewController *)controller {
    [controller dismissViewControllerAnimated:YES completion:nil];
}

@end