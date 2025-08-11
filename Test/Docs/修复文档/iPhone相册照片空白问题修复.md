# iPhone相册照片空白问题修复

## 问题描述
用户反馈在修复iPad照片选择器后，iPhone上也出现了相册列表可见但点击进入后照片为空白的问题。

## 根本原因
在TZImageManager.m中使用了一个无效的Photos框架常量：`PHAssetCollectionSubtypeAlbumRegular`

```objc
// 错误代码
PHFetchResult *smartAlbums = [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeSmartAlbum 
                                                                     subtype:PHAssetCollectionSubtypeAlbumRegular 
                                                                     options:nil];
```

这个常量在Photos框架中不存在，导致fetch返回0个结果。

## 修复方案
将无效的子类型常量替换为`PHAssetCollectionSubtypeAny`：

```objc
// 修复后的代码
PHFetchResult *smartAlbums = [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeSmartAlbum 
                                                                     subtype:PHAssetCollectionSubtypeAny 
                                                                     options:nil];
```

## 已添加的调试日志

### 1. TZPhotoPickerController.m
- fetchAssetModels方法：记录相册名称、照片数量
- initSubviews方法：记录models数量
- scrollCollectionViewToBottom方法：记录显示状态

### 2. TZImageManager.m
- getAllAlbums方法：记录相册获取过程
- getCameraRollAlbum方法：记录相机胶卷获取

## 验证步骤
1. 在iPhone设备上运行应用
2. 点击选择照片功能
3. 查看相册列表是否正常显示
4. 点击任意相册，确认照片正常显示
5. 检查控制台日志，确认没有错误

## 注意事项
1. PHAssetCollectionSubtypeAny会获取所有类型的智能相册
2. 如果需要更精确的控制，可以使用具体的子类型如：
   - PHAssetCollectionSubtypeSmartAlbumGeneric
   - PHAssetCollectionSubtypeSmartAlbumUserLibrary
   - PHAssetCollectionSubtypeSmartAlbumRecentlyAdded

## 经验教训
在使用系统框架API时，必须确保使用的常量是有效的。不存在的常量会导致运行时错误或返回空结果。