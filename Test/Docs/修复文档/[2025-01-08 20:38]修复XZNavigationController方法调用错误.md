# 修复XZNavigationController方法调用错误

> 修复时间：2025-01-08 20:38  
> 问题：编译错误 - 错误的方法调用上下文  
> 文件：XZNavigationController.m  

## 问题描述

编译时出现错误：
```
/Users/ivan/工作/Tuweia/app/在局/zaijuapp/XZVientiane/XZBase/BaseController/XZNavigationController.m:183:36 
No visible @interface for 'XZNavigationController' declares the selector 'restoreWebViewStateForViewController:withDelay:'

/Users/ivan/工作/Tuweia/app/在局/zaijuapp/XZVientiane/XZBase/BaseController/XZNavigationController.m:186:36 
No visible @interface for 'XZNavigationController' declares the selector 'restoreWebViewStateForViewController:withDelay:'
```

## 问题分析

在 `XZInlineSlideAnimator` 类（转场动画器）中，错误地直接调用了 `XZNavigationController` 的私有方法：

```objc
// ❌ 错误：在动画器类中调用导航控制器的私有方法
if ([fromVC.navigationController isKindOfClass:[XZNavigationController class]]) {
    XZNavigationController *navController = (XZNavigationController *)fromVC.navigationController;
    
    [navController restoreWebViewStateForViewController:toVC withDelay:0.1];  // 方法不可见
    [navController restoreWebViewStateForViewController:fromVC withDelay:0.2]; // 方法不可见
}
```

**问题根因：**
1. `restoreWebViewStateForViewController:withDelay:` 方法在 `XZNavigationController` 类的实现文件中定义，不在头文件中声明
2. 动画器类无法直接访问导航控制器的私有方法
3. 违反了类之间的封装原则

## 修复方案

采用通知机制解决跨类方法调用问题：

### 1. 修改动画器中的调用方式

```objc
// 修复前：直接调用私有方法
if ([fromVC.navigationController isKindOfClass:[XZNavigationController class]]) {
    XZNavigationController *navController = (XZNavigationController *)fromVC.navigationController;
    [navController restoreWebViewStateForViewController:toVC withDelay:0.1];
    [navController restoreWebViewStateForViewController:fromVC withDelay:0.2];
}

// 修复后：使用通知机制
// 发送通知让导航控制器处理WebView状态恢复
[[NSNotificationCenter defaultCenter] postNotificationName:@"InteractiveTransitionCancelled" 
                                                    object:nil 
                                                  userInfo:@{@"toViewController": toVC, 
                                                           @"fromViewController": fromVC}];
```

### 2. 在导航控制器中添加通知监听

在 `viewDidLoad` 方法中添加：
```objc
// 监听交互式转场取消通知
[[NSNotificationCenter defaultCenter] addObserver:self 
                                         selector:@selector(handleInteractiveTransitionCancelled:) 
                                             name:@"InteractiveTransitionCancelled" 
                                           object:nil];
```

### 3. 实现通知处理方法

```objc
/**
 * 处理交互式转场取消通知
 */
- (void)handleInteractiveTransitionCancelled:(NSNotification *)notification {
    NSDictionary *userInfo = notification.userInfo;
    UIViewController *toVC = userInfo[@"toViewController"];
    UIViewController *fromVC = userInfo[@"fromViewController"];
    
    if (toVC) {
        [self restoreWebViewStateForViewController:toVC withDelay:0.1];
    }
    if (fromVC) {
        [self restoreWebViewStateForViewController:fromVC withDelay:0.2];
    }
}
```

### 4. 添加内存管理

在 `dealloc` 方法中移除观察者：
```objc
- (void)dealloc {
    // 移除通知观察者
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"InteractiveTransitionCancelled" object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}
```

## 技术优势

✅ **解耦合**：动画器和导航控制器之间通过通知解耦  
✅ **封装性**：保持了类的私有方法封装  
✅ **可维护性**：清晰的责任分离，易于理解和维护  
✅ **扩展性**：可以轻松添加其他通知监听者  

## 修复结果

✅ 编译错误已修复  
✅ 保持了原有的WebView状态恢复功能  
✅ 遵循了面向对象设计原则  
✅ 提升了代码的可维护性  

## 相关文件

- `XZVientiane/XZBase/BaseController/XZNavigationController.m` (第174-183行，556-572行，903-907行)

## 设计模式

使用了 **观察者模式** 通过通知中心实现类间通信，避免了紧耦合的直接方法调用。

---

*此修复确保代码符合面向对象设计原则，提升了代码质量和可维护性。*