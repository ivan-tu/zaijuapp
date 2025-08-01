//
//  XZAuthenticationManager.m
//  XZVientiane
//
//  统一的登录状态管理器
//

#import "XZAuthenticationManager.h"
#import <WebKit/WebKit.h>
#import "HTMLCache.h"
#import "WKWebView+XZAddition.h"

NSString * const XZAuthenticationStateDidChangeNotification = @"XZAuthenticationStateDidChangeNotification";
NSString * const XZAuthenticationUserInfoKey = @"XZAuthenticationUserInfoKey";

// UserDefaults Keys
static NSString * const kUserLoginStateKey = @"isLogin";
static NSString * const kUserInfoKey = @"XZUserInfo";
static NSString * const kUserTokenKey = @"User_Token_String";
static NSString * const kUserIdKey = @"loginUid";
static NSString * const kUserNameKey = @"userName";
static NSString * const kUserPhoneKey = @"userPhone";
static NSString * const kUserAvatarKey = @"avatarURLPath";

@implementation XZUserInfo

- (instancetype)init {
    self = [super init];
    if (self) {
        _loginTime = [NSDate date];
        _extraInfo = @{};
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone {
    XZUserInfo *copy = [[XZUserInfo allocWithZone:zone] init];
    copy.userId = [self.userId copy];
    copy.nickname = [self.nickname copy];
    copy.headpic = [self.headpic copy];
    copy.token = [self.token copy];
    copy.phone = [self.phone copy];
    copy.openId = [self.openId copy];
    copy.unionId = [self.unionId copy];
    copy.loginTime = [self.loginTime copy];
    copy.extraInfo = [self.extraInfo copy];
    return copy;
}

// 实现NSCoding协议以支持归档
- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:self.userId forKey:@"userId"];
    [coder encodeObject:self.nickname forKey:@"nickname"];
    [coder encodeObject:self.headpic forKey:@"headpic"];
    [coder encodeObject:self.token forKey:@"token"];
    [coder encodeObject:self.phone forKey:@"phone"];
    [coder encodeObject:self.openId forKey:@"openId"];
    [coder encodeObject:self.unionId forKey:@"unionId"];
    [coder encodeObject:self.loginTime forKey:@"loginTime"];
    [coder encodeObject:self.extraInfo forKey:@"extraInfo"];
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super init];
    if (self) {
        self.userId = [coder decodeObjectForKey:@"userId"];
        self.nickname = [coder decodeObjectForKey:@"nickname"];
        self.headpic = [coder decodeObjectForKey:@"headpic"];
        self.token = [coder decodeObjectForKey:@"token"];
        self.phone = [coder decodeObjectForKey:@"phone"];
        self.openId = [coder decodeObjectForKey:@"openId"];
        self.unionId = [coder decodeObjectForKey:@"unionId"];
        self.loginTime = [coder decodeObjectForKey:@"loginTime"];
        self.extraInfo = [coder decodeObjectForKey:@"extraInfo"] ?: @{};
    }
    return self;
}

@end

@interface XZAuthenticationManager ()

@property (nonatomic, strong, readwrite) XZUserInfo *currentUser;
@property (nonatomic, assign, readwrite) BOOL isLoggedIn;
@property (nonatomic, strong) dispatch_queue_t authQueue;

@end

@implementation XZAuthenticationManager

+ (instancetype)sharedManager {
    static XZAuthenticationManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[XZAuthenticationManager alloc] init];
        [instance loadUserInfoFromLocal];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _authQueue = dispatch_queue_create("com.zaiju.auth", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

#pragma mark - Public Methods

- (void)loginWithUserInfo:(XZUserInfo *)userInfo completion:(nullable XZAuthenticationCompletionBlock)completion {
    if (!userInfo) {
        if (completion) {
            completion(NO, @"用户信息不能为空");
        }
        return;
    }
    
    dispatch_async(self.authQueue, ^{
        // 更新用户信息
        self.currentUser = userInfo;
        self.isLoggedIn = YES;
        
        // 保存到UserDefaults
        [self saveUserInfoToLocal];
        
        // 清除HTML缓存，确保页面能正确刷新
        [[HTMLCache sharedCache] removeAllCache];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            // 发送登录状态变化通知
            [[NSNotificationCenter defaultCenter] postNotificationName:XZAuthenticationStateDidChangeNotification
                                                                object:self
                                                              userInfo:@{XZAuthenticationUserInfoKey: userInfo}];
            
            
            if (completion) {
                completion(YES, nil);
            }
        });
    });
}

