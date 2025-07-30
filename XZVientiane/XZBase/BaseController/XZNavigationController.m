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
        _animationDuration = 0.8; // 进一步减慢动画速度，让用户有更好的控制感
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
    NSLog(@"在局🎬 [转场动画] 开始执行%@动画", self.isPresenting ? @"进入" : @"退出");
    NSLog(@"在局🎬 [转场动画] transitionContext: %@", transitionContext);
    
    UIViewController *fromVC = [transitionContext viewControllerForKey:UITransitionContextFromViewControllerKey];
    UIViewController *toVC = [transitionContext viewControllerForKey:UITransitionContextToViewControllerKey];
    UIView *containerView = [transitionContext containerView];
    
    NSLog(@"在局🎬 [转场动画] fromVC: %@", NSStringFromClass([fromVC class]));
    NSLog(@"在局🎬 [转场动画] toVC: %@", NSStringFromClass([toVC class]));
    NSLog(@"在局🎬 [转场动画] containerView: %@", containerView);
    
    CGRect finalFrameForToVC = [transitionContext finalFrameForViewController:toVC];
    CGRect initialFrameForFromVC = [transitionContext initialFrameForViewController:fromVC];
    
    NSLog(@"在局🎬 [转场动画] finalFrameForToVC: %@", NSStringFromCGRect(finalFrameForToVC));
    NSLog(@"在局🎬 [转场动画] initialFrameForFromVC: %@", NSStringFromCGRect(initialFrameForFromVC));
    
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
    
    [containerView addSubview:toVC.view];
    toVC.view.frame = finalFrame;
    
    CGRect startFrame = finalFrame;
    startFrame.origin.x = CGRectGetMaxX(containerView.bounds);
    toVC.view.frame = startFrame;
    
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
    
    NSLog(@"在局🎬 [转场动画] animateDismissalWithContext 开始执行");
    NSLog(@"在局🎬 [转场动画] containerView bounds: %@", NSStringFromCGRect(containerView.bounds));
    NSLog(@"在局🎬 [转场动画] fromVC.view: %@, frame: %@", fromVC.view, NSStringFromCGRect(fromVC.view.frame));
    NSLog(@"在局🎬 [转场动画] toVC.view: %@, frame: %@", toVC.view, NSStringFromCGRect(toVC.view.frame));
    
    // 确保toVC.view已经被添加到视图层次结构中
    if (toVC.view.superview != containerView) {
        NSLog(@"在局🎬 [转场动画] 将toVC.view插入到containerView中");
        [containerView insertSubview:toVC.view belowSubview:fromVC.view];
    } else {
        NSLog(@"在局🎬 [转场动画] toVC.view已经在containerView中");
    }
    
    CGRect backgroundInitialFrame = finalFrame;
    backgroundInitialFrame.origin.x = -CGRectGetWidth(containerView.bounds) * self.backgroundOffsetRatio;
    toVC.view.frame = backgroundInitialFrame;
    toVC.view.alpha = 0.9;
    
    NSLog(@"在局🎬 [转场动画] toVC初始frame设置为: %@", NSStringFromCGRect(backgroundInitialFrame));
    NSLog(@"在局🎬 [转场动画] 添加阴影到fromVC.view");
    [self addShadowToView:fromVC.view];
    
    NSTimeInterval duration = [self transitionDuration:transitionContext];
    NSLog(@"在局🎬 [转场动画] 动画时长: %.2f", duration);
    NSLog(@"在局🎬 [转场动画] 开始执行UIView动画");
    
    [UIView animateWithDuration:duration
                          delay:0
         usingSpringWithDamping:self.springDamping
          initialSpringVelocity:self.springVelocity
                        options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        NSLog(@"在局🎬 [转场动画] 动画块开始执行");
        
        CGRect exitFrame = initialFrame;
        exitFrame.origin.x = CGRectGetMaxX(containerView.bounds);
        fromVC.view.frame = exitFrame;
        
        toVC.view.frame = finalFrame;
        toVC.view.alpha = 1.0;
        
        NSLog(@"在局🎬 [转场动画] fromVC退出frame: %@", NSStringFromCGRect(exitFrame));
        NSLog(@"在局🎬 [转场动画] toVC最终frame: %@", NSStringFromCGRect(finalFrame));
        NSLog(@"在局🎬 [转场动画] 动画块执行完成");
        
    } completion:^(BOOL finished) {
        NSLog(@"在局🎬 [转场动画] 动画完成回调 - finished: %@", finished ? @"YES" : @"NO");
        NSLog(@"在局🎬 [转场动画] 转场是否被取消: %@", [transitionContext transitionWasCancelled] ? @"YES" : @"NO");
        
        // 清理阴影
        [self removeShadowFromView:fromVC.view];
        
        if ([transitionContext transitionWasCancelled]) {
            NSLog(@"在局🎬 [转场动画] 转场被取消，恢复视图状态");
            fromVC.view.frame = initialFrame;
            toVC.view.frame = backgroundInitialFrame;
            toVC.view.alpha = 0.9;
            
            // 如果转场被取消，确保fromVC的视图仍然在容器中
            if (fromVC.view.superview != containerView) {
                [containerView addSubview:fromVC.view];
            }
            
            // 关键修复：转场取消后恢复WebView状态
            dispatch_async(dispatch_get_main_queue(), ^{
                if ([fromVC respondsToSelector:@selector(webView)]) {
                    UIView *webView = [fromVC valueForKey:@"webView"];
                    if (webView) {
                        NSLog(@"在局🔧 [转场取消] 开始恢复WebView状态");
                        
                        // 确保WebView可见和可交互
                        webView.hidden = NO;
                        webView.alpha = 1.0;
                        webView.userInteractionEnabled = YES;
                        
                        // 确保WebView在视图层级的正确位置
                        [fromVC.view bringSubviewToFront:webView];
                        
                        // 重新设置WebView的frame，确保显示正确
                        if (CGRectEqualToRect(webView.frame, CGRectZero)) {
                            webView.frame = fromVC.view.bounds;
                            NSLog(@"在局🔧 [转场取消] 重置WebView frame: %@", NSStringFromCGRect(webView.frame));
                        }
                        
                        // 延迟触发WebView内容刷新，确保视图层级稳定后再执行
                        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                            if ([fromVC respondsToSelector:@selector(restoreWebViewStateAfterInteractiveTransition)]) {
                                SEL restoreSel = NSSelectorFromString(@"restoreWebViewStateAfterInteractiveTransition");
                                NSMethodSignature *signature = [fromVC methodSignatureForSelector:restoreSel];
                                NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
                                [invocation setTarget:fromVC];
                                [invocation setSelector:restoreSel];
                                [invocation invoke];
                                
                                NSLog(@"在局✅ [转场取消] 已恢复WebView状态");
                            }
                            
                            // 额外保护：确保导航栏状态正确
                            if ([fromVC respondsToSelector:@selector(configureNavigationBarAndStatusBar)]) {
                                SEL configureSel = NSSelectorFromString(@"configureNavigationBarAndStatusBar");
                                NSMethodSignature *signature = [fromVC methodSignatureForSelector:configureSel];
                                NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
                                [invocation setTarget:fromVC];
                                [invocation setSelector:configureSel];
                                [invocation invoke];
                                
                                NSLog(@"在局✅ [转场取消] 已恢复导航栏状态");
                            }
                        });
                    } else {
                        NSLog(@"在局⚠️ [转场取消] fromVC没有webView属性");
                    }
                } else {
                    NSLog(@"在局⚠️ [转场取消] fromVC不响应webView选择器");
                }
            });
        } else {
            NSLog(@"在局🎬 [转场动画] 转场成功，设置最终状态");
            toVC.view.frame = finalFrame;
            toVC.view.alpha = 1.0;
            
            // 转场成功完成，确保fromVC的视图被正确移除
            // 这是关键：必须在动画完成后移除fromVC的视图
            [fromVC.view removeFromSuperview];
            NSLog(@"在局🎬 [转场动画] 已移除fromVC.view");
            
            // 如果toVC是TabBarController的子控制器，确保TabBar显示
            if (toVC.tabBarController && !toVC.hidesBottomBarWhenPushed) {
                NSLog(@"在局🎬 [转场动画] 恢复TabBar显示");
                toVC.tabBarController.tabBar.hidden = NO;
                
                // 确保TabBar的frame正确
                CGRect tabBarFrame = toVC.tabBarController.tabBar.frame;
                tabBarFrame.origin.y = CGRectGetHeight(toVC.tabBarController.view.bounds) - CGRectGetHeight(tabBarFrame);
                toVC.tabBarController.tabBar.frame = tabBarFrame;
            }
        }
        
        // 对于交互式转场，即使finished为NO，如果没有被取消，仍然应该成功完成
        BOOL success = ![transitionContext transitionWasCancelled];
        NSLog(@"在局🎬 [转场动画] 调用completeTransition: %@", success ? @"YES" : @"NO");
        [transitionContext completeTransition:success];
        
        // 额外的清理工作：确保视图层级正确
        if (success) {
            // 对于交互式转场，需要确保导航控制器的状态正确更新
            NSLog(@"在局🎬 [转场动画] 转场成功完成，当前导航栈数量: %ld", (long)toVC.navigationController.viewControllers.count);
            
            // 延迟执行额外的清理，确保转场完全结束
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                NSLog(@"在局🎬 [转场动画] 延迟清理检查");
                NSLog(@"在局🎬 [转场动画] 延迟检查时导航栈数量: %ld", (long)toVC.navigationController.viewControllers.count);
                
                // 再次确保fromVC的视图已被移除
                if (fromVC.view.superview) {
                    [fromVC.view removeFromSuperview];
                    NSLog(@"在局🎬 [转场动画] 延迟清理：移除残留的fromVC.view");
                }
                
                // 确保toVC的视图在正确的位置
                if (toVC.view.superview && toVC.navigationController) {
                    [toVC.navigationController.view bringSubviewToFront:toVC.navigationController.navigationBar];
                    
                    // 如果有TabBar，确保它在最前面
                    if (toVC.tabBarController && !toVC.hidesBottomBarWhenPushed) {
                        [toVC.tabBarController.view bringSubviewToFront:toVC.tabBarController.tabBar];
                    }
                }
            });
        }
    }];
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
    
    // 设置默认值
    self.enableCustomTransition = YES;
    self.transitionDuration = 0.8; // 进一步调慢动画速度，让用户有更好的控制感
    
    // 创建自定义转场动画控制器
    self.slideAnimator = [[XZInlineSlideAnimator alloc] init];
    
    // 配置转场动画参数
    [self configureTransitionAnimator];
    
    // 设置代理
    self.delegate = self;
    
    // 配置交互式返回手势
    [self setupInteractiveGesture];
    
    NSLog(@"在局🎯 [XZNavigationController] 自定义转场动画初始化完成");
    NSLog(@"在局🎯 [XZNavigationController] enableCustomTransition: %@", self.enableCustomTransition ? @"YES" : @"NO");
    NSLog(@"在局🎯 [XZNavigationController] slideAnimator: %@", self.slideAnimator);
    NSLog(@"在局🎯 [XZNavigationController] delegate: %@", self.delegate == self ? @"自己" : @"其他");
}


