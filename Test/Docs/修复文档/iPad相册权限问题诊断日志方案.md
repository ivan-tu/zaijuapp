# iPad相册权限问题诊断日志方案

## 已添加的日志位置

### 1. CFJClientH5Controller.m
- `pushTZImagePickerControllerWithDic:` 方法中
  - 展示模式设置日志
  - 展示前后WebView状态日志
  - 展示完成回调日志
- `tz_imagePickerControllerDidCancel:` 方法中
  - 取消选择日志
  - WebView恢复日志
- `viewWillAppear:` 和 `viewDidAppear:` 方法中
  - 生命周期日志
  - _isPresentingImagePicker标志状态
- `viewWillDisappear:` 方法中
  - pageHide触发判断日志

### 2. TZImagePickerController.m
- `viewDidLoad` 方法中
  - 控制器初始化日志
- `configTableView` 方法中
  - 权限检查日志
  - 相册加载日志
  - 相册数量日志

## 通过日志需要确认的问题

1. **相册选择器是否真的被展示**
   - 查看"TZImagePickerController]viewDidLoad开始"日志
   - 查看"展示完成"日志

2. **权限状态**
   - 查看"权限状态检查"日志（状态3表示已授权）
   - 查看"TZAlbumPicker]没有相册权限"日志

3. **相册内容加载**
   - 查看"获取相册完成，相册数量"日志
   - 如果数量为0，说明没有获取到相册

4. **生命周期问题**
   - 查看pageHide是否被触发
   - 查看WebView状态变化

## 建议的下一步修复方案

基于日志结果，可能的修复方向：

1. **如果相册选择器没有被展示**
   - 检查权限请求时机
   - 可能需要在权限授权后重新展示

2. **如果相册数量为0**
   - 可能是权限授权后没有刷新
   - 需要在TZAlbumPickerController中添加权限变化监听

3. **如果是WebView被隐藏**
   - 检查optimizeWebViewLoading方法
   - 确保不会在展示相册时重新加载WebView

请运行带有这些日志的版本，并提供完整的日志输出，以便进一步定位问题。