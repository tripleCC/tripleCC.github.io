---
layout: post
title: "UITextFiled文字抖动效果"
date: 2015-07-27 20:17:49 +0800
comments: true
categories: ios
---

最终设置UITextField的placeholder效果：<br>

![](/images/2015-07-28 16_46_41.gif)<br>

有需求1如下：

- 未点击时UITextField的placeholder为浅灰色
- 点击后，还未进行输入时，UITextField的placeholder变为深灰色
<!--more-->
这个实现并不难：

- 通过通知或者重写UITextField的响应者处理方法，都可以实现捕获点击时间
- UITextField设置placeholder可以使用以下属性：
  - 通过设置这个富文本属性，可以得到丰富多彩的placeholder<br>

```swift
@NSCopying var attributedPlaceholder: NSAttributedString?

// 附带光标颜色属性
var tintColor: UIColor!
```

但是需求2加了点东西：

- 点击后，还未进行输入时，UITextField的placeholder文字左右进行小幅度抖动<br>

可以看到通过设置attributedPlaceholder，可以改变一些静态的属性，如颜色和文字大小。<br>
但是如果需要里面的文字做一些简单的抖动效果貌似就不行了，UITextField没有提供相关属性，我们也不知道placeholder是在何种控件中显示的。<br>
既然不知道laceholder是在何种控件中显示，那就通过以下代码打印出UITextField中所有的成员变量（函数参考[runtime基础元素解析](http://triplecc.github.io/blog/2015-01-10-runtimeji-chu/)），看看是否会有什么发现：

```swift
Ivar *ivars = class_copyIvarList([UITextField class], &outCount);

for (int i = 0; i < outCount; i++) {
    Ivar ivar = ivars[i];

    NSLog(@"%s", ivar_getName(ivar));
}

free(ivars);
```
截取关键部分如下：<br>

![](/images/Snip20150728_2.png)<br>

从字面上看，上面的`_placeholderLabel`是否就是显示placeholder的控件？<br>
测试实际结果的确是显示placeholder的控件。<br>
只要有了这个控件，那要做一些小抖动的动画那就没什么问题了，先获取这个UILabel:

```swift
private var tpcPlaceholderLabel:UILabel? {
    get {
        return self.valueForKey("_placeholderLabel") as? UILabel
    }
}
```
然后重写UITextField的响应者处理函数：

```swift
// 成为第一响应者
override func becomeFirstResponder() -> Bool {

    // 存储正常颜色
    if normalColor == nil {
        normalColor = tpcPlaceholderLabel?.textColor
    }
    // 存储选中颜色
    if selectedColor == nil {
        selectedColor = tpcPlaceholderLabel?.textColor
    }

    tpcPlaceholderLabel?.textColor = selectedColor

    // 执行placeholder动画函数
    placeholderLabelDoAnimationWithType(animationType)

    return super.becomeFirstResponder()
}

// 放弃第一响应者
override func resignFirstResponder() -> Bool {

    switch animationType {
    case .TPCAnimationTypeUpDown :
        fallthrough
    case .TPCAnimationTypeBlowUp :
        fallthrough
    case .TPCAnimationTypeLeftRight :
        tpcPlaceholderLabel?.transform = CGAffineTransformIdentity
    case .TPCAnimationTypeEasyInOut :
        UIView.animateWithDuration(0.5, animations: { () -> Void in
            tpcPlaceholderLabel?.alpha = 1.0
        })
    case .TPCAnimationTypeNone :
        break
    }

    if let operate = operateWhenResignFirstResponder {
        operate()
    }

    // 设置为初始颜色
    tpcPlaceholderLabel?.textColor = normalColor

    return super.resignFirstResponder()
}
```
然后通过以下函数，传入相应的动作就可以得到抖动的效果了

```swift
private func doAnimation(action: () -> ()) {
    UIView.animateWithDuration(0.5, delay: 0, usingSpringWithDamping: 0.1, initialSpringVelocity: 10, options: UIViewAnimationOptions.CurveEaseInOut, animations: { () -> Void in
        action()
        }, completion: nil)
}
```

还有一点，根据上面打印的UITextField成员变量，看到了`_displayLabel`，这个就是在键盘输入后显示文字的UILabel了。这个属性可以用来干嘛？<br>
我想，`可能会有这么一种需求（不过可能没有），就是用户输入错误时，UITextField中已经输入的文字做左右抖动，以间接的形式，辅助提醒用户，这一栏输错了，而不是弹出一个HUB`。<br>
由于UITextField内部做了某些处理，所以无法在成为第一响应者时做一些动作，那么，就在放弃第一响应者函数中。<br>

相关代码如下：

```swift
// 设置一个在放弃第一响应者的闭包属性
var operateWhenResignFirstResponder: (() -> ())?

// 在func resignFirstResponder() -> Bool函数中调用
if let operate = operateWhenResignFirstResponder {
    operate()
}
```

代码地址: [UITextFiled文字抖动效果](https://github.com/tripleCC/TPCDynamicTextFiled/blob/master/README.md)


