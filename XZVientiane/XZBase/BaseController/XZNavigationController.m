//
//  TYNavigationController.m
//  TuiYa
//
//  Created by CFJ on 15/6/14.
//  Copyright (c) 2015年 tuweia. All rights reserved.
//

#import "XZNavigationController.h"
#import "CFJClientH5Controller.h"
#import "XZBaseHead.h"
#import <objc/runtime.h>
#import <WebKit/WebKit.h>

#pragma mark - XZSlideTransitionAnimator (内联实现)

/**
 * 内联的转场动画控制器
 * 避免单独创建文件导致的链接问题
 */
@interface XZInlineSlideAnimator : NSObject <UIViewControllerAnimatedTransitioning>
@property (nonatomic, assign) BOOL isPresenting;
@property (nonatomic, assign) NSTimeInterval animationDuration;
@property (nonatomic, assign) CGFloat backgroundOffsetRatio;
@property (nonatomic, assign) CGFloat springDamping;
@property (nonatomic, assign) CGFloat springVelocity;
@end

@implementation XZInlineSlideAnimator

- (instancetype)init {
    self = [super init];
    if (self) {
        _animationDuration = 0.3; // 进一步减慢动画速度，让用户有更好的控制感
        _backgroundOffsetRatio = 0.3;
        _springDamping = 1.0; // 使用1.0避免弹簧效果，让动画更平滑
        _springVelocity = 0.0; // 初始速度设为0
        _isPresenting = YES;
    }
    return self;
}

- (NSTimeInterval)transitionDuration:(id<UIViewControllerContextTransitioning>)transitionContext {
    return self.animationDuration;
}

- (void)animateTransition:(id<UIViewControllerContextTransitioning>)transitionContext {
    
    UIViewController *fromVC = [transitionContext viewControllerForKey:UITransitionContextFromViewControllerKey];
    UIViewController *toVC = [transitionContext viewControllerForKey:UITransitionContextToViewControllerKey];
    UIView *containerView = [transitionContext containerView];
    
    
    CGRect finalFrameForToVC = [transitionContext finalFrameForViewController:toVC];
    CGRect initialFrameForFromVC = [transitionContext initialFrameForViewController:fromVC];
    
    
    if (self.isPresenting) {
        [self animatePresentationWithContext:transitionContext
                                      fromVC:fromVC
                                        toVC:toVC
                               containerView:containerView
                            finalFrameForToVC:finalFrameForToVC
                         initialFrameForFromVC:initialFrameForFromVC];
    } else {
        [self animateDismissalWithContext:transitionContext
                                   fromVC:fromVC
                                     toVC:toVC
                            containerView:containerView
                         finalFrameForToVC:finalFrameForToVC
                      initialFrameForFromVC:initialFrameForFromVC];
    }
}

- (void)animatePresentationWithContext:(id<UIViewControllerContextTransitioning>)transitionContext
                                fromVC:(UIViewController *)fromVC
                                  toVC:(UIViewController *)toVC
                         containerView:(UIView *)containerView
                      finalFrameForToVC:(CGRect)finalFrame
                   initialFrameForFromVC:(CGRect)initialFrame {
    
    // 🔧 修复：检查是否需要特殊处理
    UIView *viewToAnimate = toVC.view;
    BOOL shouldSkipAnimation = NO;
    
    // 检查fromVC是否是Tab页面的根视图控制器
    if (fromVC.tabBarController && !fromVC.hidesBottomBarWhenPushed && toVC.hidesBottomBarWhenPushed) {
        // 从Tab根页面push到子页面，使用标准处理
        shouldSkipAnimation = NO;
    }
    
    [containerView addSubview:viewToAnimate];
    viewToAnimate.frame = finalFrame;
    
    CGRect startFrame = finalFrame;
    startFrame.origin.x = CGRectGetMaxX(containerView.bounds);
    viewToAnimate.frame = startFrame;
    
    // 添加阴影效果
    [self addShadowToView:toVC.view];
    
    [UIView animateWithDuration:[self transitionDuration:transitionContext]
                          delay:0
         usingSpringWithDamping:self.springDamping
          initialSpringVelocity:self.springVelocity
                        options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        toVC.view.frame = finalFrame;
        
        CGRect backgroundFrame = initialFrame;
        backgroundFrame.origin.x = -CGRectGetWidth(containerView.bounds) * self.backgroundOffsetRatio;
        fromVC.view.frame = backgroundFrame;
        fromVC.view.alpha = 0.9;
        
    } completion:^(BOOL finished) {
        [self removeShadowFromView:toVC.view];
        fromVC.view.alpha = 1.0;
        
        if ([transitionContext transitionWasCancelled]) {
            fromVC.view.frame = initialFrame;
            [toVC.view removeFromSuperview];
        }
        
        // 对于交互式转场，即使finished为NO，如果没有被取消，仍然应该成功完成
        BOOL success = ![transitionContext transitionWasCancelled];
        [transitionContext completeTransition:success];
    }];
}

