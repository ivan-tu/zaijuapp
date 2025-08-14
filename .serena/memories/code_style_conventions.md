# 代码风格和约定

## 开发语言
- **主要语言**: Objective-C
- **禁止**: 使用Swift（保持代码一致性）

## 命名规范
- **类名**: 驼峰命名，XZ或CFJ前缀（如 XZViewController, CFJClientH5Controller）
- **方法名**: 小写开头驼峰命名（如 loadWebView, handleJSCall）
- **属性**: 小写开头驼峰命名
- **常量**: k开头驼峰命名（如 kDefaultTimeout）
- **宏定义**: 全大写下划线分隔（如 SCREEN_WIDTH）

## 注释规范
- **优先级**: WHY > WHAT > HOW（先写为何存在，再写干什么，最后是实现细节）
- **避免**: 注释显而易见的代码
- **格式**: 使用 // 单行注释或 /* */ 多行注释

## 日志规范
- **格式**: NSLog(@"在局Claude Code[功能模块]日志内容");
- **示例**: NSLog(@"在局Claude Code[地区选择]用户选择了: %@", location);
- **原则**: 避免显而易见的日志，修复完成后删除测试日志

## 代码组织
- **文件结构**: .h头文件声明接口，.m实现文件编写逻辑
- **属性声明**: 在.h中用@property声明公开属性，私有属性在.m的类扩展中声明
- **协议遵循**: 在类扩展中声明协议遵循（如 <UITableViewDelegate>）

## 修改规范
- **禁止修改manifest**: 除非必要，H5业务逻辑应由另一位开发人员处理
- **禁止修改注释代码**: 除非要删除它
- **禁止强制修复**: 修改需要稳定且优雅
- **测试代码**: 测试完成后必须删除

## 内存管理
- **ARC**: 项目使用ARC，无需手动管理内存
- **Block循环引用**: 使用__weak避免循环引用
```objc
__weak typeof(self) weakSelf = self;
[self doSomethingWithBlock:^{
    __strong typeof(weakSelf) strongSelf = weakSelf;
    if (strongSelf) {
        // 使用strongSelf
    }
}];
```

## JSBridge规范
- **桥接对象**: window.xzBridge
- **调用方式**: window.xzBridge.callHandler('方法名', 参数, 回调)
- **Handler命名**: JS端使用驼峰命名，Native端对应相同名称

## 导入规范
- **系统框架**: 使用尖括号 #import <UIKit/UIKit.h>
- **项目文件**: 使用引号 #import "XZViewController.h"
- **顺序**: 系统框架 > 第三方库 > 项目文件

## 特殊约定
- **禁用console.log**: JS调试使用alert替代
- **编译检查**: 修改完成后不要自动测试编译，让用户自己测试
- **问题定位**: 不确定原因时先定位问题，不要轻易修改