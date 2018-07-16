---
layout: post
title: "iOS知识碎片八"
date: 2017-12-02 14:29:02 +0800
comments: true
categories: 碎片系列
---
1、适配iOS11、iOS10导航栏返回按钮<br>

<!--more-->

## 适配iOS11、iOS10导航栏返回按钮

关于导航栏返回按钮的定制，很多时候都是通过设置 navigationItem 的 rightBarButtonItem 属性实现的。这种方式可以设置自己的 customView ，灵活度高。但是和原生的返回按钮相比较，设置 customView 的返回按钮会偏右，而且左边大概会有15个像素的空间，点击不会触发回调。

针对返回按钮偏右问题，一般设置 UIButton 的 contentEdgeInsets 就可以解决。不过自定义返回按钮默认距离屏幕左边15像素的问题，处理起来就比较麻烦了。

一般来说，iOS11 以下版本可以通过 UIBarButtonSystemItemFixedSpace 类型的 SystemItem 来填充距离，只要把 width 设置成负数，就可以让自定义的按钮往两边靠：

```objc
static const CGFloat kTDFNBCButtonMargin = 15.0f;

UIBarButtonItem *item = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil];
item.width = -kTDFNBCButtonMargin;
self.navigationItem.rightBarButtonItems = @[item, [[UIBarButtonItem alloc] initWithCustomView:self.tdf_sureButton]];

UIBarButtonItem *item = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil];
item.width = -kTDFNBCButtonMargin;

self.navigationItem.leftBarButtonItems = @[item, [[UIBarButtonItem alloc] initWithCustomView:self.tdf_backButton]];
```

iOS11 以上 FixedSpace 方案就不生效了，因为整个层级都变了，中间多了两层父控件，所以需要手动更改父控件的布局，可以用 hook UINavigationBar 或者继承的方式重写 `layoutSubviews` ：

```objc
self.layoutMargins = UIEdgeInsetsZero;
for (UIView *view in self.subviews) {
    if ([NSStringFromClass([view class]) containsString:@"ContentView"]) {
        UIEdgeInsets inset = view.layoutMargins;
        view.layoutMargins = UIEdgeInsetsMake(inset.top, 0, inset.bottom, 0);
    }
    
    for (UIView *subview in view.subviews) {
        if([subview isKindOfClass:[UIStackView class]]) {
            for(NSLayoutConstraint *layout in subview.constraints) {
                if(layout.firstAttribute == NSLayoutAttributeWidth ||
                   layout.secondAttribute == NSLayoutAttributeWidth) {
                    layout.constant = 0.f;
                }
            }
        }
    }
}
```

需要注意的时，如果是iOS11，那么就不需要设置 FixedSpace SystemItem 了，否则会干扰第二种方式，出现不必要的动画效果。还有由于iOS11下 customView 多了 UIStackView 父控件，并且尺寸和 customView 一致，这就导致无法使用 customView 的 `hitTest` 对不在其 frame 内的事件进行拦截，因为父控件就已经不满足条件了了。

这种解决方式是在采用原生导航栏的情况下不得已而为之的，如果需要的导航栏花样比较复杂，还是隐藏系统的，自己实现来的舒服。