- (void)logoutWithCompletion:(nullable XZAuthenticationCompletionBlock)completion {
    dispatch_async(self.authQueue, ^{
        // 清除用户信息
        self.currentUser = nil;
        self.isLoggedIn = NO;
        
        // 清除本地存储
        [self clearAllAuthenticationInfo];
        
        // 清除HTML缓存和Cookie
        [[HTMLCache sharedCache] removeAllCache];
        [WKWebView cookieDeleteAllCookie];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            // 发送登录状态变化通知
            [[NSNotificationCenter defaultCenter] postNotificationName:XZAuthenticationStateDidChangeNotification
                                                                object:self
                                                              userInfo:nil];
            
            
            if (completion) {
                completion(YES, nil);
            }
        });
    });
}

- (void)updateUserInfo:(XZUserInfo *)userInfo {
    if (!userInfo) return;
    
    dispatch_async(self.authQueue, ^{
        self.currentUser = userInfo;
        [self saveUserInfoToLocal];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:XZAuthenticationStateDidChangeNotification
                                                                object:self
                                                              userInfo:@{XZAuthenticationUserInfoKey: userInfo}];
        });
    });
}

- (void)checkAuthenticationStatus:(XZAuthenticationCompletionBlock)completion {
    dispatch_async(self.authQueue, ^{
        BOOL isValid = self.isLoggedIn && self.currentUser && self.currentUser.token.length > 0;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) {
                completion(isValid, isValid ? nil : @"登录状态无效");
            }
        });
    });
}

- (void)refreshToken:(nullable XZAuthenticationCompletionBlock)completion {
    // 这里应该调用服务器API刷新token
    // 暂时留空，根据实际API实现
    if (completion) {
        completion(NO, @"暂未实现");
    }
}

- (void)syncLoginStateToWebView:(WKWebView *)webView completion:(nullable void(^)(void))completion {
    if (!webView || !self.isLoggedIn || !self.currentUser) {
        if (completion) completion();
        return;
    }
    
    // 构造JavaScript代码，设置登录状态
    NSString *jsCode = [NSString stringWithFormat:@"\
        (function() {\
            try {\
                // 设置用户信息到app.session\
                if (typeof app !== 'undefined' && app.session && app.session.set) {\
                    app.session.set('userSession', '%@');\
                    app.session.set('userId', '%@');\
                    app.session.set('nickname', '%@');\
                    app.session.set('token', '%@');\
                }\
                // 设置到localStorage\
                if (typeof localStorage !== 'undefined') {\
                    localStorage.setItem('userSession', '%@');\
                    localStorage.setItem('userId', '%@');\
                    localStorage.setItem('token', '%@');\
                }\
                // 触发登录状态变化事件\
                if (typeof window !== 'undefined') {\
                    var event = new CustomEvent('loginStateChanged', { detail: { isLoggedIn: true } });\
                    window.dispatchEvent(event);\
                }\
                return 'success';\
            } catch(e) {\
                return 'error: ' + e.message;\
            }\
        })()",
        self.currentUser.userId ?: @"",
        self.currentUser.userId ?: @"",
        self.currentUser.nickname ?: @"",
        self.currentUser.token ?: @"",
        self.currentUser.userId ?: @"",
        self.currentUser.userId ?: @"",
        self.currentUser.token ?: @""
    ];
    
    [webView evaluateJavaScript:jsCode completionHandler:^(id result, NSError *error) {
        if (error) {
        } else {
        }
        if (completion) completion();
    }];
}

