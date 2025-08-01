//
//  XZWKWebViewBaseController.h
//  XZVientiane
//
//  Created by Assistant on 2024/12/19.
//  Copyright © 2024年 TuWeiA. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import "XZViewController.h"
#import "../../ThirdParty/WKWebViewJavascriptBridge/WKWebViewJavascriptBridge.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, GDpushType) {
    GDpushTypeNormal = 0,
    GDpushTypePresent,
    GDpushTypeAlert
};

// 兼容枚举定义
typedef NS_ENUM(NSInteger, GDpushTypeCompat) {
    isPushNormal     = 0,
    isPushPresent    = 1,
    isPushAlert      = 2
};

// JavaScript回调块类型定义
typedef void(^XZWebViewJSCallbackBlock)(id result);
typedef void(^NextPageDataBlock)(NSDictionary *dic);

// 枚举值已在GDpushTypeCompat中定义，无需额外的extern声明

@interface XZWKWebViewBaseController : XZViewController

// WebView相关属性
@property (strong, nonatomic) WKWebView *webView;
@property (strong, nonatomic) WKUserContentController *userContentController;

// 页面数据属性
@property (strong, nonatomic) NSString *pinUrl;
@property (strong, nonatomic) NSString *pinDataStr;
@property (strong, nonatomic) NSString *pagetitle;
@property (copy, nonatomic) NextPageDataBlock nextPageDataBlock;

// 组件相关属性
@property (strong, nonatomic) NSDictionary *templateDic;
@property (strong, nonatomic) NSDictionary *componentJsAndCs;
@property (strong, nonatomic) NSDictionary *componentDic;

// 兼容性属性（原有代码使用大写开头）
@property (strong, nonatomic, readonly) NSDictionary *ComponentJsAndCs;
@property (strong, nonatomic, readonly) NSDictionary *ComponentDic;

// 状态属性
@property (assign, nonatomic) BOOL isWebViewLoading;
@property (assign, nonatomic) BOOL isLoading;
@property (assign, nonatomic) int lastSelectedIndex;
@property (assign, nonatomic) GDpushType pushType;

// 导航和页面状态属性
@property (assign, nonatomic) BOOL isTabbarShow;
@property (assign, nonatomic) BOOL isExist;

// 网络监控相关属性
@property (strong, nonatomic, nullable) dispatch_source_t timer;
@property (strong, nonatomic) UIView *networkNoteView;
@property (strong, nonatomic) UIButton *networkNoteBt;

// JavaScript执行时机管理
@property (strong, nonatomic) NSMutableArray *pendingJavaScriptTasks;
@property (strong, nonatomic) NSMutableArray *delayedTimers;

// HTML模板相关属性
@property (strong, nonatomic) NSString *htmlStr;

// 性能优化相关属性
@property (strong, nonatomic) NSOperationQueue *webViewLoadingQueue;  // WebView加载操作队列
@property (strong, nonatomic) NSOperationQueue *htmlProcessingQueue;  // HTML处理队列
@property (assign, nonatomic) BOOL isWebViewPreCreated;               // WebView是否已预创建
@property (assign, nonatomic) BOOL isBridgeReady;                     // JavaScript桥接是否就绪
@property (assign, nonatomic) BOOL isLoadingInProgress;               // 是否正在执行loadHTMLString操作（防重复）

// 交互式转场恢复状态管理
@property (assign, nonatomic) BOOL isRestoreInProgress;               // 是否正在执行恢复操作
@property (strong, nonatomic) NSDate *lastRestoreTime;                // 上次恢复操作时间

// 基础方法
- (void)addWebView;
- (void)setupUnifiedJavaScriptBridge;                  // 统一的JavaScript桥接设置方法
- (void)domainOperate;
- (void)loadHTMLContent;
- (void)retryHTMLLoading;

// 性能优化方法
+ (void)preloadHTMLTemplates;                           // 预加载HTML模板
- (void)preCreateWebViewIfNeeded;                       // 预创建WebView
- (void)optimizedLoadHTMLContent;                       // 优化的HTML加载方法
- (BOOL)isReadyForJavaScriptExecution;                  // 简化的JavaScript执行状态检查
- (void)fallbackToOriginalLoadMethod;                   // 回退到原有加载方法
- (void)loadHTMLContentWithoutOptimization;             // 不使用优化的HTML加载方法
- (BOOL)isNavigationReturnScenario;                     // 检测是否为返回导航场景
- (BOOL)hasValidWebViewContent;                         // 检测WebView是否有有效内容

// JavaScript交互方法
- (void)jsCallObjc:(NSDictionary *)jsData completion:(void(^)(id result))completion;
- (void)jsCallObjc:(NSDictionary *)jsData jsCallBack:(WVJBResponseCallback)jsCallBack;
- (void)objcCallJs:(NSDictionary *)dic;
- (void)handleJavaScriptCall:(NSDictionary *)data completion:(XZWebViewJSCallbackBlock)completion;
- (void)callJavaScript:(NSString *)script completion:(XZWebViewJSCallbackBlock)completion;
- (void)safelyEvaluateJavaScript:(NSString *)javaScriptString completion:(void (^)(id result, NSError *error))completionHandler;

// 网络监控方法
- (void)listenToTimer;
- (void)networkNoteBtClick;

// 页面状态管理
- (BOOL)isShowingOnKeyWindow;
- (BOOL)isHaveNativeHeader:(NSString *)url;

// 状态栏管理
- (BOOL)prefersStatusBarHidden;
- (UIStatusBarStyle)preferredStatusBarStyle;

// 页面导航
- (void)getnavigationBarTitleText:(NSString *)title;

// 工具方法
- (NSString *)jsonStringFromObject:(id)object;

// 安全执行JavaScript
- (void)safelyEvaluateJavaScript:(NSString *)javaScriptString 
                completionHandler:(void (^ _Nullable)(_Nullable id, NSError * _Nullable error))completionHandler;

// 交互式转场后的WebView状态恢复
- (void)restoreWebViewStateAfterInteractiveTransition;

@end

NS_ASSUME_NONNULL_END 