//
//  JSActionHandler.m
//  XZVientiane
//
//  JS桥接动作处理器基类
//

#import "JSActionHandler.h"

@implementation JSActionHandler

- (NSArray<NSString *> *)supportedActions {
    // 子类需要重写此方法
    return @[];
}

- (BOOL)canHandleAction:(NSString *)action {
    return [[self supportedActions] containsObject:action];
}

- (void)handleAction:(NSString *)action 
              data:(id)data 
        controller:(UIViewController *)controller
          callback:(JSActionCallbackBlock)callback {
    // 子类需要实现具体的处理逻辑
    NSAssert(NO, @"子类必须实现 handleAction:data:controller:callback: 方法");
}

#pragma mark - 工具方法

- (NSDictionary *)formatCallbackResponse:(NSString *)apiType 
                                   data:(id)data 
                                success:(BOOL)success 
                           errorMessage:(NSString *)errorMessage {
    if (!errorMessage) {
        errorMessage = @"";
    }
    
    id formattedData = nil;
    
    if ([apiType isEqualToString:@"showModal"]) {
        formattedData = @{
            @"confirm": data[@"confirm"] ?: @"false",
            @"cancel": data[@"cancel"] ?: @"false"
        };
    } else if ([apiType isEqualToString:@"showActionSheet"]) {
        formattedData = @{
            @"tapIndex": data[@"tapIndex"] ?: @(-1)
        };
    } else if ([apiType isEqualToString:@"fancySelect"] || [apiType isEqualToString:@"areaSelect"]) {
        formattedData = @{
            @"value": data[@"value"] ?: @"",
            @"code": data[@"code"] ?: @""
        };
    } else if ([apiType isEqualToString:@"chooseFile"]) {
        formattedData = data ?: @[];
    } else if ([apiType isEqualToString:@"getLocation"]) {
        formattedData = @{
            @"latitude": data[@"lat"] ?: @(0),
            @"longitude": data[@"lng"] ?: @(0),
            @"city": data[@"city"] ?: @"",
            @"address": data[@"address"] ?: @""
        };
    } else if ([apiType isEqualToString:@"hasWx"] || [apiType isEqualToString:@"isiPhoneX"]) {
        formattedData = @{
            @"status": data[@"status"] ?: @(0)
        };
    } else if ([apiType isEqualToString:@"nativeGet"]) {
        formattedData = data ?: @"";
    } else if ([apiType isEqualToString:@"request"]) {
        if ([data isKindOfClass:[NSDictionary class]]) {
            NSNumber *serverCode = [data objectForKey:@"code"];
            NSString *codeString = @"0";
            
            if (!success) {
                if (serverCode) {
                    codeString = [serverCode stringValue];
                } else {
                    codeString = @"-1";
                }
            }
            
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
        formattedData = data ?: @{};
    }
    
    return @{
        @"success": success ? @"true" : @"false",
        @"data": formattedData,
        @"errorMessage": errorMessage
    };
}

@end