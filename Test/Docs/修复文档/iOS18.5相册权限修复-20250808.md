# iOS 18.5 相册权限修复文档

## 问题描述

**审核反馈**：
- 提交ID: bbe2c355-0a17-41d6-982f-8cb3f9f2783e
- 审核日期: 2025年8月7日
- 版本: 1.0
- 问题: 登录后点击"允许完全访问"按钮后无法访问相册，显示空白页面
- 测试设备: iPhone 13 mini, iOS 18.5

## 问题原因分析

1. **过时的权限API**
   - TZImagePickerController使用了已弃用的API `[PHPhotoLibrary requestAuthorization:]`
   - 该API在iOS 14后已被弃用，无法正确处理新的权限系统

2. **iOS 14+权限系统变更**
   - iOS 14引入了新的照片权限模式：
     - 限制访问（Limited Access）- 只能访问用户选择的特定照片
     - 完全访问（Full Access）- 可以访问所有照片
     - 不允许（Denied）
   - 需要使用新的API：`requestAuthorizationForAccessLevel:handler:`

3. **权限状态检查不兼容**
   - 旧的`authorizationStatus`方法无法正确识别iOS 14+的权限状态
   - 导致即使用户授予了"完全访问"权限，应用仍可能认为没有权限

## 修复方案

### 1. 更新权限请求方法

**文件**: `/XZVientiane/ThirdParty/TZImagePickerController/TZImageManager.m`

**修改内容**:
```objc
- (void)requestAuthorizationWithCompletion:(void (^)(void))completion {
    void (^callCompletionBlock)(void) = ^(){
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) {
                completion();
            }
        });
    };

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // iOS 14及以上版本使用新的权限请求方法
        if (@available(iOS 14, *)) {
            [PHPhotoLibrary requestAuthorizationForAccessLevel:PHAccessLevelReadWrite handler:^(PHAuthorizationStatus status) {
                NSLog(@"在局Claude Code[相册权限请求]iOS 14+权限状态: %ld", (long)status);
                callCompletionBlock();
            }];
        } else {
            // iOS 14以下版本使用旧方法
            [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
                NSLog(@"在局Claude Code[相册权限请求]iOS 14以下权限状态: %ld", (long)status);
                callCompletionBlock();
            }];
        }
    });
}
```

### 2. 更新权限状态检查方法

**修改内容**:
```objc
+ (NSInteger)authorizationStatus {
    if (iOS8Later) {
        // iOS 14及以上版本需要检查特定访问级别的权限
        if (@available(iOS 14, *)) {
            PHAuthorizationStatus status = [PHPhotoLibrary authorizationStatusForAccessLevel:PHAccessLevelReadWrite];
            NSLog(@"在局Claude Code[权限状态检查]iOS 14+权限状态: %ld", (long)status);
            return status;
        } else {
            // iOS 14以下版本使用旧方法
            PHAuthorizationStatus status = [PHPhotoLibrary authorizationStatus];
            NSLog(@"在局Claude Code[权限状态检查]iOS 14以下权限状态: %ld", (long)status);
            return status;
        }
    }
    return NO;
}
```

## 修复效果

1. **兼容iOS 14+新权限系统**
   - 正确请求和检查"完全访问"权限
   - 支持iOS 14引入的限制访问模式

2. **保持向后兼容**
   - iOS 14以下版本继续使用旧API
   - 不影响老版本iOS的正常使用

3. **添加调试日志**
   - 便于追踪权限请求和状态变化
   - 测试完成后记得删除这些日志

## 测试建议

1. **iOS 18.5设备测试**
   - 测试首次安装应用时的权限请求流程
   - 测试选择"允许完全访问"后是否能正常显示相册
   - 测试选择"限制访问"的情况

2. **权限状态变更测试**
   - 在设置中修改应用的相册权限
   - 测试从"不允许"改为"允许完全访问"
   - 测试从"允许完全访问"改为"限制访问"

3. **向后兼容测试**
   - 在iOS 13及以下设备上测试
   - 确保老版本iOS仍能正常使用

## 注意事项

1. 修复完成后需要删除调试日志
2. 重新提交审核前建议在多个iOS版本上充分测试
3. 特别注意在iOS 18.5真机上测试，不要只依赖模拟器

## 相关文件

- `/XZVientiane/ThirdParty/TZImagePickerController/TZImageManager.m` - 权限管理实现
- `/XZVientiane/ThirdParty/TZImagePickerController/TZImageManager.h` - 权限管理接口
- `/XZVientiane/ClientBase/BaseController/CFJClientH5Controller.m` - 相册选择调用入口