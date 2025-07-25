//
//  WKWebView+XZAddition.h
//  XZVientiane
//
//  Created by System on 2024/12/19.
//  Copyright © 2024年 TuWeiA. All rights reserved.
//

#import <WebKit/WebKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKWebView (XZAddition)

/**
 * 调用JavaScript方法的统一接口
 * @param function 要调用的JavaScript函数名
 * @param data 传递给JavaScript的数据
 * @return 返回调用所需的参数字典
 */
+ (NSDictionary *)objcCallJsWithFn:(NSString *)function data:(nullable id)data;

/**
 * 调用JavaScript loadPage方法的参数组装
 * @deprecated 此方法使用同步Cookie获取，会阻塞主线程。请使用 prepareLoadPageParamsAsyncWithHtml:url:requestData:completion: 替代
 * @param html 要加载的HTML代码
 * @param url 当前网址
 * @param data 请求数据
 * @return 调用loadPage所需的参数字典
 */
+ (NSDictionary *)objcCallJsLoadPageParamWithHtml:(NSString *)html 
                                               url:(NSString *)url 
                                       requestData:(nullable id)data __attribute__((deprecated("使用prepareLoadPageParamsAsyncWithHtml:url:requestData:completion:替代")));

/**
 * 持久化Cookie到UserDefaults
 */
+ (void)saveCookiesToUserDefaults;

/**
 * 从UserDefaults加载Cookie
 */
+ (void)loadCookies;

/**
 * 清除所有Cookie
 */
+ (void)clearAllCookies;

/**
 * 删除本应用所有cookie
 */
+ (void)cookieDeleteAllCookie;

/**
 * 删除指定Cookie
 * @param domain Cookie域名
 * @param cookieName Cookie名称
 * @param path Cookie路径
 */
+ (void)cookieDeleteCookieWithDomain:(NSString *)domain name:(NSString *)cookieName path:(NSString *)path;

/**
 * 设置Cookie
 * @param aDomain Cookie域名
 * @param aName Cookie名称
 * @param aValue Cookie值
 * @param expires 过期时间
 * @param path Cookie路径
 */
+ (void)setCookie:(NSString *)aDomain name:(NSString *)aName value:(NSString *)aValue expires:(NSDate *)expires path:(NSString *)path;

/**
 * 通过JavaScript操作Cookie
 * @param cookieDic Cookie信息字典
 * @param path Cookie路径
 */
+ (void)cookieJSOperateCookie:(NSDictionary *)cookieDic path:(NSString *)path;

/**
 * 异步执行JavaScript代码
 * @param script JavaScript代码
 * @param completion 完成回调
 */
- (void)safeEvaluateJavaScript:(NSString *)script completion:(nullable void (^)(id _Nullable result, NSError * _Nullable error))completion;

/**
 * 设置User-Agent
 * @param userAgent 自定义User-Agent字符串
 */
- (void)setCustomUserAgent:(NSString *)userAgent;

#pragma mark - 异步Cookie处理（推荐使用）

/**
 * 异步获取所有Cookie
 * @param completion 完成回调，返回Cookie数组
 */
+ (void)getCookiesAsyncWithCompletion:(void(^)(NSArray *cookies))completion;

/**
 * 异步准备加载页面参数
 * @param html HTML内容
 * @param url 请求URL
 * @param data 请求数据
 * @param completion 完成回调，返回参数字典
 */
+ (void)prepareLoadPageParamsAsyncWithHtml:(NSString *)html 
                                        url:(NSString *)url 
                                requestData:(nullable id)data
                                 completion:(void(^)(NSDictionary *params))completion;

@end

NS_ASSUME_NONNULL_END 