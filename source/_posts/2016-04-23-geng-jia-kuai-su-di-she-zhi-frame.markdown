---
layout: post
title: "更加快速地设置Frame"
date: 2016-04-23 13:14:55 +0800
comments: true
categories: objective-c
tags: [objective-c,frame]
---
由于现在手头上的项目是基于frame开发的，没有xib或者storyboard，没有使用自动布局，所以排布界面时总是显得很繁琐。<br>

#### 令人蛋疼的frame布局
老代码对界面的坐标尺寸设置都是通过下面的方式：

```
...
UIView * mainView = [[UIView alloc] initWithFrame:CGRectMake(0, self.height, self.width, MAIN_HEIGHT)];
[mainView setBackgroundColor:[UIColor whiteColor]];
[self addSubview:mainView];
self.mainView = mainView;

UIView * opertionMenu = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.width, 45)];
[opertionMenu setBackgroundColor:[UIColor whiteColor]];
[mainView addSubview:opertionMenu];

UIView * line = [[UIView alloc] initWithFrame:CGRectMake(0, 44, self.width, 1)];
[line setBackgroundColor:[UIColor colorWithHex:0xe9e9e9]];
[opertionMenu addSubview:line];
...
```
这些坐标设置工作都是在初始化，也就是init系列方法中完成的。这样做的弊端很明显，复用性很差，如果还是按照这种方式的话，每扩展一种界面类型，就要新增一个init方法。久而久之，冗余代码会越来越多，新增特性想重用这块控件的话，需要做比较多的无用功。<br>

<!--more-->

由于上面代码很多针对坐标尺寸的设置都是在init系列方法中完成的，所以很少有单独修改frame中的某个成员的操作，不过旧代码还是提供了快速设置某个成员的方法：

```
@interface UIView (Size)
...
- (CGFloat)width;
- (CGFloat)height;
- (CGFloat)minX;
- (CGFloat)midX;
- (CGFloat)maxX;
- (CGFloat)minY;
- (CGFloat)midY;
- (CGFloat)maxY;
...
@end
```
很明显地看出，这种分类命名是有问题的（这也是直接导致我后续没有引入masonry的诱因之一，旧代码中过多的使用了以上分类，和简易的masonry用法即没有mas前缀的方法产生的冲突过多）。<br>

于是我新增了一些快速设置的坐标的分类方法：

```
@interface UIView (Size)
...
@property (assign, nonatomic) CGFloat bq_y;
@property (assign, nonatomic) CGFloat bq_x;
@property (assign, nonatomic) CGFloat bq_width;
@property (assign, nonatomic) CGFloat bq_height;
@property (assign, nonatomic) CGFloat bq_centerX;
@property (assign, nonatomic) CGFloat bq_centerY;
@property (assign, nonatomic) CGPoint bq_origin;
@property (assign, nonatomic) CGSize bq_size;
@property (assign, nonatomic) CGFloat bq_maxX;
@property (assign, nonatomic) CGFloat bq_maxY;
@property (assign, nonatomic, readonly) CGPoint bq_subCenter;
@property (assign, nonatomic, readonly) CGFloat bq_subCenterX;
@property (assign, nonatomic, readonly) CGFloat bq_subCenterY;
- (instancetype)bq_sizeToFit;
...
@end
```

于是代码中就多了另外一种设置frame的书写格式：

```
- (void)adjustSubviewFrame {
    ...
    if (!_timeLabel.hidden) {
        [_timeLabel sizeToFit];
        CGFloat timeLabelLRMargin = 5;
        CGFloat timeLabelTopMaigin = BQMessageCommonMargin;
        _timeLabel.bq_size = CGSizeMake(_timeLabel.bq_width + 2 * timeLabelLRMargin, BQMessageTimeHeight);
        _timeLabel.center = CGPointMake(self.contentView.bq_centerX, timeLabelTopMaigin + _timeLabel.bq_height * 0.5);
    } else {
        _timeLabel.frame = CGRectZero;
    }
    CGFloat headImageEdgeMargin = BQMessageCommonMargin;
    CGFloat headImageViewX = _isSelf ? self.contentView.bq_width - _headIconImageView.bq_width - headImageEdgeMargin : headImageEdgeMargin;
    CGFloat headImageViewY = CGRectGetMaxY(_timeLabel.frame) + headImageEdgeMargin;
    _headIconImageView.bq_origin = CGPointMake(headImageViewX, headImageViewY);
    if (!_identityButton.hidden) {
        CGFloat identifyButtonTopMargin = BQMessageHeaderBottomMargin;
        CGFloat identifyButtonY = CGRectGetMaxY(_headIconImageView.frame) + identifyButtonTopMargin;
        _identityButton.bq_y = identifyButtonY;
        _identityButton.bq_centerX = _headIconImageView.bq_centerX;
    }
    CGFloat nameLabelToHeadImageTopMargin = 0;
    if (!_nameLabel.hidden) {
        [_nameLabel sizeToFit];
        CGFloat nameLabelX = CGRectGetMaxX(_headIconImageView.frame) + headImageEdgeMargin;
        CGFloat nameLabelY = _headIconImageView.bq_y + nameLabelToHeadImageTopMargin;
        _nameLabel.bq_origin = CGPointMake(nameLabelX, nameLabelY);
    }
    ...
}

```
把设置可变坐标的代码独立出来放进一个方法中增强的控件的复用性，但是也无形中增加了布局代码代码量，而且估计第二个人来看这个计算过程也会很头大。<br>

