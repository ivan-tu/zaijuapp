//
//  XZWebViewPerformanceManager.m
//  XZVientiane
//
//  WebView性能优化管理器
//

#import "XZWebViewPerformanceManager.h"
#import "XZiOSVersionManager.h"

@interface XZWebViewPerformanceManager ()

@property (nonatomic, strong) WKProcessPool *sharedProcessPool;
@property (nonatomic, strong) WKWebViewConfiguration *baseConfiguration;
@property (nonatomic, strong) NSMutableArray<WKWebView *> *webViewPool;
@property (nonatomic, strong) NSString *customUserAgent;
@property (nonatomic, assign) BOOL imageAutoLoadEnabled;
@property (nonatomic, assign) BOOL javaScriptEnabled;
@property (nonatomic, strong) dispatch_queue_t poolQueue;

@end

@implementation XZWebViewPerformanceManager

+ (instancetype)sharedManager {
    static XZWebViewPerformanceManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[XZWebViewPerformanceManager alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _sharedProcessPool = [[WKProcessPool alloc] init];
        _webViewPool = [NSMutableArray array];
        _imageAutoLoadEnabled = YES;
        _javaScriptEnabled = YES;
        _poolQueue = dispatch_queue_create("com.zaiju.webview.pool", DISPATCH_QUEUE_SERIAL);
        
        [self setupBaseConfiguration];
        
    }
    return self;
}

- (void)setupBaseConfiguration {
    _baseConfiguration = [[WKWebViewConfiguration alloc] init];
    _baseConfiguration.processPool = _sharedProcessPool;
    
    // 设置偏好设置
    WKPreferences *preferences = [[WKPreferences alloc] init];
    preferences.minimumFontSize = 9.0;
    preferences.javaScriptEnabled = _javaScriptEnabled;
    preferences.javaScriptCanOpenWindowsAutomatically = YES;
    _baseConfiguration.preferences = preferences;
    
    // 允许内联播放
    _baseConfiguration.allowsInlineMediaPlayback = YES;
    
    // iOS 10+ 自动播放视频
    if ([[XZiOSVersionManager sharedManager] isSystemVersionGreaterThanOrEqualTo:10.0]) {
        _baseConfiguration.mediaTypesRequiringUserActionForPlayback = WKAudiovisualMediaTypeNone;
    }
    
    // 设置数据存储
    if ([[XZiOSVersionManager sharedManager] isSystemVersionGreaterThanOrEqualTo:9.0]) {
        _baseConfiguration.websiteDataStore = [WKWebsiteDataStore defaultDataStore];
    }
    
    // 注入初始JavaScript
    [self injectPerformanceScripts];
}

- (void)injectPerformanceScripts {
    // 注入性能优化脚本
    NSString *performanceScript = @"\
        // 禁用长按选择\n\
        document.documentElement.style.webkitTouchCallout = 'none';\n\
        document.documentElement.style.webkitUserSelect = 'none';\n\
        \n\
        // 优化滚动性能\n\
        document.documentElement.style.webkitOverflowScrolling = 'touch';\n\
        \n\
        // 监听DOM加载完成\n\
        document.addEventListener('DOMContentLoaded', function() {\n\
            // 懒加载图片\n\
            if ('IntersectionObserver' in window) {\n\
                var images = document.querySelectorAll('img[data-src]');\n\
                var imageObserver = new IntersectionObserver(function(entries) {\n\
                    entries.forEach(function(entry) {\n\
                        if (entry.isIntersecting) {\n\
                            var img = entry.target;\n\
                            img.src = img.dataset.src;\n\
                            img.removeAttribute('data-src');\n\
                            imageObserver.unobserve(img);\n\
                        }\n\
                    });\n\
                });\n\
                images.forEach(function(img) {\n\
                    imageObserver.observe(img);\n\
                });\n\
            }\n\
        });\n\
    ";
    
    WKUserScript *userScript = [[WKUserScript alloc] initWithSource:performanceScript
                                                      injectionTime:WKUserScriptInjectionTimeAtDocumentStart
                                                   forMainFrameOnly:YES];
    [_baseConfiguration.userContentController addUserScript:userScript];
}

- (WKWebViewConfiguration *)optimizedConfiguration {
    // 创建配置副本
    WKWebViewConfiguration *config = [_baseConfiguration copy];
    
    // 设置自定义UserAgent
    if (_customUserAgent.length > 0) {
        config.applicationNameForUserAgent = _customUserAgent;
    }
    
    // 根据设置调整
    config.preferences.javaScriptEnabled = _javaScriptEnabled;
    
    return config;
}

- (void)preloadWebViewResources {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        // 预热WebView池
        dispatch_async(dispatch_get_main_queue(), ^{
            for (int i = 0; i < 2; i++) {
                WKWebView *webView = [[WKWebView alloc] initWithFrame:CGRectZero
                                                         configuration:[self optimizedConfiguration]];
                dispatch_sync(self.poolQueue, ^{
                    [self.webViewPool addObject:webView];
                });
            }
        });
        
        // 预加载常用JavaScript框架
        [self preloadCommonResources];
    });
}

- (void)preloadCommonResources {
    // 这里可以预加载一些常用的JavaScript库或CSS
    // 通过创建一个隐藏的WebView来加载这些资源
    dispatch_async(dispatch_get_main_queue(), ^{
        WKWebView *preloadWebView = [[WKWebView alloc] initWithFrame:CGRectZero
                                                        configuration:[self optimizedConfiguration]];
        
        // 加载一个包含常用资源的HTML
        NSString *preloadHTML = @"<html><head>\
            <link rel='preload' href='https://cdn.bootcdn.net/ajax/libs/zepto/1.2.0/zepto.min.js' as='script'>\
            </head><body></body></html>";
        
        [preloadWebView loadHTMLString:preloadHTML baseURL:nil];
        
        // 5秒后销毁
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [preloadWebView stopLoading];
        });
    });
}

