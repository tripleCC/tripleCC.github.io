---
layout: post
title: "新浪微博iOS底部功能按钮简单实现"
date: 2015-06-29 20:31:41 +0800
comments: true
categories: ios
---

![效果图](/images/2015-09-08 01_23_36.gif)

## 以上效果主要涉及点

- 1.九宫格布局

- 2.形变动画

- 3.UIView动画
<!--more-->
首先，考虑图片的效果，初步采用使用modal控制器来实现，但是考虑到modal最后会移除modal他的控制器的view，所以，还是使用自定义UIView来实现这个功能。

做这种功能，首先实现的是按钮出现位置，后面在实现动画就容易了。

- 1.首先进行九宫格布局，创建模型传入指定数量的按钮，并且使用形变，将所有的按钮移动到看不见的坐标

- 2.点击底部按钮后，设置形变至屏幕区域（这里直接设置成CGAffineTransformIdentity）

- 3.对功能按钮的点击和松开进行监听（实现touches方法也可），按钮点击功能菜单按钮后，使用形变设置按钮变大，松开时，再设置形变变大，并且使其透明度为0

- 4.再点击底部按钮后，设置形变至不可见区域

明确几个功能点后，动画效果就好说了。

- 1.点击底部按钮后，使用UIView弹性动画，每个按钮设置不同的delay，这样就实现了弹簧与时间间隔效果了。

```objc

+ (void)animateWithDuration:(NSTimeInterval)duration delay:(NSTimeInterval)delay usingSpringWithDamping:(CGFloat)dampingRatio initialSpringVelocity:(CGFloat)velocity options:(UIViewAnimationOptions)options animations:(void (^)(void))animations completion:(void (^)(BOOL finished))completion

```

- 2.点击功能菜单后，在点击时使用普通UIView动画，使按钮变大，松开时，再次使用UIView，让按钮变大的同时渐渐消失

- 3.再次点击底部按钮后，使用普通的UIView动画，倒序隐藏并缩小按钮

github：[代码地址](https://github.com/tripleCC/TPCSpringMenu)