能不能采用链式的方式简化对界面进行frame布局的代码？于是我借鉴了masonry的实现方式，弄了一套快速设置frame的代码。最终使用的效果：

```
UIView *v1 = [UIView new];
v1.tpc_quickAttribute
.referToView(self.view)
.addToView(self.view)
.alignOrigin(CGPointMake(10, 20))
.alignSize(CGSizeMake(-200, -400))
.backgroundColor([UIColor redColor]);

UIView *v2 = [UIView new];
v2.tpc_quickAttribute
.referToView(v1)
.addToView(v1)
.size(CGSizeMake(20, 20))
.alignCenter(pzero)
.backgroundColor([UIColor orangeColor]);

UIView *v3 = [UIView new];
v3.tpc_quickAttribute
.addToView(self.view)
.referToView(v1)
.alignSize(CGSizeMake(20, 20))
.referToView(self.view)
.alignRightToRight(20)
.alignBottomToBottom(20)
.backgroundColor([[UIColor grayColor] colorWithAlphaComponent:0.4]);
```
顿时感觉整个世界又变清新了。。。<br>

#### 实现的思路<br>
首先，给UIView绑定一个布局实例：

```
<UIView+TPCQuickAttribute.m>

- (TPCQuickAttribute *)tpc_quickAttribute {
    TPCQuickAttribute *quickAttribute = objc_getAssociatedObject(self, _cmd);
    if (!quickAttribute) {
        quickAttribute = [[TPCQuickAttribute alloc] initWithView:self];
        objc_setAssociatedObject(self, _cmd, quickAttribute, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return quickAttribute;
}
```
这个TPCQuickAttribute就是进行快速设置frame的关键：

```
<TPCQuickAttribute.h>

#if TPC_OPEN_LOG == 1
#ifdef DEBUG
#define TPCLayoutLog(s, ... ) NSLog( @"<%s:(%d)> %@", __FUNCTION__, __LINE__, [NSString stringWithFormat:(s), ##__VA_ARGS__] ) 
#else
#define TPCLayoutLog(s, ... )
#endif
#else
#define TPCLayoutLog(s, ... )
#endif
@interface TPCQuickAttribute : NSObject <TPCQuickProtcol>
- (instancetype)initWithView:(UIView *)view;
@property (weak, nonatomic, readonly) UIView *view;
@property (weak, nonatomic) UIView *referView;
@property (assign, nonatomic, readonly) BOOL referViewIsSuperview;

- (TPCQuickAttribute *(^)(UIView * view))referToView;
- (TPCQuickAttribute *(^)(UIView *))addToView;
- (void)end;
@end
```
这个类包含了要进行布局的view对象，还有进行参考的referView。<br>
一旦设置好了这两者，就可以进行下一步操作了：

```
<TPCQuickAttribute+Frame.m>
...
- (TPCQuickAttribute *(^)(CGFloat))alignLeftToLeft {
    return ^TPCQuickAttribute *(CGFloat offset) {
        return self.x(self.referViewX + offset);
    };
}

- (TPCQuickAttribute *(^)(CGFloat))alignLeftToRight {
    return ^TPCQuickAttribute *(CGFloat offset) {
        return self.alignLeftToLeft(self.referView.frame.size.width + offset);
    };
}
...
```
上面代码参考referView，对view的x坐标进行设置。对于这种链式的实现原理，就是利用了返回的block是一个无名函数，可以通过( )执行，这样对上面的方法进行调用，产生以下效果：

```
xxx.alignLeftToLeft(0)
```
了解了block的使用方式就没什么复杂的了。<br>
既然可以快速设置frame，那么常用属性呢？再增加一个分类：

```
<TPCQuickAttribute+Appearance.m>
...
- (TPCQuickAttribute *(^)(UIColor *))backgroundColor {
    return ^TPCQuickAttribute *(UIColor *backgroundColor) {
        self.view.backgroundColor = backgroundColor;
        return self;
    };
}

- (TPCQuickAttribute *(^)(UIViewContentMode))contentMode {
    return ^TPCQuickAttribute *(UIViewContentMode contentMode) {
        self.view.contentMode = contentMode;
        return self;
    };
}

...
```
同理，综合上面的代码，就可以链式地写出设置frame的代码了。<br>

#### 小结
当然，现在有了自动布局，一般界面已经不需要使用frame进行布局了，代码的自动布局可以使用masonry，我私下也喜欢用storyboard+xib的方式写一些小demo。<br>
所以以上代码纯属玩票＝＝。<br>
[代码链接](https://github.com/tripleCC/TPCQuickAttribute)
