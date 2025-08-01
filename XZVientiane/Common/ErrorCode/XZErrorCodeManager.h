//
//  XZErrorCodeManager.h
//  XZVientiane
//
//  错误码统一管理器 - 替代硬编码的错误处理
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// 错误码枚举定义
typedef NS_ENUM(NSInteger, XZErrorCode) {
    XZErrorCodeSuccess = 0,                    // 成功
    
    // 网络相关错误 (1000-1999)
    XZErrorCodeNetworkFailure = 1000,         // 网络连接失败
    XZErrorCodeNetworkTimeout = 1001,         // 网络超时
    XZErrorCodeNetworkUnauthorized = 1002,    // 未授权
    XZErrorCodeNetworkForbidden = 1003,       // 访问被禁止
    XZErrorCodeNetworkNotFound = 1004,        // 资源不存在
    XZErrorCodeNetworkServerError = 1005,     // 服务器错误
    
    // 用户相关错误 (2000-2999)
    XZErrorCodeUserNotLogin = 2000,           // 用户未登录
    XZErrorCodeUserTokenExpired = 2001,       // 用户令牌过期
    XZErrorCodeUserPermissionDenied = 2002,   // 用户权限不足
    XZErrorCodeUserAccountDisabled = 2003,    // 用户账户已禁用
    
    // 数据相关错误 (3000-3999)
    XZErrorCodeDataInvalid = 3000,            // 数据无效
    XZErrorCodeDataNotFound = 3001,           // 数据不存在
    XZErrorCodeDataCorrupted = 3002,          // 数据损坏
    XZErrorCodeDataFormatError = 3003,        // 数据格式错误
    
    // 系统相关错误 (4000-4999)
    XZErrorCodeSystemError = 4000,            // 系统错误
    XZErrorCodeSystemMemoryLow = 4001,        // 内存不足
    XZErrorCodeSystemStorageFull = 4002,      // 存储空间不足
    XZErrorCodeSystemPermissionDenied = 4003, // 系统权限被拒绝
    
    // 业务相关错误 (5000-5999)
    XZErrorCodeBusinessLogicError = 5000,     // 业务逻辑错误
    XZErrorCodeBusinessParameterError = 5001, // 业务参数错误
    XZErrorCodeBusinessOperationFailed = 5002, // 业务操作失败
    
    // WebView相关错误 (6000-6999)
    XZErrorCodeWebViewLoadFailed = 6000,      // WebView加载失败
    XZErrorCodeWebViewScriptError = 6001,     // JavaScript执行错误
    XZErrorCodeWebViewBridgeError = 6002,     // 桥接通信错误
    
    // 未知错误
    XZErrorCodeUnknown = 9999                 // 未知错误
};

@interface XZErrorCodeManager : NSObject

/**
 * 获取单例实例
 */
+ (instancetype)sharedManager;

/**
 * 根据错误码获取错误描述
 * @param errorCode 错误码
 * @return 错误描述文本
 */
- (NSString *)errorMessageForCode:(XZErrorCode)errorCode;

/**
 * 根据错误码获取用户友好的错误提示
 * @param errorCode 错误码
 * @return 用户友好的错误提示
 */
- (NSString *)userFriendlyMessageForCode:(XZErrorCode)errorCode;

/**
 * 创建NSError对象
 * @param errorCode 错误码
 * @param userInfo 附加信息（可选）
 * @return NSError对象
 */
- (NSError *)createErrorWithCode:(XZErrorCode)errorCode userInfo:(nullable NSDictionary *)userInfo;

/**
 * 判断错误是否为网络相关错误
 * @param errorCode 错误码
 * @return 是否为网络错误
 */
- (BOOL)isNetworkError:(XZErrorCode)errorCode;

/**
 * 判断错误是否为用户相关错误
 * @param errorCode 错误码
 * @return 是否为用户错误
 */
- (BOOL)isUserError:(XZErrorCode)errorCode;

/**
 * 判断错误是否为系统相关错误
 * @param errorCode 错误码
 * @return 是否为系统错误
 */
- (BOOL)isSystemError:(XZErrorCode)errorCode;

/**
 * 根据HTTP状态码转换为应用错误码
 * @param httpStatusCode HTTP状态码
 * @return 应用错误码
 */
- (XZErrorCode)errorCodeFromHTTPStatusCode:(NSInteger)httpStatusCode;

/**
 * 记录错误日志（带上下文信息）
 * @param errorCode 错误码
 * @param context 上下文信息
 */
- (void)logError:(XZErrorCode)errorCode context:(nullable NSString *)context;

@end

NS_ASSUME_NONNULL_END