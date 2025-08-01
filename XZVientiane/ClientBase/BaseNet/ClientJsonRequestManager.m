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
    NSString *cacheKey = [NSString urlWithParam:parameters andHead:URLString];
    
    if ([self cachedDataWithKey:cacheKey block:block]) {
        return;
    }
    
    [self checkAppToken];
    
    // 调用带headers参数的GET方法
    [self GET:URLString parameters:parameters headers:nil block:block];
}

- (void)GET:(NSString *)URLString parameters:(id)parameters headers:(NSDictionary *)headers block:(ClientCompletionBlock)block {
    if ([self cachedDataWithKey:[NSString urlWithParam:parameters andHead:URLString] block:block]) {
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
        [[EGOCache globalCache] setObject:responseObject forKey:[NSString urlWithParam:parameters andHead:URLString]];
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
    if ([self cachedDataWithKey:[NSString urlWithParam:parameters andHead:URLString] block:block]) {
        return;
    }
    [self checkAppToken];
    
    
    // 设置请求序列化器为JSON格式
    AFJSONRequestSerializer *jsonSerializer = [AFJSONRequestSerializer serializer];
    self.requestSerializer = jsonSerializer;
    
    // 设置请求头
    if (headers) {
        for (NSString *key in headers) {
            [self.requestSerializer setValue:headers[key] forHTTPHeaderField:key];
        }
    }
    
    
    [super POST:URLString parameters:parameters headers:nil progress:nil success:^(NSURLSessionDataTask *task, id responseObject) {
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)task.response;
        
        
        if (!responseObject || ![responseObject isKindOfClass:[NSDictionary class]]) {
            NSLog(@"POST响应数据格式错误，类型: %@", NSStringFromClass([responseObject class]));
            if (block) {
                block(nil, [NSError errorWithDomain:@"没有返回数据或数据格式错误" code:10000 userInfo:nil]);
            }
            return ;
        }
        NSNumber *codenumber = [responseObject objectForKey:@"code"];
        NSAssert(codenumber.integerValue == 0, @"请求失败");
        [[EGOCache globalCache] setObject:responseObject forKey:[NSString urlWithParam:parameters andHead:URLString]];
        
        // 恢复默认的请求序列化器
        self.requestSerializer = [AFHTTPRequestSerializer serializer];
        
        if (block) {
            block(responseObject, nil);
        }
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)task.response;
        NSLog(@"POST请求失败: %@, HTTP状态码: %ld, 错误: %@", URLString, (long)httpResponse.statusCode, error.localizedDescription);
        
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
    NSString *cacheKey = [NSString urlWithParam:parameters andHead:URLString];
    
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
        [[EGOCache globalCache] setObject:responseObject forKey:[NSString urlWithParam:parameters andHead:URLString]];
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
        NSString *urlString = [NSString stringWithFormat:@"%@/oauth/getAccessToken?appId=%@&appSecret=%@", 
                                                         [ClientSettingModel sharedInstance].domain,
                                                         appId,
                                                         appSecret];
        
        
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
