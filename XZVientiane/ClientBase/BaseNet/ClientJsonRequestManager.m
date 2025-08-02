//
//  AFAppManagerAPIClient.m
//  TuWeiAApp
//
//  Created by tuweia on 15/12/21.
//  Copyright © 2015年 hans. All rights reserved.
//

#import "ClientJsonRequestManager.h"
#import "ClientSettingModel.h"
#import "QNUploadManager.h"
#import "CLFileManager.h"
#import "EGOCache.h"
#import "NSString+addition.h"
@implementation ClientJsonRequestManager

// 在局Claude Code[缓存键生成]+安全的缓存键生成方法，支持数组和字典参数
- (NSString *)safeCacheKeyWithParameters:(id)parameters andURL:(NSString *)URLString {
    if ([parameters isKindOfClass:[NSDictionary class]]) {
        return [NSString urlWithParam:parameters andHead:URLString];
    } else {
        // 对于数组参数或其他类型，使用JSON字符串
        NSString *parametersString = @"";
        if (parameters) {
            NSError *error = nil;
            NSData *jsonData = [NSJSONSerialization dataWithJSONObject:parameters options:0 error:&error];
            if (!error && jsonData) {
                parametersString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
                // 清理缓存键中的特殊字符
                parametersString = [parametersString stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
                parametersString = [parametersString stringByReplacingOccurrencesOfString:@":" withString:@"_"];
                parametersString = [parametersString stringByReplacingOccurrencesOfString:@"." withString:@"_"];
                parametersString = [parametersString stringByReplacingOccurrencesOfString:@"-" withString:@"_"];
                parametersString = [parametersString stringByReplacingOccurrencesOfString:@" " withString:@""];
                parametersString = [parametersString stringByReplacingOccurrencesOfString:@"\n" withString:@""];
            }
        }
        NSString *cacheKey = [NSString stringWithFormat:@"%@_%@", URLString, parametersString];
        cacheKey = [cacheKey stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
        return cacheKey;
    }
}

+ (instancetype)sharedClient {
    static ClientJsonRequestManager *_sharedClient = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *domain = [[ClientSettingModel sharedInstance] domain];
        
        NSURL *url = [NSURL URLWithString:domain];
        
        // iOS 18修复：创建自定义的URLSessionConfiguration
        NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
        
        // 设置允许使用蜂窝数据
        configuration.allowsCellularAccess = YES;
        
        // 设置网络服务类型
        configuration.networkServiceType = NSURLNetworkServiceTypeDefault;
        
        // 设置超时时间
        configuration.timeoutIntervalForRequest = 45.0;
        configuration.timeoutIntervalForResource = 60.0;
        
        // 设置请求缓存策略
        configuration.requestCachePolicy = NSURLRequestUseProtocolCachePolicy;
        
        // iOS 18修复：确保允许约束网络路径
        if (@available(iOS 13.0, *)) {
            configuration.allowsConstrainedNetworkAccess = YES;
            configuration.allowsExpensiveNetworkAccess = YES;
        }
        
        // 使用自定义配置创建管理器
        _sharedClient = [[ClientJsonRequestManager alloc] initWithBaseURL:url sessionConfiguration:configuration];
        
        _sharedClient.responseSerializer = [AFJSONResponseSerializer serializer];
        _sharedClient.requestSerializer = [AFHTTPRequestSerializer serializer];
        _sharedClient.responseSerializer.acceptableContentTypes = [NSSet setWithObjects:@"application/json", @"text/plain", @"text/javascript", @"text/json", @"text/html", nil];
        
        if(ISIPAD) {
            [_sharedClient.requestSerializer setValue:@"iospad" forHTTPHeaderField:@"from"];
        } else {
            [_sharedClient.requestSerializer setValue:@"ios" forHTTPHeaderField:@"from"];
        }
        
        // 设置安全策略
        _sharedClient.securityPolicy = [AFSecurityPolicy policyWithPinningMode:AFSSLPinningModeNone];
        _sharedClient.securityPolicy.allowInvalidCertificates = NO;
        _sharedClient.securityPolicy.validatesDomainName = YES;
        
    });
    return _sharedClient;
}

