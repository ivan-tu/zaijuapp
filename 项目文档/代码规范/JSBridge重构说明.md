# JSBridge 重构说明

## 概述
将原有的 handleJavaScriptCall 方法（500+行）使用策略模式重构为模块化的处理器架构。

## 架构设计

### 1. 核心组件

#### JSActionHandler (基类)
- 定义了处理器协议 `JSActionHandlerProtocol`
- 提供了格式化回调响应的工具方法
- 所有具体处理器都继承自此基类

#### JSActionHandlerManager (管理器)
- 单例模式，管理所有处理器
- 自动注册所有默认处理器
- 根据 action 分发请求到对应处理器

### 2. 处理器分类

| 处理器 | 负责功能 | 支持的 Actions |
|--------|---------|---------------|
| JSNavigationHandler | 导航相关 | navigateTo, navigateBack, reLaunch, switchTab, closeCurrentTab, setNavigationBarTitle, hideNavationbar, showNavationbar |
| JSUIHandler | UI相关 | showModal, showToast, showActionSheet, setTabBarBadge, removeTabBarBadge, showTabBarRedDot, hideTabBarRedDot, stopPullDownRefresh, fancySelect, areaSelect, dateSelect, timeSelect |
| JSPaymentHandler | 支付相关 | weixinPay, aliPay |
| JSShareHandler | 分享相关 | share, copyLink |
| JSUserHandler | 用户相关 | userLogin, userLogout, weixinLogin |
| JSDeviceHandler | 设备相关 | hasWx, isiPhoneX, nativeGet |
| JSLocationHandler | 位置相关 | getLocation, selectLocation, selectLocationCity |
| JSMediaHandler | 媒体相关 | previewImage, saveImage, soundPlay, QRScan |
| JSFileHandler | 文件相关 | chooseFile, uploadFile |
| JSMessageHandler | 消息相关 | readMessage, changeMessageNum, noticemsg_setNumber, reloadOtherPages, dialogBridge, closePresentWindow |

### 3. 使用方式

在 CFJClientH5Controller 的 handleJavaScriptCall 方法中：

```objc
- (void)handleJavaScriptCall:(NSDictionary *)data completion:(XZWebViewJSCallbackBlock)completion {
    NSString *function = [data objectForKey:@"action"];
    
    // 检查是否可以由新的处理器管理器处理
    if ([[JSActionHandlerManager sharedManager] canHandleAction:function]) {
        [[JSActionHandlerManager sharedManager] handleJavaScriptCall:data 
                                                          controller:self 
                                                          completion:completion];
        return;
    }
    
    // 处理特殊情况（如 request 等）
    // ...
}
```

### 4. 扩展新功能

要添加新的 JS 调用处理：

1. 创建新的处理器类，继承自 JSActionHandler
2. 实现 supportedActions 方法，返回支持的 action 列表
3. 实现 handleAction:data:controller:callback: 方法
4. 在 JSActionHandlerManager 的 registerDefaultHandlers 方法中注册

示例：
```objc
@interface JSCustomHandler : JSActionHandler
@end

@implementation JSCustomHandler

- (NSArray<NSString *> *)supportedActions {
    return @[@"customAction1", @"customAction2"];
}

- (void)handleAction:(NSString *)action 
              data:(id)data 
        controller:(UIViewController *)controller
          callback:(JSActionCallbackBlock)callback {
    // 处理逻辑
}

@end
```

## 优势

1. **模块化**: 每个处理器负责特定功能，职责单一
2. **可维护性**: 易于定位和修改特定功能
3. **可扩展性**: 添加新功能只需创建新处理器
4. **代码复用**: 基类提供通用功能
5. **解耦**: 处理器之间相互独立
6. **测试友好**: 每个处理器可以独立测试

## 注意事项

1. 某些 action（如 request）仍在原方法中处理，因为它们有特殊的处理逻辑
2. 处理器中需要保持对控制器的弱引用，避免循环引用
3. 回调格式需要统一，使用 formatCallbackResponse 方法
4. 线程安全：UI 操作确保在主线程执行