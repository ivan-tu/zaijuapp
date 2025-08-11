# iPad相册权限空白问题修复文档

## 问题描述
Apple审核反馈：在iPad Air (5th generation) iPadOS 18.5上，应用授权相册权限后显示空白页面。

## 问题分析

### 1. 问题原因
- iPad上使用模态方式展示相册选择器（TZImagePickerController）
- 权限弹窗消失后，全屏模态视图返回时WebView状态未正确恢复
- iPad的模态展示方式与iPhone不同，导致生命周期回调差异

### 2. 相关代码位置
- 相册选择器展示：`CFJClientH5Controller.m` 第2693行
- 相册选择回调：`imagePickerController:didFinishPickingPhotos:` 方法
- 取消选择回调：`tz_imagePickerControllerDidCancel:` 方法

## 修复方案

### 1. 设置全屏展示模式（已完成）
```objc
// 在展示相册选择器前设置全屏模式
imagePickerVc.modalPresentationStyle = UIModalPresentationFullScreen;
```

### 2. 增强WebView状态恢复（已完成）

#### 2.1 取消选择时恢复WebView
```objc
- (void)tz_imagePickerControllerDidCancel:(TZImagePickerController *)picker {
    // 在局Claude Code[iPad适配] 相册选择器取消后检查并恢复WebView状态
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self checkAndFixPageVisibility];
        });
    }
}
```

#### 2.2 选择照片后恢复WebView
在选择照片完成回调中添加iPad适配代码：
```objc
// 普通照片选择完成后
if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self checkAndFixPageVisibility];
    });
}

// 原图选择完成后同样处理
```

### 3. 修复效果
- 确保iPad上相册选择器以全屏模式展示
- 权限授权后自动恢复WebView显示状态
- 使用`checkAndFixPageVisibility`方法确保页面正确显示

## 测试建议
1. 在iPad设备上测试相册权限授权流程
2. 测试不同场景：
   - 首次授权相册权限
   - 拒绝后再次授权
   - 选择照片后返回
   - 取消选择后返回
3. 确保WebView内容在所有场景下都能正常显示

## 注意事项
- 修复仅针对iPad设备，不影响iPhone用户体验
- 使用延迟执行确保模态转场动画完成后再恢复WebView
- 利用已有的`checkAndFixPageVisibility`方法进行状态检查和修复