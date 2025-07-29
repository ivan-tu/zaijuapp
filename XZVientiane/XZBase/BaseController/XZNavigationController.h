//
//  TYNavigationController.h
//  TuiYa
//
//  Created by CFJ on 15/6/14.
//  Copyright (c) 2015年 tuweia. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface XZNavigationController : UINavigationController <UIGestureRecognizerDelegate,UINavigationControllerDelegate>

/**
 * 是否启用自定义滑动转场动画（默认YES）
 */
@property (nonatomic, assign) BOOL enableCustomTransition;

/**
 * 自定义转场动画的持续时间（默认0.35秒）
 */
@property (nonatomic, assign) NSTimeInterval transitionDuration;

// 注意：转场动画控制器已内联实现，无需外部引用

@end
