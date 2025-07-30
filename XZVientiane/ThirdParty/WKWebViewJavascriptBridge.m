//
//  WKWebViewJavascriptBridge.m
//
//  Created by @LokiMeyburg on 10/15/14.
//  Copyright (c) 2014 @LokiMeyburg. All rights reserved.
//


#import "WKWebViewJavascriptBridge.h"
#import <UIKit/UIKit.h>

#if defined supportsWKWebView

@implementation WKWebViewJavascriptBridge {
    __weak WKWebView* _webView;
    __weak id<WKNavigationDelegate> _webViewDelegate;
    long _uniqueId;
    WebViewJavascriptBridgeBase *_base;
}

/* API
 *****/

+ (void)enableLogging { [WebViewJavascriptBridgeBase enableLogging]; }

+ (instancetype)bridgeForWebView:(WKWebView*)webView {
    WKWebViewJavascriptBridge* bridge = [[self alloc] init];
    [bridge _setupInstance:webView];
    [bridge reset];
    return bridge;
}

- (void)send:(id)data {
    [self send:data responseCallback:nil];
}

- (void)send:(id)data responseCallback:(WVJBResponseCallback)responseCallback {
    [_base sendData:data responseCallback:responseCallback handlerName:nil];
}

- (void)callHandler:(NSString *)handlerName {
    [self callHandler:handlerName data:nil responseCallback:nil];
}

- (void)callHandler:(NSString *)handlerName data:(id)data {
    [self callHandler:handlerName data:data responseCallback:nil];
}

- (void)callHandler:(NSString *)handlerName data:(id)data responseCallback:(WVJBResponseCallback)responseCallback {
    [_base sendData:data responseCallback:responseCallback handlerName:handlerName];
}

- (void)registerHandler:(NSString *)handlerName handler:(WVJBHandler)handler {
    _base.messageHandlers[handlerName] = [handler copy];
}

- (void)removeHandler:(NSString *)handlerName {
    [_base.messageHandlers removeObjectForKey:handlerName];
}

- (void)reset {
    [_base reset];
}

- (void)setWebViewDelegate:(id<WKNavigationDelegate>)webViewDelegate {
    _webViewDelegate = webViewDelegate;
}

- (void)disableJavscriptAlertBoxSafetyTimeout {
    [_base disableJavscriptAlertBoxSafetyTimeout];
}

/* Internals
 ***********/

- (void)dealloc {
    _base = nil;
    _webView = nil;
    _webViewDelegate = nil;
    _webView.navigationDelegate = nil;
}


/* WKWebView Specific Internals
 ******************************/

- (void) _setupInstance:(WKWebView*)webView {
    _webView = webView;
    _webView.navigationDelegate = self;
    _base = [[WebViewJavascriptBridgeBase alloc] init];
    _base.delegate = self;
}


