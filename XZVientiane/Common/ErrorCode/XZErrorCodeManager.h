//
//  XZErrorCodeManager.h
//  XZVientiane
//
//  统一的错误码管理器
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// 错误码定义
typedef NS_ENUM(NSInteger, XZErrorCode) {
    // 通用错误码
    XZErrorCodeSuccess = 0,                  // 成功
    XZErrorCodeUnknown = -1,                 // 未知错误
    XZErrorCodeInvalidParameter = -2,        // 参数错误
    XZErrorCodeNetworkError = -3,            // 网络错误
    XZErrorCodeTimeout = -4,                 // 超时
    XZErrorCodeCancelled = -5,               // 操作取消
    
    // 登录相关错误码
    XZErrorCodeNotLoggedIn = -100,           // 未登录
    XZErrorCodeLoginExpired = -101,          // 登录过期
    XZErrorCodeInvalidToken = -102,          // Token无效
    XZErrorCodeWeixinNotInstalled = -103,    // 微信未安装
    XZErrorCodeWeixinVersionLow = -104,      // 微信版本过低
    
    // 权限相关错误码
    XZErrorCodeNoPhotoPermission = -200,     // 无相册权限
    XZErrorCodeNoCameraPermission = -201,    // 无相机权限
    XZErrorCodeNoLocationPermission = -202,  // 无定位权限
    XZErrorCodeNoMicrophonePermission = -203,// 无麦克风权限
    
    // 文件操作错误码
    XZErrorCodeFileNotFound = -300,          // 文件不存在
    XZErrorCodeFileTooLarge = -301,          // 文件过大
    XZErrorCodeInvalidFileType = -302,       // 文件类型不支持
    XZErrorCodeUploadFailed = -303,          // 上传失败
    
    // 支付相关错误码
    XZErrorCodePaymentCancelled = -400,      // 支付取消
    XZErrorCodePaymentFailed = -401,         // 支付失败
    XZErrorCodeInvalidPaymentInfo = -402,    // 支付信息无效
    
    // 业务相关错误码
    XZErrorCodeDataNotFound = -500,          // 数据不存在
    XZErrorCodeOperationFailed = -501,       // 操作失败
    XZErrorCodeDuplicateOperation = -502,    // 重复操作
};

@interface XZErrorCodeManager : NSObject

/**
 * 获取单例实例
 */
+ (instancetype)sharedManager;

/**
 * 根据错误码获取错误描述
 * @param errorCode 错误码
 * @return 错误描述
 */
- (NSString *)errorMessageForCode:(XZErrorCode)errorCode;

/**
 * 根据错误码和自定义消息创建NSError
 * @param errorCode 错误码
 * @param message 自定义错误消息（可选）
 * @return NSError对象
 */
- (NSError *)errorWithCode:(XZErrorCode)errorCode message:(nullable NSString *)message;

/**
 * 根据错误码创建NSError
 * @param errorCode 错误码
 * @return NSError对象
 */
- (NSError *)errorWithCode:(XZErrorCode)errorCode;

/**
 * 判断错误码是否表示成功
 * @param errorCode 错误码
 * @return 是否成功
 */
- (BOOL)isSuccess:(XZErrorCode)errorCode;

/**
 * 根据服务器返回的code获取对应的XZErrorCode
 * @param serverCode 服务器返回的code
 * @return XZErrorCode
 */
- (XZErrorCode)errorCodeFromServerCode:(NSInteger)serverCode;

@end

NS_ASSUME_NONNULL_END