---
layout: post
title: "iOS知识碎片六"
date: 2016-08-10 21:23:43 +0800
comments: true
categories: 碎片系列
tags: [碎片系列]
---
1、dispatch_after及NSTimer造成对象无法释放<br>
2、宏定义`##`与`#`<br>
3、Swift实现原子属性<br>
4、Xcode图像化调试错误<br>
5、UITabBarController调用viewDidLoad的时机<br>
<!--more-->

## dispatch_after及NSTimer造成对象无法释放
dispatch_after：<br>

- 由于dispatch_after会持有block内的对象，所以会使这个对象延迟释放。使用时最好能确保block内的对象都是weak的，这样不容易出问题。

NSTimer:

- NSTimer在手动停止或截止时间点到达前，是不会释放的。所以为了能让使用NSTimer的对象能够顺利释放自身，最好对NSTimer使用**__weak**关键字，并且在dealloc时，手动停止NSTimer。如下：

```objc
...

{

    __weak NSTimer *_timer;

}
...

- (void)dealloc {

    [_timer invalidate]

}
```

## 宏定义`##`与`#`
- `##`链接符
  - 将两个字串连接起来
  	- “##”是一种分隔连接方式，它的作用是先分隔，然后进行强制连接。

	- 预处理器一般把`空格`解释成分段标志，对于每一段和前面比较，相同的就被替换。这样做的结果是， 被替换段之间存在一些空格。如果我们不希望出现这些空格，就可以通过添加一些 ##来替代空格。

	- 另外一些分隔标志是，包括操作符，比如 +, -, *, /, [,], …，

	- 强制连接的作用是，去掉和前面的字符串之间的空格，而把两者连接起来


```
#define A1(name, type) type name_##type##_type 

#define A2(name, type) type name##_##type##_type

A1(a1, int); /* 等价于: int name_int_type; */ 

A2(a1, int); /* 等价于: int a1_int_type; */

1) 在第一个宏定义中，”name”和第一个”_”之间，以及第2个”_”和第二个

 ”type”之间没有被分隔，所以预处理器会把name_##type##_type解释成3段：

 “name_”、“type”、以及“_type”，这中间只有“type”是在宏前面出现过

 的，所以它可以被宏替换。

2) 而在第二个宏定义中，“name”和第一个“_”之间也被分隔了，所以

 预处理器会把name##_##type##_type解释成4段：“name”、“_”、“type”

 以及“_type”，这其间，就有两个可以被宏替换了。

3) A1和A2的定义也可以如下：

#define A1(name, type) type name_ ##type ##_type

<##前面随意加上一些空格>

#define A2(name, type) type name ##_ ##type ##_type

结果是## 会把前面的空格去掉完成强连接，得到和上面结果相同的宏定义

```

- `#`

    - 对这个变量替换后，添加双引号
    
```objc
// 在打印枚举名时很好用
#define BQ_PUSH_MESSAGE_TYPE_ELEMENT(key) @(key) : @#key

BQPushMessageTypeStringsMap = @{
                                    BQ_PUSH_MESSAGE_TYPE_ELEMENT(BQPushMessageTypeChat),
                                    BQ_PUSH_MESSAGE_TYPE_ELEMENT(BQPushMessageTypeSystem),
                                    BQ_PUSH_MESSAGE_TYPE_ELEMENT(BQPushMessageTypeLive),
                                    };
```

## Swift实现原子属性
```swift

public struct SafeForm <U> {
    public var lock: AnyObject!
     public var value: U
     public var safeValue: U {
         get {
             return withLock {
	             return value
             }
         }
         set {
             withLock {
                 value = newValue
             }
         }
     }
     /* 不可与safeValue混用 */
     public func sync_enter() {
         objc_sync_enter(lock)
     }
     public func sync_exit() {
         objc_sync_exit(lock)
     }
     private func withLock<R>(@noescape action: () -> R) -> R {
         objc_sync_enter(lock)
         let result = action()
         objc_sync_exit(lock)
         return result
     }
}
```

实际上感觉原子属性的作用并不是很明显，对一个多步操作，还是需要自己手动加锁。

## Xcode图像化调试错误
报错：

```
Assertion failure in -[UITextView _firstBaselineOffsetFromTop], /BuildRoot/Library/Caches/com.apple.xbs/Sources/UIKit_Sim/UIKit-3512.60.7/UITextView.m:1683
```

添加以下代码即可：

```objc

@interface UITextView(MYTextView) 

@end 

@implementation UITextView (MYTextView) 

- (void)_firstBaselineOffsetFromTop { } 

- (void)_baselineOffsetFromBottom { } 

@end

```

或者

```swift

extension

UITextView 

{ 

func _firstBaselineOffsetFromTop() { } 

func _baselineOffsetFromBottom() { } 

}

```

## UITabBarController调用viewDidLoad的时机

继承UITabBarController后，从外部调用init创建，即使没有加载它的view，它也会调用viewDidLoad，这点和UIViewController不一样。 <br>
所以在使用Swift时，需要注意在UITableBarController中声明为!类型的属性，容易造成强制解包崩溃的问题。<br>
详细信息

- [UITabBarController is Different](http://www.andrewmonshizadeh.com/2015/02/23/uitabbarcontroller-is-different/)