- (BOOL)cachedDataWithKey:(NSString *)key block:(ClientCompletionBlock)block {
    // 使用共享的网络监控器，确保已经启动
    AFNetworkReachabilityManager *reachabilityManager = [AFNetworkReachabilityManager sharedManager];
    if (!reachabilityManager.isReachable && reachabilityManager.networkReachabilityStatus == AFNetworkReachabilityStatusUnknown) {
        // 如果还未初始化，启动监控
        [reachabilityManager startMonitoring];
    }
    
    AFNetworkReachabilityStatus status = reachabilityManager.networkReachabilityStatus;
    
    // iOS 18特殊处理：即使状态未知也尝试请求
    if (status == AFNetworkReachabilityStatusNotReachable) {
        if (![[EGOCache globalCache] hasCacheForKey:key]) {
            return NO;
        }
        NSDictionary *cachedDic = (NSDictionary *)[[EGOCache globalCache] objectForKey:key];
        if (block) {
            block(cachedDic,nil);
        }
        return YES;
    }
    return NO;
}
- (void)GET:(NSString *)URLString parameters:(id)parameters block:(ClientCompletionBlock)block {
    NSString *cacheKey = [self safeCacheKeyWithParameters:parameters andURL:URLString];
    
    if ([self cachedDataWithKey:cacheKey block:block]) {
        return;
    }
    
    [self checkAppToken];
    
    // 调用带headers参数的GET方法
    [self GET:URLString parameters:parameters headers:nil block:block];
}

- (void)GET:(NSString *)URLString parameters:(id)parameters headers:(NSDictionary *)headers block:(ClientCompletionBlock)block {
    if ([self cachedDataWithKey:[self safeCacheKeyWithParameters:parameters andURL:URLString] block:block]) {
        return;
    }
    [self checkAppToken];
    
    
    // 手动构建带参数的URL
    NSString *finalURLString = URLString;
    if (parameters && [parameters isKindOfClass:[NSDictionary class]] && [(NSDictionary *)parameters count] > 0) {
        NSError *error;
        NSURLRequest *request = [[AFHTTPRequestSerializer serializer] requestWithMethod:@"GET" 
                                                                              URLString:[[NSURL URLWithString:URLString relativeToURL:self.baseURL] absoluteString]
                                                                             parameters:parameters 
                                                                                  error:&error];
        if (!error && request.URL) {
            // 从完整URL中提取相对路径和查询字符串
            NSString *fullURL = request.URL.absoluteString;
            NSString *baseURLString = self.baseURL.absoluteString;
            if ([fullURL hasPrefix:baseURLString]) {
                finalURLString = [fullURL substringFromIndex:baseURLString.length];
            }
        } else {
            NSLog(@"GET请求构建URL失败: %@", error);
        }
    }
    
    
    [super GET:finalURLString parameters:nil headers:headers progress:nil success:^(NSURLSessionDataTask *task, id responseObject) {
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)task.response;
        
        
        if (!responseObject || ![responseObject isKindOfClass:[NSDictionary class]]) {
            NSLog(@"GET响应数据格式错误，类型: %@", NSStringFromClass([responseObject class]));
            if (block) {
                block(nil, [NSError errorWithDomain:@"没有返回数据或数据格式错误" code:10000 userInfo:nil]);
            }
            return ;
        }
        NSNumber *codenumber = [responseObject objectForKey:@"code"];
        NSAssert(codenumber.integerValue == 0, @"请求失败");
        [[EGOCache globalCache] setObject:responseObject forKey:[self safeCacheKeyWithParameters:parameters andURL:URLString]];
        if (block) {
            block(responseObject, nil);
        }
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)task.response;
        NSLog(@"GET请求失败: %@, HTTP状态码: %ld, 错误: %@", URLString, (long)httpResponse.statusCode, error.localizedDescription);
        
        // iOS 18修复：检查是否是网络权限问题
        if (error.code == -1009 && [error.domain isEqualToString:NSURLErrorDomain]) {
            NSDictionary *userInfo = error.userInfo;
            if (userInfo[@"_NSURLErrorNWPathKey"]) {
                NSLog(@"检测到iOS 18网络权限问题，可能需要用户在设置中授权");
                // 发送通知给UI层处理
                [[NSNotificationCenter defaultCenter] postNotificationName:@"NetworkPermissionDenied" object:nil userInfo:@{@"error": error}];
            }
        }
        
        if(block){
            block (nil,error);
        }
    }];
}

