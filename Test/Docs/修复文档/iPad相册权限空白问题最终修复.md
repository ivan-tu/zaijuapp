# iPad相册权限空白问题最终修复文档

## 问题描述
Apple审核反馈：在iPad Air (5th generation) iPadOS 18.5上，应用授权相册权限后显示空白页面。

## 问题分析
通过最新日志发现：
1. 权限状态正常（状态3=已授权）
2. UI线程问题已解决
3. **核心问题**：iPad上全屏模态展示导致`pageHide`事件触发，使WebView内容被隐藏

## 最终修复方案

### 1. 修改iPad展示模式
从全屏改为FormSheet，避免触发不必要的生命周期事件：
```objc
if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
    // iPad使用FormSheet样式，避免全屏覆盖导致生命周期问题
    imagePickerVc.modalPresentationStyle = UIModalPresentationFormSheet;
    // 设置合适的大小
    imagePickerVc.preferredContentSize = CGSizeMake(540, 620);
    // 确保不会被意外dismiss
    imagePickerVc.modalInPresentation = YES;
} else {
    // iPhone保持全屏
    imagePickerVc.modalPresentationStyle = UIModalPresentationFullScreen;
}
```

### 2. 防止pageHide事件
添加标志位控制，避免在展示图片选择器时触发pageHide：
```objc
// 添加实例变量
BOOL _isPresentingImagePicker;

// 展示时设置标志
_isPresentingImagePicker = YES;

// 在viewWillDisappear中判断
if (!_isPresentingImagePicker) {
    // 只有非图片选择器场景才触发pageHide
    [self objcCallJs:pageHideDic];
}

// dismiss时重置标志
_isPresentingImagePicker = NO;
```

### 3. 保留的其他修复
- TZImagePickerController UI线程修复
- openURL废弃API更新
- WebView状态恢复机制

## 修改的文件
1. `CFJClientH5Controller.m`
   - 第94行：添加`_isPresentingImagePicker`标志
   - 第2694-2709行：修改iPad展示模式
   - 第938-942行：防止pageHide触发
   - 第2718、2755、2797行：重置标志

2. `TZImagePickerController.m`
   - 第732行：UI线程修复
   - 第595-599行：openURL API更新

3. `TZPhotoPickerController.m`
   - 第778-782行：openURL API更新

## 技术要点
1. **iPad模态展示特性**：全屏模态会触发原控制器的完整生命周期，FormSheet则不会
2. **pageHide事件控制**：通过标志位精确控制JS事件触发时机
3. **WebView状态管理**：确保在模态dismiss后正确恢复WebView状态

## 测试建议
1. 在iPad设备上测试相册选择的完整流程
2. 验证FormSheet展示效果是否符合用户体验
3. 测试取消和选择照片后WebView内容是否正常显示
4. 确认iPhone上的行为没有受到影响