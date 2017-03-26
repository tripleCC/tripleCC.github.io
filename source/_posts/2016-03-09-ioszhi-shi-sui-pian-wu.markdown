---
layout: post
title: "iOS知识碎片五"
date: 2016-03-09 15:31:32 +0800
comments: true
categories: 
---
1、iOS中文斜体<br>
2、Swift中替代#ifdef以及关于Target管理<br>
3、UIRefreshControl下拉抖动<br>
4、聊天界面输入框换行抖动<br>
5、UITapGestureRecognizer与tableView:didSelectRowAtIndexPath:<br>
<!--more-->
##iOS中文斜体
iOS系统UIFont中的斜体对中文并不支持，所以需要用另一种方式实现：

```objc
CGAffineTransform matrix = CGAffineTransformMake(1, 0, tanf(15 * (CGFloat)M_PI / 180), 1, 0, 0);
UIFontDescriptor *desc = [UIFontDescriptor fontDescriptorWithName:@"Heiti SC Medium" matrix:matrix];
textView.font = [UIFont fontWithDescriptor:desc size:17];
```
答案来自：
[italic-font-not-work-for-chinese-japanese-korean-on-ios-7](http://stackoverflow.com/questions/21009957/italic-font-not-work-for-chinese-japanese-korean-on-ios-7)

另外，使用富文本属性`NSObliquenessAttributeName`也可以改变倾斜度，不过`TTTAttributeLabel`并不支持，所以只能用第一种方法。

##Swift中替代#ifdef以及关于Target管理

[ifdef-replacement-in-swift-language](http://stackoverflow.com/questions/24003291/ifdef-replacement-in-swift-language)

复制Target：

[xcode-6-how-to-rename-copied-target](http://stackoverflow.com/questions/27283716/xcode-6-how-to-rename-copied-target)

##UIRefreshControl下拉抖动

```
Because the refresh control is specifically designed for use in a table view that's managed by a table view controller, using it in a different context can result in undefined behavior.
```
以上是文档中对UIRefreshControl的部分描述，可见其是专门针对UITableViewController的，用在其它地方容易出现不可知的问题。

错误情况：<br>
在UIViewController中添加UIScrollView(或者任何子类)，再把UIRefreshControl作为其子控件。<br>
AppCoda上面有篇关于[自定义PullRefresh的文章](http://www.appcoda.com/custom-pull-to-refresh/)，因为其实现原理和以下一致，最终的效果也会有这种问题。当然，我的[干货](https://github.com/tripleCC/GanHuoCode)下拉参考的就是这篇文章，所以也会存在这种瑕疵。让我比较郁闷的是TestFlight，苹果自家的App也会出现这种情况。<br>

```
@IBOutlet weak var scrollView: UIScrollView!

rride func viewDidLoad() {
    super.viewDidLoad()
    let refresh = UIRefreshControl()
    refresh.addTarget(self, action: #selector(refreshAction), forControlEvents: .ValueChanged)
    scrollView.addSubview(refresh)
}

func refreshAction(sender: AnyObject) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(1.0 * Double(NSEC_PER_SEC))), dispatch_get_main_queue()) {
        (sender as? UIRefreshControl)?.endRefreshing()
    }
}
    
```

![](/images/pull_refreshing_error.gif)<br>

正确情况：<br>
在UITableViewController中将UIRefreshControl赋给refreshControl

```
override func viewDidLoad() {
    super.viewDidLoad()
    
	refreshControl = UIRefreshControl()
	refreshControl?.addTarget(self, action: #selector(refreshAction), forControlEvents: .ValueChanged)
}

func refreshAction(sender: AnyObject) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(1.0 * Double(NSEC_PER_SEC))), dispatch_get_main_queue()) { 
        (sender as? UIRefreshControl)?.endRefreshing()
    }
}
```

![](/images/pull_refreshing_right.gif)<br>

###2016-9-25补充
iOS10之后，苹果似乎修复了这个问题。UIScrollView也有refreshControl属性了。

##聊天界面输入框换行抖动
以下是错误演示，分别为boss直聘、刷脸：<br>
![](/images/boss_zhi_pin.gif)<br>
![](/images/shua_lian.gif)<br>

以下是微信效果：<br>
![](/images/wei_xin.gif)<br>

可以看出前面两者在换行时有明显的抖动情况，结合自身项目的开发情况，前两者应该是`监听UITextViewTextDidChangeNotification`或者`使用UITextView代理方法`的方式实现UITextView以及输入框frame的改变。<br>
正确做法：使用观察者监听UITextView的`contentSize`，利用contentSize的改变设置UITextView以及输入框的frame。

##UITapGestureRecognizer与tableView:didSelectRowAtIndexPath:
假设以下View层级关系(->表示右边为左边的子控件)：<br>
- UIView(1)->UIView(2)->UITabelView(3)

那么，当给控件1/2添加`UITapGestureRecognizer`后，3的`tableView:didSelectRowAtIndexPath:`将无法响应点击事件。<br>
解决方式：

- 方式1、将`tapGesture`的`cancelsTouchesInView`设置为NO
  - 这样做`tableView:didSelectRowAtIndexPath:`和`tapGesture的回调`都会调用
- 方式2、设置`tapGesture`的代理，实现以下方法：

```
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    return  ![NSStringFromClass([touch.view class]) isEqualToString:@"UITableViewCellContentView"];
}
```
stackoverflow上的解决方式：[uitapgesturerecognizer-breaks-uitableview-didselectrowatindexpath](http://stackoverflow.com/questions/8192480/uitapgesturerecognizer-breaks-uitableview-didselectrowatindexpath)<br>

另：关于子控件拦截父控件的`UIGestureRecognizer`事件<br>
子控件在可以接收交互事件的前提下(比如UIView)，默认无法拦截父控件的`UIGestureRecognizer`事件(和touchxxxx系列不一样，后者是可以被拦截的)。<br>

需要进行拦截，有两种方法：

- 在子控件中添加和父控件相同的手势
- 在父控件中的实现以下代理方法，如果点击点在子控件范围内，就不接收事件

```

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceivePress:(UIPress *)press

```

