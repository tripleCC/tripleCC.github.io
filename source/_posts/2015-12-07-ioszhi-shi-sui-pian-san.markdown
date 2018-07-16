---
layout: post
title: "iOS知识碎片三"
date: 2015-12-07 17:10:05 +0800
comments: true
categories: 碎片系列
---
1、NSSetUncaughtExceptionHandler注册捕获错误无法调用<br>
2、自定义提示宏<br>
3、frame和bounds<br>
4、Swift中inout和C/C++中指针/引用的区别<br>
5、获取UICollectionView的高度<br>
<!--more-->

## NSSetUncaughtExceptionHandler注册捕获错误无法调用
原因是老代码中集成了友盟分析，并且没有关闭友盟错误收集机制。友盟内部的错误收集方式也是采用这个方式，所以自己注册的错误处理函数被友盟覆盖，因此不会被执行。

同理，多种第三方的错误日志应该是不能同时实现捕获的。也是看到了友盟的文件夹才想到这点，stackoverflow上面说的都不是很符合这种情况。

## 自动提示宏
什么情况下需要用到自动提示宏

  - 使用KVO，KVC时使用(归档的时候也可以使用，这样就不用设置一堆宏了)

```objc
keyPath(objc, keyPath) @(((void)objc.keyPath, #keyPath))
// void 去警告
// # 表示转成c字符串
// , 逗号表达式，取最右的值
// @() 基本类型转oc类型
```
## frame和bounds
今天要实现图片浏览器中的一个需求，然后就遇到了这个问题，需要明确两者之间的区别。后来google了一些资料，有一篇[UIScrollView原理](https://www.objc.io/issues/3-views/scroll-view/)解决了我的问题。

里面对于我最重要的就是这句话了：

```
This is, in fact, exactly how a scroll view works when you set its contentOffset property: it changes the origin of the scroll view’s bounds
```
所以UIScrollView的偏移是通过设置bounds的origin来实现的。看了一些MWPhotoBrowser源码也确实使用UIScrollView的bounds来改变对应子视图的frame：

```
- (void)layoutSubviews {
	....
	// Update tap view frame
	_tapView.frame = self.bounds;
	....
	[super layoutSubviews];
	....
}
```

然后忽然又想到了另一个问题，在这里记录备忘：`CGAffineTransform实际改变的是bounds`。

[iOS-Core-Animation-Advanced-Techniques](https://github.com/AttackOnDobby/iOS-Core-Animation-Advanced-Techniques)中有一句：

```
frame并不是一个非常清晰的属性，它其实是一个虚拟属性，是根据bounds，position和transform计算而来
```
所以改变视图的transform，实际上是改变其layer的bounds。苹果相关库头文件中也有这么一句话：

```
extension UIView {
    
    // animatable. do not use frame if view is transformed since it will not correctly reflect the actual location of the view. use bounds + center instead.
    public var frame: CGRect
	// use bounds/center and not frame if non-identity transform. if bounds dimension is odd, center may be have fractional part
    public var bounds: CGRect // default bounds is zero origin, frame size. animatable
    public var center: CGPoint // center is center of frame. animatable
    ...
}
```

## Swift中inout和C/C++中指针/引用的区别
首先明确概念：

- inout是passed-in-passed-back形式
- C/C++中是引用形式

关于inout关键字，Swift的一些官方文档给出了很详细的一些回答，如下:<br>
![](/images/Snip20151231_1.png)<br>
![](/images/Snip20151231_3.png)<br>
![](/images/Snip20151231_4.png)<br>
![](/images/Snip20151231_5.png)<br>
从这么多篇幅的解释中，可以很清楚地知道inout的作用方式：<br>
1、函数被调用，拷贝实参<br>
2、拷贝在函数中被修改<br>
3、函数返回，拷贝被赋给源参<br>
并且一旦相应的函数返回，上面步骤就结束了，剩下的操作便无法改变源参。以下代码段都不会改变传入的参数：

```
/// 1
func increment(inout n: Int) -> () -> Int {
    return { ++n }
}
var x = 0
let i = increment(&x)
print(x)   // 0
print(i()) // 1

/// 2
func increment(inout n: Int) {
    dispatch_async(dispatch_get_global_queue(0, 0)) { () -> Void in
        // 假设在子线程执行前就已经return
        ++n
    }
}
var x = 0
increment(&x)
print(x) // 0
```
在Swift中，如果想改变上面代码段传入的参数，可以使用UnsafeMutablePointer指针（只是例子，实际并不推荐这么做，这种方式是不安全的）:

```
/// 1
func increment(n: UnsafeMutablePointer<Int>) -> () -> Int {
    return { ++n.memory }
}
var x = 0
increment(&x)()
print(x)

/// 2
func increment(n: UnsafeMutablePointer<Int>) {
    dispatch_async(dispatch_get_global_queue(0, 0)) { () -> Void in
        // 假设在子线程执行前就已经return
        ++n.memory
    }
}
var x = 0
increment(&x)
sleep(1)
print(x)
```

## 获取UICollectionView的高度

UICollectionView的高度通过其布局属性，也就是以下属性进行获取：

```
@property (nonatomic, strong) UICollectionViewLayout *collectionViewLayout;
```
布局属性有个获取Size的方法：

```
- (CGSize)collectionViewContentSize;
```
需要注意的是这个方法UICollectionViewLayout的子类必须进行重写（流水布局已经重写了）。<br>
这样就可以在UICollectionView的子类中重写sizeToFit方法进行自适应了：

```
- (void)sizeToFit {
    [super sizeToFit];
    self.frame = (CGRect){
        .origin = self.frame.origin,
        .size = self.collectionViewLayout.collectionViewContentSize
    };
}
```
同理，如果是一个视图的子视图，也可以同时设置父视图的frame：

```
- (void)sizeToFit {
    [super sizeToFit];
    _collectionView.frame = (CGRect){
        .origin = _collectionView.frame.origin,
        .size = _collectionView.collectionViewLayout.collectionViewContentSize
    };
    self.frame = _collectionView.bounds;
}
```
这样以来就可以很方便地对UICollectionView进行一些操作了，比如在UITableView中嵌入一个流水布局的UICollectionView就可以利用上面的方法获取其实际高度。[实际业务的应用](https://github.com/tripleCC/TPCSkillTagView)