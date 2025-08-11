# iPad相册权限空白问题修复文档（更新版）

## 问题描述
Apple审核反馈：在iPad Air (5th generation) iPadOS 18.5上，应用授权相册权限后显示空白页面。

## 根据日志发现的真实问题

### 1. 主要问题：UI线程崩溃
日志显示：
```
Main Thread Checker: UI API called on a background thread: -[UIViewController navigationController]
```
在`TZAlbumPickerController`的`configTableView`方法中，在后台线程访问了`navigationController`，导致崩溃。

### 2. 次要问题：openURL废弃API警告
```
BUG IN CLIENT OF UIKIT: The caller of UIApplication.openURL(_:) needs to migrate to the non-deprecated UIApplication.open(_:options:completionHandler:)
```

## 修复方案

### 1. 修复UI线程问题（主要修复）
在`TZImagePickerController.m`第731-732行：
```objc
// 修复前：在后台线程访问navigationController
dispatch_async(dispatch_get_global_queue(0, 0), ^{
    TZImagePickerController *imagePickerVc = (TZImagePickerController *)self.navigationController;
    
// 修复后：在主线程获取navigationController
TZImagePickerController *imagePickerVc = (TZImagePickerController *)self.navigationController;
dispatch_async(dispatch_get_global_queue(0, 0), ^{
```

### 2. 修复openURL废弃API
在`TZImagePickerController.m`和`TZPhotoPickerController.m`中：
```objc
// 修复前
[[UIApplication sharedApplication] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString]];

// 修复后
if (@available(iOS 10.0, *)) {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString] options:@{} completionHandler:nil];
} else {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString]];
}
```

### 3. 保留之前的iPad适配修复
- TZImagePickerController全屏展示模式
- 相册选择器dismiss后的WebView状态恢复

## 修改的文件
1. `CFJClientH5Controller.m` - iPad适配相关修改
2. `TZImagePickerController.m` - UI线程和openURL修复
3. `TZPhotoPickerController.m` - openURL修复

## 问题分析总结
1. **权限流程正常**：日志显示权限状态从0（未授权）变为3（已授权），说明权限请求流程正常
2. **真正原因**：第三方库TZImagePickerController在后台线程访问UI导致崩溃
3. **iPad特殊性**：iPad的全屏模态展示可能加剧了线程问题的暴露

## 测试建议
1. 在iPad设备上测试完整的相册选择流程
2. 特别关注权限授权后的相册列表加载
3. 测试取消选择和选择照片后的WebView恢复
4. 确保没有UI线程相关的崩溃