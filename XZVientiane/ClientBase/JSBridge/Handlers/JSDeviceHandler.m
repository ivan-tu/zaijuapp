//
//  JSDeviceHandler.m
//  XZVientiane
//
//  处理设备相关的JS调用
//

#import "JSDeviceHandler.h"
#import "BaseFileManager.h"
#import "XZPackageH5.h"

// 内联函数定义
static inline BOOL isIPhoneXSeries() {
    BOOL iPhoneXSeries = NO;
    if (UIDevice.currentDevice.userInterfaceIdiom != UIUserInterfaceIdiomPhone) {
        return iPhoneXSeries;
    }
    
    if (@available(iOS 11.0, *)) {
        UIWindow *mainWindow = [[[UIApplication sharedApplication] delegate] window];
        if (mainWindow.safeAreaInsets.bottom > 0.0) {
            iPhoneXSeries = YES;
        }
    }
    
    return iPhoneXSeries;
}

@implementation JSDeviceHandler

- (NSArray<NSString *> *)supportedActions {
    return @[@"hasWx", @"isiPhoneX", @"nativeGet"];
}

- (void)handleAction:(NSString *)action 
              data:(id)data 
        controller:(UIViewController *)controller
          callback:(JSActionCallbackBlock)callback {
    
    if ([action isEqualToString:@"hasWx"]) {
        [self handleHasWx:callback];
    } else if ([action isEqualToString:@"isiPhoneX"]) {
        [self handleIsiPhoneX:callback];
    } else if ([action isEqualToString:@"nativeGet"]) {
        [self handleNativeGet:data callback:callback];
    }
}

#pragma mark - 设备信息处理

- (void)handleHasWx:(JSActionCallbackBlock)callback {
    BOOL isWXInstalled = [XZPackageH5 sharedInstance].isWXAppInstalled;
    
    if (callback) {
        NSDictionary *response = [self formatCallbackResponse:@"hasWx" 
                                                        data:@{@"status": isWXInstalled ? @(1) : @(0)} 
                                                     success:YES 
                                                errorMessage:nil];
        callback(response);
    }
}

- (void)handleIsiPhoneX:(JSActionCallbackBlock)callback {
    if (callback) {
        NSDictionary *response = [self formatCallbackResponse:@"isiPhoneX" 
                                                        data:@{@"status": isIPhoneXSeries() ? @(1) : @(0)} 
                                                     success:YES 
                                                errorMessage:nil];
        callback(response);
    }
}

- (void)handleNativeGet:(id)data callback:(JSActionCallbackBlock)callback {
    NSString *myData = nil;
    
    // 安全地提取文件路径字符串
    if ([data isKindOfClass:[NSString class]]) {
        myData = (NSString *)data;
    } else if ([data isKindOfClass:[NSDictionary class]]) {
        // JS端传递的数据格式：{data: "path", success: function}
        NSDictionary *dataDict = (NSDictionary *)data;
        myData = dataDict[@"data"];
        
        // 如果data字段不存在，尝试其他可能的字段名
        if (!myData) {
            myData = dataDict[@"path"] ?: dataDict[@"file"] ?: dataDict[@"url"];
        }
    } else if (data) {
        // 其他类型尝试转换为字符串
        myData = [NSString stringWithFormat:@"%@", data];
    }
    
    if (!myData || myData.length == 0) {
        if (callback) {
            NSDictionary *response = [self formatCallbackResponse:@"nativeGet" 
                                                            data:@"" 
                                                         success:NO 
                                                    errorMessage:@"Invalid file path data"];
            callback(response);
        }
        return;
    }
    
    NSString *filepath = [[BaseFileManager appH5LocailManifesPath] stringByAppendingPathComponent:myData];
    NSString *myStr = [NSString stringWithContentsOfURL:[NSURL fileURLWithPath:filepath] encoding:NSUTF8StringEncoding error:nil];
    
    // 确保myStr不为nil，避免[object object]问题
    if (!myStr) {
        myStr = @"";
    }
    
    if (callback) {
        NSDictionary *response = [self formatCallbackResponse:@"nativeGet" 
                                                        data:myStr 
                                                     success:YES 
                                                errorMessage:nil];
        callback(response);
    }
}

@end