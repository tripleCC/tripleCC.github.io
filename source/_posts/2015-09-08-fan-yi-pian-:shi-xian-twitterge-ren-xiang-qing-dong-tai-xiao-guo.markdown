---
layout: post
title: "翻译篇：实现Twitter个人详情动态效果"
date: 2015-09-08 01:32:07 +0800
comments: true
categories: 
---
原文由[ariok](https://github.com/ariok)发表，地址是[implementing-the-twitter-ios-app-ui](http://www.thinkandbuild.it/implementing-the-twitter-ios-app-ui/)

效果图如下：<br>
![](/images/2015-09-08 14_55_03.gif)

原来作者的代码会存在一个Bug：<br>
>当快速下拉时，个人头像并不会立刻显示在HeaderView上方，我已经向作者提交了Pull requests

编译过程中会发生错误，因为swift更新了，所以需要自己解决下错误。

<!--more-->
## 结构描述
在编码之前，我将对UI的结构做一个简单的介绍。<br>

打开Main.storyboard文件。在唯一的一个控制器view中，你可以发现两个主要的对象。第一个是显示Header的视图，第二个是一个包含个人头像(我们叫它Avatar)和其他与账号相关，比如用户名、follow按钮的ScrollView。Sizer控件只是用来确认ScrollView内容是否能进行垂直滚动。<br>

就像你所看到的，这个结构非常简单。需要的注意的是，我将Header放在ScrollView外面，而不是把它和其他ScrollView子控件放在一起。因为这样做可以让这个结构具备更好的扩展性。<br>

## 开始编码
如果你仔细看完动画，你会注意到你可以管理两个不同的动作：<br>

1) 用户下拉（当ScrollView内容已经在屏幕的顶部时）<br>

2) 用户上/下滚动<br>

这个动作可以分解成四步：<br>

2.1) 向上滚动，Header控件缩小直到它的尺寸和导航栏默认尺寸相等，然后这个Header控件就会粘在屏幕的上方<br>

2.2) 向上滚动， Avatar（头像）逐渐变小<br>

2.3) 当Header控件和ScrollView的子控件重叠时，Avatar（头像）在Header控件底部<br>

2.4) 当用户名Label的顶部和Header控件底部重叠时，一个新的白色Label将会从Header控件的中底部显示。并且Header控件的图片变模糊。<br>

打开ViewController.swift，让我们一步一步地实现这些功能<br>

## 设置控制器
第一件需要去做的事是获取ScrollView的offset信息。通过实现UIScrollViewDelegate协议的scrollViewDidScroll方法，我们可以很容易地做到这一点。<br>

一种最简单的展示一个view上变化的方式是使用CoreAnimation三维变换，并且设置新值给layer.transform属性。<br>

