# iPad照片选择器系统原生方案实现

## 问题描述
- iPad上使用TZImagePickerController出现空白问题
- 点击进入相册后看不到照片
- Apple App Store因iPad兼容性问题拒绝上架

## 解决方案
为iPad实现系统原生的照片选择器，同时保持iPhone的原有逻辑不变。

## 实现细节

### 1. 设备判断逻辑
```objc
// 在pushTZImagePickerControllerWithDic方法中
if (idiom == UIUserInterfaceIdiomPad || (idiom == UIUserInterfaceIdiomPhone && screenSize.width >= 768)) {
    NSLog(@"在局Claude Code[相册选择器]iPad设备，使用系统原生照片选择器");
    [self presentSystemImagePickerForIPadWithConfig:dataDic];
    return;
}
```

### 2. 系统原生照片选择器实现
- **iOS 14+**: 使用PHPickerViewController
  - 不需要相册权限即可工作
  - 支持多选
  - 更好的隐私保护
  
- **iOS 14以下**: 使用UIImagePickerController
  - 需要相册权限
  - 只支持单选

### 3. 关键代码
```objc
// iOS 14+使用PHPickerViewController
if (@available(iOS 14, *)) {
    PHPickerConfiguration *configuration = [[PHPickerConfiguration alloc] init];
    configuration.selectionLimit = maxSelection;
    
    if ([[dataDic objectForKey:@"mimeType"] isEqualToString:@"video"]) {
        configuration.filter = [PHPickerFilter videosFilter];
    } else {
        configuration.filter = [PHPickerFilter imagesFilter];
    }
    
    PHPickerViewController *picker = [[PHPickerViewController alloc] initWithConfiguration:configuration];
    picker.delegate = self;
    
    // iPad上以popover形式展示
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        picker.modalPresentationStyle = UIModalPresentationPopover;
        picker.popoverPresentationController.sourceView = self.view;
        picker.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 0, 0);
    }
}
```

### 4. 协议实现
- 添加了PHPickerViewControllerDelegate (iOS 14+)
- 添加了UIImagePickerControllerDelegate
- 添加了UINavigationControllerDelegate

### 5. 文件修改
1. **CFJClientH5Controller.h**
   - 添加系统照片选择器协议声明
   - 导入PhotosUI框架

2. **CFJClientH5Controller.m**
   - 实现presentSystemImagePickerForIPadWithConfig方法
   - 实现PHPickerViewControllerDelegate代理方法
   - 实现UIImagePickerControllerDelegate代理方法
   - 保持原有的数据回调格式

## 优势
1. **兼容性更好**: 使用系统原生组件，避免第三方库的兼容性问题
2. **用户体验一致**: iPad用户看到的是系统标准的照片选择界面
3. **权限友好**: iOS 14+的PHPicker不需要相册权限
4. **维护简单**: 减少对第三方库的依赖

## 测试建议
1. 在iPad Air (5th generation) iOS 18.5上测试
2. 测试单选和多选功能
3. 测试图片和视频选择
4. 确认iPhone设备仍使用原有逻辑
5. 验证数据回调格式与原有实现一致

## 注意事项
- UIImagePickerController只支持单选，如果需要多选且iOS版本低于14，仍需使用TZImagePickerController
- PHPickerViewController需要iOS 14.0+
- 确保测试各种边界情况（取消选择、选择0张图片等）