- (void)POST:(NSString *)URLString parameters:(id)parameters headers:(NSDictionary *)headers block:(ClientCompletionBlock)block {
    if ([self cachedDataWithKey:[self safeCacheKeyWithParameters:parameters andURL:URLString] block:block]) {
        return;
    }
    [self checkAppToken];
    
    // 在局Claude Code[请求跟踪]+记录请求详情
    NSLog(@"在局Claude Code[POST请求]+URL: %@", URLString);
    NSLog(@"在局Claude Code[POST参数类型]+%@", NSStringFromClass([parameters class]));
    if ([parameters isKindOfClass:[NSArray class]]) {
        NSLog(@"在局Claude Code[POST数组参数]+参数内容: %@", parameters);
    } else if ([parameters isKindOfClass:[NSDictionary class]]) {
        NSLog(@"在局Claude Code[POST字典参数]+参数内容: %@", parameters);
    }
    
    // 设置请求序列化器为JSON格式
    AFJSONRequestSerializer *jsonSerializer = [AFJSONRequestSerializer serializer];
    self.requestSerializer = jsonSerializer;
    
    // 设置请求头
    if (headers) {
        for (NSString *key in headers) {
            [self.requestSerializer setValue:headers[key] forHTTPHeaderField:key];
        }
        NSLog(@"在局Claude Code[POST请求头]+Headers: %@", headers);
    }
    
    
    [super POST:URLString parameters:parameters headers:nil progress:nil success:^(NSURLSessionDataTask *task, id responseObject) {
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)task.response;
        
        // 在局Claude Code[响应跟踪]+记录响应状态
        NSLog(@"在局Claude Code[POST响应]+URL: %@, HTTP状态码: %ld", URLString, (long)httpResponse.statusCode);
        NSLog(@"在局Claude Code[POST响应数据]+%@", responseObject);
        
        if (!responseObject || ![responseObject isKindOfClass:[NSDictionary class]]) {
            NSLog(@"在局Claude Code[POST响应错误]+数据格式错误，类型: %@", NSStringFromClass([responseObject class]));
            if (block) {
                block(nil, [NSError errorWithDomain:@"没有返回数据或数据格式错误" code:10000 userInfo:nil]);
            }
            return ;
        }
        NSNumber *codenumber = [responseObject objectForKey:@"code"];
        if (codenumber.integerValue != 0) {
            NSLog(@"在局Claude Code[业务错误]+code: %@, errorMessage: %@", codenumber, [responseObject objectForKey:@"errorMessage"]);
        }
        NSAssert(codenumber.integerValue == 0, @"请求失败");
        
        // 在局Claude Code[修复缓存键生成]+使用统一的缓存键生成方法
        [[EGOCache globalCache] setObject:responseObject forKey:[self safeCacheKeyWithParameters:parameters andURL:URLString]];
        
        // 恢复默认的请求序列化器
        self.requestSerializer = [AFHTTPRequestSerializer serializer];
        
        if (block) {
            block(responseObject, nil);
        }
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)task.response;
        NSLog(@"在局Claude Code[POST请求失败]+URL: %@, HTTP状态码: %ld", URLString, (long)httpResponse.statusCode);
        NSLog(@"在局Claude Code[POST错误详情]+错误域: %@, 错误码: %ld, 描述: %@", error.domain, (long)error.code, error.localizedDescription);
        NSLog(@"在局Claude Code[POST请求参数]+失败时的参数: %@", parameters);
        
        // iOS 18修复：检查是否是网络权限问题
        if (error.code == -1009 && [error.domain isEqualToString:NSURLErrorDomain]) {
            NSDictionary *userInfo = error.userInfo;
            if (userInfo[@"_NSURLErrorNWPathKey"]) {
                NSLog(@"检测到iOS 18网络权限问题，可能需要用户在设置中授权");
                // 发送通知给UI层处理
                [[NSNotificationCenter defaultCenter] postNotificationName:@"NetworkPermissionDenied" object:nil userInfo:@{@"error": error}];
            }
        }
        
        // 恢复默认的请求序列化器
        self.requestSerializer = [AFHTTPRequestSerializer serializer];
        
        if(block){
            block (nil,error);
        }
    }];
}