- (void)animateDismissalWithContext:(id<UIViewControllerContextTransitioning>)transitionContext
                             fromVC:(UIViewController *)fromVC
                               toVC:(UIViewController *)toVC
                      containerView:(UIView *)containerView
                   finalFrameForToVC:(CGRect)finalFrame
                initialFrameForFromVC:(CGRect)initialFrame {
    
    NSLog(@"在局Claude Code[转场动画]+开始返回动画 fromVC: %@, toVC: %@", 
          NSStringFromClass([fromVC class]), NSStringFromClass([toVC class]));
    
    // 🔧 新增：打印更多上下文信息
    if ([fromVC respondsToSelector:@selector(hidesBottomBarWhenPushed)]) {
        NSLog(@"在局Claude Code[转场动画]+fromVC.hidesBottomBarWhenPushed: %@", 
              fromVC.hidesBottomBarWhenPushed ? @"YES" : @"NO");
    }
    if ([toVC respondsToSelector:@selector(hidesBottomBarWhenPushed)]) {
        NSLog(@"在局Claude Code[转场动画]+toVC.hidesBottomBarWhenPushed: %@", 
              toVC.hidesBottomBarWhenPushed ? @"YES" : @"NO");
    }
    
    // 🔧 关键修复：检查视图层级并避免操作TabBarController
    // 对于返回到Tab根页面的情况，特殊处理
    BOOL isReturningToTabRoot = (toVC.tabBarController && !toVC.hidesBottomBarWhenPushed);
    
    if (isReturningToTabRoot) {
        NSLog(@"在局Claude Code[转场修复]+检测到返回Tab根页面，特殊处理避免TabBar错位");
        
        // 对于Tab根页面，不要将其view添加到containerView
        // 因为它已经在TabBarController的视图层级中了
        // 我们只需要确保它可见
        toVC.view.hidden = NO;
        toVC.view.alpha = 1.0;
        
        // 不执行任何frame动画，保持原有位置
    } else {
        // 普通页面的处理
        if (toVC.view.superview != containerView) {
            [containerView insertSubview:toVC.view belowSubview:fromVC.view];
        }
        
        CGRect backgroundInitialFrame = finalFrame;
        backgroundInitialFrame.origin.x = -CGRectGetWidth(containerView.bounds) * self.backgroundOffsetRatio;
        toVC.view.frame = backgroundInitialFrame;
        toVC.view.alpha = 0.9;
    }
    
    
    [self addShadowToView:fromVC.view];
    
    NSTimeInterval duration = [self transitionDuration:transitionContext];
    
    // 判断是否是交互式转场
    BOOL isInteractive = transitionContext.isInteractive;
    
    // 定义动画块
    void (^animationBlock)(void) = ^{
        
        CGRect exitFrame = initialFrame;
        exitFrame.origin.x = CGRectGetMaxX(containerView.bounds);
        fromVC.view.frame = exitFrame;
        
        // 🔧 修复：根据是否返回Tab根页面使用不同的动画策略
        if (isReturningToTabRoot) {
            // Tab根页面已经在正确位置，只需要确保可见
            toVC.view.alpha = 1.0;
        } else {
            // 普通页面执行滑动动画
            toVC.view.frame = finalFrame;
            toVC.view.alpha = 1.0;
        }
    };
    
    // 定义完成块
    void (^completionBlock)(BOOL) = ^(BOOL finished) {
        
        // 清理阴影
        [self removeShadowFromView:fromVC.view];
        
        if ([transitionContext transitionWasCancelled]) {
            fromVC.view.frame = initialFrame;
            // 🔧 修复：转场取消时的处理
            if (isReturningToTabRoot) {
                // Tab根页面保持原样
                toVC.view.alpha = 1.0;
                
            } else {
                // 普通页面恢复到初始状态
                CGRect backgroundInitialFrame = finalFrame;
                backgroundInitialFrame.origin.x = -CGRectGetWidth(containerView.bounds) * self.backgroundOffsetRatio;
                toVC.view.frame = backgroundInitialFrame;
                toVC.view.alpha = 0.9;
            }
            
            // 如果转场被取消，确保fromVC的视图仍然在容器中
            if (fromVC.view.superview != containerView) {
                [containerView addSubview:fromVC.view];
            }
            
            // 🔧 关键修复：转场取消后恢复视图状态
            dispatch_async(dispatch_get_main_queue(), ^{
                NSLog(@"在局Claude Code[转场动画]+转场取消，恢复控制器状态: fromVC=%@, toVC=%@", 
                      NSStringFromClass([fromVC class]), NSStringFromClass([toVC class]));
                
                
                // 发送通知让导航控制器处理WebView状态恢复
                [[NSNotificationCenter defaultCenter] postNotificationName:@"InteractiveTransitionCancelled" 
                                                                    object:nil 
                                                                  userInfo:@{@"toViewController": toVC, 
                                                                           @"fromViewController": fromVC}];
            });
        } else {
            // 🔧 修复：转场成功时确保视图状态正确
            if (isReturningToTabRoot) {
                // Tab根页面确保完全可见
                toVC.view.alpha = 1.0;
                toVC.view.hidden = NO;
            } else {
                toVC.view.frame = finalFrame;
                toVC.view.alpha = 1.0;
            }
            
            // 转场成功完成，确保fromVC的视图被正确移除
            // 这是关键：必须在动画完成后移除fromVC的视图
            [fromVC.view removeFromSuperview];
            
            
            // 只打印调试信息，不进行任何实际操作
            if (toVC.tabBarController) {
                NSLog(@"在局Claude Code[TabBar状态]+转场完成 fromVC: %@ (hidesBottom: %@) -> toVC: %@ (hidesBottom: %@)", 
                      NSStringFromClass([fromVC class]), 
                      fromVC.hidesBottomBarWhenPushed ? @"YES" : @"NO",
                      NSStringFromClass([toVC class]), 
                      toVC.hidesBottomBarWhenPushed ? @"YES" : @"NO");
                
                NSLog(@"在局Claude Code[TabBar状态]+TabBar当前状态: hidden=%@, frame=%@", 
                      toVC.tabBarController.tabBar.hidden ? @"YES" : @"NO",
                      NSStringFromCGRect(toVC.tabBarController.tabBar.frame));
            }
        }
        
        // 对于交互式转场，即使finished为NO，如果没有被取消，仍然应该成功完成
        BOOL success = ![transitionContext transitionWasCancelled];
        [transitionContext completeTransition:success];
        
        // 额外的清理工作：确保视图层级正确
        if (success) {
            // 对于交互式转场，需要确保导航控制器的状态正确更新
            
            // 延迟执行额外的清理，确保转场完全结束
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                
                // 再次确保fromVC的视图已被移除
                if (fromVC.view.superview) {
                    [fromVC.view removeFromSuperview];
                }
                
                // 确保toVC的视图在正确的位置
                if (toVC.view.superview && toVC.navigationController) {
                    [toVC.navigationController.view bringSubviewToFront:toVC.navigationController.navigationBar];
                    
                    // 🔧 关键修复：确保TabBar完全恢复（针对手势返回到Tab根页面的情况）
                    if (!toVC.hidesBottomBarWhenPushed && toVC.tabBarController) {
                        UITabBar *tabBar = toVC.tabBarController.tabBar;
                        tabBar.userInteractionEnabled = YES;
                        tabBar.alpha = 1.0;
                        tabBar.hidden = NO;
                        
                        // 确保TabBar在最上层
                        if (tabBar.superview) {
                            [tabBar.superview bringSubviewToFront:tabBar];
                        }
                        
                        // 恢复所有子视图的交互
                        for (UIView *subview in tabBar.subviews) {
                            subview.userInteractionEnabled = YES;
                        }
                        
                        // 🔧 关键修复：确保内容视图显示正确
                        if ([toVC respondsToSelector:@selector(webView)]) {
                            UIView *webView = [toVC valueForKey:@"webView"];
                            if (webView) {
                                webView.hidden = NO;
                                webView.alpha = 1.0;
                                webView.userInteractionEnabled = YES;
                                // 确保WebView在正确的位置
                                [toVC.view bringSubviewToFront:webView];
                                NSLog(@"在局Claude Code[视图恢复]+确保WebView显示正常");
                                
                                // 🔧 新增：执行页面恢复策略
                                if ([toVC respondsToSelector:@selector(executePageReloadStrategies)]) {
                                    SEL reloadSel = NSSelectorFromString(@"executePageReloadStrategies");
                                    NSMethodSignature *signature = [toVC methodSignatureForSelector:reloadSel];
                                    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
                                    [invocation setTarget:toVC];
                                    [invocation setSelector:reloadSel];
                                    [invocation invoke];
                                    NSLog(@"在局Claude Code[页面恢复]+执行页面重载策略");
                                }
                                
                                // 🔧 关键修复：对于手势返回到Tab根页面，强制刷新内容
                                if (!toVC.hidesBottomBarWhenPushed && toVC.tabBarController) {
                                    NSLog(@"在局Claude Code[手势诊断]+检测到返回Tab根页面，开始强制刷新");
                                    
                                    // 强制触发一次视图布局
                                    [toVC.view setNeedsLayout];
                                    [toVC.view layoutIfNeeded];
                                    NSLog(@"在局Claude Code[手势诊断]+完成视图布局");
                                    
                                    // 如果是WKWebView，强制重新渲染
                                    if ([webView isKindOfClass:NSClassFromString(@"WKWebView")]) {
                                        NSLog(@"在局Claude Code[手势诊断]+检测到WKWebView，准备强制重绘");
                                        
                                        // 先检查WebView当前的加载状态
                                        SEL isLoadingSel = NSSelectorFromString(@"isLoading");
                                        if ([webView respondsToSelector:isLoadingSel]) {
                                            NSMethodSignature *sig = [webView methodSignatureForSelector:isLoadingSel];
                                            NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
                                            [inv setTarget:webView];
                                            [inv setSelector:isLoadingSel];
                                            [inv invoke];
                                            BOOL isLoading = NO;
                                            [inv getReturnValue:&isLoading];
                                            NSLog(@"在局Claude Code[手势诊断]+WebView加载状态: %@", isLoading ? @"加载中" : @"已完成");
                                        }
                                        
                                        // 触发JavaScript强制重绘
                                        SEL evalJSSel = NSSelectorFromString(@"evaluateJavaScript:completionHandler:");
                                        if ([webView respondsToSelector:evalJSSel]) {
                                            NSString *jsCode = @"(function(){"
                                                "console.log('在局Claude Code[手势诊断]+开始强制重绘检查');"
                                                "var bodyDisplay = document.body.style.display;"
                                                "var bodyHeight = document.body.offsetHeight;"
                                                "var bodyContent = document.body.textContent.substring(0, 50);"
                                                "console.log('在局Claude Code[手势诊断]+重绘前状态: display=' + bodyDisplay + ', height=' + bodyHeight + ', content=' + bodyContent);"
                                                "document.body.style.display='none';"
                                                "document.body.offsetHeight;"
                                                "document.body.style.display='block';"
                                                "console.log('在局Claude Code[手势诊断]+强制重绘完成');"
                                                "return 'rerender_completed';"
                                            "})()";
                                            
                                            NSMethodSignature *sig = [webView methodSignatureForSelector:evalJSSel];
                                            NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
                                            [inv setTarget:webView];
                                            [inv setSelector:evalJSSel];
                                            [inv setArgument:&jsCode atIndex:2];
                                            
                                            void (^completionHandler)(id, NSError *) = ^(id result, NSError *error) {
                                                if (error) {
                                                    NSLog(@"在局Claude Code[手势诊断]+JavaScript重绘失败: %@", error.localizedDescription);
                                                } else {
                                                    NSLog(@"在局Claude Code[手势诊断]+JavaScript重绘成功: %@", result);
                                                }
                                            };
                                            [inv setArgument:&completionHandler atIndex:3];
                                            [inv invoke];
                                            NSLog(@"在局Claude Code[手势诊断]+已触发WebView重新渲染");
                                        }
                                    } else {
                                        NSLog(@"在局Claude Code[手势诊断]+不是WKWebView，跳过重绘: %@", NSStringFromClass([webView class]));
                                    }
                                }
                            }
                        }
                        
                        // 确保toVC的视图完全可见
                        toVC.view.hidden = NO;
                        toVC.view.alpha = 1.0;
                        
                        // 刷新视图层级
                        [toVC.view setNeedsLayout];
                        [toVC.view layoutIfNeeded];
                        
                        NSLog(@"在局Claude Code[TabBar恢复]+延迟检查，确保TabBar和内容视图正常");
                        
                        // 🔧 关键修复：对于手势返回到Tab根页面，通知页面已经显示
                        if (!toVC.hidesBottomBarWhenPushed && toVC.tabBarController && success) {
                            NSLog(@"在局Claude Code[手势诊断]+准备发送Tab激活通知和执行恢复策略");
                            
                            // 🔧 关键修复：延迟更长时间，让JavaScript环境完全稳定
                            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                                NSLog(@"在局Claude Code[手势诊断]+1.2秒后开始执行Tab激活流程（等待JavaScript环境稳定）");
                                
                                // 🔧 新增：JavaScript环境稳定性检查
                                if ([toVC respondsToSelector:@selector(webView)]) {
                                    UIView *webView = [toVC valueForKey:@"webView"];
                                    NSLog(@"在局Claude Code[手势诊断]+激活前WebView状态: 存在=%@, hidden=%@, alpha=%.2f", 
                                          webView ? @"YES" : @"NO",
                                          webView ? (webView.hidden ? @"YES" : @"NO") : @"N/A",
                                          webView ? webView.alpha : 0.0);
                                          
                                    // 🔧 关键修复：检查JavaScript环境是否稳定
                                    if (webView && [webView isKindOfClass:NSClassFromString(@"WKWebView")]) {
                                        NSLog(@"在局Claude Code[手势诊断]+开始JavaScript环境稳定性检查");
                                        
                                        SEL evalJSSel = NSSelectorFromString(@"evaluateJavaScript:completionHandler:");
                                        if ([webView respondsToSelector:evalJSSel]) {
                                            NSString *testJS = @"(function(){ try { return 'js_env_stable'; } catch(e) { return 'js_env_error'; } })()";
                                            
                                            NSMethodSignature *sig = [webView methodSignatureForSelector:evalJSSel];
                                            NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
                                            [inv setTarget:webView];
                                            [inv setSelector:evalJSSel];
                                            [inv setArgument:&testJS atIndex:2];
                                            
                                            void (^stabilityHandler)(id, NSError *) = ^(id result, NSError *error) {
                                                if (error || !result || ![result isKindOfClass:[NSString class]] || ![(NSString *)result isEqualToString:@"js_env_stable"]) {
                                                    NSLog(@"在局Claude Code[手势诊断]+⚠️ JavaScript环境不稳定，尝试重新初始化桥接");
                                                    
                                                    // JavaScript环境异常，强制重新初始化
                                                    if ([toVC respondsToSelector:@selector(isBridgeReady)] && [toVC respondsToSelector:@selector(setIsBridgeReady:)]) {
                                                        SEL setReadySel = NSSelectorFromString(@"setIsBridgeReady:");
                                                        NSMethodSignature *setReadySig = [toVC methodSignatureForSelector:setReadySel];
                                                        NSInvocation *setReadyInv = [NSInvocation invocationWithMethodSignature:setReadySig];
                                                        [setReadyInv setTarget:toVC];
                                                        [setReadyInv setSelector:setReadySel];
                                                        BOOL falseValue = NO;
                                                        [setReadyInv setArgument:&falseValue atIndex:2];
                                                        [setReadyInv invoke];
                                                    }
                                                    
                                                    if ([toVC respondsToSelector:@selector(setupUnifiedJavaScriptBridge)]) {
                                                        SEL setupSel = NSSelectorFromString(@"setupUnifiedJavaScriptBridge");
                                                        NSMethodSignature *setupSig = [toVC methodSignatureForSelector:setupSel];
                                                        NSInvocation *setupInv = [NSInvocation invocationWithMethodSignature:setupSig];
                                                        [setupInv setTarget:toVC];
                                                        [setupInv setSelector:setupSel];
                                                        [setupInv invoke];
                                                        NSLog(@"在局Claude Code[手势诊断]+✅ 已重新初始化JavaScript桥接");
                                                    }
                                                } else {
                                                    NSLog(@"在局Claude Code[手势诊断]+✅ JavaScript环境稳定: %@", result);
                                                }
                                            };
                                            [inv setArgument:&stabilityHandler atIndex:3];
                                            [inv invoke];
                                        }
                                    }
                                }
                                
                                // 发送页面显示通知
                                [[NSNotificationCenter defaultCenter] postNotificationName:@"showTabviewController" object:toVC];
                                NSLog(@"在局Claude Code[手势诊断]+已发送showTabviewController通知");
                                
                                // 确保页面恢复策略执行
                                if ([toVC respondsToSelector:@selector(executePageReloadStrategies)]) {
                                    NSLog(@"在局Claude Code[手势诊断]+准备执行页面恢复策略");
                                    SEL reloadSel = NSSelectorFromString(@"executePageReloadStrategies");
                                    NSMethodSignature *signature = [toVC methodSignatureForSelector:reloadSel];
                                    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
                                    [invocation setTarget:toVC];
                                    [invocation setSelector:reloadSel];
                                    [invocation invoke];
                                    NSLog(@"在局Claude Code[手势诊断]+页面恢复策略执行完成");
                                } else {
                                    NSLog(@"在局Claude Code[手势诊断]+目标控制器不支持executePageReloadStrategies方法");
                                }
                                
                                // 手动触发一次viewDidAppear
                                if ([toVC respondsToSelector:@selector(viewDidAppear:)]) {
                                    NSLog(@"在局Claude Code[手势诊断]+准备手动触发viewDidAppear");
                                    [toVC viewDidAppear:YES];
                                    NSLog(@"在局Claude Code[手势诊断]+viewDidAppear触发完成");
                                } else {
                                    NSLog(@"在局Claude Code[手势诊断]+目标控制器不支持viewDidAppear方法");
                                }
                                
                                // 最终检查WebView状态和页面内容
                                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                                    if ([toVC respondsToSelector:@selector(webView)]) {
                                        UIView *webView = [toVC valueForKey:@"webView"];
                                        NSLog(@"在局Claude Code[手势诊断]+激活后WebView状态: 存在=%@, hidden=%@, alpha=%.2f", 
                                              webView ? @"YES" : @"NO",
                                              webView ? (webView.hidden ? @"YES" : @"NO") : @"N/A",
                                              webView ? webView.alpha : 0.0);
                                              
                                        // 执行JavaScript页面内容检查
                                        if (webView && [webView isKindOfClass:NSClassFromString(@"WKWebView")]) {
                                            SEL evalJSSel = NSSelectorFromString(@"evaluateJavaScript:completionHandler:");
                                            if ([webView respondsToSelector:evalJSSel]) {
                                                NSString *jsCode = @"(function(){"
                                                    "return {"
                                                        "documentReady: document.readyState,"
                                                        "bodyExists: !!document.body,"
                                                        "bodyHeight: document.body ? document.body.offsetHeight : 0,"
                                                        "bodyDisplay: document.body ? window.getComputedStyle(document.body).display : 'N/A',"
                                                        "bodyVisibility: document.body ? window.getComputedStyle(document.body).visibility : 'N/A',"
                                                        "hasContent: document.body ? document.body.textContent.trim().length > 0 : false,"
                                                        "contentPreview: document.body ? document.body.textContent.substring(0, 100) : 'N/A'"
                                                    "};"
                                                "})()";
                                                
                                                NSMethodSignature *sig = [webView methodSignatureForSelector:evalJSSel];
                                                NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
                                                [inv setTarget:webView];
                                                [inv setSelector:evalJSSel];
                                                [inv setArgument:&jsCode atIndex:2];
                                                
                                                void (^completionHandler)(id, NSError *) = ^(id result, NSError *error) {
                                                    if (error) {
                                                        NSLog(@"在局Claude Code[手势诊断]+页面内容检查失败: %@", error.localizedDescription);
                                                    } else {
                                                        NSLog(@"在局Claude Code[手势诊断]+页面内容检查结果: %@", result);
                                                    }
                                                };
                                                [inv setArgument:&completionHandler atIndex:3];
                                                [inv invoke];
                                            }
                                        }
                                    }
                                });
                            });
                        }
                    }
                }
            });
        }
    };
    
    // 根据是否是交互式转场选择不同的动画方法
    if (isInteractive) {
        // 交互式转场使用标准动画，避免spring效果导致的完成回调延迟
        [UIView animateWithDuration:duration
                              delay:0
                            options:UIViewAnimationOptionCurveLinear
                         animations:animationBlock
                         completion:completionBlock];
    } else {
        // 非交互式转场可以使用spring动画
        [UIView animateWithDuration:duration
                              delay:0
             usingSpringWithDamping:self.springDamping
              initialSpringVelocity:self.springVelocity
                            options:UIViewAnimationOptionCurveEaseInOut
                         animations:animationBlock
                         completion:completionBlock];
    }
}