//- (BOOL)shouldAutorotate {
//    return YES;
//}

//-(UIInterfaceOrientationMask)supportedInterfaceOrientations {
//    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
//        return  UIInterfaceOrientationMaskLandscape;
//    }
//    else {
//        return  UIInterfaceOrientationMaskPortrait;
//    }
//}

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
            NSLog(@"在局🚫 [XZNavigationController] 移除现有手势: %@", gesture);
        }
    }
    
    // 添加自定义的边缘滑动手势
    UIScreenEdgePanGestureRecognizer *edgePanGesture = [[UIScreenEdgePanGestureRecognizer alloc] initWithTarget:self action:@selector(handleEdgePanGesture:)];
    edgePanGesture.edges = UIRectEdgeLeft;
    edgePanGesture.delegate = self;
    [self.view addGestureRecognizer:edgePanGesture];
    
    // 验证手势设置
    NSLog(@"在局👆 [XZNavigationController] 边缘手势创建: %@", edgePanGesture);
    NSLog(@"在局👆 [XZNavigationController] 手势目标: %@", edgePanGesture.delegate);
    NSLog(@"在局👆 [XZNavigationController] 手势边缘: %lu", (unsigned long)edgePanGesture.edges);
    NSLog(@"在局👆 [XZNavigationController] 交互式返回手势设置完成，当前手势数量: %lu", (unsigned long)self.view.gestureRecognizers.count);
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
    NSLog(@"在局🔍 [手势验证] ========== 开始验证手势配置 ==========");
    
    // 1. 检查系统手势是否已禁用
    NSLog(@"在局🔍 [手势验证] 系统手势状态: %@", self.interactivePopGestureRecognizer.enabled ? @"启用❌" : @"禁用✅");
    
    // 2. 检查自定义手势
    NSInteger edgeGestureCount = 0;
    NSInteger panGestureCount = 0;
    
    for (UIGestureRecognizer *gesture in self.view.gestureRecognizers) {
        if ([gesture isKindOfClass:[UIScreenEdgePanGestureRecognizer class]]) {
            edgeGestureCount++;
            NSLog(@"在局✅ [手势验证] 找到边缘手势: %@", gesture);
        } else if ([gesture isKindOfClass:[UIPanGestureRecognizer class]]) {
            panGestureCount++;
            NSLog(@"在局❌ [手势验证] 发现多余的Pan手势: %@", gesture);
        }
    }
    
    // 3. 验证结果
    BOOL isConfigCorrect = (edgeGestureCount == 1 && panGestureCount == 0);
    NSLog(@"在局📊 [手势验证] 边缘手势数量: %ld %@", (long)edgeGestureCount, edgeGestureCount == 1 ? @"✅" : @"❌");
    NSLog(@"在局📊 [手势验证] Pan手势数量: %ld %@", (long)panGestureCount, panGestureCount == 0 ? @"✅" : @"❌");
    NSLog(@"在局📊 [手势验证] 配置状态: %@", isConfigCorrect ? @"正确✅" : @"错误❌");
    
    NSLog(@"在局🔍 [手势验证] ========== 手势配置验证完成 ==========");
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
    NSLog(@"在局🚀 [XZNavigationController] pushViewController: %@, animated: %@", 
          NSStringFromClass([viewController class]), animated ? @"YES" : @"NO");
    NSLog(@"在局🚀 [XZNavigationController] 当前视图控制器栈数量: %ld", (long)self.viewControllers.count);
    NSLog(@"在局🚀 [XZNavigationController] 代理设置状态: %@", self.delegate == self ? @"已设置" : @"未设置");
    NSLog(@"在局🚀 [XZNavigationController] viewController.hidesBottomBarWhenPushed: %@", viewController.hidesBottomBarWhenPushed ? @"YES" : @"NO");
    
    // 在push前禁用交互式手势，防止冲突
    self.interactivePopGestureRecognizer.enabled = NO;
    
    // 如果新页面需要隐藏TabBar，在push前就设置
    if (viewController.hidesBottomBarWhenPushed && self.tabBarController) {
        NSLog(@"在局📱 [XZNavigationController] 准备隐藏TabBar");
        // 注意：不要在这里直接设置hidden，让系统的hidesBottomBarWhenPushed机制处理
        // 只是记录日志以便调试
    }
    
    [super pushViewController:viewController animated:animated];
}

