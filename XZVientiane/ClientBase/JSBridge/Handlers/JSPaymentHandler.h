//
//  JSPaymentHandler.h
//  XZVientiane
//
//  处理支付相关的JS调用
//

#import "JSActionHandler.h"

NS_ASSUME_NONNULL_BEGIN

// 在局Claude Code[修复未声明选择器警告]+声明支付回调协议
@protocol JSPaymentCallbackSupport <NSObject>
@optional
@property (nonatomic, copy, nullable) JSActionCallbackBlock webviewBackCallBack;
@end

@interface JSPaymentHandler : JSActionHandler

@end

NS_ASSUME_NONNULL_END