- (void)addShadowToView:(UIView *)view {
    view.layer.shadowColor = [UIColor blackColor].CGColor;
    view.layer.shadowOffset = CGSizeMake(-2, 0);
    view.layer.shadowOpacity = 0.2;
    view.layer.shadowRadius = 8.0;
    view.layer.masksToBounds = NO;
    
    UIBezierPath *shadowPath = [UIBezierPath bezierPathWithRect:view.bounds];
    view.layer.shadowPath = shadowPath.CGPath;
}

- (void)removeShadowFromView:(UIView *)view {
    view.layer.shadowColor = nil;
    view.layer.shadowOffset = CGSizeZero;
    view.layer.shadowOpacity = 0.0;
    view.layer.shadowRadius = 0.0;
    view.layer.shadowPath = nil;
}

@end

#pragma mark - XZNavigationController

@interface XZNavigationController ()

/**
 * 自定义滑动转场动画控制器（内联实现）
 */
@property (nonatomic, strong) XZInlineSlideAnimator *slideAnimator;

/**
 * 交互式返回手势控制器
 */
@property (nonatomic, strong) UIPercentDrivenInteractiveTransition *interactiveTransition;

/**
 * 是否正在进行交互式转场
 */
@property (nonatomic, assign) BOOL isInteractiveTransition;

/**
 * 交互式转场是否已经开始（用于跟踪整个手势周期）
 */
@property (nonatomic, assign) BOOL interactiveTransitionStarted;

@end

@implementation XZNavigationController


- (void)viewDidLoad
{
    [super viewDidLoad];
    self.navigationBar.backgroundColor = [UIColor whiteColor];
    self.navigationBar.barTintColor = [UIColor whiteColor];
    self.navigationBar.tintColor = [UIColor whiteColor];
    // 确保导航栏默认是显示的
    [self setNavigationBarHidden:NO animated:NO];
    
    // 设置默认值
    self.enableCustomTransition = YES;
    self.transitionDuration = 0.3; // 进一步调慢动画速度，让用户有更好的控制感
    
    // 创建自定义转场动画控制器
    self.slideAnimator = [[XZInlineSlideAnimator alloc] init];
    
    // 配置转场动画参数
    [self configureTransitionAnimator];
    
    // 设置代理
    self.delegate = self;
    
    // 配置交互式返回手势
    [self setupInteractiveGesture];
    
    // 监听交互式转场取消通知
    [[NSNotificationCenter defaultCenter] addObserver:self 
                                             selector:@selector(handleInteractiveTransitionCancelled:) 
                                                 name:@"InteractiveTransitionCancelled" 
                                               object:nil];
}


#pragma mark - Setup Methods

/**
 * 设置交互式返回手势
 */
- (void)setupInteractiveGesture {
    // 禁用系统默认的交互式返回手势，使用自定义的
    self.interactivePopGestureRecognizer.enabled = NO;
    
    // 先移除所有现有的pan手势
    NSArray *existingGestures = [self.view.gestureRecognizers copy];
    for (UIGestureRecognizer *gesture in existingGestures) {
        if ([gesture isKindOfClass:[UIPanGestureRecognizer class]]) {
            [self.view removeGestureRecognizer:gesture];
        }
    }
    
    // 添加自定义的边缘滑动手势
    UIScreenEdgePanGestureRecognizer *edgePanGesture = [[UIScreenEdgePanGestureRecognizer alloc] initWithTarget:self action:@selector(handleEdgePanGesture:)];
    edgePanGesture.edges = UIRectEdgeLeft;
    edgePanGesture.delegate = self;
    [self.view addGestureRecognizer:edgePanGesture];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    // 验证手势配置
    [self verifyGestureConfiguration];
}

/**
 * 验证手势配置是否正确
 */
- (void)verifyGestureConfiguration {
    
    // 1. 检查系统手势是否已禁用
    
    // 2. 检查自定义手势
    NSInteger edgeGestureCount = 0;
    NSInteger panGestureCount = 0;
    
    for (UIGestureRecognizer *gesture in self.view.gestureRecognizers) {
        if ([gesture isKindOfClass:[UIScreenEdgePanGestureRecognizer class]]) {
            edgeGestureCount++;
        } else if ([gesture isKindOfClass:[UIPanGestureRecognizer class]]) {
            panGestureCount++;
        }
    }
    
    // 3. 验证结果
    BOOL isConfigCorrect = (edgeGestureCount == 1 && panGestureCount == 0);
}


#pragma mark - Configuration

/**
 * 配置转场动画参数（可供子类重写）
 */
- (void)configureTransitionAnimator {
    self.slideAnimator.animationDuration = self.transitionDuration;
    self.slideAnimator.backgroundOffsetRatio = 0.3;
    self.slideAnimator.springDamping = 1.0;
    self.slideAnimator.springVelocity = 0.0;
}

/**
 * 是否应该允许交互式返回（可供子类重写）
 */
- (BOOL)shouldAllowInteractivePopForViewController:(UIViewController *)viewController {
    // 默认允许返回手势
    // 子类可以重写此方法来禁用特定页面的返回手势
    return YES;
}

#pragma mark - Navigation Override

- (void)pushViewController:(UIViewController *)viewController animated:(BOOL)animated {
    
    // 在push前禁用交互式手势，防止冲突
    self.interactivePopGestureRecognizer.enabled = NO;
    
    // 🔧 关键修复：如果新页面需要隐藏TabBar，在push前将其移出屏幕
    if (viewController.hidesBottomBarWhenPushed && self.tabBarController) {
        UITabBar *tabBar = self.tabBarController.tabBar;
        CGRect oldFrame = tabBar.frame;
        CGRect tabBarFrame = tabBar.frame;
        tabBarFrame.origin.y = [UIScreen mainScreen].bounds.size.height;
        tabBar.frame = tabBarFrame;
        NSLog(@"在局Claude Code[TabBar位置修改]+Push前将TabBar移出屏幕");
        NSLog(@"在局Claude Code[TabBar位置修改]+原始frame: %@", NSStringFromCGRect(oldFrame));
        NSLog(@"在局Claude Code[TabBar位置修改]+新的frame: %@", NSStringFromCGRect(tabBar.frame));
        NSLog(@"在局Claude Code[TabBar位置修改]+屏幕高度: %.0f", [UIScreen mainScreen].bounds.size.height);
    }
    
    [super pushViewController:viewController animated:animated];
}

- (UIViewController *)popViewControllerAnimated:(BOOL)animated {
    UIViewController *poppedVC = [super popViewControllerAnimated:animated];
    return poppedVC;
}

#pragma mark - UINavigationControllerDelegate

- (id<UIViewControllerAnimatedTransitioning>)navigationController:(UINavigationController *)navigationController
                                  animationControllerForOperation:(UINavigationControllerOperation)operation
                                               fromViewController:(UIViewController *)fromVC
                                                 toViewController:(UIViewController *)toVC {
    
    
    // 如果禁用了自定义转场动画，返回nil使用系统默认动画
    if (!self.enableCustomTransition) {
        return nil;
    }
    
    // 关键修复：如果是交互式转场，必须返回动画控制器才能触发交互控制器方法
    if (self.isInteractiveTransition && operation == UINavigationControllerOperationPop) {
        
        // 为交互式转场配置动画控制器
        self.slideAnimator.isPresenting = NO; // Pop操作
        self.slideAnimator.animationDuration = self.transitionDuration;
        
        return self.slideAnimator;
    }
    
    // 临时修复：非交互式转场使用系统默认动画
    
    return nil;
}

- (id<UIViewControllerInteractiveTransitioning>)navigationController:(UINavigationController *)navigationController
                         interactionControllerForAnimationController:(id<UIViewControllerAnimatedTransitioning>)animationController {
    
    
    // 关键修复：只要是交互式转场就返回交互控制器
    if (self.isInteractiveTransition && self.interactiveTransition) {
        return self.interactiveTransition;
    }
    
    return nil;
}

