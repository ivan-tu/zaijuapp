//
//  JSMiscHandler.m
//  XZVientiane
//
//  处理其他杂项JS调用
//

#import "JSMiscHandler.h"
#import "HTMLCache.h"
#import "ManageCenter.h"
#import "CFJClientH5Controller.h"
#import "UIBarButtonItem+PPBadgeView.h"
#import <AFNetworking/AFNetworking.h>

@implementation JSMiscHandler

- (NSArray<NSString *> *)supportedActions {
    return @[@"reload", @"customReturn", @"openQRCode"];
}

- (void)handleAction:(NSString *)action 
              data:(id)data 
        controller:(UIViewController *)controller
          callback:(JSActionCallbackBlock)callback {
    
    if ([action isEqualToString:@"reload"]) {
        [self handleReload:controller];
    } else if ([action isEqualToString:@"customReturn"]) {
        [self handleCustomReturn:data controller:controller];
    } else if ([action isEqualToString:@"openQRCode"]) {
        [self handleOpenQRCode:controller callback:callback];
    }
}

#pragma mark - 杂项处理

- (void)handleReload:(UIViewController *)controller {
    // 检查网络状态
    if (NoReachable) {
        return;
    }
    
    // 清除缓存
    if ([controller respondsToSelector:@selector(webViewDomain)]) {
        NSString *webViewDomain = [controller valueForKey:@"webViewDomain"];
        [[HTMLCache sharedCache] removeObjectForKey:webViewDomain];
    }
    
    // 重新加载
    if ([controller respondsToSelector:@selector(domainOperate)]) {
        [controller performSelector:@selector(domainOperate)];
    }
    
    // 更新消息和购物车数量
    if ([controller isKindOfClass:[CFJClientH5Controller class]]) {
        CFJClientH5Controller *cfController = (CFJClientH5Controller *)controller;
        
        if (cfController.rightMessage) {
            [ManageCenter requestMessageNumber:^(id aResponseObject, NSError *anError) {
                NSInteger num = [[aResponseObject objectForKey:@"data"] integerValue];
                if (num == 0 || !num) {
                    num = 0;
                }
                [cfController.navigationItem.rightBarButtonItem pp_addBadgeWithNumber:num];
            }];
        }
        
        if (cfController.leftMessage) {
            [ManageCenter requestMessageNumber:^(id aResponseObject, NSError *anError) {
                NSInteger num = [[aResponseObject objectForKey:@"data"] integerValue];
                if (num == 0 || !num) {
                    num = 0;
                }
                [cfController.navigationItem.leftBarButtonItem pp_addBadgeWithNumber:num];
            }];
        }
        
        if (cfController.rightShop) {
            [ManageCenter requestshoppingCartNumber:^(id aResponseObject, NSError *anError) {
                NSInteger num = [[aResponseObject objectForKey:@"data"] integerValue];
                if (num == 0 || !num) {
                    num = 0;
                }
                [cfController.navigationItem.rightBarButtonItem pp_addBadgeWithNumber:num];
            }];
        }
        
        if (cfController.leftShop) {
            [ManageCenter requestshoppingCartNumber:^(id aResponseObject, NSError *anError) {
                NSInteger num = [[aResponseObject objectForKey:@"data"] integerValue];
                if (num == 0 || !num) {
                    num = 0;
                }
                [cfController.navigationItem.leftBarButtonItem pp_addBadgeWithNumber:num];
            }];
        }
    }
}

- (void)handleCustomReturn:(id)data controller:(UIViewController *)controller {
    NSDictionary *dataDic = (NSDictionary *)data;
    NSString *backStr = [dataDic objectForKey:@"url"];
    
    // 在局Claude Code[修复未声明选择器警告]+抑制backStr警告
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
    if ([controller respondsToSelector:@selector(setBackStr:)]) {
#pragma clang diagnostic pop
        [controller setValue:backStr forKey:@"backStr"];
    }
}

- (void)handleOpenQRCode:(UIViewController *)controller callback:(JSActionCallbackBlock)callback {
    // 保存回调
    if ([controller respondsToSelector:@selector(setWebviewBackCallBack:)]) {
        [controller performSelector:@selector(setWebviewBackCallBack:) withObject:callback];
    }
}

@end