- (UIViewController *)popViewControllerAnimated:(BOOL)animated {
    NSLog(@"在局🔙 [XZNavigationController] popViewController animated: %@", animated ? @"YES" : @"NO");
    NSLog(@"在局🔙 [XZNavigationController] 当前栈数量: %ld", (long)self.viewControllers.count);
    UIViewController *poppedVC = [super popViewControllerAnimated:animated];
    NSLog(@"在局🔙 [XZNavigationController] pop后栈数量: %ld", (long)self.viewControllers.count);
    NSLog(@"在局🔙 [XZNavigationController] 被pop的控制器: %@", poppedVC ? NSStringFromClass([poppedVC class]) : @"nil");
    return poppedVC;
}

#pragma mark - UINavigationControllerDelegate

- (id<UIViewControllerAnimatedTransitioning>)navigationController:(UINavigationController *)navigationController
                                  animationControllerForOperation:(UINavigationControllerOperation)operation
                                               fromViewController:(UIViewController *)fromVC
                                                 toViewController:(UIViewController *)toVC {
    
    NSLog(@"在局🔍 [转场代理] animationControllerForOperation被调用");
    NSLog(@"在局🔍 [转场代理] 操作类型: %@", operation == UINavigationControllerOperationPush ? @"Push" : @"Pop");
    NSLog(@"在局🔍 [转场代理] From控制器: %@", NSStringFromClass([fromVC class]));
    NSLog(@"在局🔍 [转场代理] To控制器: %@", NSStringFromClass([toVC class]));
    NSLog(@"在局🔍 [转场代理] 交互式转场状态: %@", self.isInteractiveTransition ? @"YES" : @"NO");
    
    // 如果禁用了自定义转场动画，返回nil使用系统默认动画
    if (!self.enableCustomTransition) {
        NSLog(@"在局⚪ [转场动画] 自定义动画已禁用，使用系统默认");
        return nil;
    }
    
    // 关键修复：如果是交互式转场，必须返回动画控制器才能触发交互控制器方法
    if (self.isInteractiveTransition && operation == UINavigationControllerOperationPop) {
        NSLog(@"在局🎬 [转场动画] 交互式Pop转场，返回自定义动画控制器");
        
        // 为交互式转场配置动画控制器
        self.slideAnimator.isPresenting = NO; // Pop操作
        self.slideAnimator.animationDuration = self.transitionDuration;
        
        return self.slideAnimator;
    }
    
    // 临时修复：非交互式转场使用系统默认动画
    NSLog(@"在局⚪ [转场动画] 非交互式转场，使用系统默认动画");
    
    return nil;
}

