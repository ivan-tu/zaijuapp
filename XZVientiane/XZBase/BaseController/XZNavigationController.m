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
        _animationDuration = 0.35;
        _backgroundOffsetRatio = 0.3;
        _springDamping = 0.8;
        _springVelocity = 0.5;
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
        
        [transitionContext completeTransition:finished && ![transitionContext transitionWasCancelled]];
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
        
        BOOL success = finished && ![transitionContext transitionWasCancelled];
        NSLog(@"在局🎬 [转场动画] 调用completeTransition: %@", success ? @"YES" : @"NO");
        [transitionContext completeTransition:success];
        
        // 额外的清理工作：确保视图层级正确
        if (success) {
            // 延迟执行额外的清理，确保转场完全结束
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                NSLog(@"在局🎬 [转场动画] 延迟清理检查");
                
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
    self.transitionDuration = 0.35;
    
    // 创建自定义转场动画控制器
    self.slideAnimator = [[XZInlineSlideAnimator alloc] init];
    
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
    
    // 添加自定义的边缘滑动手势
    UIScreenEdgePanGestureRecognizer *edgePanGesture = [[UIScreenEdgePanGestureRecognizer alloc] initWithTarget:self action:@selector(handleEdgePanGesture:)];
    edgePanGesture.edges = UIRectEdgeLeft;
    edgePanGesture.delegate = self;
    [self.view addGestureRecognizer:edgePanGesture];
    
    NSLog(@"在局👆 [XZNavigationController] 交互式返回手势设置完成");
}

#pragma mark - Navigation Override

- (void)pushViewController:(UIViewController *)viewController animated:(BOOL)animated {
    NSLog(@"在局🚀 [XZNavigationController] pushViewController: %@, animated: %@", 
          NSStringFromClass([viewController class]), animated ? @"YES" : @"NO");
    NSLog(@"在局🚀 [XZNavigationController] 当前视图控制器栈数量: %ld", (long)self.viewControllers.count);
    NSLog(@"在局🚀 [XZNavigationController] 代理设置状态: %@", self.delegate == self ? @"已设置" : @"未设置");
    
    // 在push前禁用交互式手势，防止冲突
    self.interactivePopGestureRecognizer.enabled = NO;
    
    [super pushViewController:viewController animated:animated];
}

- (UIViewController *)popViewControllerAnimated:(BOOL)animated {
    NSLog(@"在局🔙 [XZNavigationController] popViewController animated: %@", animated ? @"YES" : @"NO");
    return [super popViewControllerAnimated:animated];
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
    NSLog(@"在局🔍 [转场代理] 当前导航控制器: %@", NSStringFromClass([navigationController class]));
    NSLog(@"在局🔍 [转场代理] 代理设置正确: %@", navigationController.delegate == self ? @"YES" : @"NO");
    NSLog(@"在局🔍 [转场代理] enableCustomTransition: %@", self.enableCustomTransition ? @"YES" : @"NO");
    
    // 如果禁用了自定义转场动画，返回nil使用系统默认动画
    if (!self.enableCustomTransition) {
        NSLog(@"在局⚪ [转场动画] 自定义动画已禁用，使用系统默认");
        return nil;
    }
    
    // 只对WebView页面使用自定义动画
    BOOL shouldUseCustomAnimation = [self shouldUseCustomAnimationForFromVC:fromVC toVC:toVC operation:operation];
    
    if (shouldUseCustomAnimation) {
        NSLog(@"在局🎬 [转场动画] 使用自定义动画 - 操作: %@", 
              operation == UINavigationControllerOperationPush ? @"Push" : @"Pop");
        NSLog(@"在局🎬 [转场动画] slideAnimator实例: %@", self.slideAnimator);
        
        // 配置动画控制器
        self.slideAnimator.isPresenting = (operation == UINavigationControllerOperationPush);
        self.slideAnimator.animationDuration = self.transitionDuration;
        
        NSLog(@"在局🎬 [转场动画] 返回动画控制器: %@", self.slideAnimator);
        return self.slideAnimator;
    } else {
        NSLog(@"在局⚪ [转场动画] 不使用自定义动画，使用系统默认");
        return nil;
    }
}

- (id<UIViewControllerInteractiveTransitioning>)navigationController:(UINavigationController *)navigationController
                         interactionControllerForAnimationController:(id<UIViewControllerAnimatedTransitioning>)animationController {
    
    // 只在交互式转场时返回交互控制器
    if (self.isInteractiveTransition && animationController == self.slideAnimator) {
        NSLog(@"在局👆 [交互转场] 返回交互控制器");
        return self.interactiveTransition;
    }
    
    return nil;
}

- (void)navigationController:(UINavigationController *)navigationController 
       didShowViewController:(UIViewController *)viewController 
                    animated:(BOOL)animated {
    
    NSLog(@"在局✅ [XZNavigationController] didShowViewController: %@", NSStringFromClass([viewController class]));
    
    // 重置交互式转场状态
    self.isInteractiveTransition = NO;
    self.interactiveTransition = nil;
    
    // 根据视图控制器数量决定是否启用返回手势
    // 注意：我们使用自定义手势，所以保持系统手势禁用
    self.interactivePopGestureRecognizer.enabled = NO;
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
    // 只有在有多个视图控制器时才允许返回
    if (self.viewControllers.count <= 1) {
        return;
    }
    
    CGPoint translation = [gesture translationInView:gesture.view];
    CGFloat progress = translation.x / gesture.view.bounds.size.width;
    progress = MAX(0.0, MIN(1.0, progress));
    
    switch (gesture.state) {
        case UIGestureRecognizerStateBegan: {
            NSLog(@"在局👆 [交互手势] 开始边缘滑动");
            self.isInteractiveTransition = YES;
            self.interactiveTransition = [[UIPercentDrivenInteractiveTransition alloc] init];
            [self popViewControllerAnimated:YES];
            break;
        }
        case UIGestureRecognizerStateChanged: {
            NSLog(@"在局👆 [交互手势] 滑动进度: %.2f", progress);
            [self.interactiveTransition updateInteractiveTransition:progress];
            break;
        }
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled: {
            CGFloat velocity = [gesture velocityInView:gesture.view].x;
            BOOL shouldComplete = progress > 0.5 || velocity > 500;
            
            NSLog(@"在局👆 [交互手势] 结束 - 进度: %.2f, 速度: %.2f, 完成: %@", 
                  progress, velocity, shouldComplete ? @"YES" : @"NO");
            
            if (shouldComplete) {
                [self.interactiveTransition finishInteractiveTransition];
            } else {
                [self.interactiveTransition cancelInteractiveTransition];
            }
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
        NSLog(@"在局👆 [手势判断] 允许边缘滑动手势");
        return YES;
    }
    
    return YES;
}
@end