- (void)POSTRPC:(NSString *)URLString parameters:(id)parameters block:(ClientCompletionBlock)block
{
    NSString *cacheKey = [self safeCacheKeyWithParameters:parameters andURL:URLString];
    
    if ([self cachedDataWithKey:cacheKey block:block]) {
        return;
    }
    
    [self checkAppToken];
    NSString *dataJsonStr = @"";
    if (parameters) {
        NSError *jsonError = nil;
        NSData *data = [NSJSONSerialization dataWithJSONObject:parameters
                                                       options:NSJSONWritingPrettyPrinted error:&jsonError];
        if (jsonError) {
            NSLog(@"POSTRPC JSON序列化失败: %@", jsonError);
        }
        dataJsonStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    }
    NSString *loginWebsiteUid = [[NSUserDefaults standardUserDefaults] objectForKey:@"loginUid"] ? [[NSUserDefaults standardUserDefaults] objectForKey:@"loginUid"] : @"";
    NSDictionary *paramDic = @{
        @"data" : dataJsonStr,
        @"userid" : loginWebsiteUid,
        @"userToken" : @""
    };
    [self POST:URLString parameters:paramDic headers:nil progress:nil success:^(NSURLSessionDataTask *task, id responseObject) {
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)task.response;
        
        //没有返回数据或者返回数据格式有误
        if (!responseObject || ![responseObject isKindOfClass:[NSDictionary class]]) {
            NSLog(@"POSTRPC响应数据格式错误，类型: %@", NSStringFromClass([responseObject class]));
            if (block) {
                block(nil, [NSError errorWithDomain:@"没有返回数据或数据格式错误" code:10000 userInfo:nil]);
            }
            return ;
        }
        //返回错误码
        NSNumber *codenumber = [responseObject objectForKey:@"code"];
        //        NSString *erromessage = [responseObject objectForKey:@"errorMessage"];
        NSAssert(codenumber.integerValue == 0, @"请求失败");
        [[EGOCache globalCache] setObject:responseObject forKey:[self safeCacheKeyWithParameters:parameters andURL:URLString]];
        if (block) {
            block(responseObject, nil);
        }
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)task.response;
        NSLog(@"POSTRPC请求失败: %@, HTTP状态码: %ld, 错误: %@", URLString, (long)httpResponse.statusCode, error.localizedDescription);
        if(block){
            block (nil,error);
        }
    }];
}

- (void)POST:(NSString *)URLString parameters:(id)parameters block:(ClientCompletionBlock)block
{
    // 直接调用带headers参数的POST方法，避免重复处理
    [self POST:URLString parameters:parameters headers:nil block:block];
}

