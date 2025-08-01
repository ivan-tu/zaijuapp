//
//  WKWebView+XZAddition.m
//  XZVientiane
//
//  Created by System on 2024/12/19.
//  Copyright © 2024年 TuWeiA. All rights reserved.
//

#import "WKWebView+XZAddition.h"
#import "XZBaseHead.h"
#import "NSString+addition.h"
#import "PublicSettingModel.h"
#import <objc/runtime.h>

#define User_Cookie   @"User_Cookie"

@implementation WKWebView (XZAddition)

#pragma mark - JavaScript Bridge Methods

+ (NSDictionary *)objcCallJsWithFn:(NSString *)function data:(id)data {
    // 确保所有值都不为nil，避免字典创建失败
    NSString *safeFunction = function ?: @"";
    id safeData = data ?: [NSNull null];
    NSString *callback = @"";
    
    NSDictionary *dic = @{
        @"action": safeFunction,
        @"data": safeData,
        @"callback": callback
    };
    return dic;
}

+ (NSDictionary *)objcCallJsLoadPageParamWithHtml:(NSString *)html url:(NSString *)url requestData:(id)data {
    
    // 确保URL不为nil
    if (!url) {
        url = @"";
    }
    
    url = [url stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    NSRange range = [url rangeOfString:@"://"];
    if(range.length <= 0)
    {
        url = [NSString stringWithFormat:@"http://%@%@",MainDomain,url];
    }
    
    NSMutableArray *cookieAry = [NSMutableArray array];
    
    // 如果在主线程，跳过Cookie获取，避免阻塞
    if ([NSThread isMainThread]) {
        // 使用缓存的Cookie或空数组
        NSData *cachedCookieData = [[NSUserDefaults standardUserDefaults] objectForKey:@"CachedCookieArray"];
        if (cachedCookieData) {
            NSArray *cachedCookies = [NSKeyedUnarchiver unarchiveObjectWithData:cachedCookieData];
            if (cachedCookies) {
                cookieAry = [cachedCookies mutableCopy];
            }
        }
    } else {
        // 非主线程，可以执行同步获取（但仍然不推荐）
        if (@available(iOS 11.0, *)) {
            dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
            
            WKHTTPCookieStore *cookieStore = [[WKWebsiteDataStore defaultDataStore] httpCookieStore];
            [cookieStore getAllCookies:^(NSArray<NSHTTPCookie *> *cookies) {
                for (NSHTTPCookie *cookie in cookies) {
                    NSString *name = cookie.name ?: @"";
                    NSString *value = cookie.value ?: @"";
                    NSDictionary *cookieDic = @{
                        @"name" : name,
                        @"value" : value,
                    };
                    [cookieAry addObject:cookieDic];
                }
                dispatch_semaphore_signal(semaphore);
            }];
            
            // 设置超时时间，避免无限等待
            dispatch_time_t timeout = dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC); // 减少到1秒
            dispatch_semaphore_wait(semaphore, timeout);
        } else {
            // 降级到NSHTTPCookieStorage
            NSArray *storageCookieAry = [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookiesForURL:[NSURL URLWithString:url]];
            for (NSHTTPCookie *cookie in storageCookieAry) {
                NSString *name = cookie.name ?: @"";
                NSString *value = cookie.value ?: @"";
                NSDictionary *cookieDic = @{
                    @"name" : name,
                    @"value" : value,
                };
                [cookieAry addObject:cookieDic];
            }
        }
    }
    
    // 确保requestData不为nil
    id safeRequestData = data ?: [NSNull null];
    
    NSDictionary *paramDic = @{
        @"url" : url,
        @"cookie" : cookieAry,
        @"vs" : @(3),
        @"requestData" : safeRequestData
    };
    return [WKWebView objcCallJsWithFn:@"loadPage" data:paramDic];
}

#pragma mark - Cookie Management