- (void)navigationController:(UINavigationController *)navigationController 
       didShowViewController:(UIViewController *)viewController 
                    animated:(BOOL)animated {
    
    // 🔧 关键修复：先保存交互式转场状态，用于后续判断
    BOOL wasInteractiveTransition = self.isInteractiveTransition || self.interactiveTransitionStarted;
    
    // 重置交互式转场状态
    self.isInteractiveTransition = NO;
    self.interactiveTransition = nil;
    self.interactiveTransitionStarted = NO;
    
    // 根据视图控制器数量决定是否启用返回手势
    // 注意：我们使用自定义手势，所以保持系统手势禁用
    self.interactivePopGestureRecognizer.enabled = NO;
    
    // 🔧 关键修复：在导航完成后手动控制TabBar显示状态和位置
    // 使用self.topViewController来获取当前真正显示的视图控制器
    UIViewController *currentVC = self.topViewController;
    if (self.tabBarController && currentVC) {
        UITabBar *tabBar = self.tabBarController.tabBar;
        CGFloat screenHeight = [UIScreen mainScreen].bounds.size.height;
        CGFloat tabBarHeight = tabBar.frame.size.height;
        
        if (currentVC.hidesBottomBarWhenPushed) {
            // 当前页面需要隐藏TabBar - 移出屏幕
            CGRect oldFrame = tabBar.frame;
            CGRect tabBarFrame = tabBar.frame;
            tabBarFrame.origin.y = screenHeight;
            tabBar.frame = tabBarFrame;
            NSLog(@"在局Claude Code[TabBar位置修改]+导航完成，将TabBar移出屏幕 (currentVC: %@)", NSStringFromClass([currentVC class]));
            NSLog(@"在局Claude Code[TabBar位置修改]+原始frame: %@", NSStringFromCGRect(oldFrame));
            NSLog(@"在局Claude Code[TabBar位置修改]+新的frame: %@", NSStringFromCGRect(tabBar.frame));
        } else {
            // 当前页面需要显示TabBar - 恢复到正确位置
            NSLog(@"在局Claude Code[TabBar恢复]+导航完成，准备恢复TabBar (currentVC: %@)", NSStringFromClass([currentVC class]));
            
            // 恢复所有属性
            tabBar.alpha = 1.0;
            tabBar.hidden = NO;
            tabBar.userInteractionEnabled = YES;
            
            // 恢复frame
            CGRect oldFrame = tabBar.frame;
            CGRect tabBarFrame = tabBar.frame;
            tabBarFrame.origin.y = screenHeight - tabBarHeight;
            
            NSLog(@"在局Claude Code[TabBar恢复]+原始frame: %@", NSStringFromCGRect(oldFrame));
            NSLog(@"在局Claude Code[TabBar恢复]+目标frame: %@", NSStringFromCGRect(tabBarFrame));
            
            // 使用动画平滑过渡
            [UIView animateWithDuration:0.25 animations:^{
                tabBar.frame = tabBarFrame;
                tabBar.alpha = 1.0;
            } completion:^(BOOL finished) {
                // 🔧 关键修复：确保TabBar完全恢复交互能力
                tabBar.userInteractionEnabled = YES;
                // 恢复到父视图的正常层级
                if (tabBar.superview) {
                    [tabBar.superview bringSubviewToFront:tabBar];
                }
                NSLog(@"在局Claude Code[TabBar恢复]+动画完成，最终frame: %@, alpha: %.2f, userInteractionEnabled: %@", 
                      NSStringFromCGRect(tabBar.frame), tabBar.alpha, 
                      tabBar.userInteractionEnabled ? @"YES" : @"NO");
                
                // 确保TabBar的所有子视图也可以交互
                for (UIView *subview in tabBar.subviews) {
                    subview.userInteractionEnabled = YES;
                }
            }];
        }
    }
    
    // 确保TabBar的显示状态正确
    [self configureTabBarVisibilityForViewController:viewController];
    
    // 根本问题已在转场动画中修复，不再需要额外的TabBar位置检查
    
    // 🔧 优化：避免重复触发pageShow导致首页空白
    // 只在必要时处理WebView状态
    static NSTimeInterval lastWebViewHandleTime = 0;
    NSTimeInterval currentTime = [[NSDate date] timeIntervalSince1970];
    
    // 如果距离上次处理不到0.5秒，跳过处理
    if (currentTime - lastWebViewHandleTime < 0.5) {
        NSLog(@"在局Claude Code[WebView处理]+跳过重复处理，避免首页空白");
        return;
    }
    
    // 检查是否需要处理WebView状态
    // 🔧 关键修复：只有在Tab切换时才跳过处理，手势返回不算Tab切换
    BOOL isTabSwitch = NO;
    // Tab切换的判断条件：不是动画导航且是根视图控制器
    if (!animated && viewController.tabBarController) {
        UIViewController *selectedVC = viewController.tabBarController.selectedViewController;
        if (selectedVC == self || 
            (selectedVC == viewController.navigationController && 
             [(UINavigationController *)selectedVC viewControllers].count == 1)) {
            isTabSwitch = YES;
        }
    }
    
    // 对于手势返回到Tab根页面，不触发domainOperate
    BOOL isInteractivePopToTabRoot = wasInteractiveTransition && 
                                      !viewController.hidesBottomBarWhenPushed && 
                                      viewController.tabBarController;
    
    // 🔧 关键修复：针对手势返回到Tab根页面的特殊处理
    if (isInteractivePopToTabRoot && [viewController respondsToSelector:@selector(webView)]) {
        NSLog(@"在局Claude Code[手势诊断]+检测到手势返回Tab根页面，执行特殊修复逻辑");
        
        // 🔧 关键修复：延迟更长时间，让JavaScript环境完全稳定
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIView *webView = [viewController valueForKey:@"webView"];
            if (webView) {
                NSLog(@"在局Claude Code[手势诊断]+1.2秒后开始执行手势返回页面修复");
                
                // 1. 确保WebView完全可见
                webView.hidden = NO;
                webView.alpha = 1.0;
                webView.userInteractionEnabled = YES;
                [viewController.view bringSubviewToFront:webView];
                
                // 🔧 关键修复：移除所有可能的遮罩视图
                NSLog(@"在局Claude Code[手势诊断]+开始清理可能的遮罩视图");
                NSArray *subviews = [viewController.view.subviews copy];
                for (UIView *subview in subviews) {
                    if (subview == webView) continue; // 跳过WebView本身
                    
                    // 检查是否可能是遮罩视图
                    BOOL isSuspiciousMask = NO;
                    NSString *className = NSStringFromClass([subview class]);
                    
                    // 1. 检查frame是否覆盖WebView
                    if (CGRectIntersectsRect(subview.frame, webView.frame) && 
                        !subview.hidden && subview.alpha > 0.01) {
                        
                        // 2. 检查是否是空视图或只包含加载指示器
                        if (subview.subviews.count == 0 ||
                            (subview.subviews.count == 1 && 
                             ([NSStringFromClass([subview.subviews.firstObject class]) containsString:@"Activity"] ||
                              [NSStringFromClass([subview.subviews.firstObject class]) containsString:@"Indicator"]))) {
                            isSuspiciousMask = YES;
                            NSLog(@"在局Claude Code[手势诊断]+发现疑似遮罩视图: %@ frame: %@", 
                                  className, NSStringFromCGRect(subview.frame));
                        }
                        
                        // 3. 检查是否是纯色背景视图
                        if (subview.backgroundColor && 
                            (subview.backgroundColor == [UIColor whiteColor] ||
                             subview.backgroundColor == [UIColor clearColor] ||
                             [className isEqualToString:@"UIView"])) {
                            isSuspiciousMask = YES;
                            NSLog(@"在局Claude Code[手势诊断]+发现疑似背景遮罩: %@", className);
                        }
                    }
                    
                    // 移除疑似遮罩视图
                    if (isSuspiciousMask) {
                        NSLog(@"在局Claude Code[手势诊断]+✅ 移除遮罩视图: %@", className);
                        [subview removeFromSuperview];
                    }
                }
                
                // 2. 强制触发视图重新布局
                [viewController.view setNeedsLayout];
                [viewController.view layoutIfNeeded];
                
                // 🔧 关键修复：修复WebView的scrollView状态
                if ([webView respondsToSelector:@selector(scrollView)]) {
                    UIScrollView *scrollView = [webView valueForKey:@"scrollView"];
                    if (scrollView) {
                        NSLog(@"在局Claude Code[手势诊断]+修复scrollView状态");
                        // 重置contentOffset到顶部
                        scrollView.contentOffset = CGPointZero;
                        // 强制刷新scrollView
                        [scrollView setNeedsLayout];
                        [scrollView layoutIfNeeded];
                        // 触发一个微小的滚动来激活渲染
                        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                            scrollView.contentOffset = CGPointMake(0, 1);
                            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                                scrollView.contentOffset = CGPointZero;
                            });
                        });
                    }
                }
                
                // 🔧 关键修复：检查JavaScript环境是否稳定
                if ([webView isKindOfClass:NSClassFromString(@"WKWebView")]) {
                    NSLog(@"在局Claude Code[手势诊断]+开始JavaScript环境稳定性检查");
                    
                    SEL evalJSSel = NSSelectorFromString(@"evaluateJavaScript:completionHandler:");
                    if ([webView respondsToSelector:evalJSSel]) {
                        NSString *testJS = @"(function(){ try { return 'js_env_stable'; } catch(e) { return 'js_env_error'; } })()";
                        
                        NSMethodSignature *sig = [webView methodSignatureForSelector:evalJSSel];
                        NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
                        [inv setTarget:webView];
                        [inv setSelector:evalJSSel];
                        [inv setArgument:&testJS atIndex:2];
                        
                        void (^stabilityHandler)(id, NSError *) = ^(id result, NSError *error) {
                            if (error || !result || ![result isKindOfClass:[NSString class]] || ![(NSString *)result isEqualToString:@"js_env_stable"]) {
                                NSLog(@"在局Claude Code[手势诊断]+⚠️ JavaScript环境不稳定: %@", error ? error.localizedDescription : @"结果异常");
                                
                                // 🔧 关键修复：JavaScript环境异常时，强制重新加载页面作为fallback
                                NSLog(@"在局Claude Code[手势诊断]+执行终极修复：强制重新加载页面");
                                if ([viewController respondsToSelector:@selector(domainOperate)]) {
                                    SEL domainSel = NSSelectorFromString(@"domainOperate");
                                    NSMethodSignature *domainSig = [viewController methodSignatureForSelector:domainSel];
                                    NSInvocation *domainInv = [NSInvocation invocationWithMethodSignature:domainSig];
                                    [domainInv setTarget:viewController];
                                    [domainInv setSelector:domainSel];
                                    [domainInv invoke];
                                    NSLog(@"在局Claude Code[手势诊断]+✅ 终极修复：domainOperate已执行");
                                }
                                
                                // JavaScript环境异常，尝试重新初始化桥接
                                if ([viewController respondsToSelector:@selector(isBridgeReady)] && [viewController respondsToSelector:@selector(setIsBridgeReady:)]) {
                                    SEL setReadySel = NSSelectorFromString(@"setIsBridgeReady:");
                                    NSMethodSignature *setReadySig = [viewController methodSignatureForSelector:setReadySel];
                                    NSInvocation *setReadyInv = [NSInvocation invocationWithMethodSignature:setReadySig];
                                    [setReadyInv setTarget:viewController];
                                    [setReadyInv setSelector:setReadySel];
                                    BOOL falseValue = NO;
                                    [setReadyInv setArgument:&falseValue atIndex:2];
                                    [setReadyInv invoke];
                                }
                                
                                if ([viewController respondsToSelector:@selector(setupUnifiedJavaScriptBridge)]) {
                                    SEL setupSel = NSSelectorFromString(@"setupUnifiedJavaScriptBridge");
                                    NSMethodSignature *setupSig = [viewController methodSignatureForSelector:setupSel];
                                    NSInvocation *setupInv = [NSInvocation invocationWithMethodSignature:setupSig];
                                    [setupInv setTarget:viewController];
                                    [setupInv setSelector:setupSel];
                                    [setupInv invoke];
                                    NSLog(@"在局Claude Code[手势诊断]+✅ 已重新初始化JavaScript桥接");
                                }
                            } else {
                                NSLog(@"在局Claude Code[手势诊断]+✅ JavaScript环境稳定: %@", result);
                            }
                        };
                        [inv setArgument:&stabilityHandler atIndex:3];
                        [inv invoke];
                    }
                }
                
                // 3. 延迟执行页面恢复策略，确保JavaScript环境已经稳定
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    
                    // 🔧 关键修复：在执行页面恢复策略之前，先进行快速内容检查
                    if ([webView isKindOfClass:NSClassFromString(@"WKWebView")]) {
                        NSString *quickCheckJS = @"(function(){ try { return document.body ? document.body.innerHTML.length : -1; } catch(e) { return -2; } })()";
                        
                        SEL evalJSSel = NSSelectorFromString(@"evaluateJavaScript:completionHandler:");
                        if ([webView respondsToSelector:evalJSSel]) {
                            NSMethodSignature *sig = [webView methodSignatureForSelector:evalJSSel];
                            NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
                            [inv setTarget:webView];
                            [inv setSelector:evalJSSel];
                            [inv setArgument:&quickCheckJS atIndex:2];
                            
                            void (^quickCheckHandler)(id, NSError *) = ^(id result, NSError *error) {
                                NSInteger contentLength = -999;
                                if (!error && result && [result isKindOfClass:[NSNumber class]]) {
                                    contentLength = [(NSNumber *)result integerValue];
                                }
                                
                                NSLog(@"在局Claude Code[手势诊断]+快速内容检查结果: %ld", (long)contentLength);
                                
                                // 如果JavaScript执行失败或页面内容为空，立即执行domainOperate
                                if (error || contentLength < 50) {
                                    NSLog(@"在局Claude Code[手势诊断]+⚠️ 快速检查发现问题，立即执行domainOperate修复");
                                    if ([viewController respondsToSelector:@selector(domainOperate)]) {
                                        SEL domainSel = NSSelectorFromString(@"domainOperate");
                                        NSMethodSignature *domainSig = [viewController methodSignatureForSelector:domainSel];
                                        NSInvocation *domainInv = [NSInvocation invocationWithMethodSignature:domainSig];
                                        [domainInv setTarget:viewController];
                                        [domainInv setSelector:domainSel];
                                        [domainInv invoke];
                                        NSLog(@"在局Claude Code[手势诊断]+✅ 快速修复：domainOperate已执行");
                                    }
                                    return; // 快速修复后直接返回，不执行后续策略
                                }
                                
                                // 页面内容正常，但需要强制修复显示状态
                                NSLog(@"在局Claude Code[手势诊断]+页面内容正常，但执行强制显示修复");
                                
                                // 🔧 关键修复：强制修复页面显示状态，即使内容存在
                                NSString *forceDisplayJS = @"(function(){"
                                    "try {"
                                        "console.log('在局Claude Code[强制显示修复]+开始修复页面显示状态');"
                                        
                                        // 1. 修复body显示状态
                                        "if(document.body) {"
                                            "document.body.style.display = 'block';"
                                            "document.body.style.visibility = 'visible';"
                                            "document.body.style.opacity = '1';"
                                            "console.log('在局Claude Code[强制显示修复]+修复body显示状态');"
                                        "}"
                                        
                                        // 2. 修复html显示状态
                                        "if(document.documentElement) {"
                                            "document.documentElement.style.display = 'block';"
                                            "document.documentElement.style.visibility = 'visible';"
                                            "document.documentElement.style.opacity = '1';"
                                            "console.log('在局Claude Code[强制显示修复]+修复html显示状态');"
                                        "}"
                                        
                                        // 3. 修复主要容器的显示状态
                                        "var containers = document.querySelectorAll('div, main, section, .container, .content, .page, .app');"
                                        "for(var i = 0; i < containers.length; i++) {"
                                            "var container = containers[i];"
                                            "var computed = window.getComputedStyle(container);"
                                            "if(computed.display === 'none' || computed.visibility === 'hidden' || computed.opacity === '0') {"
                                                "container.style.display = computed.display === 'none' ? 'block' : computed.display;"
                                                "container.style.visibility = 'visible';"
                                                "container.style.opacity = '1';"
                                                "console.log('在局Claude Code[强制显示修复]+修复容器显示状态: ' + container.className);"
                                            "}"
                                        "}"
                                        
                                        // 4. 强制滚动到顶部
                                        "window.scrollTo(0, 0);"
                                        "document.body.scrollTop = 0;"
                                        "if(document.documentElement) document.documentElement.scrollTop = 0;"
                                        "console.log('在局Claude Code[强制显示修复]+重置滚动位置到顶部');"
                                        
                                        // 5. 触发重新渲染
                                        "document.body.style.transform = 'translateZ(0)';"
                                        "setTimeout(function() {"
                                            "document.body.style.transform = '';"
                                        "}, 10);"
                                        "console.log('在局Claude Code[强制显示修复]+触发强制重新渲染');"
                                        
                                        // 6. 强制重新布局
                                        "document.body.offsetHeight;"
                                        "if(document.documentElement) document.documentElement.offsetHeight;"
                                        "console.log('在局Claude Code[强制显示修复]+强制重新布局');"
                                        
                                        "return 'force_display_fixed';"
                                    "} catch(e) {"
                                        "console.log('在局Claude Code[强制显示修复]+修复失败: ' + e.message);"
                                        "return 'force_display_error: ' + e.message;"
                                    "}"
                                "})()";
                                
                                NSMethodSignature *fixSig = [webView methodSignatureForSelector:evalJSSel];
                                NSInvocation *fixInv = [NSInvocation invocationWithMethodSignature:fixSig];
                                [fixInv setTarget:webView];
                                [fixInv setSelector:evalJSSel];
                                [fixInv setArgument:&forceDisplayJS atIndex:2];
                                
                                void (^forceDisplayHandler)(id, NSError *) = ^(id result, NSError *error) {
                                    if (error) {
                                        NSLog(@"在局Claude Code[手势诊断]+强制显示修复失败: %@", error.localizedDescription);
                                    } else {
                                        NSLog(@"在局Claude Code[手势诊断]+强制显示修复结果: %@", result);
                                    }
                                    
                                    // 🔧 关键修复：在JavaScript修复完成后，执行WebView层面的强制重新渲染修复
                                    dispatch_async(dispatch_get_main_queue(), ^{
                                        NSLog(@"在局Claude Code[手势诊断]+开始WebView容器层面的强制修复");
                                        
                                        // 1. 确保WebView完全可见且在正确位置
                                        webView.hidden = NO;
                                        webView.alpha = 1.0;
                                        webView.userInteractionEnabled = YES;
                                        
                                        // 2. 强制重新设置WebView的frame
                                        CGRect originalFrame = webView.frame;
                                        webView.frame = CGRectMake(originalFrame.origin.x, originalFrame.origin.y, 
                                                                  originalFrame.size.width, originalFrame.size.height);
                                        
                                        // 3. 触发WebView重新布局
                                        [webView setNeedsLayout];
                                        [webView layoutIfNeeded];
                                        
                                        // 4. 强制WebView重新绘制
                                        [webView setNeedsDisplay];
                                        [webView.layer setNeedsDisplay];
                                        
                                        // 5. 强制触发WebView内容重新渲染
                                        if ([webView respondsToSelector:@selector(scrollView)]) {
                                            UIScrollView *scrollView = [webView valueForKey:@"scrollView"];
                                            if (scrollView) {
                                                // 微调scrollView来强制重新渲染
                                                CGPoint originalOffset = scrollView.contentOffset;
                                                scrollView.contentOffset = CGPointMake(originalOffset.x, originalOffset.y + 1);
                                                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                                                    scrollView.contentOffset = originalOffset;
                                                    NSLog(@"在局Claude Code[手势诊断]+WebView scrollView强制重新渲染完成");
                                                });
                                            }
                                        }
                                        
                                        // 6. 确保WebView在视图层级的最前面
                                        [viewController.view bringSubviewToFront:webView];
                                        
                                        // 7. 强制父视图重新布局
                                        [viewController.view setNeedsLayout];
                                        [viewController.view layoutIfNeeded];
                                        
                                        NSLog(@"在局Claude Code[手势诊断]+WebView容器层面的强制修复完成");
                                        
                                        // 8. 最后验证修复结果
                                        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                                            NSLog(@"在局Claude Code[手势诊断]+最终修复验证 - WebView状态: hidden=%@, alpha=%.2f, frame=%@", 
                                                  webView.hidden ? @"YES" : @"NO", 
                                                  webView.alpha, 
                                                  NSStringFromCGRect(webView.frame));
                                                  
                                            // 最后一次页面内容检查
                                            NSString *finalCheckJS = @"(function(){ try { return { bodyVisible: document.body && window.getComputedStyle(document.body).display !== 'none', contentLength: document.body ? document.body.innerHTML.length : 0, scrollTop: window.pageYOffset || document.documentElement.scrollTop }; } catch(e) { return { error: e.message }; } })()";
                                            
                                            NSMethodSignature *checkSig = [webView methodSignatureForSelector:evalJSSel];
                                            NSInvocation *checkInv = [NSInvocation invocationWithMethodSignature:checkSig];
                                            [checkInv setTarget:webView];
                                            [checkInv setSelector:evalJSSel];
                                            [checkInv setArgument:&finalCheckJS atIndex:2];
                                            
                                            void (^finalCheckHandler)(id, NSError *) = ^(id checkResult, NSError *checkError) {
                                                if (checkError) {
                                                    NSLog(@"在局Claude Code[手势诊断]+最终验证失败: %@", checkError.localizedDescription);
                                                } else {
                                                    NSLog(@"在局Claude Code[手势诊断]+最终验证结果: %@", checkResult);
                                                    NSLog(@"在局Claude Code[手势诊断]+🎯 强制显示修复流程全部完成！");
                                                }
                                            };
                                            [checkInv setArgument:&finalCheckHandler atIndex:3];
                                            [checkInv invoke];
                                        });
                                    });
                                };
                                [fixInv setArgument:&forceDisplayHandler atIndex:3];
                                [fixInv invoke];
                                
                                // 如果支持页面可见性修复，也执行修复
                                if ([viewController respondsToSelector:@selector(checkAndFixPageVisibility)]) {
                                    SEL fixSel = NSSelectorFromString(@"checkAndFixPageVisibility");
                                    NSMethodSignature *signature = [viewController methodSignatureForSelector:fixSel];
                                    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
                                    [invocation setTarget:viewController];
                                    [invocation setSelector:fixSel];
                                    [invocation invoke];
                                    NSLog(@"在局Claude Code[手势诊断]+已触发页面可见性检查和修复");
                                }
                                
                                // 如果支持页面恢复策略，执行恢复
                                if ([viewController respondsToSelector:@selector(executePageReloadStrategies)]) {
                                    SEL reloadSel = NSSelectorFromString(@"executePageReloadStrategies");
                                    NSMethodSignature *signature = [viewController methodSignatureForSelector:reloadSel];
                                    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
                                    [invocation setTarget:viewController];
                                    [invocation setSelector:reloadSel];
                                    [invocation invoke];
                                    NSLog(@"在局Claude Code[手势诊断]+已触发页面恢复策略");
                                }
                            };
                            [inv setArgument:&quickCheckHandler atIndex:3];
                            [inv invoke];
                        } else {
                            NSLog(@"在局Claude Code[手势诊断]+WebView不支持JavaScript执行，直接执行domainOperate");
                            if ([viewController respondsToSelector:@selector(domainOperate)]) {
                                SEL domainSel = NSSelectorFromString(@"domainOperate");
                                NSMethodSignature *domainSig = [viewController methodSignatureForSelector:domainSel];
                                NSInvocation *domainInv = [NSInvocation invocationWithMethodSignature:domainSig];
                                [domainInv setTarget:viewController];
                                [domainInv setSelector:domainSel];
                                [domainInv invoke];
                                NSLog(@"在局Claude Code[手势诊断]+✅ 无JS环境时的修复：domainOperate已执行");
                            }
                        }
                    } else {
                        NSLog(@"在局Claude Code[手势诊断]+非WKWebView，执行常规恢复策略");
                        
                        // 如果支持页面可见性修复，执行修复
                        if ([viewController respondsToSelector:@selector(checkAndFixPageVisibility)]) {
                            SEL fixSel = NSSelectorFromString(@"checkAndFixPageVisibility");
                            NSMethodSignature *signature = [viewController methodSignatureForSelector:fixSel];
                            NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
                            [invocation setTarget:viewController];
                            [invocation setSelector:fixSel];
                            [invocation invoke];
                            NSLog(@"在局Claude Code[手势诊断]+已触发页面可见性检查和修复");
                        }
                        
                        // 如果支持页面恢复策略，执行恢复
                        if ([viewController respondsToSelector:@selector(executePageReloadStrategies)]) {
                            SEL reloadSel = NSSelectorFromString(@"executePageReloadStrategies");
                            NSMethodSignature *signature = [viewController methodSignatureForSelector:reloadSel];
                            NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
                            [invocation setTarget:viewController];
                            [invocation setSelector:reloadSel];
                            [invocation invoke];
                            NSLog(@"在局Claude Code[手势诊断]+已触发页面恢复策略");
                        }
                    }
                    
                    // 🔧 终极修复方案：如果页面仍然空白，强制重新加载
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        // 检查页面是否真的有内容
                        if ([webView isKindOfClass:NSClassFromString(@"WKWebView")]) {
                            NSString *checkContentJS = @"(function(){ return document.body ? document.body.innerHTML.length : 0; })()";
                            
                            SEL evalJSSel = NSSelectorFromString(@"evaluateJavaScript:completionHandler:");
                            if ([webView respondsToSelector:evalJSSel]) {
                                NSMethodSignature *sig = [webView methodSignatureForSelector:evalJSSel];
                                NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
                                [inv setTarget:webView];
                                [inv setSelector:evalJSSel];
                                [inv setArgument:&checkContentJS atIndex:2];
                                
                                void (^contentHandler)(id, NSError *) = ^(id result, NSError *error) {
                                    NSInteger contentLength = 0;
                                    if (result && [result isKindOfClass:[NSNumber class]]) {
                                        contentLength = [(NSNumber *)result integerValue];
                                    }
                                    
                                    NSLog(@"在局Claude Code[手势诊断]+页面内容长度: %ld", (long)contentLength);
                                    
                                    // 如果页面内容为空或很少，强制重新加载
                                    if (contentLength < 100) {
                                        NSLog(@"在局Claude Code[手势诊断]+⚠️ 检测到页面内容为空，执行终极修复方案");
                                        
                                        // 强制重新执行domainOperate
                                        if ([viewController respondsToSelector:@selector(domainOperate)]) {
                                            SEL domainSel = NSSelectorFromString(@"domainOperate");
                                            NSMethodSignature *domainSig = [viewController methodSignatureForSelector:domainSel];
                                            NSInvocation *domainInv = [NSInvocation invocationWithMethodSignature:domainSig];
                                            [domainInv setTarget:viewController];
                                            [domainInv setSelector:domainSel];
                                            [domainInv invoke];
                                            NSLog(@"在局Claude Code[手势诊断]+✅ 已强制执行domainOperate");
                                        }
                                    }
                                };
                                [inv setArgument:&contentHandler atIndex:3];
                                [inv invoke];
                            }
                        }
                    });
                });
                
                // 🔧 新增：详细的视图层级诊断，查找可能的遮罩
                [self diagnoseViewHierarchyForViewController:viewController];
                
                NSLog(@"在局Claude Code[手势诊断]+手势返回页面修复完成");
            } else {
                NSLog(@"在局Claude Code[手势诊断]+手势返回修复失败: WebView不存在");
            }
        });
    }
    
    // 添加调试日志
    NSLog(@"在局Claude Code[WebView状态检查]+wasInteractive: %@, isTabSwitch: %@, isInteractivePopToTabRoot: %@, viewController: %@", 
          wasInteractiveTransition ? @"YES" : @"NO",
          isTabSwitch ? @"YES" : @"NO",
          isInteractivePopToTabRoot ? @"YES" : @"NO",
          NSStringFromClass([viewController class]));
    
    // 🔧 关键修复：手势返回Tab根页面时不再跳过WebView状态检查
    // 特殊修复逻辑作为补充，正常的WebView状态检查仍然需要执行
    if ([viewController respondsToSelector:@selector(webView)] && 
        [viewController respondsToSelector:@selector(pinUrl)] &&
        !isTabSwitch) {
        
        NSLog(@"在局Claude Code[WebView状态检查]+将要处理WebView状态");
        lastWebViewHandleTime = currentTime;
        dispatch_async(dispatch_get_main_queue(), ^{
            [self handleWebViewStateForViewController:viewController];
        });
    } else {
        NSLog(@"在局Claude Code[WebView状态检查]+跳过WebView处理");
    }
    
    // 清理可能残留的视图
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
        // 检查并移除不应该存在的视图
        for (UIViewController *vc in self.viewControllers) {
            if (vc != viewController && vc.view.superview && vc.view.superview != vc.navigationController.view) {
                [vc.view removeFromSuperview];
            }
        }
    });
}