这个关于CoreAnimation的教程可能会让它变得简便：<br>
[http://www.thinkandbuild.it/playing-around-with-core-graphics-core-animation-and-touch-events-part-1/.](http://www.thinkandbuild.it/playing-around-with-core-graphics-core-animation-and-touch-events-part-1/.)

以下是scrollViewDidScroll方法的第一部分：

```objc
let offset = scrollView.contentOffset.y
var avatarTransform = CATransform3DIdentity
var headerTransform = CATransform3DIdentity
```
我们可以在这个方法里面获取当前的竖直偏移，并且初始化两个将要在方法后面设置的转换信息。

## 下拉
让我们对下拉动作进行处理：

```objc  
if offset < 0 {
    
    let headerScaleFactor:CGFloat = -(offset) / header.bounds.height
    let headerSizevariation = ((header.bounds.height * (1.0 + headerScaleFactor)) - header.bounds.height)/2.0
    headerTransform = CATransform3DTranslate(headerTransform, 0, headerSizevariation, 0)
    headerTransform = CATransform3DScale(headerTransform, 1.0 + headerScaleFactor, 1.0 + headerScaleFactor, 0)
    
    header.layer.transform = headerTransform
}
```
首先，我们检查偏移量是否为负数，即ScrollView是否已出现弹性区域。<br>

剩下的代码是一些简单的数学运算。<br>

这个Header控件需要放大来保持它的上边缘和屏幕顶部相对固定，并且这个图片是从底部开始放大的。<br>

总的来说，这个变换主要由缩放，然后转化view的尺寸变化为到顶部的距离构成。事实上，你可以朝屏幕顶端移动ImageView图层的中点并且进行缩放来相同的效果。<br>

![](/images/Snip20150908_3.png)

使用一个属性来对头部缩放比例进行计算。我们希望Header控件参照偏移量进行适当的缩放。换种说法：当偏移量为Header视图控件的两倍时，头部缩放比例应该设置为2.0。<br>

我们需要处理的第二个动作是上下滚动。让我们看看如何一步一步地完成主要视图的变换。<br>

## Header（第一阶段）
当前的偏移量应该大于0。Header控件应该根据以下的偏移量来进行竖直移动，直到它到达指定高度（我们下面将会对Header模糊进行讲解）。

```objc
headerTransform = CATransform3DTranslate(headerTransform, 0, max(-offset_HeaderStop, -offset), 0)
```

这段代码真的是很简单。我们只需要设置Header控件偏移一个最小值，Header控件将会在offset_HeaderStop这个点停止移动。<br>

因为我比较懒，所以我写死了一些数值，比如offset_HeaderStop。我们可以通过更加优雅的方式，比如计算UI控件的位置来实现相同的效果。或许在下一次我会试试。<br>

## AVATAR（头像）
这个头像（图片）以和下拉相同的逻辑进行缩放，只是在这种情况下，图片是和底部贴合而不是顶部。这段代码和上面比较相似，除了减小缩放的比例为1.4。<br>

```objc
let avatarScaleFactor = (min(offset_HeaderStop, offset)) / avatarImage.bounds.height / 1.4 // Slow down the animation
let avatarSizeVariation = ((avatarImage.bounds.height * (1.0 + avatarScaleFactor)) - avatarImage.bounds.height) / 2.0
avatarTransform = CATransform3DTranslate(avatarTransform, 0, avatarSizeVariation, 0)
avatarTransform = CATransform3DScale(avatarTransform, 1.0 - avatarScaleFactor, 1.0 - avatarScaleFactor, 0)
```

就像你看到的，当Header控件停止变化时，我们通过min函数来停止对个人头像的缩放（offset_HeaderStop）。<br>

此时，我们根据当前的偏移量来设置最顶层的图层。除非偏移量大于等于offset_HeaderStop，否则顶部图层始终是个人头像。当偏移量大于offset_HeaderStop，这个图层就变成了Header控件。<br>

```objc
if offset <= offset_HeaderStop {
    
    if avatarImage.layer.zPosition < header.layer.zPosition{
        header.layer.zPosition = 0
    }
    
}else {
    if avatarImage.layer.zPosition >= header.layer.zPosition{
        header.layer.zPosition = 2
    }
}

```
## 白色Label
以下是白色Label执行动画的代码：

```objc
let labelTransform = CATransform3DMakeTranslation(0, max(-distance_W_LabelHeader, offset_B_LabelHeader - offset), 0)
headerLabel.layer.transform = labelTransform
```
这里介绍两个新的变量：当偏移量等于offset_B_LabelHeader时，这个黑色的用户名Label刚好到达Header视图的底部。<br>

![](/images/Snip20150908_4.png)<br>

distance_W_LabelHeader是Header控件的底部和Header中的白色Label中点的距离。<br>
![](/images/Snip20150908_5.png)<br>

这个转换通过以下逻辑进行计算：黑色Label一旦喝Header控件相交，白色Label就立即显示，并且白色Label到达Header控件的中点时停止。所以使用以下代码来创建Y的偏移：

```objc
max(-distance_W_LabelHeader, offset_B_LabelHeader - offset)
```

## 模糊

最后一个效果是模糊Header控件。为了得到合适的解决方案，我使用了三个不同的库...我还尝试创建自己的OpenGL ES，但是实时更新模糊效果总是非常迟缓。<br>

我了解到我可以只对模糊进行一次计算，让模糊和非模糊的图片进行重叠，并且改变透明度值。我很确定，这就是Twitter采用的方法。<br>

在viewDidAppear中我们计算模糊的Header并且通过设置透明度为0来进行隐藏。<br>

```objc
headerBlurImageView = UIImageView(frame: header.bounds)
headerBlurImageView?.image = UIImage(named: "header_bg")?.blurredImageWithRadius(10, iterations: 20, tintColor: UIColor.clearColor())
headerBlurImageView?.contentMode = UIViewContentMode.ScaleAspectFill
headerBlurImageView?.alpha = 0.0
header.insertSubview(headerBlurImageView, belowSubview: headerLabel)
```
模糊的view可以使用[FXBlurView](https://github.com/nicklockwood/FXBlurView)得到。<br>

在scrollViewDidScroll方法中，我们只需要根据偏移量来更新透明度就行了。<br>

```objc
headerBlurImageView?.alpha = min (1.0, (offset - offset_B_LabelHeader)/distance_W_LabelHeader)
```

以上计算逻辑主要为：透明度最大值必须为1，模糊效果必须在黑色Label到达Header控件时出现，在白色Label停止后停止加深模糊。<br>

[源码地址](https://github.com/ariok/TB_TwitterUI)