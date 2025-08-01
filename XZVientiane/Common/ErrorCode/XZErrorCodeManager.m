//
//  XZErrorCodeManager.m
//  XZVientiane
//
//  错误码统一管理器 - 替代硬编码的错误处理
//

#import "XZErrorCodeManager.h"

static NSString * const XZErrorDomain = @"com.zaiju.error";

@interface XZErrorCodeManager ()

@property (nonatomic, strong) NSDictionary<NSNumber *, NSString *> *errorMessages;
@property (nonatomic, strong) NSDictionary<NSNumber *, NSString *> *userFriendlyMessages;

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
        [self setupUserFriendlyMessages];
        
        NSLog(@"在局✅ [XZErrorCodeManager] 错误码管理器初始化完成");
    }
    return self;
}

#pragma mark - Setup Methods

- (void)setupErrorMessages {
    _errorMessages = @{
        // 成功
        @(XZErrorCodeSuccess): @"操作成功",
        
        // 网络相关错误
        @(XZErrorCodeNetworkFailure): @"网络连接失败",
        @(XZErrorCodeNetworkTimeout): @"网络请求超时",
        @(XZErrorCodeNetworkUnauthorized): @"未授权访问",
        @(XZErrorCodeNetworkForbidden): @"访问被禁止",
        @(XZErrorCodeNetworkNotFound): @"请求的资源不存在",
        @(XZErrorCodeNetworkServerError): @"服务器内部错误",
        
        // 用户相关错误
        @(XZErrorCodeUserNotLogin): @"用户未登录",
        @(XZErrorCodeUserTokenExpired): @"用户登录状态已过期",
        @(XZErrorCodeUserPermissionDenied): @"用户权限不足",
        @(XZErrorCodeUserAccountDisabled): @"用户账户已被禁用",
        
        // 数据相关错误
        @(XZErrorCodeDataInvalid): @"数据格式不正确",
        @(XZErrorCodeDataNotFound): @"未找到相关数据",
        @(XZErrorCodeDataCorrupted): @"数据已损坏",
        @(XZErrorCodeDataFormatError): @"数据格式错误",
        
        // 系统相关错误
        @(XZErrorCodeSystemError): @"系统错误",
        @(XZErrorCodeSystemMemoryLow): @"系统内存不足",
        @(XZErrorCodeSystemStorageFull): @"存储空间已满",
        @(XZErrorCodeSystemPermissionDenied): @"系统权限被拒绝",
        
        // 业务相关错误
        @(XZErrorCodeBusinessLogicError): @"业务逻辑处理失败",
        @(XZErrorCodeBusinessParameterError): @"请求参数错误",
        @(XZErrorCodeBusinessOperationFailed): @"操作执行失败",
        
        // WebView相关错误
        @(XZErrorCodeWebViewLoadFailed): @"页面加载失败",
        @(XZErrorCodeWebViewScriptError): @"页面脚本执行错误",
        @(XZErrorCodeWebViewBridgeError): @"页面通信桥接错误",
        
        // 未知错误
        @(XZErrorCodeUnknown): @"未知错误"
    };
}

- (void)setupUserFriendlyMessages {
    _userFriendlyMessages = @{
        // 成功
        @(XZErrorCodeSuccess): @"操作完成",
        
        // 网络相关错误
        @(XZErrorCodeNetworkFailure): @"网络连接失败，请检查网络设置",
        @(XZErrorCodeNetworkTimeout): @"网络请求超时，请重试",
        @(XZErrorCodeNetworkUnauthorized): @"请先登录后再试",
        @(XZErrorCodeNetworkForbidden): @"暂无访问权限",
        @(XZErrorCodeNetworkNotFound): @"请求的内容不存在",
        @(XZErrorCodeNetworkServerError): @"服务器忙，请稍后重试",
        
        // 用户相关错误
        @(XZErrorCodeUserNotLogin): @"请先登录",
        @(XZErrorCodeUserTokenExpired): @"登录已过期，请重新登录",
        @(XZErrorCodeUserPermissionDenied): @"权限不足，无法执行此操作",
        @(XZErrorCodeUserAccountDisabled): @"账户已被禁用，请联系客服",
        
        // 数据相关错误
        @(XZErrorCodeDataInvalid): @"数据格式不正确",
        @(XZErrorCodeDataNotFound): @"暂无相关数据",
        @(XZErrorCodeDataCorrupted): @"数据异常，请重试",
        @(XZErrorCodeDataFormatError): @"数据格式有误",
        
        // 系统相关错误
        @(XZErrorCodeSystemError): @"系统异常，请稍后重试",
        @(XZErrorCodeSystemMemoryLow): @"设备内存不足",
        @(XZErrorCodeSystemStorageFull): @"设备存储空间不足",
        @(XZErrorCodeSystemPermissionDenied): @"需要相应的系统权限",
        
        // 业务相关错误
        @(XZErrorCodeBusinessLogicError): @"操作失败，请重试",
        @(XZErrorCodeBusinessParameterError): @"参数错误，请检查输入",
        @(XZErrorCodeBusinessOperationFailed): @"操作失败",
        
        // WebView相关错误
        @(XZErrorCodeWebViewLoadFailed): @"页面加载失败，请刷新重试",
        @(XZErrorCodeWebViewScriptError): @"页面运行异常",
        @(XZErrorCodeWebViewBridgeError): @"页面通信异常",
        
        // 未知错误
        @(XZErrorCodeUnknown): @"出现未知错误，请重试"
    };
}

