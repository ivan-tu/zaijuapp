//
//  XZiOSVersionManager.h
//  XZVientiane
//
//  iOS版本统一管理器
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface XZiOSVersionManager : NSObject

/**
 * 获取单例实例
 */
+ (instancetype)sharedManager;

/**
 * 系统版本号（如 15.0）
 */
@property (nonatomic, readonly) CGFloat systemVersion;

/**
 * 是否为iOS 11及以上
 */
@property (nonatomic, readonly) BOOL iOS11Later;

/**
 * 是否为iOS 13及以上
 */
@property (nonatomic, readonly) BOOL iOS13Later;

/**
 * 是否为iOS 14及以上
 */
@property (nonatomic, readonly) BOOL iOS14Later;

/**
 * 是否为iOS 15及以上
 */
@property (nonatomic, readonly) BOOL iOS15Later;

/**
 * 是否为iOS 16及以上
 */
@property (nonatomic, readonly) BOOL iOS16Later;

/**
 * 是否为iOS 17及以上
 */
@property (nonatomic, readonly) BOOL iOS17Later;

/**
 * 是否为iOS 18及以上
 */
@property (nonatomic, readonly) BOOL iOS18Later;

/**
 * 判断是否为指定版本或更高版本
 * @param version 版本号，如 11.0, 13.0
 */
- (BOOL)isSystemVersionGreaterThanOrEqualTo:(CGFloat)version;

/**
 * 判断是否为iPhone X系列（有刘海的机型）
 */
@property (nonatomic, readonly) BOOL isiPhoneXSeries;

/**
 * 判断是否为iPad
 */
@property (nonatomic, readonly) BOOL isiPad;

/**
 * 获取安全区域底部高度（iPhone X系列为34，其他为0）
 */
@property (nonatomic, readonly) CGFloat safeAreaBottomHeight;

/**
 * 获取状态栏高度（iPhone X系列为44，其他为20）
 */
@property (nonatomic, readonly) CGFloat statusBarHeight;

/**
 * 获取导航栏高度（标准为44）
 */
@property (nonatomic, readonly) CGFloat navigationBarHeight;

/**
 * 获取TabBar高度（iPhone X系列为83，其他为49）
 */
@property (nonatomic, readonly) CGFloat tabBarHeight;

@end

NS_ASSUME_NONNULL_END