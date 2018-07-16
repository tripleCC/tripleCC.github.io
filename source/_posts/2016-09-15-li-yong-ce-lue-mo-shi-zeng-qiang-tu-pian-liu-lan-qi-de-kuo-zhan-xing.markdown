---
layout: post
title: "利用策略模式增强图片浏览器的扩展性"
date: 2016-09-15 10:33:54 +0800
comments: true
categories: ios
tags: [PhotoBrowser,策略模式]
---
说到图片浏览器，项目中比较常用的成熟框架有Objective-C版本的[MWPhotoBrowser](https://github.com/mwaterfall/MWPhotoBrowser)，[IDMPhotoBrowser](https://github.com/ideaismobile/IDMPhotoBrowser)或者Swift版本的[SKPhotoBrowser](https://github.com/suzuki-0000/SKPhotoBrowser)。<br>

从核心功能来看，MWPhotoBrowser，IDMPhotoBrowser这两个框架，都很好地实现了对本地资源、相册资源、网络资源的获取与显示。并且很好地封装了网络和相册的获取方式，在我看来，这是他的优势，但同时，高度的集成也催生了一些不足。<br>

这样做的优势不言而喻，调用者只需要很少的几行代码，就可以集成一个图片浏览器框架，省时省力。以MWPhotoBrowser为例，在不设置额外属性的情况下，只需要下面两行代码就可以创建：

```objc
MWPhotoBrowser *browser = [[MWPhotoBrowser alloc] initWithPhotos:self.photos];
[self.navigationController pushViewController:browser animated:YES];
```
使用者只要关注如何提供MWPhotoBrowser所要展示资源就可以了，不需要做额外的操作，非常地简洁方便。<br>

关于不足，由于MWPhotoBrowser内部实现了获取网络图片功能，在追求内部实现尽量精简的前提下，不可避免地要依赖加载图片的第三方库(SDWebImage)。如果原来项目并没有使用SDWebImage，而是用YYWebImage或者Kingfisher，那么使用MWPhotoBrowser便会引入冗余的框架，从而让项目额外增加了一种图片缓存机制，不利于内存以及磁盘使用率的优化。<br>

对于相册资源的访问，MWPhotoBrowser内部也实现了通过PHAsset或者ALAsset获取相片的功能。不过一般来说，项目会有自己的一套相册选择器，进而会有相应的相册资源获取策略。所以以个人观点来看，如何获取相册资源，应该由使用者告知，而不是在框架内部自己实现一套，这样更加符合DRY。<br>

接下来，我会针对上面的不足，实现一套兼容本地资源、相册资源、网络资源的简易图片选择器。<br>
本文章对应的所有代码在仓库[TBVImageBrowser](https://github.com/tobevoid/TBVImageBrowser)中。
<!--More-->

### 框架概览
TBVImageBrowser的主要组成如下：<br>
![图一](/images/Snip20160915_3.png)<br>
![图二](/images/Snip20160915_4.png)<br>

从图一可以看出，TBVImageBrowserView持有了一个遵守TBVImageProviderManagerProtocol的对象。根据此持有的策略管理对象，可以通过抽象策略接口TBVImageProviderProtocol访问对应的具体策略类：TBVWebImageProvider、TBVLocalImageProvider、TBVAssetImageProvider和自定义的Provider。<br>

实际上具体的策略都可以由使用者实现，也就是说图一中的TBVWebImageProvider、TBVLocalImageProvider、TBVAssetImageProvider都可以去除，只要提供遵守策略接口TBVImageProviderProtocol的具体策略类就行了。一般来说，访问资源的策略由使用者提供，因为使用者知道自己实际的获取方式。<br>

从图二中可以看出，TBVImageBrowserView持有的策略管理对象的内部组成。只要遵守TBVImageProviderManagerProtocol协议，都可以成为策略管理对象。

除了以上几个协议，我还抽出了TBVImageIdentifierProtocol、TBVImageElementProtocol以及TBVImageProgressPresenterProtocol协议。
TBVImageProviderIdentifierProtocol的声明如下：

```objc
@protocol TBVImageIdentifierProtocol <NSObject>
@required
@property (strong, nonatomic, readonly) NSString *identifier;
@end
```
identifier作为匹配Provider和资源类型的标志，是每个策略必须要实现的。<br>
TBVImageElementProtocol的声明如下：

```objc
@protocol TBVImageElementProtocol <TBVImageIdentifierProtocol>
@required
@property (strong, nonatomic) NSObject *resource;
@property (assign, nonatomic) CGFloat progress;
@optional
@property (strong, nonatomic) NSDictionary *options;
@end
```
TBVImageElementProtocol遵守了TBVImageProviderIdentifierProtocol协议，提供解析自身资源的Provider标志。resource用来存储实际需要获取的资源，progress则表示获取的进度。<br>
TBVImageProgressPresenterProtocol的声明如下：

```objc
@protocol TBVImageProgressPresenterProtocol <NSObject>
+ (instancetype)presenter;
- (void)setPresenterProgress:(CGFloat)progress animated:(BOOL)animated;
@end
```
由于项目中可能有自己的一套loading progress控件，仅仅为了图片选择器而引入另一套控件是不划算的，所以BVImageBrowser的loading progress控件也让使用者来提供，尽量减少不必要依赖。
 
### TBVImageProviderManager
TBVImageProviderManager帮助TBVImageBrowserView管理所有添加的策略，让TBVImageBrowserView得以关注其浏览业务本身，而不必掺杂获取资源的具体逻辑。<br>

首先是添加删除策略接口：

```objc
- (void)addImageProvider:(id<TBVImageProviderProtocol>)provider {
    NSCParameterAssert(provider);
    NSAssert(provider.identifier, @"identifier of %@ can not be nil.", provider);
    TBVLogInfo(@"add provider %@", provider);
    
    @synchronized (self) {
        self.providerMap[provider.identifier] = provider;
    }
}

- (BOOL)removeImageProvider:(id<TBVImageProviderProtocol>)provider {
    NSAssert(provider.identifier, @"identifier of %@ can not be nil.", provider);
    TBVLogInfo(@"remove provider %@", provider);
    
    @synchronized (self) {
        [self.providerMap removeObjectForKey:provider.identifier];
        return [self.providerMap.allKeys containsObject:provider.identifier];
    }
}
```
TBVImageProviderManager中会声明一个providerMap字典，以策略的identifier作key，策略作为value。
接下来是获取资源的接口：

```objc
- (RACSignal *)imageSignalForElement:(id<TBVImageElementProtocol>)element {
    NSAssert(element.identifier, @"identifier of %@ can not be nil.", element);
    
    @weakify(self)
    return [[[RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
        @strongify(self)
        TBVLogInfo(@"\nimage resource:\n\t%@;\nidentifier:\n\t%@;\n", element.resource, element.identifier);
        if ([self.providerMap.allKeys containsObject:element.identifier]) {
            [subscriber sendNext:[self.providerMap[element.identifier]
                    imageSignalForElement:element
                    progress:^(CGFloat progress) {
                        element.progress = progress;
                    }]];
            [subscriber sendCompleted];
        } else {
            NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
            userInfo[kTBVImageBrowserErrorKey] =
            [NSString stringWithFormat:@"image provider with identifier %@ was not found", element.identifier];
            [subscriber sendError:[NSError errorWithDomain:@"TBVImageProviderManager"
                                                        code:-1
                                                    userInfo:userInfo]];
        }
        return nil;
    }]
        switchToLatest]
        catch:^RACSignal *(NSError *error) {
            TBVLogError(@"\nerror domain: \n\t%@; \nerror code: \n\t%ld; \nerror info: \n\t%@;\n", error.domain, error.code, error.userInfo);
            return [RACSignal empty];
    }];
}
```
TBVImageProviderManager根据element提供的identifier，去providerMap字典中查找匹配的策略，并调用策略接口，获取element的resource中存储的资源。

### 载入自定义loading progress控件
在加载一个loading progress控件时，我需要什么样的接口?<br>
首先是控件本身，TBVImageBrowserView需要使用者创建这个控件的实体给TBVImageBrowserView，而控件的具体属性则由调用者在创建控件时一并设置。然后因为是loading progress控件，理所当然地应该提供设置progress的接口。由这两个需求催生TBVImageProgressPresenterProtocol协议，来对使用者提供的loading progress控件进行限定。<br>

有了满足要求的控件，如何在内部进行创建？TBVImageBrowserView需要使用者提供控件对应Class，然后在内部以以下方式进行添加：

```objc
- (void)setupProgressPresenter:(Class)progressPresenter{
    if (self.progressView || !progressPresenter) return;
    
    if ([progressPresenter conformsToProtocol:@protocol(TBVImageProgressPresenterProtocol)]) {
        id presenter = [progressPresenter presenter];
        if ([presenter isKindOfClass:[UIView class]]) {
            self.progressView = presenter;
            [self.contentView addSubview:self.progressView];
            CGSize size = CGSizeEqualToSize(CGSizeZero, self.progressView.frame.size) ?
                CGSizeMake(40.0f, 40.0f) : self.progressView.frame.size ;
            [self.progressView mas_makeConstraints:^(MASConstraintMaker *make) {
                make.width.equalTo(@(size.width));
                make.height.equalTo(@(size.height));
                make.center.equalTo(self.contentView);
            }];
        } else {
            TBVLogError(@"progressPresenter should be subclass of UIView.");
        }
    } else {
        TBVLogError(@"progressPresenter should comfirm TBVImageProgressPresenterProtocol.");
    }
}
```
至此，载入自定义的loading progress控件已经实现了。接下来以DACircularProgress控件为例，说明如何使用。<br>
首先，创建DALabeledCircularProgressView的分类，然后在分类中遵守TBVImageProgressPresenterProtocol协议，并实现其中的接口:

```objc
@implementation DALabeledCircularProgressView (TBVImageProgressPresenter)
+ (instancetype)presenter {
    DALabeledCircularProgressView *progressView = [[DALabeledCircularProgressView alloc] initWithFrame:CGRectMake(0, 0, 40, 40)];
    progressView.thicknessRatio = 0.1;
    progressView.progressLabel.textColor = [UIColor whiteColor];
    progressView.progressLabel.font = [UIFont systemFontOfSize:12];
    progressView.userInteractionEnabled = NO;
    return progressView;
}

- (void)setPresenterProgress:(CGFloat)progress animated:(BOOL)animated {
    [self setProgress:progress animated:animated];
    if (progress != 0 && progress != 1) TBVLogDebug(@"load progress %f", progress);
    
    self.progressLabel.text = [NSString stringWithFormat:@"%.02f", progress];
}
@end
```
并且在初始化TBVImageBrowserView时，传入DALabeledCircularProgressView类：

```objc
_configuration.progressPresenterClass = [DALabeledCircularProgressView class];
```

### 总结
TBVImageBrowser是在自己做IM发送相册图片时造的轮子，由于后期项目本身并没有使用SDWebImage，并且有一套自己访问相册的策略，所以MWPhotoBrowser并不是很符合自己的需求。<br>

TBVImageBrowser遵循了一个原则：使用者应该知道自己如何得到资源，并向框架提供获取资源的方法，这样才能让框架具有更好的扩展性。<br>
详细的使用方法在[仓库说明](https://github.com/tobevoid/TBVImageBrowser)中。