#pragma mark - Helper Methods

/**
 * 判断是否应该使用自定义动画
 */
- (BOOL)shouldUseCustomAnimationForFromVC:(UIViewController *)fromVC 
                                     toVC:(UIViewController *)toVC 
                                operation:(UINavigationControllerOperation)operation {
    
    
    // 检查是否为WebView相关的页面
    BOOL fromIsWebView = [fromVC isKindOfClass:[CFJClientH5Controller class]] || 
                        [fromVC isKindOfClass:NSClassFromString(@"XZWKWebViewBaseController")];
    BOOL toIsWebView = [toVC isKindOfClass:[CFJClientH5Controller class]] || 
                      [toVC isKindOfClass:NSClassFromString(@"XZWKWebViewBaseController")];
    
    
    // 只要涉及WebView页面就使用自定义动画
    BOOL shouldUse = fromIsWebView || toIsWebView;
    
    return shouldUse;
}

#pragma mark - 在局Claude Code[转场动画优化]+通知处理

/**
 * 处理交互式转场取消通知
 */
- (void)handleInteractiveTransitionCancelled:(NSNotification *)notification {
    NSDictionary *userInfo = notification.userInfo;
    UIViewController *toVC = userInfo[@"toViewController"];
    UIViewController *fromVC = userInfo[@"fromViewController"];
    
    if (toVC) {
        [self restoreWebViewStateForViewController:toVC withDelay:0.1];
    }
    if (fromVC) {
        [self restoreWebViewStateForViewController:fromVC withDelay:0.2];
    }
}

