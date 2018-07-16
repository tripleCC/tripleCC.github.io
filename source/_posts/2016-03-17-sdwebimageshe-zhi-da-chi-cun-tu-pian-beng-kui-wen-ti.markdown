---
layout: post
title: "SDWebImage设置大尺寸图片崩溃问题"
date: 2016-03-17 18:41:01 +0800
comments: true
categories: ios
---
昨天产品在teambition上提了一个bug：点击特定的页面app闪退。<br>
我很是纳闷，因为通过其它类型索引进入的详情页面都不会出现这样的情况，为什么偏偏是这个页面？还是因为memory warning而闪退？而且内存不是慢慢增加，而是从80M左右激增到600M＋<br>
接着我查看了进入这个页面时获取的json，仔细观察后，发现并没有特别的地方。于是我决定使用instruments的Allocations查看到底是什么操作占用了如此庞大的内存。<br>
进入界面之后，展示的界面如下图：
<!--more-->

![](/images/Snip20160317_2.png)

追踪到底是哪个函数调用申请了这么多内存：

![](/images/Snip20160317_4.png)

根据经验，考虑到SDWebImage是直接使用原图进行渲染，所以初步可以断定是图片渲染导致内存的问题。<br>
于是我查看了这个界面唯一的图片：

![](/images/Snip20160317_1.png)

![](/images/Snip20160317_5.png)

...WTF...<br>
问了后台，这个图片是企业上传的，最大不超过2M，而且给App的图片并没有经过压缩处理。接着我又查看了安卓端，发现他们并没有显示出这一张logo。。。<br>

