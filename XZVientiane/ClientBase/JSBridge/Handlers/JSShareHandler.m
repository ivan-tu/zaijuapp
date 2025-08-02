//
//  JSShareHandler.m
//  XZVientiane
//
//  处理分享相关的JS调用
//

#import "JSShareHandler.h"
#import "CFJClientH5Controller.h"

@implementation JSShareHandler

- (NSArray<NSString *> *)supportedActions {
    return @[@"share", @"copyLink"];
}

- (void)handleAction:(NSString *)action 
              data:(id)data 
        controller:(UIViewController *)controller
          callback:(JSActionCallbackBlock)callback {
    
    // 保存回调
    if ([controller respondsToSelector:@selector(setWebviewBackCallBack:)]) {
        [controller performSelector:@selector(setWebviewBackCallBack:) withObject:callback];
    }
    
    if ([action isEqualToString:@"share"]) {
        [self handleShare:data controller:controller];
    } else if ([action isEqualToString:@"copyLink"]) {
        [self handleCopyLink:data controller:controller callback:callback];
    }
}

#pragma mark - 分享处理

- (void)handleShare:(id)data controller:(UIViewController *)controller {
    
    if ([controller isKindOfClass:[CFJClientH5Controller class]]) {
        CFJClientH5Controller *cfController = (CFJClientH5Controller *)controller;
        [cfController shareContent:data presentedVC:controller];
    }
}

- (void)handleCopyLink:(id)data controller:(UIViewController *)controller callback:(JSActionCallbackBlock)callback {
    NSDictionary *dataDic = (NSDictionary *)data;
    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
    pasteboard.string = [NSString stringWithFormat:@"%@", [dataDic objectForKey:@"url"]];
    
    if (callback) {
        callback(@{
            @"data": @"",
            @"success": @"true",
            @"errorMassage": @""
        });
    }
}

@end