---
layout: post
title: "使用AssetsLibrary和PhotoKit做一个简易的相片选择器"
date: 2016-09-10 21:25:36 +0800
comments: true
categories: ios
---
iOS8之后，苹果推出了PhotoKit，让开发者在处理相册相关的业务时，可以更加得心应手。github上的开发者针对PhotoKit做了一层很优秀的封装[CTAssetsPickerController](https://github.com/chiunam/CTAssetsPickerController)，如果只需要支持iOS8+，那么可定制程度非常高的[CTAssetsPickerController](https://github.com/chiunam/CTAssetsPickerController)是个不错的选择。<br>
但是由于现有的业务还是需要支持iOS7，所以并不能完全舍弃使用`AssetsLibrary`的方式来访问相册。因此也就需要自己封装一套兼容iOS7的相册管理器。

本文涉及代码：[TBVAssetsPicker](https://github.com/tobevoid/TBVAssetsPicker)

<!--more-->

## 统一asset以及collection

| AssetsLibrary | PhotoKit |
| :--- | :--- |
| ALAssetsGroup | PHAssetCollection |
| ALAsset | PHAsset |
| TBVAsset | TBVCollection |

相片选择器最终需要向外部提供统一的标识相片的结构。同样，统一结构能让相片选择器更加优雅地实现内部逻辑。所以这里我声明了两个对应的类：`TBVAsset`、`TBVCollection`，并提供一些最基本的功能。

```objc
@interface TBVAsset : NSObject
/**
 *  PHAsset or ALAsset
 */
@property (strong, nonatomic) NSObject  *asset;

+ (instancetype)assetWithOriginAsset:(NSObject *)asset;
/** 本地标识 */
- (NSString *)assetLocalIdentifer;
/** 源照片尺寸 */
- (CGSize)assetPixelSize;
@end

@interface TBVCollection : NSObject
/**
 *  ALAssetsGroup or PHAssetCollection
 */
@property (strong, nonatomic) NSObject  *collection;

+ (instancetype)collectionWithOriginCollection:(NSObject *)aCollection;
/** 相簿名 */
- (NSString *)collectionTitle;
/** 估算的相簿相片个数 */
- (NSInteger)collectionEstimatedAssetCount;
/** 精确的相簿相片个数 */
- (NSInteger)collectionAccurateAssetCountWithFetchOptions:(id)filterOptions;
- (NSInteger)collectionAccurateAssetCountWithMediaType:(TBVAssetsPickerMediaType)mediaType;
@end
```
有了这些最基本的功能，在实现相册选择器时，就可以方便地对资源进行操作了。<br>
其实对于这部分的兼容处理，主要就是对两个不同的库进行封装，使其呈现同样的外观，后续的几步大体也是围绕这个目标进行。

## 封装manager
由于是两个不同版本的库，并且AssetsLibrary已经在iOS9时被弃用，使用时会产生`deprecated`警告，所以我分别对`ALAssetsLibrary`和`PHCachingImageManager`进行了封装，然后通过统一的接口`TBVAssetsManagerProtocol`暴露其功能。

一般相册选择器具有如下页面及对应功能（UI展示）：

- 首页
  - 相簿名
  - 相簿缩略图
  - 相簿拥有相片数
- 预览页
  - 相片缩略图
  - 选中相片大小
- 浏览页
  - 相片大图
  - 选中相片大小

所以我提供的接口如下：

```objc
//====================================
//              image
//====================================

/** requestImage返回都是一个RACTuple，first是Image，second是是否为degraded */

/** 请求特定大小的图片 */
- (RACSignal *)requestImageForAsset:(TBVAsset *)asset
                         targetSize:(CGSize)targetSize
                        contentMode:(TBVAssetsPickerContentMode)contentMode;
/** 请求相簿缩略图 */
- (RACSignal *)requestPosterImageForCollection:(TBVCollection *)collection
                                     mediaType:(TBVAssetsPickerMediaType)mediaType;

/** 请求相片缩略图 */
- (RACSignal *)requestPosterImageForAsset:(TBVAsset *)asset;

/** 请求相片原图 */
- (RACSignal *)requestFullResolutionImageForAsset:(TBVAsset *)asset;

//====================================
//              asset / collection
//====================================

/** 请求相片资源大小 */
- (RACSignal *)requestSizeForAssets:(NSArray <TBVAsset *> *)assets;

/** 请求所有相簿 */
- (RACSignal *)requestAllCollections;

/** 请求所有相片资源 */
- (RACSignal *)requestAssetsForCollection:(TBVCollection *)collection
                                mediaType:(TBVAssetsPickerMediaType)mediaType;

/** 请求相机胶卷相簿（针对一般业务首先进入相机胶卷的预览页） */
- (RACSignal *)requestCameraRollCollection;

//====================================
//              video
//====================================

/** 请求AVPlayerItem */
- (RACSignal *)requestVideoForAsset:(TBVAsset *)asset;

/** 请求AVURLAsset */
- (RACSignal *)requestURLAssetForAsset:(TBVAsset *)asset;
```
实现以上接口，一般相册选择器的功能点就已经完成大半了。<br>

## TBVAssetsPickerManager
由于自定义的相册manager都遵守`TBVAssetsManagerProtocol`，`TBVAssetsPickerManager`
的实现就变得相对简单，没有一大串令人厌烦的`if-else`。当然`TBVAssetsPickerManager`本身也是遵守`TBVAssetsManagerProtocol`的。

```objc
@interface TBVAssetsPickerManager() 
@property (strong, nonatomic) NSObject<TBVAssetsManagerProtocol> *realManager;
@property (strong, nonatomic) NSMutableArray *requestIdList;
@property (assign, nonatomic) BOOL photoKitAvailable;
@end

#pragma mark life cycle
- (instancetype)init {
    self = [super init];
    if (self) {
        _photoKitAvailable = NSClassFromString(@"PHImageManager") != nil;
    }
    return self;
}

#pragma mark TBVAssetsManagerProtocol
....

#pragma mark getter setter
- (NSObject *)realManager
{
    if (_realManager == nil) {
        if (self.photoKitAvailable) {
            _realManager = [[TBVCachingImageManager alloc] init];
        } else {
            _realManager = [[TBVAssetsLibrary alloc] init];
        }
    }
    
    return _realManager;
}
```
这样`_realManager`拿到的就是当前版本最新的相册manager了。

## 接口的实现
其实接口文档描述的还是非常清晰的，所以这里只是罗列了下代码，并没有针对每一步做解释，因为这些基本的操作进去头文件看看就全明白了。

### - requestImageForAsset:targetSize:(CGSize)targetSize:contentMode:
这个接口主要用来获取非原图。

- TBVCachingImageManager
  - 关于PHImageRequestOptions的deliveryMode，
    - 设置为PHImageRequestOptionsDeliveryModeOpportunistic并且synchronous为NO时，请求可能会先返回一张缩略图，然后再返回一张大图，这个可以通过获取请求回调字典中PHImageResultIsDegradedKey对应value来判别
    - PHImageRequestOptionsDeliveryModeHighQualityFormat和PHImageRequestOptionsDeliveryModeFastFormat都返回一张图片，只不过前者返回的图片的质量高于或等于请求的质量，而后者可能返回一张质量稍低的图片
- TBVAssetsLibrary
  - 由于AssetsLibrary并没有提供获取特定尺寸的相片接口，所以这里只是返回thumbnail、aspectRatioThumbnail、fullScreenImage中尺寸和目标大小最接近的一张图片。

```objc
// TBVCachingImageManager
- (RACSignal *)requestImageForAsset:(TBVAsset *)asset
                         targetSize:(CGSize)targetSize
                        contentMode:(TBVAssetsPickerContentMode)contentMode {
    return [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
        PHImageRequestID requestId = [self.imageManager
                                      requestImageForAsset:(PHAsset *)asset.asset
                                      targetSize:targetSize
                                      contentMode:[self contentModeForCustomContentMode:contentMode]
                                      options:self.defaultImageRequestOptions
                                      resultHandler:^(UIImage * _Nullable result,
                                                      NSDictionary * _Nullable info) {
                                          [subscriber sendNext:RACTuplePack(result, info[PHImageResultIsDegradedKey])];
                                          if (![info[PHImageResultIsDegradedKey] boolValue]) {
                                              [subscriber sendCompleted];
                                          }
                                      }];
        return [RACDisposable disposableWithBlock:^{
            [self.imageManager cancelImageRequest:requestId];
        }];
    }];
}

// TBVAssetsLibrary
- (RACSignal *)requestImageForAsset:(TBVAsset *)aAsset
                         targetSize:(CGSize)targetSize
                        contentMode:(TBVAssetsPickerContentMode)contentMode {
    return [[[RACSignal return:aAsset.asset]
                deliverOn:[RACScheduler scheduler]]
                map:^id(ALAsset * asset) {
        CGImageRef resultImageRef = nil;
        
        BOOL degraded = NO;
        if (targetSize.width < CGImageGetWidth(asset.thumbnail) &&
            targetSize.height < CGImageGetHeight(asset.thumbnail)) {
            // TBVAssetsPickerContentModeFill
            resultImageRef = asset.thumbnail;
            degraded = YES;
        }
        if (!resultImageRef) {
            CGImageRef aspectRatioThumbnail = asset.aspectRatioThumbnail;
            if (targetSize.width < CGImageGetWidth(aspectRatioThumbnail) &&
                targetSize.height < CGImageGetHeight(aspectRatioThumbnail)) {
                // TBVAssetsPickerContentModeFit
                resultImageRef = aspectRatioThumbnail;
            }
            if (!resultImageRef) {
                ALAssetRepresentation *assetRepresentation = [asset defaultRepresentation];
                resultImageRef = [assetRepresentation fullScreenImage];
            }
        }
        UIImage *resultImage = nil;
        if (resultImageRef) {
            resultImage = [UIImage imageWithCGImage:resultImageRef
                                              scale:BQAP_SCREEN_SCALE
                                        orientation:UIImageOrientationUp];
        }
        return RACTuplePack(resultImage, @(degraded));
    }];
}
```

### -requestPosterImageForCollection:mediaType:
- TBVCachingImageManager
  - 通过-fetchKeyAssetsInAssetCollection:options:获取相簿keyAssets，最多可以返回三个
  - 最终还是通过requestPosterImageForAsset:获取缩略图
   - 获取keyAssets前，需要设置options对资源进行过滤：

```objc
+ (instancetype)tbv_fetchOptionsWithCustomMediaType:(TBVAssetsPickerMediaType)mediaType {
    NSArray *mediaTypes = [self tbv_mediaTypesWithCustonMediaType:mediaType];
    if (!mediaTypes.count) return nil;
    
    PHFetchOptions *options = [[PHFetchOptions alloc] init];
    NSMutableString *predicateString = [NSMutableString string];
    for (NSNumber *mediaType in mediaTypes) {
        [predicateString appendFormat:@"mediaType = %@", mediaType];
        if (![mediaType isEqual:mediaTypes.lastObject]) [predicateString appendString:@" || "];
    }
    options.predicate = [NSPredicate predicateWithFormat:predicateString];
    return options;
}
```
- TBVAssetsLibrary
  - ALAssetsGroup有posterImage属性，直接返回相簿缩略图
  - 和PhotoKit不同，AssetLibrary通过ALAssetsGroup的setAssetsFilter方法进行过滤

```objc
[group setAssetsFilter:[ALAssetsFilter tbv_assetsFilterWithCustomMediaType:mediaType]];
```
这样设置以后，后续针对group的操作都会在过滤的结果中进行了。

```objc
// TBVCachingImageManager
- (RACSignal *)requestPosterImageForCollection:(TBVCollection *)collection
                              mediaType:(TBVAssetsPickerMediaType)mediaType {
    return [[RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
        PHFetchOptions *fetchOptions = [PHFetchOptions tbv_fetchOptionsWithCustomMediaType:mediaType];
        fetchOptions.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"creationDate"
                                                                       ascending:YES]];
        PHAssetCollection *realCollection = (PHAssetCollection *)collection.collection;
        /* fetchKeyAssetsInAssetCollection 获取至多三张 */
        PHFetchResult *result = [PHAsset fetchKeyAssetsInAssetCollection:realCollection
                                                                 options:fetchOptions];
        if (!result.count) {
            [subscriber sendNext:[RACSignal empty]];
            [subscriber sendCompleted];
            return nil;
        }
        
        TBVAsset *posterAsset = [TBVAsset assetWithOriginAsset:result.firstObject];
        [subscriber sendNext:[self requestPosterImageForAsset:posterAsset]];
        [subscriber sendCompleted];
        return nil;
    }] switchToLatest];
}

// TBVAssetsLibrary
- (RACSignal *)requestAssetsForCollection:(TBVCollection *)collection
                                mediaType:(TBVAssetsPickerMediaType)mediaType {
    return [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
        NSMutableArray *assets = [NSMutableArray array];
        ALAssetsGroup *group = (ALAssetsGroup *)collection.collection;
        [group setAssetsFilter:[ALAssetsFilter tbv_assetsFilterWithCustomMediaType:mediaType]];
        [group enumerateAssetsUsingBlock:^(ALAsset *result, NSUInteger index, BOOL *stop) {
            if (result) {
                [assets addObject:[TBVAsset assetWithOriginAsset:result]];
            } else {
                [subscriber sendNext:assets];
                [subscriber sendCompleted];
            }
        }];
        return nil;
    }];
}
```

### -requestPosterImageForAsset:
获取asset的缩略图，需要注意的一点就是：在获取缩略图的情况下，Fill比Fit获取的图片要清晰

```objc
// TBVCachingImageManager
- (RACSignal *)requestPosterImageForAsset:(TBVAsset *)asset {
    return [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
        CGSize posterSize = CGSizeMake(kBQPosterImageWidth * BQAP_SCREEN_SCALE,
                                       kBQPosterImageHeight * BQAP_SCREEN_SCALE);
        /* 在获取缩略图的情况下，Fill比Fit获取的图片要清晰 */
        PHImageRequestID requestId = [self.imageManager
                                      requestImageForAsset:(PHAsset *)asset.asset
                                      targetSize:posterSize
                                      contentMode:PHImageContentModeAspectFill
                                      options:self.defaultImageRequestOptions
                                      resultHandler:^(UIImage * _Nullable result,
                                                      NSDictionary * _Nullable info) {
                                          [subscriber sendNext:RACTuplePack(result, info[PHImageResultIsDegradedKey])];
                                          if (![info[PHImageResultIsDegradedKey] boolValue]) {
                                              [subscriber sendCompleted];
                                          }
                                      }];
        return [RACDisposable disposableWithBlock:^{
            [self.imageManager cancelImageRequest:requestId];
        }];
    }];
}

// TBVAssetsLibrary
- (RACSignal *)requestPosterImageForAsset:(TBVAsset *)asset {
    return [[RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
        CGSize posterSize = CGSizeMake(kBQPosterImageWidth * BQAP_SCREEN_SCALE,
                                       kBQPosterImageHeight * BQAP_SCREEN_SCALE);
        [subscriber sendNext:[self requestImageForAsset:asset
                                             targetSize:posterSize
                                            contentMode:TBVAssetsPickerContentModeFill]];
        [subscriber sendCompleted];
        return nil;
    }] switchToLatest];
}
```

### -requestFullResolutionImageForAsset:
获取原图时有一点很重要，就是尽量不要快速连续地获取原图，大图也可以列入这个范畴。连续地获取大图或者原图，设备的内存会急剧增高，甚至崩溃，这种情况通常在上传图片时比较常见。
所以在上传图片时，尽量上传一张原图后再获取下一张原图进行上传，而不是全部获取完成之后再上传。

```objc
// TBVCachingImageManager
- (RACSignal *)requestFullResolutionImageForAsset:(TBVAsset *)asset {
    return [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
        self.defaultImageRequestOptions.networkAccessAllowed = YES;
        PHImageRequestID requestId = [self.imageManager
                                      requestImageForAsset:(PHAsset *)asset.asset
                                      targetSize:PHImageManagerMaximumSize
                                      contentMode:PHImageContentModeDefault
                                      options:self.defaultImageRequestOptions
                                      resultHandler:^(UIImage * _Nullable result,
                                                      NSDictionary * _Nullable info) {
                                          [subscriber sendNext:RACTuplePack(result, info[PHImageResultIsDegradedKey])];
                                          if (![info[PHImageResultIsDegradedKey] boolValue]) {
                                              [subscriber sendCompleted];
                                          }
                                      }];
        return [RACDisposable disposableWithBlock:^{
            [self.imageManager cancelImageRequest:requestId];
        }];
    }];
}

// TBVAssetsLibrary
- (RACSignal *)requestFullResolutionImageForAsset:(TBVAsset *)asset {
    return [[[RACSignal return:asset.asset]
        deliverOn:[RACScheduler scheduler]]
        map:^id(ALAsset * asset) {
            ALAssetRepresentation *assetRepresentation = [asset defaultRepresentation];
            CGImageRef fullResolutionImage = [assetRepresentation fullResolutionImage];
            UIImage *resultImage = [UIImage imageWithCGImage:fullResolutionImage
                                                       scale:BQAP_SCREEN_SCALE
                                                 orientation:UIImageOrientationUp];
            
            return RACTuplePack(resultImage, @(NO));
        }];
}
```
### -requestSizeForAssets:
请求大小是针对的图片，所以对非图片的asset进行了过滤

```objc
// TBVCachingImageManager
- (RACSignal *)requestSizeForAssets:(NSArray<TBVAsset *> *)assets {
    RACSequence *requestSequence = [[assets.rac_sequence
        filter:^BOOL(TBVAsset *asset) {
            return ((PHAsset *)asset.asset).mediaType == PHAssetMediaTypeImage;
        }]
        map:^id(TBVAsset *asset) {
            return [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
                self.defaultImageRequestOptions.deliveryMode = PHImageRequestOptionsDeliveryModeHighQualityFormat;
                PHImageRequestID requestId =[self.imageManager
                                             requestImageDataForAsset:(PHAsset *)asset.asset
                                             options:self.defaultImageRequestOptions
                                             resultHandler:^(NSData * _Nullable imageData,
                                                             NSString * _Nullable dataUTI,
                                                             UIImageOrientation orientation,
                                                             NSDictionary * _Nullable info) {
                                                 [subscriber sendNext:@(imageData.length)];
                                                 [subscriber sendCompleted];
                                             }];
                return [RACDisposable disposableWithBlock:^{
                    [self.imageManager cancelImageRequest:requestId];
                }];
            }];
        }];
    
    return [[RACSignal
        zip:requestSequence]
        map:^id(RACTuple *value) {
            return [value.rac_sequence foldLeftWithStart:@0 reduce:^id(id accumulator, id value) {
                return @([accumulator integerValue] + [value integerValue]);
            }];
        }];
}

// TBVAssetsLibrary
- (RACSignal *)requestSizeForAssets:(NSArray<TBVAsset *> *)assets {
    return [RACSignal
        return:[[[[assets.rac_sequence
            map:^id(TBVAsset *asset) {
               return asset.asset;
            }]
            filter:^BOOL(ALAsset *asset) {
                return [asset valueForProperty:ALAssetPropertyType] == ALAssetTypePhoto;
            }]
            map:^id(ALAsset *asset) {
                return @([asset defaultRepresentation].size);
            }]
            foldLeftWithStart:@(0) reduce:^id(id accumulator, id value) {
                return @([accumulator integerValue] + [value integerValue]);
            }]];
    
}
```
### -requestAllCollections

```objc
// TBVCachingImageManager
- (RACSignal *)requestAllCollections {
    return [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
        PHFetchResult *smartResult = [PHAssetCollection
                                      fetchAssetCollectionsWithType:PHAssetCollectionTypeSmartAlbum
                                      subtype:PHAssetCollectionSubtypeAlbumRegular
                                      options:nil];
        PHFetchResult *topLevelUserCollections = [PHCollectionList fetchTopLevelUserCollectionsWithOptions:nil];
        
        NSMutableArray *collections = [NSMutableArray array];
        for (PHAssetCollection *aCollection in smartResult) {
            TBVCollection *collection = [TBVCollection collectionWithOriginCollection:aCollection];
            [collections addObject:collection];
        }
        for (PHAssetCollection *aCollection in topLevelUserCollections) {
            TBVCollection *collection = [TBVCollection collectionWithOriginCollection:aCollection];
            [collections addObject:collection];
        }
        [subscriber sendNext:collections];
        [subscriber sendCompleted];
        return nil;
    }];
}

// TBVAssetsLibrary
- (RACSignal *)requestAllCollections {
    return [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
        NSMutableArray *collections = [NSMutableArray array];
        [self.assetsLibrary enumerateGroupsWithTypes:ALAssetsGroupAll
                                          usingBlock:^(ALAssetsGroup *group, BOOL *stop) {
            if (group) {
                TBVCollection *collection = [TBVCollection collectionWithOriginCollection:group];
                [collections addObject:collection];
            } else {
                [subscriber sendNext:collections];
                [subscriber sendCompleted];
            }
        } failureBlock:^(NSError *error) {
            [subscriber sendError:error];
        }];
        return nil;
    }];
}
```
### -requestAssetsForCollection:mediaType:

```objc
// TBVCachingImageManager
- (RACSignal *)requestAssetsForCollection:(TBVCollection *)collection
                                mediaType:(TBVAssetsPickerMediaType)mediaType {
    return [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
        PHFetchOptions *options = [PHFetchOptions tbv_fetchOptionsWithCustomMediaType:mediaType];
        PHFetchResult *fetchResult = [PHAsset fetchAssetsInAssetCollection:(PHAssetCollection *)collection.collection
                                                                   options:options];
        NSMutableArray *assets = [NSMutableArray arrayWithCapacity:fetchResult.count];
        for (PHAsset *asset in fetchResult) {
            [assets addObject:[TBVAsset assetWithOriginAsset:asset]];
        }
        [subscriber sendNext:assets];
        [subscriber sendCompleted];
        return nil;
    }];
}

// TBVAssetsLibrary
- (RACSignal *)requestAssetsForCollection:(TBVCollection *)collection
                                mediaType:(TBVAssetsPickerMediaType)mediaType {
    return [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
        NSMutableArray *assets = [NSMutableArray array];
        ALAssetsGroup *group = (ALAssetsGroup *)collection.collection;
        [group setAssetsFilter:[ALAssetsFilter tbv_assetsFilterWithCustomMediaType:mediaType]];
        [group enumerateAssetsUsingBlock:^(ALAsset *result, NSUInteger index, BOOL *stop) {
            if (result) {
                [assets addObject:[TBVAsset assetWithOriginAsset:result]];
            } else {
                [subscriber sendNext:assets];
                [subscriber sendCompleted];
            }
        }];
        return nil;
    }];
}
```

### -requestCameraRollCollection
```objc
// TBVCachingImageManager
- (RACSignal *)requestCameraRollCollection {
    return [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
        PHFetchResult *smartAlbums = [PHAssetCollection
                                      fetchAssetCollectionsWithType:PHAssetCollectionTypeSmartAlbum
                                      subtype:PHAssetCollectionSubtypeSmartAlbumUserLibrary
                                      options:nil];
        [subscriber sendNext:[TBVCollection collectionWithOriginCollection:smartAlbums.firstObject]];
        [subscriber sendCompleted];
        return nil;
    }];
}

// TBVAssetsLibrary
- (RACSignal *)requestCameraRollCollection {
    return [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
        [self.assetsLibrary enumerateGroupsWithTypes:ALAssetsGroupSavedPhotos usingBlock:^(ALAssetsGroup *group, BOOL *stop) {
            [subscriber sendNext:[TBVCollection collectionWithOriginCollection:group]];
            [subscriber sendCompleted];
        } failureBlock:^(NSError *error) {
            [subscriber sendError:error];
        }];
        return nil;
    }];
}
```

### -requestVideoForAsset:和-requestURLAssetForAsset:
由于业务上没有视频的需求，所以这一块还没有去实现。

## 实现过程中的一些小坑
### 用ALAssetsLibrary申请访问相册权限

这一点貌似有些代码用authorizationStatus就能实现，不过
应用的时候还是发现不能触发请求权限alert，所以这里需要访问下相册的资源[ask-permission-to-access-camera-roll](http://stackoverflow.com/questions/13572220/ask-permission-to-access-camera-roll)，
来触发这个请求动作：

```objc
+ (RACSignal *)tbv_forceTriggerPermissionAsking {
    return [[RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
        void (^sendStatus)() = ^{
            [subscriber sendNext:@([self tbv_authorizationStatus])];
            [subscriber sendCompleted];
        };
        
        if ([self tbv_authorizationStatus] != BQAuthorizationStatusNotDetermined) {
            sendStatus();
            return nil;
        }
        ALAssetsLibrary *lib = [[ALAssetsLibrary alloc] init];
        [lib enumerateGroupsWithTypes:ALAssetsGroupSavedPhotos usingBlock:^(ALAssetsGroup *group, BOOL *stop) {
            sendStatus();
            *stop = YES;
        } failureBlock:^(NSError *error) {
            sendStatus();
        }];
        return nil;
    }] deliverOnMainThread];
}
```

### ALAssetsLibrary请求的ALAsset被置空问题
官方文档里面有这么一句：

```
The lifetimes of objects you get back from a library instance are tied to the lifetime of the library instance.
```
可以看到，在使用ALAssetsLibrary请求回来的资源时，是不能释放对应的ALAssetsLibrary对象的。在发送多图的场合，如果不注意保持住ALAssetsLibrary对象，很容易发生后面几张图片获取不到的情况。

所以，要么在选择器返回选中的资源时，强引用对应的manager，要么这个manager由调用者传给相册选择器。

### 更改应用权限并切回前台
如果应用在后台时，更改了权限，当切回前台后，App会重新启动 。这里如果设置了断点，别以为是程序崩了。

## 不足
一个很明显的问题是使用了RAC的版本后，相册选择器滚动的性能会下降，没有以前通过回调来的顺畅。如果稍微快速一点滚动的话，CPU很容易就上100%。

可能是使用RAC的方式不是很正确造成的，后续尽可能优化这一块。

## 2016-9-25补充
关于grid界面卡顿的原因:<br>
因为这个界面的cell非常多，如果快速滚动时不对获取图片的信号进行throttle，那么CPU的占用率就会很高，从而界面就会变得卡顿。<br>
在这里设置throttle为0.05左右就可以使界面变得比较顺畅，并且不会有太大的刷新延迟以至于影响用户体验。如下：

```
RAC(self, contentImageView.image) = [[[viewModel.contentImageSignal
        throttle:0.05]
        takeUntil:self.rac_prepareForReuseSignal]
        map:^id(RACTuple *value) {
            return [value first];
        }];
```