[图片链接](http://cv.qiaobutang.com//uploads//company_logos//2014//12//12//20//548ae4240cf23e379a82db93//original.png)

虽然图片只有1.8M，但是像素为15497*10166，iOS解压到内存并显示所需要的内存通过以下公式计算出：

```objc
#define bytesPerMB 1048576.0f 
// 这里针对32色来说 (32 / 8)
#define bytesPerPixel 4.0f
#define pixelsPerMB ( bytesPerMB / bytesPerPixel )

 Width x Height / pixelsPerMB
```
所以大概可以计算出这张图片需要600M左右的内存进行解码显示。

google了下，最多的解决方式是利用UIGraphicsBeginImageContext对图片进行裁剪后渲染：

```objc

UIGraphicsBeginImageContext(size);
CGContextRef context = UIGraphicsGetCurrentContext();
CGContextClearRect(context, CGRectMake(0, 0, size.width, size.height));

CGContextSetInterpolationQuality(context, 0.8);

[self drawInRect:drawRect blendMode:kCGBlendModeNormal alpha:1];

UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
UIGraphicsEndImageContext();

```
虽然这样做最终会让内存稳定在80M左右，但是在回落之前，内存会有一小段时间上升至300M左右。也就是说，这种方法在处理10000*10000px的图片时，还是有崩溃的危险的。<br>

然后我又尝试了苹果提供的使用ImageIO进行缩小图片的方法：

```objc
CGImageRef MyCreateThumbnailImageFromData (NSData * data, int imageSize)
{
    CGImageRef        myThumbnailImage = NULL;
    CGImageSourceRef  myImageSource;
    CFDictionaryRef   myOptions = NULL;
    CFStringRef       myKeys[3];
    CFTypeRef         myValues[3];
    CFNumberRef       thumbnailSize;
    
    // Create an image source from NSData; no options.
    myImageSource = CGImageSourceCreateWithData((CFDataRef)data,
                                                NULL);
    // Make sure the image source exists before continuing.
    if (myImageSource == NULL){
        fprintf(stderr, "Image source is NULL.");
        return  NULL;
    }
    
    // Package the integer as a  CFNumber object. Using CFTypes allows you
    // to more easily create the options dictionary later.
    thumbnailSize = CFNumberCreate(NULL, kCFNumberIntType, &imageSize);
    
    // Set up the thumbnail options.
    myKeys[0] = kCGImageSourceCreateThumbnailWithTransform;
    myValues[0] = (CFTypeRef)kCFBooleanTrue;
    myKeys[1] = kCGImageSourceCreateThumbnailFromImageIfAbsent;
    myValues[1] = (CFTypeRef)kCFBooleanTrue;
    myKeys[2] = kCGImageSourceThumbnailMaxPixelSize;
    myValues[2] = (CFTypeRef)thumbnailSize;
    
    myOptions = CFDictionaryCreate(NULL, (const void **) myKeys,
                                   (const void **) myValues, 2,
                                   &kCFTypeDictionaryKeyCallBacks,
                                   & kCFTypeDictionaryValueCallBacks);
    
    // Create the thumbnail image using the specified options.
    myThumbnailImage = CGImageSourceCreateThumbnailAtIndex(myImageSource,
                                                           0,
                                                           myOptions);
    // Release the options dictionary and the image source
    // when you no longer need them.
    CFRelease(thumbnailSize);
    CFRelease(myOptions);
    CFRelease(myImageSource);
    
    // Make sure the thumbnail image exists before continuing.
    if (myThumbnailImage == NULL){
        fprintf(stderr, "Thumbnail image not created from image source.");
        return NULL;
    }
    
    return myThumbnailImage;
}
```
结果和使用UIGraphicsBeginImageContext一样，会有一个内存波峰。<br>

最终还是通过苹果找到了对应的解决方案：
[LargeImageDownsizing](https://developer.apple.com/library/ios/samplecode/LargeImageDownsizing/)(最终尝试后只对jpg有效)<br>
在stackoverflow上用蹩脚的书面英文也获取了对应的方案：
[App crashed when I display a large image by UIImageView](http://stackoverflow.com/questions/36031808/app-crashed-when-i-display-a-large-image-by-uiimageview/36032154#36032154)

不过最终我还是采用了和安卓端一样的处理方法（考虑到后台以后会进行图片裁剪）。因为是针对所有显示图片的地方，所以我给UIImageView添加了一个分类来对图片大小进行限制：

```objc
@implementation UIImageView (Extension)
+ (void)load
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class class = [self class];
        
        SEL origionSel = @selector(setImage:);
        SEL swizzlingSel = @selector(bq_setImage:);
        Method origionMethod = class_getInstanceMethod(class, origionSel);
        Method swizzlingMethod = class_getInstanceMethod(class, swizzlingSel);
        
        BOOL hasAdded = class_addMethod(class, origionSel, method_getImplementation(swizzlingMethod), method_getTypeEncoding(swizzlingMethod));
        
        if (hasAdded) {
            class_replaceMethod(class, swizzlingSel, method_getImplementation(origionMethod), method_getTypeEncoding(origionMethod));
        } else {
            method_exchangeImplementations(origionMethod, swizzlingMethod);
        }
    });
}

- (void)bq_setImage:(UIImage *)image {
    CGFloat maxImageWH = 3000;
    if (image.size.width > maxImageWH || image.size.height > maxImageWH) {
        image = self.placeholder;
    }
    [self bq_setImage:image];
}

- (void)setPlaceholder:(UIImage *)placeholder {
    objc_setAssociatedObject(self, @selector(placeholder), placeholder, OBJC_ASSOCIATION_RETAIN);
}

- (UIImage *)placeholder {
    return objc_getAssociatedObject(self, _cmd);
}
@end
```
在宽度或者高度可能超过3000的地方，提前设置placeholder，否则显示的将是一个空白UIImageView。<br>
对于苹果提供的那种方法，后面再继续研究下，和[YYWebImage](https://github.com/ibireme/YYWebImage)的显示方式有点像，都是进行逐步显示，而不是直接对整个原图进行渲染。

## 2016-9-12 新动态
```objc

UIGraphicsBeginImageContext(size);
CGContextRef context = UIGraphicsGetCurrentContext();
CGContextClearRect(context, CGRectMake(0, 0, size.width, size.height));

CGContextSetInterpolationQuality(context, 0.8);

[self drawInRect:drawRect blendMode:kCGBlendModeNormal alpha:1];

UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
UIGraphicsEndImageContext();

```
以上代码针对jpg是有效的，针对png会出现原来说的那种情况。

## 2016-9-23 新动态＝＝，我傻逼了！
嗯，苹果提供的方法是可行的，下面代码创建字典的时候漏了一个限定图片大小的键值对。＝＝|

```objc
CGImageRef MyCreateThumbnailImageFromData (NSData * data, int imageSize)
{
    CGImageRef        myThumbnailImage = NULL;
    CGImageSourceRef  myImageSource;
    CFDictionaryRef   myOptions = NULL;
    CFStringRef       myKeys[3];
    CFTypeRef         myValues[3];
    CFNumberRef       thumbnailSize;
    
    // Create an image source from NSData; no options.
    myImageSource = CGImageSourceCreateWithData((CFDataRef)data,
                                                NULL);
    // Make sure the image source exists before continuing.
    if (myImageSource == NULL){
        fprintf(stderr, "Image source is NULL.");
        return  NULL;
    }
    
    // Package the integer as a  CFNumber object. Using CFTypes allows you
    // to more easily create the options dictionary later.
    thumbnailSize = CFNumberCreate(NULL, kCFNumberIntType, &imageSize);
    
    // Set up the thumbnail options.
    myKeys[0] = kCGImageSourceCreateThumbnailWithTransform;
    myValues[0] = (CFTypeRef)kCFBooleanTrue;
    myKeys[1] = kCGImageSourceCreateThumbnailFromImageIfAbsent;
    myValues[1] = (CFTypeRef)kCFBooleanTrue;
    myKeys[2] = kCGImageSourceThumbnailMaxPixelSize;
    myValues[2] = (CFTypeRef)thumbnailSize;
    
    // 就是这里，numValues应该是3，不是2。＝＝
    myOptions = CFDictionaryCreate(NULL, (const void **) myKeys,
                                   (const void **) myValues, 3,
                                   &kCFTypeDictionaryKeyCallBacks,
                                   & kCFTypeDictionaryValueCallBacks);
    
    // Create the thumbnail image using the specified options.
    myThumbnailImage = CGImageSourceCreateThumbnailAtIndex(myImageSource,
                                                           0,
                                                           myOptions);
    // Release the options dictionary and the image source
    // when you no longer need them.
    CFRelease(thumbnailSize);
    CFRelease(myOptions);
    CFRelease(myImageSource);
    
    // Make sure the thumbnail image exists before continuing.
    if (myThumbnailImage == NULL){
        fprintf(stderr, "Thumbnail image not created from image source.");
        return NULL;
    }
    
    return myThumbnailImage;
}
```
 
还有一篇关于这个的文章[resizing-high-resolution-images-on-ios-without-memory-issues](http://pulkitgoyal.in/resizing-high-resolution-images-on-ios-without-memory-issues/)。

大体的意思就是有以下几点:

- 解码PNG占用了高内存
- CoreGraphic缩放图片时，还是会对图片进行解码
- 需要在不解码的情况下对图片进行缩放
- ImageIO的ImageSource可以满足这一点，不解码并可以缩放

代码差不多是这样：

```objc
CGImageRef thumbnailImageWithData(NSData *data, NSInteger imageSize) {
    CGImageSourceRef imageSource = CGImageSourceCreateWithData((CFDataRef)data, NULL);
    CFDictionaryRef options =
        (__bridge CFDictionaryRef) @{
                                     (id) kCGImageSourceCreateThumbnailWithTransform : @YES,
                                     (id) kCGImageSourceCreateThumbnailFromImageAlways : @YES,
                                     (id) kCGImageSourceThumbnailMaxPixelSize : @(imageSize)
                                     };
    CGImageRef thumbnail = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options);
    CFRelease(imageSource);

    return thumbnail;
}
```

这样的话，最终的解决方案差不多可以是这样的：

- 用MethodSwizzling替换UIImageView的setImage方法
- 然后判断当前图片大小，如果大于某个限制，就用上面的函数缩放图片

嗯，就酱紫。还是要理解原理，然后细心点。