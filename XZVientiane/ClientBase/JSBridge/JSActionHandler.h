//
//  JSActionHandler.h
//  XZVientiane
//
//  JS桥接动作处理器基类
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

// JS回调块定义
typedef void(^JSActionCallbackBlock)(id _Nullable responseData);

// JS动作处理器协议
@protocol JSActionHandlerProtocol <NSObject>

@required
// 是否可以处理指定的动作
- (BOOL)canHandleAction:(NSString *)action;

// 处理JS调用
- (void)handleAction:(NSString *)action 
              data:(id _Nullable)data 
        controller:(UIViewController *)controller
          callback:(JSActionCallbackBlock _Nullable)callback;

@optional
// 获取处理器支持的动作列表
- (NSArray<NSString *> *)supportedActions;

@end

// JS动作处理器基类
@interface JSActionHandler : NSObject <JSActionHandlerProtocol>

// 子类需要重写此方法，返回支持的动作列表
- (NSArray<NSString *> *)supportedActions;

// 格式化回调响应
- (NSDictionary *)formatCallbackResponse:(NSString *)apiType 
                                   data:(id _Nullable)data 
                                success:(BOOL)success 
                           errorMessage:(NSString * _Nullable)errorMessage;

@end

NS_ASSUME_NONNULL_END