+ (void)saveCookiesToUserDefaults {
    if (@available(iOS 11.0, *)) {
        WKHTTPCookieStore *cookieStore = [WKWebsiteDataStore defaultDataStore].httpCookieStore;
        [cookieStore getAllCookies:^(NSArray<NSHTTPCookie *> *cookies) {
            NSData *cookiesData = [NSKeyedArchiver archivedDataWithRootObject:cookies requiringSecureCoding:NO error:nil];
            NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
            [defaults setObject:cookiesData forKey:User_Cookie];
            [defaults synchronize];
        }];
    } else {
        // 降级到NSHTTPCookieStorage
        NSData *cookiesData = [NSKeyedArchiver archivedDataWithRootObject:[[NSHTTPCookieStorage sharedHTTPCookieStorage] cookies]];
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults setObject:cookiesData forKey:User_Cookie];
        [defaults synchronize];
    }
}

+ (void)loadCookies {
    NSData *cookiesData = [[NSUserDefaults standardUserDefaults] objectForKey:User_Cookie];
    if (!cookiesData) return;
    
    NSArray *cookies = [NSKeyedUnarchiver unarchiveObjectWithData:cookiesData];
    if (!cookies) return;
    
    if (@available(iOS 11.0, *)) {
        WKHTTPCookieStore *cookieStore = [WKWebsiteDataStore defaultDataStore].httpCookieStore;
        for (NSHTTPCookie *cookie in cookies) {
            [cookieStore setCookie:cookie completionHandler:nil];
        }
    } else {
        // 降级到NSHTTPCookieStorage
        NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
        for (NSHTTPCookie *cookie in cookies) {
            [cookieStorage setCookie:cookie];
        }
    }
}

+ (void)clearAllCookies {
    if (@available(iOS 11.0, *)) {
        WKHTTPCookieStore *cookieStore = [WKWebsiteDataStore defaultDataStore].httpCookieStore;
        [cookieStore getAllCookies:^(NSArray<NSHTTPCookie *> *cookies) {
            for (NSHTTPCookie *cookie in cookies) {
                [cookieStore deleteCookie:cookie completionHandler:nil];
            }
        }];
    } else {
        // 降级到NSHTTPCookieStorage
        NSArray *cookies = [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookies];
        for (NSHTTPCookie *cookie in cookies) {
            [[NSHTTPCookieStorage sharedHTTPCookieStorage] deleteCookie:cookie];
        }
    }
}

+ (void)cookieDeleteAllCookie {
    [self clearAllCookies];
}

