//
//  XZAuthenticationManager.h
//  XZVientiane
//
//  统一的登录状态管理器
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// 登录状态变化通知
extern NSString * const XZAuthenticationStateDidChangeNotification;
extern NSString * const XZAuthenticationUserInfoKey;

// 用户信息模型
@interface XZUserInfo : NSObject

@property (nonatomic, copy) NSString *userId;
@property (nonatomic, copy) NSString *nickname;
@property (nonatomic, copy) NSString *headpic;
@property (nonatomic, copy) NSString *token;
@property (nonatomic, copy) NSString *phone;
@property (nonatomic, copy) NSString *openId;      // 微信openId
@property (nonatomic, copy) NSString *unionId;     // 微信unionId
@property (nonatomic, strong) NSDate *loginTime;
@property (nonatomic, strong) NSDictionary *extraInfo; // 额外信息

@end

// 登录状态回调
typedef void(^XZAuthenticationCompletionBlock)(BOOL success, NSString * _Nullable errorMessage);

@interface XZAuthenticationManager : NSObject

/**
 * 获取单例实例
 */
+ (instancetype)sharedManager;

/**
 * 当前是否已登录
 */
@property (nonatomic, readonly) BOOL isLoggedIn;

/**
 * 当前用户信息（未登录时为nil）
 */
@property (nonatomic, strong, readonly, nullable) XZUserInfo *currentUser;

/**
 * 登录
 * @param userInfo 用户信息
 * @param completion 完成回调
 */
- (void)loginWithUserInfo:(XZUserInfo *)userInfo completion:(nullable XZAuthenticationCompletionBlock)completion;

/**
 * 退出登录
 * @param completion 完成回调
 */
- (void)logoutWithCompletion:(nullable XZAuthenticationCompletionBlock)completion;

/**
 * 更新用户信息
 * @param userInfo 新的用户信息
 */
- (void)updateUserInfo:(XZUserInfo *)userInfo;

/**
 * 检查登录状态是否有效
 * @param completion 回调
 */
- (void)checkAuthenticationStatus:(XZAuthenticationCompletionBlock)completion;

/**
 * 刷新Token
 * @param completion 完成回调
 */
- (void)refreshToken:(nullable XZAuthenticationCompletionBlock)completion;

/**
 * 同步登录状态到WebView
 * @param webView 需要同步的WebView
 * @param completion 完成回调
 */
- (void)syncLoginStateToWebView:(WKWebView *)webView completion:(nullable void(^)(void))completion;

/**
 * 从WebView同步登录状态
 * @param webView 来源WebView
 * @param completion 完成回调
 */
- (void)syncLoginStateFromWebView:(WKWebView *)webView completion:(nullable void(^)(void))completion;

/**
 * 清除所有认证信息
 */
- (void)clearAllAuthenticationInfo;

/**
 * 保存用户信息到本地
 */
- (void)saveUserInfoToLocal;

/**
 * 从本地加载用户信息
 */
- (void)loadUserInfoFromLocal;

@end

NS_ASSUME_NONNULL_END