---
layout: post
title: "NSJSONSerialization和NSNumber的事故现场"
date: 2017-03-09 17:20:39 +0800
comments: true
categories: objective-c
---
最近同事在和后台联调时，出现了一个诡异的问题：后台传输的价格为 0.07 ，但是到了 iOS 这边，就变成了 0.07000000000000001 。奇怪的是安卓端并没有此问题，并且从 charles 抓包内容来看，后台传输的价格确实是0.07。

在排除了业务层转化因素后，我们进入了 AFNetworking 框架内部，看能不能找到一点线索，然后就定位到了以下方法：

``` objc
- (void)URLSession:(__unused NSURLSession *)session
              task:(NSURLSessionTask *)task
didCompleteWithError:(NSError *)error
```

  在拿到原始的 data 后，我尝试在调试终端使用 NSJSONSerialization 对其进行反序列化，结果发现价格在这里已经变成了 0.07000000000000001 。

众所周知，由于计算机无法精确存储浮点数，实际上存储的浮点型变量实际数值就是取范围允许内最接近的值，也就是上面接收到的那样。（注：[Float who stole your accuracy](http://justjavac.com/codepuzzle/2012/11/11/codepuzzle-float-who-stole-your-accuracy.html)） 

难道是 NSJSONSerialization 在反序列化的时候出了问题？
<!--more-->


## 解决过程

  **在确定了后台传的价格并不是字符串类型后** <br>(注： [Why not use double or float to represent currency](http://stackoverflow.com/questions/3730019/why-not-use-double-or-float-to-represent-currency))，<br>我开始查找相关资料，并写了以下代码进行测试：

```objc
NSString *json = @"{\"price\" : 0.07}";
NSData *data = [json dataUsingEncoding:NSUTF8StringEncoding];
NSDictionary *rJson = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];

NSLog(@"\nclass: %@\n%@", NSStringFromClass([rJson[@"price"] class]), rJson);
```

上面代码块的输出如下：

```objc
class: __NSCFNumber
{
    price = "0.07000000000000001";
}
```

那么问题来了，如果传过来的价格是字符串类型的，输出结果会是正确的么？

```
NSString *json = @"{\"price\" : \"0.07\"}";
NSData *data = [json dataUsingEncoding:NSUTF8StringEncoding];
NSDictionary *rJson = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];

NSLog(@"\nclass: %@\n%@", NSStringFromClass([rJson[@"price"] class]), rJson);
```

上面代码块的输出为：

```
class: NSTaggedPointerString
{
    price = "0.07";
}
```
Bingo ！结果是正确的。

那么，在确定 data 是准确的前提下 ：

```
7b227072 69636522 203a2030 2e30377d
-------------------------0--.-0-7	
```

再通过以下代码，来确认下是不是 NSNumber 造成了这种差异：

```objc
double a = 0.07;
NSLog(@"%@", [NSNumber numberWithDouble:a]);
```

上面代码块的输出如下：

```objc
0.07000000000000001
```

综上，可以看出: 

**由于后台传过来的是浮点型而不是字符串类型的 0.07，导致 NSJSONSerialization 内部进行反序列化时，把 0.07 转化成了 NSNumber 对象，而 NSNumber 对象无法正确地表示浮点型的 0.07** 



## 反思

针对当前的业务：

1.就像 [Why not use double or float to represent currency](http://stackoverflow.com/questions/3730019/why-not-use-double-or-float-to-represent-currency) 说的一样，后台传价格相关的数据时，不要用浮点型，要么乘以 100 ，前端再除以 100 ，要么用字符串。

2.如果数据对精度非常敏感的话，不要用 NSNumber，应该用 NSDecimalnumber。

另外小吐槽下，后台传输的数据应该遵守相关规范：[jsonapi](http://jsonapi.org/format/#document-top-level)，特别是后端开发的同学，更应该熟悉这套规范。


## 参考资料

[JSON object with data wrong decimal places while parsing](http://stackoverflow.com/questions/36218949/jsonobjectwithdata-wrong-decimal-places-while-parsing)<br>
[NSNumber calculations precision](http://stackoverflow.com/questions/2333755/nsnumber-calculations-precision)<br>
[Why not use double or float to represent currency](http://stackoverflow.com/questions/3730019/why-not-use-double-or-float-to-represent-currency)<br>
[Pretend precision](http://twistedoakstudios.com/blog/Post4428_unfathomable-bugs-6-pretend-precision)<br>
[What is the right choice between NSDecimal NSDecimalnumber CFNumber](http://stackoverflow.com/questions/1704504/what-is-the-right-choice-between-nsdecimal-nsdecimalnumber-cfnumber)<br>
[Don‘t be lazy with NSDecimalnumber like me](http://www.cimgf.com/2008/04/23/cocoa-tutorial-dont-be-lazy-with-nsdecimalnumber-like-me/)<br>
[Working with NSDecimalnumber and NSNumber](http://www.cocoabuilder.com/archive/cocoa/166167-working-with-nsdecimalnumber-and-nsnumber.html)<br>










