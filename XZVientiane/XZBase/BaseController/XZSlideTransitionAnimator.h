//
//  XZSlideTransitionAnimator.h
//  XZVientiane
//
//  Created by Assistant on 2024/12/19.
//  Copyright © 2024年 TuWeiA. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * 自定义滑动转场动画控制器
 * 实现从右向左的页面进入动画和从左向右的退出动画
 * 提供流畅的用户体验，符合iOS设计规范
 */
@interface XZSlideTransitionAnimator : NSObject <UIViewControllerAnimatedTransitioning>

/**
 * 是否为推入动画（YES: push进入动画, NO: pop退出动画）
 */
@property (nonatomic, assign) BOOL isPresenting;

/**
 * 动画持续时间（默认0.35秒）
 */
@property (nonatomic, assign) NSTimeInterval animationDuration;

/**
 * 背景页面的偏移比例（默认0.3，即背景页面左移30%）
 */
@property (nonatomic, assign) CGFloat backgroundOffsetRatio;

/**
 * 弹簧动画的阻尼系数（默认0.8）
 */
@property (nonatomic, assign) CGFloat springDamping;

/**
 * 弹簧动画的初始速度（默认0.5）
 */
@property (nonatomic, assign) CGFloat springVelocity;

@end

NS_ASSUME_NONNULL_END