- (void)syncLoginStateFromWebView:(WKWebView *)webView completion:(nullable void(^)(void))completion {
    if (!webView) {
        if (completion) completion();
        return;
    }
    
    // 从WebView获取登录状态
    NSString *jsCode = @"\
        (function() {\
            try {\
                var userSession = null;\
                // 从app.session获取\
                if (typeof app !== 'undefined' && app.session && app.session.get) {\
                    userSession = app.session.get('userSession');\
                }\
                // 如果没有，从localStorage获取\
                if (!userSession && typeof localStorage !== 'undefined') {\
                    userSession = localStorage.getItem('userSession');\
                }\
                return userSession || '';\
            } catch(e) {\
                return '';\
            }\
        })()";
    
    [webView evaluateJavaScript:jsCode completionHandler:^(id result, NSError *error) {
        if (error || !result || ![result isKindOfClass:[NSString class]] || [(NSString *)result length] == 0) {
            // WebView中没有登录状态
            if (self.isLoggedIn) {
                // Native已登录但WebView未登录，执行退出登录
                [self logoutWithCompletion:nil];
            }
        } else {
            // WebView中有登录状态
            if (!self.isLoggedIn) {
                // Native未登录但WebView已登录，需要同步
                // 这里应该解析userSession获取完整用户信息
            }
        }
        
        if (completion) completion();
    }];
}

#pragma mark - Private Methods

- (void)saveUserInfoToLocal {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    // 保存登录状态
    [defaults setBool:self.isLoggedIn forKey:kUserLoginStateKey];
    
    if (self.currentUser) {
        // 归档用户信息
        NSData *userData = [NSKeyedArchiver archivedDataWithRootObject:self.currentUser];
        [defaults setObject:userData forKey:kUserInfoKey];
        
        // 保存常用字段到独立的key（为了兼容旧代码）
        [defaults setObject:self.currentUser.token ?: @"" forKey:kUserTokenKey];
        [defaults setObject:self.currentUser.userId ?: @"" forKey:kUserIdKey];
        [defaults setObject:self.currentUser.nickname ?: @"" forKey:kUserNameKey];
        [defaults setObject:self.currentUser.phone ?: @"" forKey:kUserPhoneKey];
        [defaults setObject:self.currentUser.headpic ?: @"" forKey:kUserAvatarKey];
    }
    
    [defaults synchronize];
}

- (void)loadUserInfoFromLocal {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    // 读取登录状态
    self.isLoggedIn = [defaults boolForKey:kUserLoginStateKey];
    
    if (self.isLoggedIn) {
        // 尝试解档用户信息
        NSData *userData = [defaults objectForKey:kUserInfoKey];
        if (userData) {
            @try {
                self.currentUser = [NSKeyedUnarchiver unarchiveObjectWithData:userData];
            } @catch (NSException *exception) {
                
                // 从独立的key读取
                XZUserInfo *userInfo = [[XZUserInfo alloc] init];
                userInfo.token = [defaults objectForKey:kUserTokenKey];
                userInfo.userId = [defaults objectForKey:kUserIdKey];
                userInfo.nickname = [defaults objectForKey:kUserNameKey];
                userInfo.phone = [defaults objectForKey:kUserPhoneKey];
                userInfo.headpic = [defaults objectForKey:kUserAvatarKey];
                
                if (userInfo.userId.length > 0) {
                    self.currentUser = userInfo;
                } else {
                    self.isLoggedIn = NO;
                }
            }
        }
    }
    
}

- (void)clearAllAuthenticationInfo {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    // 清除所有相关的key
    [defaults removeObjectForKey:kUserLoginStateKey];
    [defaults removeObjectForKey:kUserInfoKey];
    [defaults removeObjectForKey:kUserTokenKey];
    [defaults removeObjectForKey:kUserIdKey];
    [defaults removeObjectForKey:kUserNameKey];
    [defaults removeObjectForKey:kUserPhoneKey];
    [defaults removeObjectForKey:kUserAvatarKey];
    
    // 清除消息和购物车数量
    [defaults setInteger:0 forKey:@"clinetMessageNum"];
    [defaults setInteger:0 forKey:@"shoppingCartNum"];
    
    [defaults synchronize];
}

@end