- (void)WKFlushMessageQueue {
    // 检查应用状态，如果不在前台则不执行JavaScript
    UIApplicationState state = [[UIApplication sharedApplication] applicationState];
    
    // 🔧 修复手势返回空白页：检查WebView是否在显示中
    BOOL isWebViewVisible = _webView && _webView.window && !_webView.window.hidden && _webView.superview;
    
    // 如果应用在后台且WebView不可见，则跳过执行
    if (state == UIApplicationStateBackground || (state == UIApplicationStateInactive && !isWebViewVisible)) {
        NSLog(@"WebViewJavascriptBridge: 应用不在前台且WebView不可见，跳过JavaScript执行");
        return;
    } else if (state == UIApplicationStateInactive && isWebViewVisible) {
        NSLog(@"WebViewJavascriptBridge: 应用非活跃但WebView可见（可能是手势返回），允许执行");
    }
    
    // 检查webView和base是否存在
    if (!_webView || !_base) {
        NSLog(@"WebViewJavascriptBridge: webView或base已释放，跳过JavaScript执行");
        return;
    }
    
    // 使用weak-strong模式避免循环引用和崩溃
    __weak typeof(self) weakSelf = self;
    NSString *javascriptCommand = [_base webViewJavascriptFetchQueyCommand];
    
    // 异步执行JavaScript，避免阻塞主线程
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // 异步检查应用状态，避免dispatch_sync导致的潜在死锁
        UIApplicationState bgState = [[UIApplication sharedApplication] applicationState];
        // 🔧 修复：只在真正后台时才跳过，Inactive状态可能是手势返回
        if (bgState == UIApplicationStateBackground) {
            NSLog(@"WebViewJavascriptBridge: 后台线程检查，应用在后台");
            return;
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf || !strongSelf->_webView || !strongSelf->_base) {
                NSLog(@"WebViewJavascriptBridge: 对象已释放");
                return;
            }
            
            // 设置超时保护
            __block BOOL hasCompleted = NO;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                if (!hasCompleted) {
                    hasCompleted = YES;
                    NSLog(@"WebViewJavascriptBridge: JavaScript执行超时");
                }
            });
            
            [strongSelf->_webView evaluateJavaScript:javascriptCommand completionHandler:^(NSString* result, NSError* error) {
                if (hasCompleted) {
                    return; // 已经超时，忽略结果
                }
                hasCompleted = YES;
                
                __strong typeof(weakSelf) strongSelf2 = weakSelf;
                if (!strongSelf2 || !strongSelf2->_base) {
                    NSLog(@"WebViewJavascriptBridge: 在回调中对象已释放");
                    return;
                }
                
                // 回调已经在主线程，直接检查应用状态
                UIApplicationState callbackState = [[UIApplication sharedApplication] applicationState];
                // 🔧 修复：检查WebView是否仍然可见
                BOOL isStillVisible = strongSelf2->_webView && strongSelf2->_webView.window && 
                                     !strongSelf2->_webView.window.hidden && strongSelf2->_webView.superview;
                
                if (callbackState == UIApplicationStateBackground || 
                    (callbackState == UIApplicationStateInactive && !isStillVisible)) {
                    NSLog(@"WebViewJavascriptBridge: 回调时应用在后台或WebView不可见");
                    return;
                }
                
                if (error != nil) {
                    NSLog(@"WebViewJavascriptBridge: WARNING: Error when trying to fetch data from WKWebView: %@", error);
                }
                [strongSelf2->_base flushMessageQueue:result];
            }];
        });
    });
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    if (webView != _webView) { return; }
    
    __strong typeof(_webViewDelegate) strongDelegate = _webViewDelegate;
    if (strongDelegate && [strongDelegate respondsToSelector:@selector(webView:didFinishNavigation:)]) {
        [strongDelegate webView:webView didFinishNavigation:navigation];
    }
}


- (void)webView:(WKWebView *)webView decidePolicyForNavigationResponse:(WKNavigationResponse *)navigationResponse decisionHandler:(void (^)(WKNavigationResponsePolicy))decisionHandler {
    if (webView != _webView) { return; }

    __strong typeof(_webViewDelegate) strongDelegate = _webViewDelegate;
    if (strongDelegate && [strongDelegate respondsToSelector:@selector(webView:decidePolicyForNavigationResponse:decisionHandler:)]) {
        [strongDelegate webView:webView decidePolicyForNavigationResponse:navigationResponse decisionHandler:decisionHandler];
    }
    else {
        decisionHandler(WKNavigationResponsePolicyAllow);
    }
}

- (void)webView:(WKWebView *)webView didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential *))completionHandler {
    if (webView != _webView) { return; }

    __strong typeof(_webViewDelegate) strongDelegate = _webViewDelegate;
    if (strongDelegate && [strongDelegate respondsToSelector:@selector(webView:didReceiveAuthenticationChallenge:completionHandler:)]) {
        [strongDelegate webView:webView didReceiveAuthenticationChallenge:challenge completionHandler:completionHandler];
    } else {
        completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
    }
}

- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    if (webView != _webView) { return; }
    NSURL *url = navigationAction.request.URL;
    __strong typeof(_webViewDelegate) strongDelegate = _webViewDelegate;

    if ([_base isWebViewJavascriptBridgeURL:url]) {
        if ([_base isBridgeLoadedURL:url]) {
            // 检查应用状态，避免在后台注入JavaScript
            UIApplicationState state = [[UIApplication sharedApplication] applicationState];
            // 🔧 修复：检查WebView是否可见
            BOOL isVisible = _webView && _webView.window && !_webView.window.hidden && _webView.superview;
            
            if (state == UIApplicationStateActive || (state == UIApplicationStateInactive && isVisible)) {
                [_base injectJavascriptFile];
            } else {
                NSLog(@"WebViewJavascriptBridge: 应用在后台或WebView不可见，跳过JavaScript注入");
            }
        } else if ([_base isQueueMessageURL:url]) {
            // 异步处理消息队列，避免阻塞导航决策
            dispatch_async(dispatch_get_main_queue(), ^{
                [self WKFlushMessageQueue];
            });
        } else {
            [_base logUnkownMessage:url];
        }
        decisionHandler(WKNavigationActionPolicyCancel);
        return;
    }
    
    if (strongDelegate && [strongDelegate respondsToSelector:@selector(webView:decidePolicyForNavigationAction:decisionHandler:)]) {
        [_webViewDelegate webView:webView decidePolicyForNavigationAction:navigationAction decisionHandler:decisionHandler];
    } else {
        decisionHandler(WKNavigationActionPolicyAllow);
    }
}

- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(WKNavigation *)navigation {
    if (webView != _webView) { return; }
    
    __strong typeof(_webViewDelegate) strongDelegate = _webViewDelegate;
    if (strongDelegate && [strongDelegate respondsToSelector:@selector(webView:didStartProvisionalNavigation:)]) {
        [strongDelegate webView:webView didStartProvisionalNavigation:navigation];
    }
}


- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    if (webView != _webView) { return; }
    
    __strong typeof(_webViewDelegate) strongDelegate = _webViewDelegate;
    if (strongDelegate && [strongDelegate respondsToSelector:@selector(webView:didFailNavigation:withError:)]) {
        [strongDelegate webView:webView didFailNavigation:navigation withError:error];
    }
}

- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    if (webView != _webView) { return; }
    
    __strong typeof(_webViewDelegate) strongDelegate = _webViewDelegate;
    if (strongDelegate && [strongDelegate respondsToSelector:@selector(webView:didFailProvisionalNavigation:withError:)]) {
        [strongDelegate webView:webView didFailProvisionalNavigation:navigation withError:error];
    }
}

- (NSString*) _evaluateJavascript:(NSString*)javascriptCommand {
    // 检查应用状态，如果不在前台则不执行JavaScript
    UIApplicationState state = [[UIApplication sharedApplication] applicationState];
    
    // 🔧 修复手势返回空白页：检查WebView是否在显示中
    BOOL isWebViewVisible = _webView && _webView.window && !_webView.window.hidden && _webView.superview;
    
    if (state == UIApplicationStateBackground || (state == UIApplicationStateInactive && !isWebViewVisible)) {
        NSLog(@"WebViewJavascriptBridge: 应用在后台或WebView不可见，跳过JavaScript执行");
        return NULL;
    }
    
    // 检查webView是否存在
    if (!_webView) {
        NSLog(@"WebViewJavascriptBridge: webView已释放，跳过JavaScript执行");
        return NULL;
    }
    
    // 异步执行JavaScript，避免阻塞主线程
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf || !strongSelf->_webView) {
            return;
        }
        
        // 再次检查应用状态
        UIApplicationState currentState = [[UIApplication sharedApplication] applicationState];
        if (currentState != UIApplicationStateActive) {
            NSLog(@"WebViewJavascriptBridge: 执行前应用已不在前台");
            return;
        }
        
        // 执行JavaScript，但不等待回调避免在后台时出现问题
        [strongSelf->_webView evaluateJavaScript:javascriptCommand completionHandler:^(id _Nullable result, NSError * _Nullable error) {
            if (error) {
                NSLog(@"WebViewJavascriptBridge: JavaScript执行错误: %@", error);
            }
        }];
    });
    return NULL;
}



@end


#endif
