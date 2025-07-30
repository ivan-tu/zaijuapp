//
//  XZSlideTransitionAnimator.m
//  XZVientiane
//
//  Created by Assistant on 2024/12/19.
//  Copyright © 2024年 TuWeiA. All rights reserved.
//

#import "XZSlideTransitionAnimator.h"
#import "XZBaseHead.h"

@implementation XZSlideTransitionAnimator

#pragma mark - Initialization

- (instancetype)init {
    self = [super init];
    if (self) {
        // 设置默认值
        _animationDuration = 0.35;
        _backgroundOffsetRatio = 0.3;
        _springDamping = 0.8;
        _springVelocity = 0.5;
        _isPresenting = YES;
    }
    return self;
}

#pragma mark - UIViewControllerAnimatedTransitioning

- (NSTimeInterval)transitionDuration:(id<UIViewControllerContextTransitioning>)transitionContext {
    return self.animationDuration;
}

- (void)animateTransition:(id<UIViewControllerContextTransitioning>)transitionContext {
    // 获取转场上下文
    UIViewController *fromVC = [transitionContext viewControllerForKey:UITransitionContextFromViewControllerKey];
    UIViewController *toVC = [transitionContext viewControllerForKey:UITransitionContextToViewControllerKey];
    UIView *containerView = [transitionContext containerView];
    
    // 获取最终frame
    CGRect finalFrameForToVC = [transitionContext finalFrameForViewController:toVC];
    CGRect initialFrameForFromVC = [transitionContext initialFrameForViewController:fromVC];
    
    if (self.isPresenting) {
        // 进入动画：新页面从右侧滑入
        [self animatePresentationWithContext:transitionContext
                                  fromVC:fromVC
                                    toVC:toVC
                           containerView:containerView
                        finalFrameForToVC:finalFrameForToVC
                     initialFrameForFromVC:initialFrameForFromVC];
    } else {
        // 退出动画：当前页面向右滑出
        [self animateDismissalWithContext:transitionContext
                               fromVC:fromVC
                                 toVC:toVC
                        containerView:containerView
                     finalFrameForToVC:finalFrameForToVC
                  initialFrameForFromVC:initialFrameForFromVC];
    }
}

#pragma mark - Private Animation Methods

/**
 * 进入动画：新页面从右侧滑入，背景页面微微左移
 */
- (void)animatePresentationWithContext:(id<UIViewControllerContextTransitioning>)transitionContext
                                fromVC:(UIViewController *)fromVC
                                  toVC:(UIViewController *)toVC
                         containerView:(UIView *)containerView
                      finalFrameForToVC:(CGRect)finalFrame
                   initialFrameForFromVC:(CGRect)initialFrame {
    
    // 将新页面添加到容器视图
    [containerView addSubview:toVC.view];
    
    // 确保新页面的frame正确
    toVC.view.frame = finalFrame;
    
    // 设置新页面初始位置：在屏幕右侧外
    CGRect startFrame = finalFrame;
    startFrame.origin.x = CGRectGetMaxX(containerView.bounds);
    toVC.view.frame = startFrame;
    
    // 设置阴影效果
    [self addShadowToView:toVC.view];
    
    // 执行动画
    [UIView animateWithDuration:[self transitionDuration:transitionContext]
                          delay:0
         usingSpringWithDamping:self.springDamping
          initialSpringVelocity:self.springVelocity
                        options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        // 新页面滑入到最终位置
        toVC.view.frame = finalFrame;
        
        // 背景页面微微左移，产生层次感
        CGRect backgroundFrame = initialFrame;
        backgroundFrame.origin.x = -CGRectGetWidth(containerView.bounds) * self.backgroundOffsetRatio;
        fromVC.view.frame = backgroundFrame;
        
        // 背景页面稍微变暗
        fromVC.view.alpha = 0.9;
        
    } completion:^(BOOL finished) {
        // 清理阴影
        [self removeShadowFromView:toVC.view];
        
        // 恢复背景页面的透明度
        fromVC.view.alpha = 1.0;
        
        // 如果动画被取消，恢复原始状态
        if ([transitionContext transitionWasCancelled]) {
            fromVC.view.frame = initialFrame;
            [toVC.view removeFromSuperview];
        }
        
        // 通知转场完成
        BOOL success = ![transitionContext transitionWasCancelled];
        [transitionContext completeTransition:success];
    }];
}

/**
 * 退出动画：当前页面向右滑出，背景页面恢复位置
 */
