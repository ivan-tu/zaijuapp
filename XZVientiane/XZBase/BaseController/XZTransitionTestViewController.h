//
//  XZTransitionTestViewController.h
//  XZVientiane
//
//  Created by Assistant on 2024/12/19.
//  Copyright © 2024年 TuWeiA. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * 转场动画测试控制器
 * 用于测试自定义滑动转场动画效果
 */
@interface XZTransitionTestViewController : UIViewController

/**
 * 页面标识（用于区分不同的测试页面）
 */
@property (nonatomic, strong) NSString *pageIdentifier;

/**
 * 背景颜色（用于视觉区分）
 */
@property (nonatomic, strong) UIColor *pageBackgroundColor;

@end

NS_ASSUME_NONNULL_END