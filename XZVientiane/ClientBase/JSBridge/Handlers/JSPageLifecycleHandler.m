//
//  JSPageLifecycleHandler.m
//  XZVientiane
//
//  处理页面生命周期相关的JS调用
//

#import "JSPageLifecycleHandler.h"

@implementation JSPageLifecycleHandler

- (NSArray<NSString *> *)supportedActions {
    return @[@"pageShow", @"pageHide", @"pageUnload"];
}

- (void)handleAction:(NSString *)action 
              data:(id)data 
        controller:(UIViewController *)controller
          callback:(JSActionCallbackBlock)callback {
    
    if ([action isEqualToString:@"pageShow"]) {
        [self handlePageShow:data controller:controller callback:callback];
    } else if ([action isEqualToString:@"pageHide"]) {
        [self handlePageHide:data controller:controller callback:callback];
    } else if ([action isEqualToString:@"pageUnload"]) {
        [self handlePageUnload:data controller:controller callback:callback];
    }
}

#pragma mark - Private Methods

- (void)handlePageShow:(id)data controller:(UIViewController *)controller callback:(JSActionCallbackBlock)callback {
    // pageShow 通常用于页面显示时的回调
    // 可以在这里添加统计或其他逻辑
    
    if (callback) {
        callback([self formatCallbackResponse:@"pageShow" data:@{} success:YES errorMessage:nil]);
    }
}

- (void)handlePageHide:(id)data controller:(UIViewController *)controller callback:(JSActionCallbackBlock)callback {
    // pageHide 通常用于页面隐藏时的回调
    // 可以在这里添加统计或其他逻辑
    
    if (callback) {
        callback([self formatCallbackResponse:@"pageHide" data:@{} success:YES errorMessage:nil]);
    }
}

- (void)handlePageUnload:(id)data controller:(UIViewController *)controller callback:(JSActionCallbackBlock)callback {
    // pageUnload 通常用于页面卸载时的回调
    // 可以在这里添加清理逻辑
    
    if (callback) {
        callback([self formatCallbackResponse:@"pageUnload" data:@{} success:YES errorMessage:nil]);
    }
}

@end