+ (void)cookieDeleteCookieWithDomain:(NSString *)domain name:(NSString *)cookieName path:(NSString *)path {
    if (!cookieName) return;
    
    if (@available(iOS 11.0, *)) {
        WKHTTPCookieStore *cookieStore = [WKWebsiteDataStore defaultDataStore].httpCookieStore;
        [cookieStore getAllCookies:^(NSArray<NSHTTPCookie *> *cookies) {
            for (NSHTTPCookie *cookie in cookies) {
                if ([cookie.name isEqualToString:cookieName] && 
                    (!domain || [cookie.domain isEqualToString:domain]) &&
                    (!path || [cookie.path isEqualToString:path])) {
                    [cookieStore deleteCookie:cookie completionHandler:nil];
                }
            }
        }];
    } else {
        // 降级到NSHTTPCookieStorage
        NSArray *cookies;
        if (domain) {
            cookies = [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookiesForURL:[NSURL URLWithString:domain]];
        } else {
            cookies = [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookies];
        }
        
        for (NSHTTPCookie *cookie in cookies) {
            if ([cookie.name isEqualToString:cookieName] && 
                (!path || [cookie.path isEqualToString:path])) {
                [[NSHTTPCookieStorage sharedHTTPCookieStorage] deleteCookie:cookie];
            }
        }
    }
    
    // 保持原有的特殊逻辑
    if ([cookieName isEqualToString:@"loginUid"]) {
        [[NSUserDefaults standardUserDefaults] setObject:@"" forKey:@"loginUid"];
        [[NSUserDefaults standardUserDefaults] setObject:@"" forKey:@"userName"];
        [[NSUserDefaults standardUserDefaults] setObject:@"" forKey:@"userPhone"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}

+ (void)setCookie:(NSString *)aDomain name:(NSString *)aName value:(NSString *)aValue expires:(NSDate *)expires path:(NSString *)path
{
    if (!aName) {
        return;
    }
    
    if (!aValue) {
        // 删除Cookie
        [WKWebView cookieDeleteCookieWithDomain:aDomain name:aName path:path];
        return;
    }
    
    NSMutableDictionary *cookieProperties = [NSMutableDictionary dictionary];
    cookieProperties[NSHTTPCookieDomain] = aDomain;
    cookieProperties[NSHTTPCookieName] = aName;
    
    // 有的cookie值是数字型的，需要转换一下
    if ([aValue isKindOfClass:[NSNumber class]]) {
        aValue = [(NSNumber *)aValue stringValue];
    }
    
    if ([[NSUserDefaults standardUserDefaults] objectForKey:@"UserDefault_IsClient"]) {
        cookieProperties[NSHTTPCookieValue] = [NSString encodeString:aValue];
    } else {
        cookieProperties[NSHTTPCookieValue] = [aValue stringByRemovingPercentEncoding];
    }
    
    cookieProperties[NSHTTPCookiePath] = path;
    cookieProperties[NSHTTPCookieVersion] = @"0";
    cookieProperties[NSHTTPCookieExpires] = expires;
    
    NSHTTPCookie *cookie = [NSHTTPCookie cookieWithProperties:cookieProperties];
    
    if (@available(iOS 11.0, *)) {
        WKHTTPCookieStore *cookieStore = [WKWebsiteDataStore defaultDataStore].httpCookieStore;
        [cookieStore setCookie:cookie completionHandler:nil];
    } else {
        // 降级到NSHTTPCookieStorage
        [[NSHTTPCookieStorage sharedHTTPCookieStorage] setCookie:cookie];
    }
}

+ (void)cookieJSOperateCookie:(NSDictionary *)cookieDic path:(NSString *)aPath {
    NSString *name = [cookieDic objectForKey:@"name"];
    NSString *value = [cookieDic objectForKey:@"value"];
    NSDictionary *optionDic = [cookieDic objectForKey:@"options"];
    if (!optionDic) {
        return;
    }
    NSNumber *expires = [optionDic objectForKey:@"expires"];
    NSString *domain = [optionDic objectForKey:@"domain"];
    NSString *path = [optionDic objectForKey:@"path"];
    if (optionDic.count <= 0) {
        NSArray *httpAry = [aPath componentsSeparatedByString:@"://"];
        NSString *httpPath = httpAry.count > 1 ? httpAry[1] : httpAry[0];
        domain = httpAry.count > 1 ? [httpPath componentsSeparatedByString:@"/"][0] : [NSString stringWithFormat:@".%@",MainDomain];
        path = httpAry.count > 1 ? [httpPath stringByReplacingOccurrencesOfString:domain withString:@""] : httpAry[0];
    }
    if (!domain) {
        NSURL *pathUrl = [NSURL URLWithString:aPath];
        domain = pathUrl.host;
    }
    if (!domain) {
        domain = [NSString stringWithFormat:@".%@",MainDomain];
    }
    if (!path) {
        path = @"/";
    }
    
    if ((expires.integerValue <= 0 && expires) || !value || [value isKindOfClass:[NSNull class]]) {
        //删除cookie
        [WKWebView cookieDeleteCookieWithDomain:domain name:name path:path];
    }
    else {
        //存储cookie
        if (!expires) {
            expires = @(10000);
        }
        
        [WKWebView setCookie:domain name:name value:value expires:[NSDate dateWithTimeIntervalSinceNow:expires.integerValue * 60 * 60 * 24] path:path];
    }
}

#pragma mark - JavaScript Execution

- (void)safeEvaluateJavaScript:(NSString *)script completion:(void (^)(id _Nullable, NSError * _Nullable))completion {
    if (!script || script.length == 0) {
        if (completion) {
            NSError *error = [NSError errorWithDomain:@"WKWebViewAddition" 
                                                 code:-1 
                                             userInfo:@{NSLocalizedDescriptionKey: @"JavaScript script is empty"}];
            completion(nil, error);
        }
        return;
    }
    
    // 确保在主线程执行
    if ([NSThread isMainThread]) {
        [self evaluateJavaScript:script completionHandler:completion];
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self evaluateJavaScript:script completionHandler:completion];
        });
    }
}

