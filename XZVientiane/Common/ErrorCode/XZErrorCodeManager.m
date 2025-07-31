//
//  XZErrorCodeManager.m
//  XZVientiane
//
//  统一的错误码管理器
//

#import "XZErrorCodeManager.h"

static NSString * const XZErrorDomain = @"com.zaiju.error";

@interface XZErrorCodeManager ()

@property (nonatomic, strong) NSDictionary<NSNumber *, NSString *> *errorMessages;

@end

@implementation XZErrorCodeManager

+ (instancetype)sharedManager {
    static XZErrorCodeManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[XZErrorCodeManager alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [self setupErrorMessages];
    }
    return self;
}

- (void)setupErrorMessages {
    self.errorMessages = @{
        // 通用错误码
        @(XZErrorCodeSuccess): @"操作成功",
        @(XZErrorCodeUnknown): @"未知错误",
        @(XZErrorCodeInvalidParameter): @"参数错误",
        @(XZErrorCodeNetworkError): @"网络连接失败，请检查网络设置",
        @(XZErrorCodeTimeout): @"请求超时，请稍后重试",
        @(XZErrorCodeCancelled): @"操作已取消",
        
        // 登录相关错误码
        @(XZErrorCodeNotLoggedIn): @"请先登录",
        @(XZErrorCodeLoginExpired): @"登录已过期，请重新登录",
        @(XZErrorCodeInvalidToken): @"登录信息无效，请重新登录",
        @(XZErrorCodeWeixinNotInstalled): @"您没有安装微信",
        @(XZErrorCodeWeixinVersionLow): @"您的微信版本太低",
        
        // 权限相关错误码
        @(XZErrorCodeNoPhotoPermission): @"请在设置中允许访问相册",
        @(XZErrorCodeNoCameraPermission): @"请在设置中允许访问相机",
        @(XZErrorCodeNoLocationPermission): @"请在设置中允许访问位置信息",
        @(XZErrorCodeNoMicrophonePermission): @"请在设置中允许访问麦克风",
        
        // 文件操作错误码
        @(XZErrorCodeFileNotFound): @"文件不存在",
        @(XZErrorCodeFileTooLarge): @"文件过大",
        @(XZErrorCodeInvalidFileType): @"不支持的文件类型",
        @(XZErrorCodeUploadFailed): @"上传失败，请重试",
        
        // 支付相关错误码
        @(XZErrorCodePaymentCancelled): @"支付已取消",
        @(XZErrorCodePaymentFailed): @"支付失败",
        @(XZErrorCodeInvalidPaymentInfo): @"支付信息无效",
        
        // 业务相关错误码
        @(XZErrorCodeDataNotFound): @"数据不存在",
        @(XZErrorCodeOperationFailed): @"操作失败",
        @(XZErrorCodeDuplicateOperation): @"请勿重复操作"
    };
}

- (NSString *)errorMessageForCode:(XZErrorCode)errorCode {
    NSString *message = self.errorMessages[@(errorCode)];
    return message ?: @"未知错误";
}

- (NSError *)errorWithCode:(XZErrorCode)errorCode message:(nullable NSString *)message {
    NSString *errorMessage = message ?: [self errorMessageForCode:errorCode];
    
    NSDictionary *userInfo = @{
        NSLocalizedDescriptionKey: errorMessage,
        @"errorCode": @(errorCode)
    };
    
    return [NSError errorWithDomain:XZErrorDomain code:errorCode userInfo:userInfo];
}

- (NSError *)errorWithCode:(XZErrorCode)errorCode {
    return [self errorWithCode:errorCode message:nil];
}

- (BOOL)isSuccess:(XZErrorCode)errorCode {
    return errorCode == XZErrorCodeSuccess;
}

- (XZErrorCode)errorCodeFromServerCode:(NSInteger)serverCode {
    // 服务器返回的code映射到本地错误码
    switch (serverCode) {
        case 0:
            return XZErrorCodeSuccess;
        case -1:
            return XZErrorCodeUnknown;
        case 401:
        case 403:
            return XZErrorCodeNotLoggedIn;
        case 404:
            return XZErrorCodeDataNotFound;
        case 500:
        case 502:
        case 503:
            return XZErrorCodeNetworkError;
        default:
            return XZErrorCodeUnknown;
    }
}

@end