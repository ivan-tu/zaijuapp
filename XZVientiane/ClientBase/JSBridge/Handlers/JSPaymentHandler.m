//
//  JSPaymentHandler.m
//  XZVientiane
//
//  处理支付相关的JS调用
//

#import "JSPaymentHandler.h"
#import <AlipaySDK/AlipaySDK.h>
#import "WXApi.h"
#import "PublicSettingModel.h"
#import "NSString+MD5.h"

@implementation JSPaymentHandler

- (NSArray<NSString *> *)supportedActions {
    return @[@"weixinPay", @"aliPay"];
}

- (void)handleAction:(NSString *)action 
              data:(id)data 
        controller:(UIViewController *)controller
          callback:(JSActionCallbackBlock)callback {
    
    // 保存回调
    if ([controller respondsToSelector:@selector(setWebviewBackCallBack:)]) {
        [controller performSelector:@selector(setWebviewBackCallBack:) withObject:callback];
    }
    
    if ([action isEqualToString:@"weixinPay"]) {
        [self handleWeixinPay:data controller:controller];
    } else if ([action isEqualToString:@"aliPay"]) {
        [self handleAliPay:data controller:controller];
    }
}

#pragma mark - 支付处理

- (void)handleWeixinPay:(id)data controller:(UIViewController *)controller {
    NSDictionary *jsDic = (NSDictionary *)data;
    NSLog(@"在局🔧 [JSPaymentHandler-微信支付] 开始处理微信支付请求，原始数据: %@", jsDic);
    
    // 兼容两种数据格式：嵌套在data字段中的 和 直接的支付参数
    NSDictionary *messageDic = [jsDic objectForKey:@"data"];
    if (!messageDic || ![messageDic isKindOfClass:[NSDictionary class]]) {
        // 如果没有data字段，则直接使用jsDic作为支付参数
        messageDic = jsDic;
        NSLog(@"在局🔧 [JSPaymentHandler-微信支付] 使用直接参数格式");
    } else {
        NSLog(@"在局🔧 [JSPaymentHandler-微信支付] 使用嵌套参数格式");
    }
    
    NSLog(@"在局🔧 [JSPaymentHandler-微信支付] 处理的支付参数: %@", messageDic);
    
    if (messageDic && [messageDic isKindOfClass:[NSDictionary class]]) {
        // 检查微信是否可用
        if (![WXApi isWXAppInstalled]) {
            NSLog(@"在局❌ [JSPaymentHandler-微信支付] 微信应用未安装");
            // 获取回调并执行错误回调
            if ([controller respondsToSelector:@selector(webviewBackCallBack)]) {
                JSActionCallbackBlock callback = [controller performSelector:@selector(webviewBackCallBack)];
                if (callback) {
                    callback(@{
                        @"success": @"false",
                        @"errorMessage": @"请先安装微信应用"
                    });
                }
            }
            return;
        }
        if (![WXApi isWXAppSupportApi]) {
            NSLog(@"在局❌ [JSPaymentHandler-微信支付] 微信版本过低，不支持支付");
            // 获取回调并执行错误回调
            if ([controller respondsToSelector:@selector(webviewBackCallBack)]) {
                JSActionCallbackBlock callback = [controller performSelector:@selector(webviewBackCallBack)];
                if (callback) {
                    callback(@{
                        @"success": @"false",
                        @"errorMessage": @"微信版本过低，请升级微信"
                    });
                }
            }
            return;
        }
        
        // 创建支付请求
        PayReq *request = [[PayReq alloc] init];
        
        // 类型安全的参数提取
        id partnerIdObj = [messageDic objectForKey:@"partnerid"];
        request.partnerId = [partnerIdObj isKindOfClass:[NSString class]] ? (NSString *)partnerIdObj : [NSString stringWithFormat:@"%@", partnerIdObj];
        
        request.prepayId = [messageDic objectForKey:@"prepayid"];
        request.package = [messageDic objectForKey:@"package"];
        request.nonceStr = [messageDic objectForKey:@"noncestr"];
        
        // 时间戳类型安全转换
        id timestampObj = [messageDic objectForKey:@"timestamp"];
        if ([timestampObj isKindOfClass:[NSString class]]) {
            request.timeStamp = (UInt32)[(NSString *)timestampObj integerValue];
        } else if ([timestampObj isKindOfClass:[NSNumber class]]) {
            request.timeStamp = (UInt32)[(NSNumber *)timestampObj unsignedIntValue];
        } else {
            request.timeStamp = 0;
        }
        
        NSLog(@"在局🔧 [JSPaymentHandler-微信支付] 支付参数设置 - partnerId:%@, prepayId:%@, package:%@, nonceStr:%@, timeStamp:%u", 
              request.partnerId, request.prepayId, request.package, request.nonceStr, (unsigned int)request.timeStamp);
        
        // 验证必要参数
        if (!request.partnerId || !request.prepayId || !request.package || !request.nonceStr || request.timeStamp == 0) {
            NSLog(@"在局❌ [JSPaymentHandler-微信支付] 支付参数不完整");
            if ([controller respondsToSelector:@selector(webviewBackCallBack)]) {
                JSActionCallbackBlock callback = [controller performSelector:@selector(webviewBackCallBack)];
                if (callback) {
                    callback(@{
                        @"success": @"false",
                        @"errorMessage": @"支付参数不完整"
                    });
                }
            }
            return;
        }
        
        // 重新计算签名（确保签名正确）
        NSString *appid = [[PublicSettingModel sharedInstance] weiXin_AppID];
        NSString *stringA = [NSString stringWithFormat:@"appid=%@&noncestr=%@&package=%@&partnerid=%@&prepayid=%@&timestamp=%u",
                           appid, request.nonceStr, request.package, request.partnerId, request.prepayId, (unsigned int)request.timeStamp];
        NSString *appKey = [[PublicSettingModel sharedInstance] weiXin_Key];
        NSString *stringSignTemp = [NSString stringWithFormat:@"%@&key=%@", stringA, appKey];
        NSString *sign = [stringSignTemp MD5];
        request.sign = [sign uppercaseString];
        
        NSLog(@"在局🔧 [JSPaymentHandler-微信支付] 签名计算 - 原字符串: %@", stringA);
        NSLog(@"在局🔧 [JSPaymentHandler-微信支付] 签名计算 - 最终签名: %@", request.sign);
        
        // 发送支付请求
        [WXApi sendReq:request completion:^(BOOL success) {
            NSLog(@"在局🔧 [JSPaymentHandler-微信支付] 支付请求发送结果: %@", success ? @"成功" : @"失败");
            if (!success && [controller respondsToSelector:@selector(webviewBackCallBack)]) {
                JSActionCallbackBlock callback = [controller performSelector:@selector(webviewBackCallBack)];
                if (callback) {
                    callback(@{
                        @"success": @"false",
                        @"errorMessage": @"微信支付调用失败"
                    });
                }
            }
        }];
    } else {
        NSLog(@"在局❌ [JSPaymentHandler-微信支付] 支付参数格式错误");
        if ([controller respondsToSelector:@selector(webviewBackCallBack)]) {
            JSActionCallbackBlock callback = [controller performSelector:@selector(webviewBackCallBack)];
            if (callback) {
                callback(@{
                    @"success": @"false",
                    @"errorMessage": @"支付参数格式错误"
                });
            }
        }
    }
}

- (void)handleAliPay:(id)data controller:(UIViewController *)controller {
    NSDictionary *jsDic = (NSDictionary *)data;
    NSString *appScheme = [[PublicSettingModel sharedInstance] app_Scheme];
    NSString *sign = [jsDic objectForKey:@"data"];
    
    if (!sign || sign.length <= 0) {
        NSLog(@"在局支付宝支付信息出错");
        return;
    }
    
    [[AlipaySDK defaultService] payOrder:sign fromScheme:appScheme callback:^(NSDictionary *resultDic) {
        // 回调会在支付结果通知中处理
    }];
}

@end