#pragma mark - 在局Claude Code[转场动画优化]+WebView状态管理

/**
 * 恢复WebView状态（统一方法）
 */
- (void)restoreWebViewStateForViewController:(UIViewController *)viewController withDelay:(NSTimeInterval)delay {
    if (![viewController respondsToSelector:@selector(webView)]) {
        return;
    }
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIView *webView = [viewController valueForKey:@"webView"];
        if (webView) {
            [self configureWebViewState:webView forViewController:viewController];
            [self invokeWebViewRestoreMethodForViewController:viewController];
        }
    });
}

/**
 * 配置WebView状态
 */
- (void)configureWebViewState:(UIView *)webView forViewController:(UIViewController *)viewController {
    // 确保WebView可见和可交互
    webView.hidden = NO;
    webView.alpha = 1.0;
    webView.userInteractionEnabled = YES;
    
    // 确保WebView在视图层级的正确位置
    [viewController.view bringSubviewToFront:webView];
    
    // 重新设置WebView的frame，确保显示正确
    if (CGRectEqualToRect(webView.frame, CGRectZero)) {
        webView.frame = viewController.view.bounds;
    }
}

/**
 * 调用WebView恢复方法
 */
- (void)invokeWebViewRestoreMethodForViewController:(UIViewController *)viewController {
    if (![viewController respondsToSelector:@selector(restoreWebViewStateAfterInteractiveTransition)]) {
        return;
    }
    
    SEL restoreSel = NSSelectorFromString(@"restoreWebViewStateAfterInteractiveTransition");
    NSMethodSignature *signature = [viewController methodSignatureForSelector:restoreSel];
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
    [invocation setTarget:viewController];
    [invocation setSelector:restoreSel];
    [invocation invoke];
}

/**
 * 处理WebView状态（包括重新创建和恢复）
 */
- (void)handleWebViewStateForViewController:(UIViewController *)viewController {
    if (![viewController respondsToSelector:@selector(webView)] || 
        ![viewController respondsToSelector:@selector(pinUrl)]) {
        return;
    }
    
    UIView *webView = [viewController valueForKey:@"webView"];
    NSString *pinUrl = [viewController valueForKey:@"pinUrl"];
    
    if (!webView && pinUrl && pinUrl.length > 0) {
        // WebView不存在但有URL，说明这是一个新实例，需要重新加载
        [self triggerWebViewReloadForViewController:viewController];
    } else if (webView) {
        // WebView存在，恢复其状态
        [self configureWebViewState:webView forViewController:viewController];
        [self invokeWebViewRestoreMethodForViewController:viewController];
    }
}

/**
 * 触发WebView重新加载
 */
- (void)triggerWebViewReloadForViewController:(UIViewController *)viewController {
    if (![viewController respondsToSelector:@selector(domainOperate)]) {
        return;
    }
    
    SEL domainOperateSel = NSSelectorFromString(@"domainOperate");
    NSMethodSignature *signature = [viewController methodSignatureForSelector:domainOperateSel];
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
    [invocation setTarget:viewController];
    [invocation setSelector:domainOperateSel];
    [invocation invoke];
}

#pragma mark - 在局Claude Code[转场动画优化]+TabBar管理

/**
 * 配置TabBar显示状态（统一方法）
 * 🔧 修复：不再手动设置TabBar的hidden属性，让系统自动处理
 */
- (void)configureTabBarVisibilityForViewController:(UIViewController *)viewController {
    if (!viewController.tabBarController) {
        return;
    }
    
    // 只打印调试信息，不进行实际操作
    NSLog(@"在局Claude Code[TabBar配置]+viewController: %@, hidesBottomBarWhenPushed: %@", 
          NSStringFromClass([viewController class]), 
          viewController.hidesBottomBarWhenPushed ? @"YES" : @"NO");
    
    // 移除手动设置TabBar hidden的逻辑
    // iOS系统会自动处理
}

/**
 * 判断是否应该隐藏TabBar
 */
- (BOOL)shouldHideTabBarForViewController:(UIViewController *)viewController {
    // 首先检查控制器本身的设置
    if (viewController.hidesBottomBarWhenPushed) {
        return YES; // 如果控制器明确要求隐藏，则隐藏
    }
    
    // 检查是否有TabBarController
    if (!viewController.tabBarController) {
        return YES; // 没有TabBarController，隐藏
    }
    
    // 判断是否是TabBarController的直接子控制器的根视图
    BOOL isTabRootViewController = NO;
    NSArray *tabViewControllers = viewController.tabBarController.viewControllers;
    
    for (UIViewController *tabVC in tabViewControllers) {
        if ([tabVC isKindOfClass:[UINavigationController class]]) {
            UINavigationController *navVC = (UINavigationController *)tabVC;
            // 检查viewController是否是某个tab的导航控制器的根视图控制器
            if (navVC == self && navVC.viewControllers.count == 1 && navVC.viewControllers.firstObject == viewController) {
                isTabRootViewController = YES;
                break;
            }
        } else if (tabVC == viewController) {
            // 直接是tab的视图控制器（非导航控制器包装）
            isTabRootViewController = YES;
            break;
        }
    }
    
    // 只有是Tab的根视图控制器时才显示TabBar（返回NO表示不隐藏）
    return !isTabRootViewController;
}

/**
 * 调整TabBar frame
 */
- (void)adjustTabBarFrameForViewController:(UIViewController *)viewController {
    UITabBar *tabBar = viewController.tabBarController.tabBar;
    UIView *containerView = viewController.tabBarController.view;
    
    CGRect tabBarFrame = tabBar.frame;
    CGFloat tabBarHeight = CGRectGetHeight(tabBarFrame);
    CGFloat screenHeight = CGRectGetHeight(containerView.bounds);
    tabBarFrame.origin.y = screenHeight - tabBarHeight;
    tabBar.frame = tabBarFrame;
    
    // 确保TabBar在视图层级的最前面
    [containerView bringSubviewToFront:tabBar];
}

#pragma mark - Interactive Gesture

/**
 * 处理边缘滑动手势
 */
