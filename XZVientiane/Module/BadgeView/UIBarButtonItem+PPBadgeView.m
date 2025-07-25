//
//  UIBarButtonItem+PPBadgeView.m
//  PPBadgeViewObjc
//
//  Created by AndyPang on 2017/6/17.
//  Copyright © 2017年 AndyPang. All rights reserved.
//

/*
 *********************************************************************************
 *
 * Weibo : jkpang-庞 ( http://weibo.com/jkpang )
 * Email : jkpang@outlook.com
 * QQ 群 : 323408051
 * GitHub: https://github.com/jkpang
 *
 *********************************************************************************
 */

#import "UIBarButtonItem+PPBadgeView.h"
#import "UIView+PPBadgeView.h"

@implementation UIBarButtonItem (PPBadgeView)

- (void)pp_addBadgeWithText:(NSString *)text
{
    [[self bottomView] pp_addBadgeWithText:text];
}

- (void)pp_addBadgeWithNumber:(NSInteger)number
{
    [[self bottomView] pp_addBadgeWithNumber:number];
}

- (void)pp_addDotWithColor:(UIColor *)color
{
    [[self bottomView] pp_addDotWithColor:color];
}

- (void)pp_setBadgeHeightPoints:(CGFloat)points
{
    [[self bottomView] pp_setBadgeHeightPoints:points];
}

- (void)pp_moveBadgeWithX:(CGFloat)x Y:(CGFloat)y
{
    [[self bottomView] pp_moveBadgeWithX:x Y:y];
}

- (void)pp_setBadgeLabelAttributes:(void(^)(PPBadgeLabel *badgeLabel))attributes
{
    [[self bottomView] pp_setBadgeLabelAttributes:attributes];
}

- (void)pp_showBadge
{
    [[self bottomView] pp_showBadge];
}

- (void)pp_hiddenBadge
{
    [[self bottomView] pp_hiddenBadge];
}

- (void)pp_increase
{
    [[self bottomView] pp_increase];
}

- (void)pp_increaseBy:(NSInteger)number
{
    [[self bottomView] pp_increaseBy:number];
}

- (void)pp_decrease
{
    [[self bottomView] pp_decrease];
}

- (void)pp_decreaseBy:(NSInteger)number
{
    [[self bottomView] pp_decreaseBy:number];
}

#pragma mark - 获取Badge的父视图

- (UIView *)bottomView
{
    NSLog(@"在局🔧 [UIBarButtonItem+PPBadgeView] 获取Badge父视图");
    
    // 首先尝试获取customView
    if (self.customView) {
        NSLog(@"在局✅ [UIBarButtonItem+PPBadgeView] 使用customView作为Badge父视图");
        self.customView.layer.masksToBounds = NO;
        return self.customView;
    }
    
    // 如果没有customView，尝试通过target-action找到对应的视图
    // 这是一个更安全的方法，但可能无法在所有情况下工作
    if (self.target && [self.target isKindOfClass:[UIView class]]) {
        UIView *targetView = (UIView *)self.target;
        NSLog(@"在局✅ [UIBarButtonItem+PPBadgeView] 使用target视图作为Badge父视图");
        targetView.layer.masksToBounds = NO;
        return targetView;
    }
    
    NSLog(@"在局❌ [UIBarButtonItem+PPBadgeView] 无法获取Badge父视图，返回nil");
    // 无法安全地获取视图，返回nil
    // 调用方需要处理这种情况
    return nil;
}
@end
