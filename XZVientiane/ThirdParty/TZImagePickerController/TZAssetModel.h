//
//  TZAssetModel.h
//  TZImagePickerController
//
//  Created by 谭真 on 15/12/24.
//  Copyright © 2015年 谭真. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

typedef enum : NSUInteger {
    TZAssetModelMediaTypePhoto = 0,
    TZAssetModelMediaTypeLivePhoto,
    TZAssetModelMediaTypePhotoGif,
    TZAssetModelMediaTypeVideo,
    TZAssetModelMediaTypeAudio
} TZAssetModelMediaType;

@class PHAsset;
@interface TZAssetModel : NSObject

@property (nonatomic, strong) PHAsset *asset;             ///< PHAsset
@property (nonatomic, assign) BOOL isSelected;      ///< The select status of a photo, default is No
@property (nonatomic, assign) TZAssetModelMediaType type;
@property (assign, nonatomic) BOOL needOscillatoryAnimation;
@property (nonatomic, copy) NSString *timeLength;
@property (strong, nonatomic) UIImage *cachedImage;

/// Init a photo dataModel With a asset
/// 用一个PHAsset实例，初始化一个照片模型
+ (instancetype)modelWithAsset:(PHAsset *)asset type:(TZAssetModelMediaType)type;
+ (instancetype)modelWithAsset:(PHAsset *)asset type:(TZAssetModelMediaType)type timeLength:(NSString *)timeLength;

@end


@class PHFetchResult;
@interface TZAlbumModel : NSObject

@property (nonatomic, strong) NSString *name;        ///< The album name
@property (nonatomic, assign) NSInteger count;       ///< Count of photos the album contain
@property (nonatomic, strong) PHFetchResult * result;             ///< PHFetchResult<PHAsset> or ALAssetsGroup<ALAsset>

@property (nonatomic, strong) NSArray *models;
@property (nonatomic, strong) NSArray *selectedModels;
@property (nonatomic, assign) NSUInteger selectedCount;

@property (nonatomic, assign) BOOL isCameraRoll;

- (void)setResult:(PHFetchResult *)result needFetchAssets:(BOOL)needFetchAssets;

@end
