# 修复CFJClientH5Controller缺少isCheck属性

> 修复时间：2025-01-08 20:35  
> 问题：编译错误 - 缺少属性声明  
> 文件：CFJClientH5Controller.h  

## 问题描述

编译时出现错误：
```
/Users/ivan/工作/Tuweia/app/在局/zaijuapp/XZVientiane/XZBase/BaseController/XZTabBarController.m:150:28 
Property 'isCheck' not found on object of type 'CFJClientH5Controller *'

/Users/ivan/工作/Tuweia/app/在局/zaijuapp/XZVientiane/XZBase/BaseController/XZTabBarController.m:219:32 
Property 'isCheck' not found on object of type 'CFJClientH5Controller *'
```

## 问题分析

`XZTabBarController.m` 中使用了 `CFJClientH5Controller` 的 `isCheck` 属性：

```objc
// 第150行
if ([[dic objectForKey:@"isCheck"] isEqualToString:@"1"]) {
    homeVC.isCheck = YES;  // ❌ 属性未声明
}

// 第219行  
if ([[tabConfig objectForKey:@"isCheck"] isEqualToString:@"1"]) {
    homeVC.isCheck = YES;  // ❌ 属性未声明
}
```

但是 `CFJClientH5Controller.h` 头文件中没有声明 `isCheck` 属性。

## 属性用途分析

通过检查 `CFJClientH5Controller.m` 的实现，发现 `isCheck` 属性的用途：

1. **版本检查控制**（第711-717行）：
   ```objc
   if (self.isCheck) {
       self.isCheck = NO;
       dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
           //版本更新提示
           [[XZPackageH5 sharedInstance] checkVersion];
       });
   }
   ```

2. **定位管理器初始化**（第816-819行）：
   ```objc
   if (self.isCheck) {
       self.JFlocationManager = [[JFLocation alloc] init];
       _JFlocationManager.delegate = self;
   }
   ```

## 修复方案

在 `CFJClientH5Controller.h` 中添加 `isCheck` 属性声明：

```objc
// 修复前
@property (nonatomic, assign) BOOL imVC;//判断是不是从聊天模块过来的，是的话不要显示messageBtn

@property (nonatomic, copy) CallBackToNative callBackToNative;//回调给原生页面

// 修复后
@property (nonatomic, assign) BOOL imVC;//判断是不是从聊天模块过来的，是的话不要显示messageBtn
@property (nonatomic, assign) BOOL isCheck;//是否需要检查版本更新和初始化定位

@property (nonatomic, copy) CallBackToNative callBackToNative;//回调给原生页面
```

## 修复结果

✅ 编译错误已修复  
✅ 属性声明与实际用途一致  
✅ 不影响现有功能逻辑  

## 相关文件

- `XZVientiane/ClientBase/BaseController/CFJClientH5Controller.h` (添加属性声明)
- `XZVientiane/XZBase/BaseController/XZTabBarController.m` (使用该属性)
- `XZVientiane/ClientBase/BaseController/CFJClientH5Controller.m` (属性的具体使用)

---

*此修复确保代码能够正常编译，属性用途明确，功能完整。*