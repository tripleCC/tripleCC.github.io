---
layout: post
title: "iOS知识碎片一"
date: 2015-09-06 00:04:36 +0800
comments: true
categories: 
---
学习工作中总会有那么几个注意点和困惑点，这些琐碎的知识点容易让我迷惑，所以决定做这么一个纪录，希望能持之以恒，积少成多

1. 解决同时设置阴影和裁剪，阴影消失问题
2. swift中使用字符串创建类及错误处理
3. swift中回调函数设置作用域注意
4. 可视化界面调整图片拉伸
5. AFNetworking出现SSL错误
<!--more-->
#解决同时设置阴影和裁剪，阴影消失问题
###阴影注意点
- 图层的阴影是根据`内容外形`确定，不是根据边界和角半径确定
- 阴影通常在layer的边界之外

### 裁剪注意点
- 所有从图层中突出的内容都会被裁剪掉

### 引出问题
- 同时设置视图masksToBounds和图层的阴影，图层的阴影效果可能会失效。<br>
- 原因是：图层阴影被裁剪掉了。

### 解决方案
使用一个只画阴影的空视图，成为需要裁剪视图的父控件

原理：

- 内部子控件进行裁剪后，外部父视图的内容就只有被裁剪的子控件，所以会在子控件周围绘制阴影，而子控件只对它以及它的子控件进行了裁剪


# 在Swift中使用字符串创建类
在swift中有了命名空间这个概念（namespace），使用.self打印类名，会发现对应的类名带有namespace前缀如下：

```objc
<SwiftWB.HomeViewController: 0x7fbf81f4e5e0>
```

Swift还在不断改进，所以这里只针对Xcode7 Beta5（在beta4写出来貌似在这个测试版本上会出错）

```objc
let path = NSBundle.mainBundle().pathForResource("MainVCSettings", ofType: "json")
if let jsonPath = path {
    do {
        let data = NSData(contentsOfFile: jsonPath)
        let dataArr = try NSJSONSerialization.JSONObjectWithData(data!, options: NSJSONReadingOptions.MutableContainers)
        
        // 命名空间名
        let prefixStr = NSBundle.mainBundle().infoDictionary!["CFBundleExecutable"] as! String
        
        for object in dataArr as! [[String : String]] {
            let cls: AnyClass? = NSClassFromString(prefixStr + "." + object["vcName"]!)
            
            // 读取的名称不一定有对应的控制器，所以在这里做一个动态绑定
            if let vcCls = cls as? UIViewController.Type {
                let vc = vcCls.init()
                addChildViewController(vc, title: object["title"]!, imageName: object["imageName"]!)
            }
        }
    } catch {
        addChildViewController()
    }
}
```

上面代码从MainVCSettings文件读取控制器的关联信息，并创建对应的控制器，详细信息已在注释中表明

从上面代码还可以看出，swift对于错误的处理有了一定的变化。在Objective-C中，对应的JSON解析是通过参数传出错误的方式来进行处理的：

```objc
NSJSONSerialization dataWithJSONObject:(id) options:(NSJSONWritingOptions) error:(NSError *__autoreleasing *)
```

而swift中采用了抛出异常的方式：

```objc
public class func JSONObjectWithData(data: NSData, options opt: NSJSONReadingOptions) throws -> AnyObject
```

模式的写法如下：

```objc
do {
	...
	// 注意需要使用try
    let dataArr = try NSJSONSerialization.JSONObjectWithData(data!, options: NSJSONReadingOptions.MutableContainers)
    ...
    
} catch {
	// 错误处理
	...
}
```

# swift中回调函数设置作用域注意

在swift中，存在private修饰符，表示私有变量或者私有方法。一般只在本类中使用的，不暴露给外界的方法都会加上这个修饰符。<br>
但是在添加按钮点击回调函数时，却不能这么做。如果给按钮的回调函方法添加了private修饰符，程序会抛出找不到实例方法错误。<br>
原因如下：<br>
首先，在回调方法中添加一个断点：<br>

![](/images/Snip20150908_2.png)

然后运行程序，会崩溃后会出现以下函数调用栈：<br>
![](/images/Snip20150908_1.png)

可以看到，按钮的点击事件是通过`运行循环`进行监听，并且以Source0的形式让RunLoop执行处理([RunLoop基础元素解析](http://triplecc.github.io/blog/2015-09-04-runloopji-chu-yuan-su-jie-xi/))。然后以`消息机制`传递，对方法进行调用，所以按钮的回调方法不能设置为private，否则外界会找不到对应的方法。

# 可视化界面调整图片拉伸

发现最近个版本的Xcode在调整图片拉伸情况时，还可以使用一种可视化界面调整。

详细步骤如下：<br>

一般打开的图片显示如下:<br>
![](/images/Snip20150909_2.png)<br>

更改显示方式<br>
![](/images/Snip20150909_4.png)

可视化调整拉伸方式<br>
![](/images/Snip20150909_5.png)

开始拉伸<br>
![](/images/Snip20150909_6.png)

调整对应的线来对局部进行拉伸
![](/images/Snip20150909_7.png)

# AFNetworking出现SSL错误
获取优酷视频信息数据时出现问题。

加载HTTPS网络数据时出现以下错误：

```objc
NSURLSession/NSURLConnection HTTP load failed (kCFStreamErrorDomainSSL, -9824)
Error Domain=NSURLErrorDomain Code=-1200 "An SSL error has occurred and a secure connection to the server cannot be made." UserInfo={_kCFStreamErrorCodeKey=-9824, NSLocalizedRecoverySuggestion=Would you like to connect to the server anyway?, NSUnderlyingError=0x7fbdf1e2e870 {Error Domain=kCFErrorDomainCFNetwork Code=-1200 "(null)" UserInfo={_kCFStreamPropertySSLClientCertificateState=0, _kCFNetworkCFStreamSSLErrorOriginalValue=-9824, _kCFStreamErrorDomainKey=3, _kCFStreamErrorCodeKey=-9824}}, NSLocalizedDescription=An SSL error has occurred and a secure connection to the server cannot be made., NSErrorFailingURLKey=https://openapi.youku.com/v2/videos/by_category.json?client_id=693bf79be3aee68f, NSErrorFailingURLStringKey=https://openapi.youku.com/v2/videos/by_category.json?client_id=693bf79be3aee68f, _kCFStreamErrorDomainKey=3}
```
在info.plist中添加以下字段就可以解决：

![](/images/Snip20150915_1.png)

最新的版本：

![](/images/Snip20151101-1.png)