- (void)animateDismissalWithContext:(id<UIViewControllerContextTransitioning>)transitionContext
                             fromVC:(UIViewController *)fromVC
                               toVC:(UIViewController *)toVC
                      containerView:(UIView *)containerView
                   finalFrameForToVC:(CGRect)finalFrame
                initialFrameForFromVC:(CGRect)initialFrame {
    
    NSLog(@"在局🚀 [退出动画] 开始 - fromVC:%@ toVC:%@", 
          NSStringFromClass([fromVC class]), 
          NSStringFromClass([toVC class]));
    
    // 将背景页面插入到当前页面下方
    [containerView insertSubview:toVC.view belowSubview:fromVC.view];
    
    // 设置背景页面的初始状态（左移且稍暗）
    CGRect backgroundInitialFrame = finalFrame;
    backgroundInitialFrame.origin.x = -CGRectGetWidth(containerView.bounds) * self.backgroundOffsetRatio;
    toVC.view.frame = backgroundInitialFrame;
    toVC.view.alpha = 0.9;
    
    // 设置当前页面的阴影
    [self addShadowToView:fromVC.view];
    
    // 获取动画时长
    NSTimeInterval duration = [self transitionDuration:transitionContext];
    
    // 判断是否是交互式转场
    BOOL isInteractive = transitionContext.isInteractive;
    NSLog(@"在局🎯 [退出动画] 交互式转场: %@", isInteractive ? @"YES" : @"NO");
    
    // 执行动画
    // 对于交互式转场，使用不同的动画选项以避免完成回调延迟
    UIViewAnimationOptions animationOptions = isInteractive ? 
        UIViewAnimationOptionCurveLinear : 
        (UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionAllowUserInteraction);
    
    [UIView animateWithDuration:duration
                          delay:0
         usingSpringWithDamping:self.springDamping
          initialSpringVelocity:self.springVelocity
                        options:animationOptions
                     animations:^{
        // 当前页面向右滑出
        CGRect exitFrame = initialFrame;
        exitFrame.origin.x = CGRectGetMaxX(containerView.bounds);
        fromVC.view.frame = exitFrame;
        
        // 背景页面恢复到正常位置和透明度
        toVC.view.frame = finalFrame;
        toVC.view.alpha = 1.0;
        
    } completion:^(BOOL finished) {
        // 清理阴影
        [self removeShadowFromView:fromVC.view];
        
        // 获取转场是否被取消
        BOOL cancelled = [transitionContext transitionWasCancelled];
        
        // 如果动画被取消，恢复原始状态
        if (cancelled) {
            fromVC.view.frame = initialFrame;
            toVC.view.frame = backgroundInitialFrame;
            toVC.view.alpha = 0.9;
        } else {
            // 动画成功完成
            // 确保背景页面状态正确
            toVC.view.frame = finalFrame;
            toVC.view.alpha = 1.0;
            
            // 重要：从容器视图中移除 fromVC.view
            // 这是解决视图残留问题的关键
            [fromVC.view removeFromSuperview];
        }
        
        // 通知转场完成
        // 必须在所有视图操作完成后调用
        [transitionContext completeTransition:!cancelled];
        
        // 添加日志以调试完成回调延迟问题
        NSLog(@"在局✅ [退出动画] 动画完成 - finished:%@, cancelled:%@", 
              finished ? @"YES" : @"NO", 
              cancelled ? @"YES" : @"NO");
    }];
}

#pragma mark - Shadow Effects

/**
 * 为视图添加阴影效果，增强层次感
 */
- (void)addShadowToView:(UIView *)view {
    view.layer.shadowColor = [UIColor blackColor].CGColor;
    view.layer.shadowOffset = CGSizeMake(-2, 0);
    view.layer.shadowOpacity = 0.2;
    view.layer.shadowRadius = 8.0;
    view.layer.masksToBounds = NO;
    
    // 优化性能：设置shadowPath
    UIBezierPath *shadowPath = [UIBezierPath bezierPathWithRect:view.bounds];
    view.layer.shadowPath = shadowPath.CGPath;
}

/**
 * 移除视图的阴影效果
 */
- (void)removeShadowFromView:(UIView *)view {
    view.layer.shadowColor = nil;
    view.layer.shadowOffset = CGSizeZero;
    view.layer.shadowOpacity = 0.0;
    view.layer.shadowRadius = 0.0;
    view.layer.shadowPath = nil;
}

#pragma mark - Animation Interruption Support

- (void)animationEnded:(BOOL)transitionCompleted {
    // 动画结束回调
}

@end