#pragma mark - User Agent


#pragma mark - Utility Methods

+ (NSString *)jsonStringFromObject:(id)object {
    if (!object) return @"null";
    
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:object 
                                                       options:NSJSONWritingPrettyPrinted 
                                                         error:&error];
    if (error) {
        return @"{}";
    }
    
    return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
}

+ (id)objectFromJSONString:(NSString *)jsonString {
    if (!jsonString || jsonString.length == 0) return nil;
    
    NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    NSError *error;
    id object = [NSJSONSerialization JSONObjectWithData:jsonData 
                                                options:NSJSONReadingMutableContainers 
                                                  error:&error];
    if (error) {
        return nil;
    }
    
    return object;
}

#pragma mark - 异步Cookie获取（推荐使用）

+ (void)getCookiesAsyncWithCompletion:(void(^)(NSArray *cookies))completion {
    
    if (@available(iOS 11.0, *)) {
        WKHTTPCookieStore *cookieStore = [[WKWebsiteDataStore defaultDataStore] httpCookieStore];
        [cookieStore getAllCookies:^(NSArray<NSHTTPCookie *> *cookies) {
            NSMutableArray *cookieAry = [NSMutableArray array];
            for (NSHTTPCookie *cookie in cookies) {
                NSDictionary *cookieDic = @{
                    @"name": cookie.name ?: @"",
                    @"value": cookie.value ?: @""
                };
                [cookieAry addObject:cookieDic];
            }
            
            // 缓存Cookie以供紧急使用
            NSData *cookieData = [NSKeyedArchiver archivedDataWithRootObject:cookieAry requiringSecureCoding:NO error:nil];
            [[NSUserDefaults standardUserDefaults] setObject:cookieData forKey:@"CachedCookieArray"];
            [[NSUserDefaults standardUserDefaults] synchronize];
            
            if (completion) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(cookieAry);
                });
            }
        }];
    } else {
        // iOS 11以下版本
        NSMutableArray *cookieAry = [NSMutableArray array];
        NSArray *cookies = [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookies];
        for (NSHTTPCookie *cookie in cookies) {
            NSDictionary *cookieDic = @{
                @"name": cookie.name ?: @"",
                @"value": cookie.value ?: @""
            };
            [cookieAry addObject:cookieDic];
        }
        if (completion) {
            completion(cookieAry);
        }
    }
}

+ (void)prepareLoadPageParamsAsyncWithHtml:(NSString *)html 
                                        url:(NSString *)url 
                                requestData:(id)data
                                 completion:(void(^)(NSDictionary *params))completion {
    
    // 确保URL不为nil
    if (!url) {
        url = @"";
    }
    
    url = [url stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    NSRange range = [url rangeOfString:@"://"];
    if(range.length <= 0) {
        url = [NSString stringWithFormat:@"http://%@%@",MainDomain,url];
    }
    
    // 异步获取Cookie
    [self getCookiesAsyncWithCompletion:^(NSArray *cookies) {
        id safeRequestData = data ?: [NSNull null];
        
        NSDictionary *paramDic = @{
            @"url" : url,
            @"cookie" : cookies ?: @[],
            @"requestData" : safeRequestData,
            @"html" : html ?: @""
        };
        
        NSDictionary *dic = @{
            @"fn": @"loadPage",
            @"data": paramDic,
        };
        
        if (completion) {
            completion(dic);
        }
    }];
}

@end 