- (void)handleEdgePanGesture:(UIScreenEdgePanGestureRecognizer *)gesture {
    CGPoint translation = [gesture translationInView:gesture.view];
    CGFloat progress = translation.x / gesture.view.bounds.size.width;
    progress = MAX(0.0, MIN(1.0, progress));
    
    
    switch (gesture.state) {
        case UIGestureRecognizerStateBegan: {
            // 只在开始时检查导航栈，后续状态不检查
            if (self.viewControllers.count <= 1) {
                NSLog(@"在局Claude Code[手势诊断]+导航栈只有一个控制器，取消手势");
                return;
            }
            
            // 🔧 新增：详细的手势开始诊断日志
            UIViewController *currentVC = self.topViewController;
            UIViewController *toVC = nil;
            if (self.viewControllers.count >= 2) {
                toVC = [self.viewControllers objectAtIndex:self.viewControllers.count - 2];
            }
            
            NSLog(@"在局Claude Code[手势诊断]+手势开始");
            NSLog(@"在局Claude Code[手势诊断]+导航栈数量: %ld", (long)self.viewControllers.count);
            NSLog(@"在局Claude Code[手势诊断]+当前控制器: %@ (hidesBottomBar: %@)", 
                  NSStringFromClass([currentVC class]), 
                  currentVC.hidesBottomBarWhenPushed ? @"YES" : @"NO");
            NSLog(@"在局Claude Code[手势诊断]+目标控制器: %@ (hidesBottomBar: %@)", 
                  NSStringFromClass([toVC class]), 
                  toVC ? (toVC.hidesBottomBarWhenPushed ? @"YES" : @"NO") : @"NO");
            
            // 检查当前WebView的状态
            if ([currentVC respondsToSelector:@selector(webView)]) {
                UIView *webView = [currentVC valueForKey:@"webView"];
                NSLog(@"在局Claude Code[手势诊断]+当前WebView状态: 存在=%@, hidden=%@, alpha=%.2f, frame=%@", 
                      webView ? @"YES" : @"NO",
                      webView ? (webView.hidden ? @"YES" : @"NO") : @"N/A",
                      webView ? webView.alpha : 0.0,
                      webView ? NSStringFromCGRect(webView.frame) : @"N/A");
            }
            
            // 检查目标WebView的状态
            if ([toVC respondsToSelector:@selector(webView)]) {
                UIView *webView = [toVC valueForKey:@"webView"];
                NSLog(@"在局Claude Code[手势诊断]+目标WebView状态: 存在=%@, hidden=%@, alpha=%.2f, frame=%@", 
                      webView ? @"YES" : @"NO",
                      webView ? (webView.hidden ? @"YES" : @"NO") : @"N/A",
                      webView ? webView.alpha : 0.0,
                      webView ? NSStringFromCGRect(webView.frame) : @"N/A");
            }
            
            // 确保delegate被正确设置
            if (self.delegate != self) {
                self.delegate = self;
                NSLog(@"在局Claude Code[手势诊断]+设置delegate为self");
            } else {
                NSLog(@"在局Claude Code[手势诊断]+delegate已正确设置");
            }
            
            // 🔧 关键修复：在手势开始时，检查是否需要临时移动TabBar
            
            // 如果是从隐藏TabBar的页面返回到显示TabBar的页面，需要特殊处理
            if (currentVC.hidesBottomBarWhenPushed && toVC && !toVC.hidesBottomBarWhenPushed && self.tabBarController) {
                UITabBar *tabBar = self.tabBarController.tabBar;
                
                NSLog(@"在局Claude Code[TabBar隐藏]+手势开始，准备隐藏TabBar");
                NSLog(@"在局Claude Code[TabBar隐藏]+原始状态 - hidden: %@, alpha: %.2f, frame: %@", 
                      tabBar.hidden ? @"YES" : @"NO", tabBar.alpha, NSStringFromCGRect(tabBar.frame));
                
                // 保存原始状态，用于恢复
                objc_setAssociatedObject(tabBar, @"originalAlpha", @(tabBar.alpha), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                objc_setAssociatedObject(tabBar, @"originalHidden", @(tabBar.hidden), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                
                // 使用多重方案确保TabBar被隐藏
                tabBar.alpha = 0.0;
                tabBar.hidden = YES;
                
                // 移出屏幕
                CGFloat screenHeight = CGRectGetHeight([UIScreen mainScreen].bounds);
                CGRect tabBarFrame = tabBar.frame;
                tabBarFrame.origin.y = screenHeight + 100;
                tabBar.frame = tabBarFrame;
                
                // 🔧 移除层级调整，避免破坏视图结构
                // [tabBar.superview sendSubviewToBack:tabBar];
                
                // 暂时禁用交互
                tabBar.userInteractionEnabled = NO;
                
                NSLog(@"在局Claude Code[TabBar隐藏]+处理后状态 - hidden: %@, alpha: %.2f, frame: %@", 
                      tabBar.hidden ? @"YES" : @"NO", tabBar.alpha, NSStringFromCGRect(tabBar.frame));
            }
            
            // 原生导航栈返回
            self.isInteractiveTransition = YES;
            self.interactiveTransition = [[UIPercentDrivenInteractiveTransition alloc] init];
            // 设置交互式转场的参数，优化动画效果
            self.interactiveTransition.completionCurve = UIViewAnimationCurveEaseOut;
            // 关键修复：设置交互式转场的时长，确保动画跟随手指
            self.interactiveTransition.completionSpeed = 1.0;
            
            
            // 在调用popViewControllerAnimated之前，确保delegate方法会被调用
            // 这是关键：确保系统知道这是一个交互式转场
            
            // 必须同步调用，否则交互式转场会失效
            UIViewController *poppedVC = [self popViewControllerAnimated:YES];
            
            if (!poppedVC) {
                self.isInteractiveTransition = NO;
                self.interactiveTransition = nil;
                self.interactiveTransitionStarted = NO;
                
            } else {
                // 设置转场已开始标志
                self.interactiveTransitionStarted = YES;
            }
            break;
        }
        case UIGestureRecognizerStateChanged: {
            
            // 只有在转场已经开始的情况下才更新进度
            if (self.interactiveTransitionStarted && self.interactiveTransition) {
                [self.interactiveTransition updateInteractiveTransition:progress];
            } else {
            }
            break;
        }
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled: {
            CGFloat velocity = [gesture velocityInView:gesture.view].x;
            // 优化完成判断逻辑：进度超过40%或速度超过300即可完成
            BOOL shouldComplete = progress > 0.4 || velocity > 300;
            
            // 如果手势被取消（比如用户手指离开了屏幕边缘），则取消转场
            if (gesture.state == UIGestureRecognizerStateCancelled) {
                shouldComplete = NO;
            }
            
            
            if (self.interactiveTransition) {
                if (shouldComplete) {
                    // 修复：设置合适的完成速度，确保动画流畅且不会过快
                    // 使用固定的速度避免动画突然加速
                    CGFloat completionSpeed = MIN(1.5, MAX(0.5, 1.0)); // 限制在0.5-1.5倍速之间
                    self.interactiveTransition.completionSpeed = completionSpeed;
                    [self.interactiveTransition finishInteractiveTransition];
                    
                    // 🔧 关键修复：移除手势结束时的TabBar显示逻辑
                    // TabBar的显示应该完全由转场动画完成回调来控制，确保时机正确
                        
                    // 添加额外的清理逻辑，确保视图被正确移除
                    if (self.viewControllers.count >= 2) {
                        UIViewController *fromVC = self.topViewController;
                        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                            // 确保fromVC的视图已从其父视图中移除
                            if (fromVC.view.superview && fromVC != self.topViewController) {
                                [fromVC.view removeFromSuperview];
                            }
                        });
                    }
                } else {
                    // 修复：设置合适的取消速度，确保返回动画流畅且不会过快
                    CGFloat cancelSpeed = MIN(2.0, MAX(0.8, 1.2)); // 限制在0.8-2.0倍速之间
                    self.interactiveTransition.completionSpeed = cancelSpeed;
                    [self.interactiveTransition cancelInteractiveTransition];
                    
                    // 🔧 关键修复：手势取消时，确保TabBar位置正确
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        UIViewController *currentVC = self.topViewController;
                        if (currentVC && self.tabBarController) {
                            UITabBar *tabBar = self.tabBarController.tabBar;
                            CGFloat screenHeight = [UIScreen mainScreen].bounds.size.height;
                            CGFloat tabBarHeight = tabBar.frame.size.height;
                            CGRect tabBarFrame = tabBar.frame;
                            
                            if (currentVC.hidesBottomBarWhenPushed) {
                                // 当前页面需要隐藏TabBar - 确保完全隐藏
                                tabBar.alpha = 0.0;
                                tabBar.hidden = YES;
                                tabBarFrame.origin.y = screenHeight + 100;
                                tabBar.frame = tabBarFrame;
                                tabBar.userInteractionEnabled = NO;
                                NSLog(@"在局Claude Code[TabBar手势取消]+保持TabBar隐藏");
                                NSLog(@"在局Claude Code[TabBar手势取消]+frame: %@, hidden: %@, alpha: %.2f", 
                                      NSStringFromCGRect(tabBar.frame), tabBar.hidden ? @"YES" : @"NO", tabBar.alpha);
                            } else {
                                // 当前页面需要显示TabBar - 完全恢复
                                tabBar.alpha = 1.0;
                                tabBar.hidden = NO;
                                tabBarFrame.origin.y = screenHeight - tabBarHeight;
                                tabBar.frame = tabBarFrame;
                                tabBar.userInteractionEnabled = YES;
                                NSLog(@"在局Claude Code[TabBar手势取消]+恢复TabBar显示");
                                NSLog(@"在局Claude Code[TabBar手势取消]+frame: %@, hidden: %@, alpha: %.2f", 
                                      NSStringFromCGRect(tabBar.frame), tabBar.hidden ? @"YES" : @"NO", tabBar.alpha);
                            }
                        }
                    });
                }
            } else {
            }
            
            // 🔧 关键修复：延迟清理交互状态，确保didShowViewController能正确识别
            // 不在这里立即清理，在didShowViewController中清理，确保状态能被正确识别
            NSLog(@"在局Claude Code[手势诊断]+手势结束，转场状态: isInteractive=%@, transitionStarted=%@", 
                  self.isInteractiveTransition ? @"YES" : @"NO",
                  self.interactiveTransitionStarted ? @"YES" : @"NO");
            break;
        }
        default:
            break;
    }
}

#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    
    // 只有在有多个视图控制器时才允许手势
    if (self.viewControllers.count <= 1) {
        return NO;
    }
    
    // 检查是否为边缘滑动手势
    if ([gestureRecognizer isKindOfClass:[UIScreenEdgePanGestureRecognizer class]]) {
        // 获取手势位置
        CGPoint location = [gestureRecognizer locationInView:self.view];
        
        // 检查当前视图控制器是否允许返回手势
        UIViewController *topViewController = self.topViewController;
        
        BOOL shouldAllow = [self shouldAllowInteractivePopForViewController:topViewController];
        
        if (!shouldAllow) {
            return NO;
        }
        
        return YES;
    }
    
    return YES;
}

// 防止手势冲突
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    // 减少日志输出，只在关键冲突时输出
    if ([gestureRecognizer isKindOfClass:[UIScreenEdgePanGestureRecognizer class]]) {
        // 如果另一个手势来自WebView的scrollView，我们需要特殊处理
        if ([otherGestureRecognizer.view isKindOfClass:[UIScrollView class]]) {
            // 检查scrollView是否在左边缘可以滚动
            UIScrollView *scrollView = (UIScrollView *)otherGestureRecognizer.view;
            if (scrollView.contentOffset.x <= 0) {
                return NO; // 不允许同时识别，让返回手势优先
            }
        }
        
        // 对于边缘手势，只与ScrollView相关手势互斥，其他手势可以同时识别以避免阻塞
        NSString *gestureClassName = NSStringFromClass([otherGestureRecognizer class]);
        if ([gestureClassName containsString:@"UIScrollView"]) {
            return NO;
        }
        
        // 其他手势允许同时识别
        return YES;
    }
    
    // 默认不允许同时识别多个手势
    return NO;
}

// 手势优先级判断
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRequireFailureOfGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    // 如果是边缘手势，不需要等待其他手势失败
    if ([gestureRecognizer isKindOfClass:[UIScreenEdgePanGestureRecognizer class]]) {
        return NO;
    }
    return NO;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldBeRequiredToFailByGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    // 如果是边缘手势，其他手势应该等待边缘手势失败
    if ([gestureRecognizer isKindOfClass:[UIScreenEdgePanGestureRecognizer class]]) {
        if ([otherGestureRecognizer.view isKindOfClass:[UIScrollView class]]) {
            UIScrollView *scrollView = (UIScrollView *)otherGestureRecognizer.view;
            if (scrollView.contentOffset.x <= 0) {
                return YES;
            }
        }
    }
    return NO;
}

/**
 * 诊断视图层级，查找可能遮挡WebView的视图
 */