#pragma mark - Public Methods

- (NSString *)errorMessageForCode:(XZErrorCode)errorCode {
    NSString *message = _errorMessages[@(errorCode)];
    return message ?: _errorMessages[@(XZErrorCodeUnknown)];
}

- (NSString *)userFriendlyMessageForCode:(XZErrorCode)errorCode {
    NSString *message = _userFriendlyMessages[@(errorCode)];
    return message ?: _userFriendlyMessages[@(XZErrorCodeUnknown)];
}

- (NSError *)createErrorWithCode:(XZErrorCode)errorCode userInfo:(NSDictionary *)userInfo {
    NSMutableDictionary *mutableUserInfo = [NSMutableDictionary dictionary];
    
    // 添加错误描述
    mutableUserInfo[NSLocalizedDescriptionKey] = [self errorMessageForCode:errorCode];
    mutableUserInfo[NSLocalizedFailureReasonErrorKey] = [self userFriendlyMessageForCode:errorCode];
    
    // 添加自定义信息
    if (userInfo) {
        [mutableUserInfo addEntriesFromDictionary:userInfo];
    }
    
    return [NSError errorWithDomain:XZErrorDomain code:errorCode userInfo:[mutableUserInfo copy]];
}

- (BOOL)isNetworkError:(XZErrorCode)errorCode {
    return errorCode >= XZErrorCodeNetworkFailure && errorCode < 2000;
}

- (BOOL)isUserError:(XZErrorCode)errorCode {
    return errorCode >= XZErrorCodeUserNotLogin && errorCode < 3000;
}

- (BOOL)isSystemError:(XZErrorCode)errorCode {
    return errorCode >= XZErrorCodeSystemError && errorCode < 5000;
}

- (XZErrorCode)errorCodeFromHTTPStatusCode:(NSInteger)httpStatusCode {
    switch (httpStatusCode) {
        case 200:
        case 201:
        case 204:
            return XZErrorCodeSuccess;
            
        case 400:
            return XZErrorCodeBusinessParameterError;
            
        case 401:
            return XZErrorCodeNetworkUnauthorized;
            
        case 403:
            return XZErrorCodeNetworkForbidden;
            
        case 404:
            return XZErrorCodeNetworkNotFound;
            
        case 408:
            return XZErrorCodeNetworkTimeout;
            
        case 500:
        case 501:
        case 502:
        case 503:
        case 504:
            return XZErrorCodeNetworkServerError;
            
        default:
            if (httpStatusCode >= 400 && httpStatusCode < 500) {
                return XZErrorCodeBusinessLogicError;
            } else if (httpStatusCode >= 500) {
                return XZErrorCodeNetworkServerError;
            }
            return XZErrorCodeUnknown;
    }
}

- (void)logError:(XZErrorCode)errorCode context:(NSString *)context {
    NSString *errorMessage = [self errorMessageForCode:errorCode];
    NSString *logMessage = [NSString stringWithFormat:@"在局❌ [错误日志] 错误码: %ld, 描述: %@", (long)errorCode, errorMessage];
    
    if (context && context.length > 0) {
        logMessage = [logMessage stringByAppendingFormat:@", 上下文: %@", context];
    }
    
    NSLog(@"%@", logMessage);
    
    // 这里可以扩展为发送到远程日志服务
    // [self sendErrorToRemoteLogging:errorCode message:errorMessage context:context];
}

@end