- (nullable WKWebView *)getPrewarmedWebView {
    __block WKWebView *webView = nil;
    
    dispatch_sync(self.poolQueue, ^{
        if (self.webViewPool.count > 0) {
            webView = [self.webViewPool firstObject];
            [self.webViewPool removeObjectAtIndex:0];
        }
    });
    
    if (!webView) {
        // 池中没有可用的，创建新的
        webView = [[WKWebView alloc] initWithFrame:CGRectZero
                                      configuration:[self optimizedConfiguration]];
    }
    
    // 异步补充池
    dispatch_async(dispatch_get_main_queue(), ^{
        dispatch_sync(self.poolQueue, ^{
            if (self.webViewPool.count < 2) {
                WKWebView *newWebView = [[WKWebView alloc] initWithFrame:CGRectZero
                                                            configuration:[self optimizedConfiguration]];
                [self.webViewPool addObject:newWebView];
            }
        });
    });
    
    return webView;
}

- (void)recycleWebView:(WKWebView *)webView {
    if (!webView) return;
    
    // 清理WebView
    [webView stopLoading];
    [webView loadHTMLString:@"" baseURL:nil];
    
    dispatch_sync(self.poolQueue, ^{
        if (self.webViewPool.count < 3) { // 最多保留3个
            [self.webViewPool addObject:webView];
        } else {
        }
    });
}

- (void)clearWebViewCache:(nullable void(^)(void))completion {
    if ([[XZiOSVersionManager sharedManager] isSystemVersionGreaterThanOrEqualTo:9.0]) {
        NSSet *websiteDataTypes = [WKWebsiteDataStore allWebsiteDataTypes];
        NSDate *dateFrom = [NSDate dateWithTimeIntervalSince1970:0];
        
        [[WKWebsiteDataStore defaultDataStore] removeDataOfTypes:websiteDataTypes
                                                    modifiedSince:dateFrom
                                                completionHandler:^{
            if (completion) {
                dispatch_async(dispatch_get_main_queue(), completion);
            }
        }];
    } else {
        // iOS 9以下版本的处理
        NSString *libraryPath = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) firstObject];
        NSString *cookiesPath = [libraryPath stringByAppendingPathComponent:@"Cookies"];
        NSString *webKitPath = [libraryPath stringByAppendingPathComponent:@"WebKit"];
        
        NSError *error;
        [[NSFileManager defaultManager] removeItemAtPath:cookiesPath error:&error];
        [[NSFileManager defaultManager] removeItemAtPath:webKitPath error:&error];
        
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), completion);
        }
    }
}

- (void)setCustomUserAgent:(NSString *)customUserAgent {
    _customUserAgent = customUserAgent;
}

- (void)setImageAutoLoadEnabled:(BOOL)enabled {
    _imageAutoLoadEnabled = enabled;
}

- (void)setJavaScriptEnabled:(BOOL)enabled {
    _javaScriptEnabled = enabled;
    _baseConfiguration.preferences.javaScriptEnabled = enabled;
}

- (void)getCacheSize:(void(^)(NSUInteger size))completion {
    if ([[XZiOSVersionManager sharedManager] isSystemVersionGreaterThanOrEqualTo:9.0]) {
        [[WKWebsiteDataStore defaultDataStore] fetchDataRecordsOfTypes:[WKWebsiteDataStore allWebsiteDataTypes]
                                                      completionHandler:^(NSArray<WKWebsiteDataRecord *> * _Nonnull records) {
            NSUInteger totalSize = 0;
            for (WKWebsiteDataRecord *record in records) {
                // 这里只能获取记录数，无法获取准确大小
                totalSize += 1024 * 1024; // 估算每条记录1MB
            }
            
            if (completion) {
                completion(totalSize);
            }
        }];
    } else {
        if (completion) {
            completion(0);
        }
    }
}

- (void)configureCookies:(NSArray<NSHTTPCookie *> *)cookies completion:(nullable void(^)(void))completion {
    if ([[XZiOSVersionManager sharedManager] isiOS11Later]) {
        WKHTTPCookieStore *cookieStore = _baseConfiguration.websiteDataStore.httpCookieStore;
        
        __block NSInteger pendingCookies = cookies.count;
        if (pendingCookies == 0 && completion) {
            completion();
            return;
        }
        
        for (NSHTTPCookie *cookie in cookies) {
            [cookieStore setCookie:cookie completionHandler:^{
                pendingCookies--;
                if (pendingCookies == 0 && completion) {
                    dispatch_async(dispatch_get_main_queue(), completion);
                }
            }];
        }
    } else {
        // iOS 11以下通过JavaScript注入Cookie
        NSMutableString *cookieScript = [NSMutableString string];
        for (NSHTTPCookie *cookie in cookies) {
            [cookieScript appendFormat:@"document.cookie='%@=%@; path=%@';",
             cookie.name, cookie.value, cookie.path ?: @"/"];
        }
        
        if (cookieScript.length > 0) {
            WKUserScript *userScript = [[WKUserScript alloc] initWithSource:cookieScript
                                                              injectionTime:WKUserScriptInjectionTimeAtDocumentStart
                                                           forMainFrameOnly:NO];
            [_baseConfiguration.userContentController addUserScript:userScript];
        }
        
        if (completion) {
            completion();
        }
    }
}

@end