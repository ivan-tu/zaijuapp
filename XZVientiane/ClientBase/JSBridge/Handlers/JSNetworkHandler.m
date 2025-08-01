//
//  JSNetworkHandler.m
//  XZVientiane
//
//  处理网络请求相关的JS调用
//

#import "JSNetworkHandler.h"
#import "ClientJsonRequestManager.h"

@implementation JSNetworkHandler

- (NSArray<NSString *> *)supportedActions {
    return @[@"request"];
}

- (void)handleAction:(NSString *)action 
              data:(id)data 
        controller:(UIViewController *)controller
          callback:(JSActionCallbackBlock)callback {
    
    if ([action isEqualToString:@"request"]) {
        [self handleRequest:data controller:controller callback:callback];
    }
}

#pragma mark - Private Methods

- (void)handleRequest:(id)data controller:(UIViewController *)controller callback:(JSActionCallbackBlock)callback {
    NSDictionary *dataDic = (NSDictionary *)data;
    
    NSString *url = dataDic[@"url"];
    NSString *method = dataDic[@"method"] ?: @"GET";
    NSDictionary *parameters = dataDic[@"data"] ?: @{};
    NSDictionary *headers = dataDic[@"header"] ?: @{};
    
    if (!url || url.length == 0) {
        if (callback) {
            callback([self formatCallbackResponse:@"request" data:@{} success:NO errorMessage:@"URL不能为空"]);
        }
        return;
    }
    
    // 使用ClientJsonRequestManager发起请求
    if ([method.uppercaseString isEqualToString:@"GET"]) {
        [[ClientJsonRequestManager sharedClient] GET:url
                                           parameters:parameters
                                                block:^(id responseObject, NSError *error) {
            if (callback) {
                if (error) {
                    callback([self formatCallbackResponse:@"request" 
                                                     data:@{} 
                                                  success:NO 
                                             errorMessage:error.localizedDescription]);
                } else {
                    callback([self formatCallbackResponse:@"request" 
                                                     data:responseObject ?: @{} 
                                                  success:YES 
                                             errorMessage:nil]);
                }
            }
        }];
    } else if ([method.uppercaseString isEqualToString:@"POST"]) {
        [[ClientJsonRequestManager sharedClient] POST:url
                                            parameters:parameters
                                                 block:^(id responseObject, NSError *error) {
            if (callback) {
                if (error) {
                    callback([self formatCallbackResponse:@"request" 
                                                     data:@{} 
                                                  success:NO 
                                             errorMessage:error.localizedDescription]);
                } else {
                    callback([self formatCallbackResponse:@"request" 
                                                     data:responseObject ?: @{} 
                                                  success:YES 
                                             errorMessage:nil]);
                }
            }
        }];
    } else {
        if (callback) {
            callback([self formatCallbackResponse:@"request" 
                                             data:@{} 
                                          success:NO 
                                     errorMessage:@"不支持的请求方法"]);
        }
    }
}

@end