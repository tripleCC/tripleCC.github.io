---
layout: post
title: "ShareExtension在干货中的应用"
date: 2016-05-05 20:33:43 +0800
comments: true
categories: 
---
在Safari中，经常可以看到以下功能界面：

![](/images/IMG_2122.PNG)

在系统相册也可以看到这样的界面。以下就选择查看花瓣的界面：

![](/images/IMG_2123.PNG)

可以看到，通过这个界面，可以向花瓣传送采集到的图片。而这也是ShareExtension一般用法：向服务器传输数据。接下来就进行一次ShareExtension的基本实践。

<!--more-->

####建立ShareExtension
首先按照以下步骤创建ShareExtension的target:

![](/images/Snip20160505_1.png)<br>
![](/images/Snip20160505_2.png)<br>
接着运行这个创建的target:
![](/images/Snip20160505_3.png)<br>
![](/images/Snip20160505_4.png)<br>
![](/images/Snip20160505_5.png)<br>
可以看到以上运行效果。<br>
当然，目前的效果很单一，一般的业务都会或多或少有自定义的元素存在。

####系统ShareExtension常用函数
创建的ShareViewController有默认的三个函数:

```
// 判断内容是否可用，返回false，则post不可用
// 一般用来判断用户的输入内容是否符合规范
override func isContentValid() -> Bool

// 点击了post后调用
// 一般在这个函数里面进行网络请求，发送数据
override func didSelectPost()

// 可以在界面的底部增加类似UITableViewCell的控件
override func configurationItems() -> [AnyObject]!
```

其中didSelectPost中还调用了一个函数：

```
self.extensionContext!.completeRequestReturningItems([], completionHandler: nil)
```
这个函数一般在didSelectPost函数中调用，用来表示ShareExtension的逻辑已经处理完成，也可以通过第一个参数向ContainerApp传输数据（NSExtensionItem实例数组）。

添加以下代码后，可以得到如下效果：

```
override func configurationItems() -> [AnyObject]! {
    let item = SLComposeSheetConfigurationItem()
    item.title = "进度"
    item.value = "20%"
    item.valuePending = true
    item.tapHandler = {
        self.pushConfigurationViewController(UIViewController())
    }
    
    return [item]
}
```
![](/images/Snip20160506_1.png)<br>
其中pushConfigurationViewController可以推入完全自定义的控制器。
