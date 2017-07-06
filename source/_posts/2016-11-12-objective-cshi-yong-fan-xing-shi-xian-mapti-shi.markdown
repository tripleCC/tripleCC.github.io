---
layout: post
title: "Objective-C使用范型实现map提示"
date: 2016-11-12 14:45:35 +0800
comments: true
categories: 
---
在当前项目的一些内容加工逻辑较多的界面，我会使用`ViewModel`来对`Model`进行一层包装，这样可以保持`Model`的纯净，也可以减少`Controller`中弱逻辑代码的堆叠。当然，部分公用内容也是可以通过给`Model`添加分类来实现的，`ViewModel`更多是提供特定页面的定制化内容。

由于项目并没有采用`MVVM`模式，也就没有引入`ReactiveCocoa`，所以项目里面比较多这样的代码：

```objc
NSArray <TBVEmployee *> *employees = @[[TBVEmployee new]];

NSMutableArray *items = [NSMutableArray array];
for (TBVEmployee *employee in employees) {
    TBVEmployeeItemViewModel *item = [TBVEmployeeItemViewModel itemWithEmployee:employee];
    [items addObject:item];
}
```

这段代码主要是为了将`Model` 转化成`ViewModel`。
<!--more-->
这里可以给`NSArray`增加一个`tbv_map`方法，让这段代码阅读起来更加函数式：

```objc
@interface NSArray (SwiftOperation)
- (instancetype)tbv_map:(id (^)(id value))block;
@end

@implementation NSArray (SwiftOperation)
- (instancetype)tbv_map:(id(^)(id))block {
    NSCParameterAssert(block != NULL);
    NSMutableArray *temp = [NSMutableArray array];
    for (id element in self) {
        [temp addObject:block(element)];
    }
    return temp;
}
@end
```
添加分类后，上面那段代码可以这样写：

```objc
NSArray *employees = @[[TBVEmployee new]];
NSMutableArray *items = [employees tbv_map:^id(id value) {
    return [TBVEmployeeItemViewModel itemWithEmployee:value];
}];
```

嗯！看起来清爽了不少。但是写多了之后会有一个小瑕疵：为了能`map`到`NSArray`可容纳的所有类型，`block`的传参使用了`id`类型，当需要使用形参的个别属性时，我需要手动更改`id`为具体的类名：

```
NSMutableArray *items = [employees tbv_map:^id(TBVEmployee *value) {
    NSLog(@"employee's name: %@", value.name);
    return [TBVEmployeeItemViewModel itemWithEmployee:value];
}];
```
有没有什么法子，能让`Xcode`的智能提示帮我直接预测到想要`map`的元素类型呢？

答案是`Objective-C`的范型。虽然`Objective-C`对于范型的支持还是比较弱的，但是处理当前的这个需求还是可以的。

先给`NSArray`分类添加范型：

```objc
@interface NSArray <T> (SwiftOperation)
- (instancetype)tbv_map:(id (^)(T value))block;
@end
```
然后在使用时，指定需要`map`数组的元素类型：

```objc
NSArray <TBVEmployee *> *employees = @[[TBVEmployee new]];
```

然后`Xcode`就会根据数组元素的类型，做出智能提示啦：

![](/images/2016-11-12-3.26.30.png)

以此还可以增加其它的操作：

```objc
@interface NSArray <T> (SwiftOperation)
/** -> swift map */
- (instancetype)tbv_map:(id (^)(T value))block;
/** -> swift filter */
- (instancetype)tbv_filter:(BOOL (^)(T value))block;
/** -> swift reduce */
- (id)tbv_foldLeftWithStart:(T)start reduce:(T (^)(T result, T next))reduce;
/** -> swift forEach */
- (void)tbv_forEach:(void (^)(T value))block;
@end
```
这里只添加了`NSArray`类型的操作，`NSDictionary`、`NSSet`这类集合类型也可以以此类推来实现。不过上面的方法只是做了一层简易的包装，并没有延迟计算啥的，只是让我写起来能更加开心、舒畅点吧。

## 更改
2017-07-06 ： 

需要注意的是 `instancetype` 会包含范型检查，为了避免使用者过多地进行强制类型转换， `tbv_map` 可以修改成如下形式：

```
- (NSArray *)tbv_map:(id (^)(T value))block;
```
