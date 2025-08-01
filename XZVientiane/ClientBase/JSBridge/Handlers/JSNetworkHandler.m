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
    NSString *method = dataDic[@"method"];
    
    // 在局Claude Code修复：如果前端没有指定method，默认使用POST
    if (!method || method.length == 0) {
        method = @"POST";
    }
    
    NSDictionary *originalParameters = dataDic[@"data"] ?: @{};
    NSDictionary *headers = dataDic[@"header"] ?: @{};
    
    // 过滤掉null参数，但保留空字符串参数（某些API需要空字符串参数）
    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
    for (NSString *key in originalParameters) {
        id value = originalParameters[key];
        if (value && ![value isEqual:[NSNull null]]) {
            parameters[key] = value;
        }
    }
    
    
    
    if (!url || url.length == 0) {
        if (callback) {
            callback([self formatCallbackResponse:@"request" data:@{} success:NO errorMessage:@"URL不能为空"]);
        }
        return;
    }
    
    // 使用ClientJsonRequestManager发起请求，传递headers参数
    if ([method.uppercaseString isEqualToString:@"GET"]) {
        [[ClientJsonRequestManager sharedClient] GET:url
                                           parameters:parameters
                                              headers:headers
                                                block:^(id responseObject, NSError *error) {
            if (callback) {
                if (error) {
                    NSLog(@"GET请求失败: %@, 错误: %@", url, error);
                    callback([self formatCallbackResponse:@"request" 
                                                     data:@{} 
                                                  success:NO 
                                             errorMessage:error.localizedDescription]);
                } else {
                    
                    // 封装响应数据
                    NSDictionary *responseData = responseObject ?: @{};
                    
                    // 检查业务错误
                    NSNumber *code = responseData[@"code"];
                    if (code && [code integerValue] != 0) {
                        NSLog(@"业务错误 - code: %@, errorMessage: %@", code, responseData[@"errorMessage"]);
                    }
                    
                    callback([self formatCallbackResponse:@"request" 
                                                     data:responseData
                                                  success:YES 
                                             errorMessage:nil]);
                }
            }
        }];
    } else if ([method.uppercaseString isEqualToString:@"POST"]) {
        [[ClientJsonRequestManager sharedClient] POST:url
                                            parameters:parameters
                                               headers:headers
                                                 block:^(id responseObject, NSError *error) {
            if (callback) {
                if (error) {
                    NSLog(@"POST请求失败: %@, 错误: %@", url, error);
                    callback([self formatCallbackResponse:@"request" 
                                                     data:@{} 
                                                  success:NO 
                                             errorMessage:error.localizedDescription]);
                } else {
                    
                    // 封装响应数据
                    NSDictionary *responseData = responseObject ?: @{};
                    
                    // 检查业务错误
                    NSNumber *code = responseData[@"code"];
                    if (code && [code integerValue] != 0) {
                        NSLog(@"业务错误 - code: %@, errorMessage: %@", code, responseData[@"errorMessage"]);
                    }
                    
                    callback([self formatCallbackResponse:@"request" 
                                                     data:responseData
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