- (id<UIViewControllerInteractiveTransitioning>)navigationController:(UINavigationController *)navigationController
                         interactionControllerForAnimationController:(id<UIViewControllerAnimatedTransitioning>)animationController {
    
    NSLog(@"在局🎉🎉🎉 [交互转场] interactionControllerForAnimationController被调用！");
    NSLog(@"在局👆 [交互转场] animationController: %@", animationController);
    NSLog(@"在局👆 [交互转场] animationController类型: %@", NSStringFromClass([animationController class]));
    NSLog(@"在局👆 [交互转场] isInteractiveTransition: %@", self.isInteractiveTransition ? @"YES" : @"NO");
    NSLog(@"在局👆 [交互转场] interactiveTransition对象: %@", self.interactiveTransition);
    
    // 关键修复：只要是交互式转场就返回交互控制器
    if (self.isInteractiveTransition && self.interactiveTransition) {
        NSLog(@"在局👆 [交互转场] ✅ 返回交互控制器 - %@", self.interactiveTransition);
        return self.interactiveTransition;
    }
    
    NSLog(@"在局👆 [交互转场] ❌ 不返回交互控制器 (isInteractive:%@ transition:%@)", 
          self.isInteractiveTransition ? @"YES" : @"NO",
          self.interactiveTransition ? @"存在" : @"nil");
    return nil;
}

