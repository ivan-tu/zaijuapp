//
//  JSActionHandlerManager.h
//  XZVientiane
//
//  JS动作处理器管理器
//

#import <Foundation/Foundation.h>
#import "JSActionHandler.h"

NS_ASSUME_NONNULL_BEGIN

@interface JSActionHandlerManager : NSObject

// 单例
+ (instancetype)sharedManager;

// 注册处理器
- (void)registerHandler:(JSActionHandler *)handler;

// 处理JS调用
- (void)handleJavaScriptCall:(NSDictionary *)data 
                  controller:(UIViewController *)controller
                  completion:(JSActionCallbackBlock _Nullable)completion;

// 检查是否可以处理指定action
- (BOOL)canHandleAction:(NSString *)action;

@end

NS_ASSUME_NONNULL_END