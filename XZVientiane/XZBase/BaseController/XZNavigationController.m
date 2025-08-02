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
    
    // 🔧 修复：统一处理所有页面，确保Tab页面在手势返回时也可见
    // 将目标视图插入到容器视图中
    if (toVC.view.superview != containerView) {
        [containerView insertSubview:toVC.view belowSubview:fromVC.view];
    }
    
    // 设置初始位置和透明度
    CGRect backgroundInitialFrame = finalFrame;
    backgroundInitialFrame.origin.x = -CGRectGetWidth(containerView.bounds) * self.backgroundOffsetRatio;
    toVC.view.frame = backgroundInitialFrame;
    toVC.view.alpha = 0.9;
    
    if (isReturningToTabRoot) {
        NSLog(@"在局Claude Code[转场修复]+检测到返回Tab根页面，正常添加到动画容器");
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
        
        // 🔧 修复：统一动画处理，确保所有页面都正常滑动
        // 所有页面都执行相同的滑动动画
        toVC.view.frame = finalFrame;
        toVC.view.alpha = 1.0;
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
            toVC.view.frame = finalFrame;
            toVC.view.alpha = 1.0;
            toVC.view.hidden = NO;
            
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
                                
                            }
                        }
                        
                        // 确保toVC的视图完全可见
                        toVC.view.hidden = NO;
                        toVC.view.alpha = 1.0;
                        
                        // 刷新视图层级
                        [toVC.view setNeedsLayout];
                        [toVC.view layoutIfNeeded];
                        
                        NSLog(@"在局Claude Code[TabBar恢复]+延迟检查，确保TabBar和内容视图正常");
                        
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
    return [super popViewControllerAnimated:animated];
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
    
    // 只有在非Tab切换且非手势返回到Tab根页面时才处理WebView状态
    if ([viewController respondsToSelector:@selector(webView)] && 
        [viewController respondsToSelector:@selector(pinUrl)] &&
        !isTabSwitch && !isInteractivePopToTabRoot) {
        
        lastWebViewHandleTime = currentTime;
        dispatch_async(dispatch_get_main_queue(), ^{
            [self handleWebViewStateForViewController:viewController];
        });
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


- (void)dealloc {
    // 移除通知观察者
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"InteractiveTransitionCancelled" object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
