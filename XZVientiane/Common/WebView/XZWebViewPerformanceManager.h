//
//  XZWebViewPerformanceManager.h
//  XZVientiane
//
//  WebView性能优化管理器
//

#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface XZWebViewPerformanceManager : NSObject

/**
 * 获取单例实例
 */
+ (instancetype)sharedManager;

/**
 * 获取共享的WKProcessPool
 * 使用共享的ProcessPool可以共享Cookie、缓存等
 */
@property (nonatomic, strong, readonly) WKProcessPool *sharedProcessPool;

/**
 * 获取优化的WKWebViewConfiguration
 * 包含了性能优化的各种配置
 */
- (WKWebViewConfiguration *)optimizedConfiguration;

/**
 * 预加载WebView资源
 * 在应用启动时调用，提前初始化WebView相关资源
 */
- (void)preloadWebViewResources;

/**
 * 清理WebView缓存
 * @param completion 完成回调
 */
- (void)clearWebViewCache:(nullable void(^)(void))completion;

/**
 * 设置UserAgent
 * @param customUserAgent 自定义的UserAgent字符串
 */
- (void)setCustomUserAgent:(NSString *)customUserAgent;

/**
 * 获取缓存大小
 * @param completion 回调，返回缓存大小（字节）
 */
- (void)getCacheSize:(void(^)(NSUInteger size))completion;

/**
 * 配置Cookie
 * @param cookies Cookie数组
 * @param completion 完成回调
 */
- (void)configureCookies:(NSArray<NSHTTPCookie *> *)cookies completion:(nullable void(^)(void))completion;

/**
 * 启用或禁用图片自动加载
 * @param enabled 是否启用
 */
- (void)setImageAutoLoadEnabled:(BOOL)enabled;

/**
 * 设置是否允许JavaScript
 * @param enabled 是否允许
 */
- (void)setJavaScriptEnabled:(BOOL)enabled;

/**
 * 获取预热的WebView
 * 用于提高首次加载速度
 */
- (nullable WKWebView *)getPrewarmedWebView;

/**
 * 回收WebView到池中
 * @param webView 要回收的WebView
 */
- (void)recycleWebView:(WKWebView *)webView;

@end

NS_ASSUME_NONNULL_END