#pragma mark - CheckToken -
//检查appToken，如果过期，同步请求Token
- (void)checkAppToken {
    NSString *appTkn = [[NSUserDefaults standardUserDefaults] objectForKey:User_Token_String];
    [[ClientJsonRequestManager sharedClient].requestSerializer setValue:appTkn forHTTPHeaderField:@"AUTHORIZATION"];
    
    NSDate *expireDate = [[NSUserDefaults standardUserDefaults] objectForKey:@"User_Token_Expire_Time"];
    
    if ([expireDate compare:[NSDate date]] != NSOrderedDescending) {
        NSLog(@"Token已过期，开始刷新");
        // 获取原始的AppId和AppSecret
        NSString *appId = [ClientSettingModel sharedInstance].appId;
        NSString *appSecret = [ClientSettingModel sharedInstance].appSecret;
        
        
        // 使用GET请求方式，与原项目保持一致
        // 在局Claude Code[Token刷新修复]+完整URL编码处理所有特殊字符
        NSLog(@"在局Claude Code[Token刷新修复]+原始AppId: %@", appId);
        NSLog(@"在局Claude Code[Token刷新修复]+原始AppSecret: %@", appSecret);
        
        // 完整的URL编码函数，处理所有需要编码的字符
        NSString* (^urlEncode)(NSString*) = ^NSString*(NSString *string) {
            if (!string) return @"";
            
            NSString *encoded = string;
            // 按照RFC 3986标准进行URL编码
            encoded = [encoded stringByReplacingOccurrencesOfString:@"%" withString:@"%25"]; // 先处理%
            encoded = [encoded stringByReplacingOccurrencesOfString:@"$" withString:@"%24"];
            encoded = [encoded stringByReplacingOccurrencesOfString:@"&" withString:@"%26"];
            encoded = [encoded stringByReplacingOccurrencesOfString:@"+" withString:@"%2B"];
            encoded = [encoded stringByReplacingOccurrencesOfString:@"," withString:@"%2C"];
            encoded = [encoded stringByReplacingOccurrencesOfString:@"/" withString:@"%2F"];
            encoded = [encoded stringByReplacingOccurrencesOfString:@":" withString:@"%3A"];
            encoded = [encoded stringByReplacingOccurrencesOfString:@";" withString:@"%3B"];
            encoded = [encoded stringByReplacingOccurrencesOfString:@"=" withString:@"%3D"];
            encoded = [encoded stringByReplacingOccurrencesOfString:@"?" withString:@"%3F"];
            encoded = [encoded stringByReplacingOccurrencesOfString:@"@" withString:@"%40"];
            encoded = [encoded stringByReplacingOccurrencesOfString:@" " withString:@"%20"];
            encoded = [encoded stringByReplacingOccurrencesOfString:@"\"" withString:@"%22"];
            encoded = [encoded stringByReplacingOccurrencesOfString:@"<" withString:@"%3C"];
            encoded = [encoded stringByReplacingOccurrencesOfString:@">" withString:@"%3E"];
            encoded = [encoded stringByReplacingOccurrencesOfString:@"#" withString:@"%23"];
            encoded = [encoded stringByReplacingOccurrencesOfString:@"{" withString:@"%7B"];
            encoded = [encoded stringByReplacingOccurrencesOfString:@"}" withString:@"%7D"];
            encoded = [encoded stringByReplacingOccurrencesOfString:@"|" withString:@"%7C"];
            encoded = [encoded stringByReplacingOccurrencesOfString:@"\\" withString:@"%5C"];
            encoded = [encoded stringByReplacingOccurrencesOfString:@"^" withString:@"%5E"];
            encoded = [encoded stringByReplacingOccurrencesOfString:@"~" withString:@"%7E"];
            encoded = [encoded stringByReplacingOccurrencesOfString:@"[" withString:@"%5B"];
            encoded = [encoded stringByReplacingOccurrencesOfString:@"]" withString:@"%5D"];
            encoded = [encoded stringByReplacingOccurrencesOfString:@"`" withString:@"%60"];
            return encoded;
        };
        
        NSString *encodedAppId = urlEncode(appId);
        NSString *encodedAppSecret = urlEncode(appSecret);
        
        NSLog(@"在局Claude Code[Token刷新修复]+编码后AppId: %@", encodedAppId);
        NSLog(@"在局Claude Code[Token刷新修复]+编码后AppSecret: %@", encodedAppSecret);
        
        NSString *urlString = [NSString stringWithFormat:@"%@/oauth/getAccessToken?appId=%@&appSecret=%@", 
                                                         [ClientSettingModel sharedInstance].domain,
                                                         encodedAppId,
                                                         encodedAppSecret];
        
        NSLog(@"在局Claude Code[Token刷新修复]+刷新URL: %@", urlString);
        
        
        // 使用异步请求避免阻塞主线程
        NSURL *url = [NSURL URLWithString:urlString];
        NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
            
            if (error) {
                NSLog(@"Token刷新失败: %@", error.localizedDescription);
                return;
            }
            
            if (data && !error) {
                NSString *resultString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                
                if (resultString) {
                    NSError *parseError = nil;
                    NSDictionary *result = [NSJSONSerialization JSONObjectWithData:[resultString dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingAllowFragments error:&parseError];
                    if (parseError) {
                        NSLog(@"Token刷新JSON解析失败: %@", parseError);
                        return;
                    }
                    
                    if (result) {
                        
                        // 检查是否有错误
                        NSNumber *code = result[@"code"];
                        if (code && [code integerValue] != 0) {
                            NSLog(@"Token刷新失败 - 错误码: %@, 错误信息: %@", code, result[@"errorMessage"]);
                        }
                        
                        NSDictionary *dataDic = [result objectForKey:@"data"];
                        
                        NSString *appTkn = [dataDic objectForKey:@"access_token"];
                        if(appTkn) {
                            NSLog(@"Token刷新成功");
                            dispatch_async(dispatch_get_main_queue(), ^{
                                [[ClientJsonRequestManager sharedClient].requestSerializer setValue:appTkn forHTTPHeaderField:@"AUTHORIZATION"];
                                NSInteger intervalTime = [[dataDic objectForKey:@"expire"] integerValue];
                                NSDate *expireDate = [NSDate dateWithTimeIntervalSinceNow:intervalTime];
                                [[NSUserDefaults standardUserDefaults] setObject:expireDate forKey:@"User_Token_Expire_Time"];
                                [[NSUserDefaults standardUserDefaults] setObject:appTkn forKey:User_Token_String];
                                [[NSUserDefaults standardUserDefaults] synchronize];
                            });
                        } else {
                            NSLog(@"Token刷新错误: 响应中没有access_token");
                        }
                    }
                }
            }
        }];
        [task resume];
        return; // 异步获取token，不等待结果
    }
}



@end