- (void)navigationController:(UINavigationController *)navigationController 
       didShowViewController:(UIViewController *)viewController 
                    animated:(BOOL)animated {
    
    NSLog(@"在局✅ [XZNavigationController] didShowViewController: %@", NSStringFromClass([viewController class]));
    NSLog(@"在局📊 [XZNavigationController] 转场完成统计 - 导航栈数量: %ld, 是否动画: %@", (long)self.viewControllers.count, animated ? @"YES" : @"NO");
    
    // 重置交互式转场状态
    self.isInteractiveTransition = NO;
    self.interactiveTransition = nil;
    self.interactiveTransitionStarted = NO;
    
    // 根据视图控制器数量决定是否启用返回手势
    // 注意：我们使用自定义手势，所以保持系统手势禁用
    self.interactivePopGestureRecognizer.enabled = NO;
    
    // 确保TabBar的显示状态正确
    if (viewController.tabBarController) {
        BOOL shouldHideTabBar = viewController.hidesBottomBarWhenPushed;
        
        // 如果是导航控制器的根视图控制器，应该显示TabBar
        if (self.viewControllers.count == 1) {
            shouldHideTabBar = NO;
        }
        
        NSLog(@"在局📱 [XZNavigationController] TabBar应该隐藏: %@", shouldHideTabBar ? @"YES" : @"NO");
        viewController.tabBarController.tabBar.hidden = shouldHideTabBar;
        
        // 如果显示TabBar，确保其frame正确
        if (!shouldHideTabBar) {
            CGRect tabBarFrame = viewController.tabBarController.tabBar.frame;
            CGFloat tabBarHeight = CGRectGetHeight(tabBarFrame);
            CGFloat screenHeight = CGRectGetHeight(viewController.tabBarController.view.bounds);
            tabBarFrame.origin.y = screenHeight - tabBarHeight;
            viewController.tabBarController.tabBar.frame = tabBarFrame;
            
            // 确保TabBar在视图层级的最前面
            [viewController.tabBarController.view bringSubviewToFront:viewController.tabBarController.tabBar];
        }
    }
    
    // 关键修复：检查并恢复WebView控制器状态
    if ([viewController respondsToSelector:@selector(webView)] && [viewController respondsToSelector:@selector(pinUrl)]) {
        NSLog(@"在局🔧 [转场恢复] 开始恢复WebView控制器状态");
        
        dispatch_async(dispatch_get_main_queue(), ^{
            UIView *webView = [viewController valueForKey:@"webView"];
            NSString *pinUrl = [viewController valueForKey:@"pinUrl"];
            
            NSLog(@"在局🔍 [转场恢复] WebView存在: %@, pinUrl: %@", webView ? @"YES" : @"NO", pinUrl ?: @"nil");
            
            if (!webView && pinUrl && pinUrl.length > 0) {
                // WebView不存在但有URL，说明这是一个新实例，需要重新加载
                NSLog(@"在局🚨 [转场恢复] 检测到空白WebView实例，触发重新加载");
                
                // 优化：立即触发domainOperate重新创建WebView，无延迟
                if ([viewController respondsToSelector:@selector(domainOperate)]) {
                    NSLog(@"在局🚀 [转场恢复] 立即触发WebView重新加载");
                    SEL domainOperateSel = NSSelectorFromString(@"domainOperate");
                    NSMethodSignature *signature = [viewController methodSignatureForSelector:domainOperateSel];
                    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
                    [invocation setTarget:viewController];
                    [invocation setSelector:domainOperateSel];
                    [invocation invoke];
                    
                    NSLog(@"在局✅ [转场恢复] 已触发WebView重新加载");
                }
            } else if (webView) {
                // WebView存在，恢复其状态
                webView.hidden = NO;
                webView.alpha = 1.0;
                webView.userInteractionEnabled = YES;
                
                // 确保WebView在视图层级的正确位置
                [viewController.view bringSubviewToFront:webView];
                
                NSLog(@"在局✅ [转场恢复] WebView状态已恢复 - frame: %@", NSStringFromCGRect(webView.frame));
                
                // 触发WebView恢复方法
                if ([viewController respondsToSelector:@selector(restoreWebViewStateAfterInteractiveTransition)]) {
                    SEL restoreSel = NSSelectorFromString(@"restoreWebViewStateAfterInteractiveTransition");
                    NSMethodSignature *signature = [viewController methodSignatureForSelector:restoreSel];
                    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
                    [invocation setTarget:viewController];
                    [invocation setSelector:restoreSel];
                    [invocation invoke];
                    
                    NSLog(@"在局✅ [转场恢复] 已触发WebView状态恢复");
                }
            } else {
                NSLog(@"在局⚠️ [转场恢复] 控制器缺少WebView和URL，无法恢复");
            }
        });
    }
    
    // 清理可能残留的视图
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSLog(@"在局🧹 [XZNavigationController] 执行延迟清理检查");
        
        // 检查并移除不应该存在的视图
        for (UIViewController *vc in self.viewControllers) {
            if (vc != viewController && vc.view.superview && vc.view.superview != vc.navigationController.view) {
                NSLog(@"在局⚠️ [XZNavigationController] 发现残留视图: %@", NSStringFromClass([vc class]));
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
    
    NSLog(@"在局🔍 [转场判断] ========== 开始页面类型检测 ==========");
    NSLog(@"在局🔍 [转场判断] FromVC类名: %@", NSStringFromClass([fromVC class]));
    NSLog(@"在局🔍 [转场判断] ToVC类名: %@", NSStringFromClass([toVC class]));
    
    // 检查是否为WebView相关的页面
    BOOL fromIsWebView = [fromVC isKindOfClass:[CFJClientH5Controller class]] || 
                        [fromVC isKindOfClass:NSClassFromString(@"XZWKWebViewBaseController")];
    BOOL toIsWebView = [toVC isKindOfClass:[CFJClientH5Controller class]] || 
                      [toVC isKindOfClass:NSClassFromString(@"XZWKWebViewBaseController")];
    
    NSLog(@"在局🔍 [转场判断] FromVC是否WebView: %@ (CFJClientH5Controller: %@, XZWKWebViewBaseController: %@)",
          fromIsWebView ? @"YES" : @"NO",
          [fromVC isKindOfClass:[CFJClientH5Controller class]] ? @"YES" : @"NO",
          [fromVC isKindOfClass:NSClassFromString(@"XZWKWebViewBaseController")] ? @"YES" : @"NO");
    
    NSLog(@"在局🔍 [转场判断] ToVC是否WebView: %@ (CFJClientH5Controller: %@, XZWKWebViewBaseController: %@)",
          toIsWebView ? @"YES" : @"NO",
          [toVC isKindOfClass:[CFJClientH5Controller class]] ? @"YES" : @"NO",
          [toVC isKindOfClass:NSClassFromString(@"XZWKWebViewBaseController")] ? @"YES" : @"NO");
    
    // 只要涉及WebView页面就使用自定义动画
    BOOL shouldUse = fromIsWebView || toIsWebView;
    
    NSLog(@"在局🔍 [转场判断] 最终决定 - 使用自定义动画: %@", shouldUse ? @"YES" : @"NO");
    NSLog(@"在局🔍 [转场判断] ========== 页面类型检测结束 ==========");
    
    return shouldUse;
}

#pragma mark - Interactive Gesture

/**
 * 处理边缘滑动手势
 */
- (void)handleEdgePanGesture:(UIScreenEdgePanGestureRecognizer *)gesture {
    CGPoint translation = [gesture translationInView:gesture.view];
    CGFloat progress = translation.x / gesture.view.bounds.size.width;
    progress = MAX(0.0, MIN(1.0, progress));
    
    NSLog(@"在局👆 [交互手势] 手势状态: %ld, 位移: (%.1f, %.1f), 进度: %.3f", 
          (long)gesture.state, translation.x, translation.y, progress);
    
    switch (gesture.state) {
        case UIGestureRecognizerStateBegan: {
            // 只在开始时检查导航栈，后续状态不检查
            if (self.viewControllers.count <= 1) {
                NSLog(@"在局❌ [交互手势] 导航栈只有%ld个控制器，无法返回", (long)self.viewControllers.count);
                return;
            }
            NSLog(@"在局👆 [交互手势] 开始边缘滑动");
            NSLog(@"在局👆 [交互手势] 当前视图控制器栈: %ld", (long)self.viewControllers.count);
            NSLog(@"在局👆 [交互手势] 当前顶部控制器: %@", NSStringFromClass([self.topViewController class]));
            
            // 确保delegate被正确设置
            if (self.delegate != self) {
                NSLog(@"在局⚠️ [交互手势] 导航控制器delegate不是自己！当前delegate: %@", self.delegate);
                self.delegate = self;
            } else {
                NSLog(@"在局✅ [交互手势] 导航控制器delegate确认为自己");
            }
            
            // 原生导航栈返回
            self.isInteractiveTransition = YES;
            self.interactiveTransition = [[UIPercentDrivenInteractiveTransition alloc] init];
            // 设置交互式转场的参数，优化动画效果
            self.interactiveTransition.completionCurve = UIViewAnimationCurveEaseOut;
            // 关键修复：设置交互式转场的时长，确保动画跟随手指
            self.interactiveTransition.completionSpeed = 1.0;
            
            NSLog(@"在局👆 [交互手势] 即将调用popViewControllerAnimated");
            NSLog(@"在局👆 [交互手势] pop前导航栈数量: %ld", (long)self.viewControllers.count);
            
            // 在调用popViewControllerAnimated之前，确保delegate方法会被调用
            // 这是关键：确保系统知道这是一个交互式转场
            NSLog(@"在局🔍 [交互手势] 验证delegate链: self.delegate = %@", self.delegate);
            NSLog(@"在局🔍 [交互手势] 当前交互状态: isInteractive=%@, transition=%@", 
                  self.isInteractiveTransition ? @"YES" : @"NO", 
                  self.interactiveTransition);
            
            // 必须同步调用，否则交互式转场会失效
            UIViewController *poppedVC = [self popViewControllerAnimated:YES];
            NSLog(@"在局👆 [交互手势] popViewControllerAnimated返回: %@", poppedVC ? NSStringFromClass([poppedVC class]) : @"nil");
            NSLog(@"在局👆 [交互手势] pop后导航栈数量: %ld", (long)self.viewControllers.count);
            NSLog(@"在局👆 [交互手势] 交互式转场对象: %@", self.interactiveTransition);
            
            if (!poppedVC) {
                NSLog(@"在局❌ [交互手势] popViewControllerAnimated失败！");
                self.isInteractiveTransition = NO;
                self.interactiveTransition = nil;
                self.interactiveTransitionStarted = NO;
            } else {
                // 设置转场已开始标志
                self.interactiveTransitionStarted = YES;
                NSLog(@"在局✅ [交互手势] 交互式转场已开始");
            }
            break;
        }
        case UIGestureRecognizerStateChanged: {
            NSLog(@"在局👆 [交互手势] 滑动变化 - 进度: %.2f, 位移: %.1f", progress, translation.x);
            NSLog(@"在局👆 [交互手势] 转场状态 - started: %@, isInteractive: %@, transition: %@", 
                  self.interactiveTransitionStarted ? @"YES" : @"NO",
                  self.isInteractiveTransition ? @"YES" : @"NO",
                  self.interactiveTransition ? @"存在" : @"nil");
            
            // 只有在转场已经开始的情况下才更新进度
            if (self.interactiveTransitionStarted && self.interactiveTransition) {
                [self.interactiveTransition updateInteractiveTransition:progress];
                NSLog(@"在局👆 [交互手势] 已更新交互进度: %.2f", progress);
            } else {
                NSLog(@"在局❌ [交互手势] 转场未开始或interactiveTransition为nil，无法更新进度");
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
            
            NSLog(@"在局👆 [交互手势] 结束 - 进度: %.2f, 速度: %.2f, 完成: %@", 
                  progress, velocity, shouldComplete ? @"YES" : @"NO");
            
            if (self.interactiveTransition) {
                if (shouldComplete) {
                    NSLog(@"在局👆 [交互手势] 完成转场");
                    // 修复：设置合适的完成速度，确保动画流畅且不会过快
                    // 使用固定的速度避免动画突然加速
                    CGFloat completionSpeed = MIN(1.5, MAX(0.5, 1.0)); // 限制在0.5-1.5倍速之间
                    self.interactiveTransition.completionSpeed = completionSpeed;
                    [self.interactiveTransition finishInteractiveTransition];
                    
                    // 手势完成，确保TabBar会在转场完成后正确显示
                    if (self.viewControllers.count >= 2) {
                        UIViewController *toVC = [self.viewControllers objectAtIndex:self.viewControllers.count - 2];
                        if (toVC.tabBarController && self.viewControllers.count == 2) {
                            // 如果返回到根视图控制器，应该显示TabBar
                            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                                NSLog(@"在局👆 [交互手势] 延迟确保TabBar显示");
                                toVC.tabBarController.tabBar.hidden = NO;
                            });
                        }
                    }
                } else {
                    NSLog(@"在局👆 [交互手势] 取消转场");
                    // 修复：设置合适的取消速度，确保返回动画流畅且不会过快
                    CGFloat cancelSpeed = MIN(2.0, MAX(0.8, 1.2)); // 限制在0.8-2.0倍速之间
                    self.interactiveTransition.completionSpeed = cancelSpeed;
                    [self.interactiveTransition cancelInteractiveTransition];
                }
            } else {
                NSLog(@"在局❌ [交互手势] 结束时interactiveTransition为nil，无法处理手势结束");
            }
            
            // 清理交互状态
            self.isInteractiveTransition = NO;
            self.interactiveTransition = nil;
            self.interactiveTransitionStarted = NO;
            NSLog(@"在局🧹 [交互手势] 已清理所有交互式转场状态");
            break;
        }
        default:
            break;
    }
}

#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    NSLog(@"在局🔍 [手势代理] gestureRecognizerShouldBegin被调用");
    NSLog(@"在局🔍 [手势代理] 手势类型: %@", NSStringFromClass([gestureRecognizer class]));
    NSLog(@"在局🔍 [手势代理] 视图控制器栈数量: %ld", (long)self.viewControllers.count);
    
    // 只有在有多个视图控制器时才允许手势
    if (self.viewControllers.count <= 1) {
        NSLog(@"在局❌ [手势代理] 只有一个视图控制器，不允许返回");
        return NO;
    }
    
    // 检查是否为边缘滑动手势
    if ([gestureRecognizer isKindOfClass:[UIScreenEdgePanGestureRecognizer class]]) {
        // 获取手势位置
        CGPoint location = [gestureRecognizer locationInView:self.view];
        NSLog(@"在局📍 [手势代理] 手势位置: %@", NSStringFromCGPoint(location));
        
        // 检查当前视图控制器是否允许返回手势
        UIViewController *topViewController = self.topViewController;
        NSLog(@"在局🔍 [手势代理] 当前顶部控制器: %@", NSStringFromClass([topViewController class]));
        
        BOOL shouldAllow = [self shouldAllowInteractivePopForViewController:topViewController];
        
        if (!shouldAllow) {
            NSLog(@"在局❌ [手势代理] 当前视图控制器禁用了返回手势");
            return NO;
        }
        
        NSLog(@"在局✅ [手势代理] 允许边缘滑动手势");
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
                NSLog(@"在局✅ [手势冲突] ScrollView在左边缘，优先响应返回手势");
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

@end