- (void)diagnoseViewHierarchyForViewController:(UIViewController *)viewController {
    NSLog(@"在局Claude Code[视图诊断]+开始视图层级分析");
    
    UIView *mainView = viewController.view;
    UIView *webView = nil;
    
    if ([viewController respondsToSelector:@selector(webView)]) {
        webView = [viewController valueForKey:@"webView"];
    }
    
    if (!webView) {
        NSLog(@"在局Claude Code[视图诊断]+WebView不存在，无法进行对比分析");
        return;
    }
    
    NSLog(@"在局Claude Code[视图诊断]+主视图: %@, frame: %@", NSStringFromClass([mainView class]), NSStringFromCGRect(mainView.frame));
    NSLog(@"在局Claude Code[视图诊断]+WebView: %@, frame: %@", NSStringFromClass([webView class]), NSStringFromCGRect(webView.frame));
    
    // 检查TabBar相关状态
    if (viewController.tabBarController) {
        UITabBar *tabBar = viewController.tabBarController.tabBar;
        NSLog(@"在局Claude Code[视图诊断]+TabBar状态: hidden=%@, alpha=%.2f, frame=%@", 
              tabBar.hidden ? @"YES" : @"NO", tabBar.alpha, NSStringFromCGRect(tabBar.frame));
        NSLog(@"在局Claude Code[视图诊断]+TabBar父视图: %@", NSStringFromClass([tabBar.superview class]));
        
        // 检查TabBarController的view状态
        UIView *tabBarControllerView = viewController.tabBarController.view;
        NSLog(@"在局Claude Code[视图诊断]+TabBarController视图: frame=%@, subviews=%ld", 
              NSStringFromCGRect(tabBarControllerView.frame), (long)tabBarControllerView.subviews.count);
    }
    
    // 检查导航控制器状态
    if (viewController.navigationController) {
        NSLog(@"在局Claude Code[视图诊断]+导航控制器视图: frame=%@, subviews=%ld", 
              NSStringFromCGRect(viewController.navigationController.view.frame), 
              (long)viewController.navigationController.view.subviews.count);
    }
    
    // 分析主视图的所有子视图
    NSArray *subviews = mainView.subviews;
    NSLog(@"在局Claude Code[视图诊断]+主视图子视图数量: %ld", (long)subviews.count);
    
    for (int i = 0; i < subviews.count; i++) {
        UIView *subview = subviews[i];
        NSString *className = NSStringFromClass([subview class]);
        CGRect frame = subview.frame;
        BOOL hidden = subview.hidden;
        CGFloat alpha = subview.alpha;
        BOOL userInteractionEnabled = subview.userInteractionEnabled;
        
        NSLog(@"在局Claude Code[视图诊断]+子视图[%d]: %@", i, className);
        NSLog(@"在局Claude Code[视图诊断]+  frame: %@", NSStringFromCGRect(frame));
        NSLog(@"在局Claude Code[视图诊断]+  hidden: %@, alpha: %.2f, userInteraction: %@", 
              hidden ? @"YES" : @"NO", alpha, userInteractionEnabled ? @"YES" : @"NO");
        
        // 🔧 关键修复：改进遮挡检查逻辑
        BOOL coversWebView = NO;
        BOOL isWebViewItself = (subview == webView);
        
        // 如果是WebView本身，跳过遮挡检查
        if (isWebViewItself) {
            NSLog(@"在局Claude Code[视图诊断]+这是WebView本身，跳过遮挡检查");
        } else if (!hidden && alpha > 0.01) {
            // 检查frame是否覆盖WebView，但排除WebView本身
            if (CGRectContainsRect(frame, webView.frame) || 
                CGRectIntersectsRect(frame, webView.frame)) {
                coversWebView = YES;
            }
        } else if (hidden && CGRectEqualToRect(frame, webView.frame)) {
            // 特殊情况：完全相同frame但被隐藏的视图可能是WebView容器
            NSLog(@"在局Claude Code[视图诊断]+发现隐藏的同尺寸视图: %@", className);
            
            // 🔧 关键修复：检查是否是网络错误视图，不要显示它！
            BOOL isNetworkErrorView = NO;
            
            // 检查是否是networkNoteView（网络错误提示视图）
            if ([className isEqualToString:@"UIView"] && subview.subviews.count > 0) {
                for (UIView *childView in subview.subviews) {
                    if ([childView isKindOfClass:[UIButton class]]) {
                        UIButton *button = (UIButton *)childView;
                        NSString *buttonTitle = [button titleForState:UIControlStateNormal];
                        if ([buttonTitle containsString:@"网络连接失败"] || 
                            [buttonTitle containsString:@"点击重试"] ||
                            [buttonTitle containsString:@"重新加载"]) {
                            isNetworkErrorView = YES;
                            NSLog(@"在局Claude Code[视图诊断]+识别为网络错误页面，按钮文字: %@", buttonTitle);
                            break;
                        }
                    }
                }
            }
            
            if (isNetworkErrorView) {
                NSLog(@"在局Claude Code[视图诊断]+✅ 检测到网络错误页面，保持隐藏状态（不显示）");
                // 确保网络错误页面保持隐藏
                dispatch_async(dispatch_get_main_queue(), ^{
                    subview.hidden = YES;
                    subview.alpha = 0.0;
                });
            } else if ([className isEqualToString:@"UIView"]) {
                // 只有不是网络错误页面的UIView容器才考虑显示
                NSLog(@"在局Claude Code[视图诊断]+可能是WebView容器，但当前保持隐藏状态");
                // 暂时不自动显示，等待进一步分析
            }
        }
        
        if (coversWebView) {
            NSLog(@"在局Claude Code[视图诊断]+⚠️ 发现可能的遮挡视图: %@", className);
            NSLog(@"在局Claude Code[视图诊断]+    视图背景色: %@", subview.backgroundColor);
            
            // 检查是否是可疑的遮罩视图
            BOOL isSuspiciousMask = NO;
            
            // 1. 检查类名特征
            if ([className containsString:@"Loading"] || 
                [className containsString:@"Activity"] ||
                [className containsString:@"Indicator"] ||
                [className containsString:@"Mask"] ||
                [className containsString:@"Overlay"] ||
                [className containsString:@"Cover"]) {
                isSuspiciousMask = YES;
                NSLog(@"在局Claude Code[视图诊断]+🔍 通过类名识别为遮罩视图");
            }
            
            // 2. 检查frame特征（完全覆盖或大面积覆盖）
            if (CGRectContainsRect(frame, webView.frame) && 
                (frame.size.width >= webView.frame.size.width * 0.8) &&
                (frame.size.height >= webView.frame.size.height * 0.8)) {
                isSuspiciousMask = YES;
                NSLog(@"在局Claude Code[视图诊断]+🔍 通过尺寸特征识别为遮罩视图");
            }
            
            // 3. 检查背景色特征（透明或白色可能是遮罩）
            if (subview.backgroundColor) {
                CGFloat red, green, blue, alpha;
                [subview.backgroundColor getRed:&red green:&green blue:&blue alpha:&alpha];
                
                // 透明视图或白色视图都可能是遮罩
                if (alpha < 0.9 || (red > 0.9 && green > 0.9 && blue > 0.9)) {
                    NSLog(@"在局Claude Code[视图诊断]+🔍 疑似透明/白色遮罩视图 RGBA(%.2f,%.2f,%.2f,%.2f)", red, green, blue, alpha);
                    isSuspiciousMask = YES;
                }
            }
            
            // 4. 检查子视图内容（如果子视图很少，可能是空的遮罩）
            if (subview.subviews.count == 0 || 
                (subview.subviews.count == 1 && [NSStringFromClass([subview.subviews.firstObject class]) containsString:@"Activity"])) {
                NSLog(@"在局Claude Code[视图诊断]+🔍 疑似空内容遮罩视图");
                isSuspiciousMask = YES;
            }
            
            if (isSuspiciousMask) {
                NSLog(@"在局Claude Code[视图诊断]+⚠️ 确认为可疑遮罩，准备移除/隐藏");
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    // 先尝试隐藏，而不是直接移除
                    subview.hidden = YES;
                    subview.alpha = 0.0;
                    subview.userInteractionEnabled = NO;
                    
                    // 如果确认是遮罩类视图，才移除
                    if ([className containsString:@"Mask"] || 
                        [className containsString:@"Overlay"] ||
                        [className containsString:@"Loading"]) {
                        [subview removeFromSuperview];
                        NSLog(@"在局Claude Code[视图诊断]+✅ 已移除遮挡视图: %@", className);
                    } else {
                        NSLog(@"在局Claude Code[视图诊断]+✅ 已隐藏可疑遮挡视图: %@", className);
                    }
                });
            } else {
                NSLog(@"在局Claude Code[视图诊断]+ℹ️ 普通遮挡视图，保持原状: %@", className);
            }
        }
        
        // 检查视图的z-index（通过subview顺序判断）
        if (subview == webView) {
            NSLog(@"在局Claude Code[视图诊断]+WebView在子视图中的位置: %d（数字越大越在前面）", i);
        }
        
        // 如果子视图还有子视图，递归检查
        if (subview.subviews.count > 0) {
            NSLog(@"在局Claude Code[视图诊断]+  该视图还有 %ld 个子视图", (long)subview.subviews.count);
            [self diagnoseSubviewsRecursively:subview.subviews depth:1 webViewFrame:webView.frame];
        }
    }
    
    // 检查WebView是否在最前面
    if (webView.superview) {
        NSArray *siblings = webView.superview.subviews;
        NSInteger webViewIndex = [siblings indexOfObject:webView];
        NSLog(@"在局Claude Code[视图诊断]+WebView在同级视图中的位置: %ld/%ld", (long)webViewIndex, (long)siblings.count);
        
        if (webViewIndex < siblings.count - 1) {
            NSLog(@"在局Claude Code[视图诊断]+⚠️ WebView不在最前面，尝试置顶");
            dispatch_async(dispatch_get_main_queue(), ^{
                [webView.superview bringSubviewToFront:webView];
                NSLog(@"在局Claude Code[视图诊断]+✅ WebView已置顶");
            });
        }
    }
}

/**
 * 递归诊断子视图
 */
- (void)diagnoseSubviewsRecursively:(NSArray *)subviews depth:(NSInteger)depth webViewFrame:(CGRect)webViewFrame {
    if (depth > 3) return; // 限制递归深度
    
    NSString *indent = [@"" stringByPaddingToLength:depth * 2 withString:@" " startingAtIndex:0];
    
    for (UIView *subview in subviews) {
        NSString *className = NSStringFromClass([subview class]);
        CGRect frame = subview.frame;
        BOOL hidden = subview.hidden;
        CGFloat alpha = subview.alpha;
        
        NSLog(@"在局Claude Code[视图诊断]+%@子视图: %@, frame: %@, hidden: %@, alpha: %.2f", 
              indent, className, NSStringFromCGRect(frame), hidden ? @"YES" : @"NO", alpha);
        
        // 检查深层子视图是否可能遮挡
        if (!hidden && alpha > 0.01 && CGRectIntersectsRect(frame, webViewFrame)) {
            if ([className containsString:@"Loading"] || 
                [className containsString:@"Activity"] ||
                [className containsString:@"Indicator"] ||
                [className containsString:@"Mask"] ||
                [className containsString:@"Overlay"]) {
                NSLog(@"在局Claude Code[视图诊断]+%@🔍 发现深层遮挡视图: %@", indent, className);
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    subview.hidden = YES;
                    subview.alpha = 0.0;
                    NSLog(@"在局Claude Code[视图诊断]+%@✅ 已隐藏深层遮挡视图: %@", indent, className);
                });
            }
        }
        
        // 继续递归
        if (subview.subviews.count > 0) {
            [self diagnoseSubviewsRecursively:subview.subviews depth:depth + 1 webViewFrame:webViewFrame];
        }
    }
}

- (void)dealloc {
    // 移除通知观察者
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"InteractiveTransitionCancelled" object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
