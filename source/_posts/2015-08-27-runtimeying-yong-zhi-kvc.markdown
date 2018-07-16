---
layout: post
title: "Runtime应用之KVC"
date: 2015-07-11 20:16:13 +0800
comments: true
categories: objective-c 
---

runtime可以以底层的角度来对一些实现方式进行更改，比如说KVC<br>
首先，先来了解下KVC的底层原理:<br>
key : value

- 1.去模型中查找有没有setValue:，直接调用这个对象setValue:赋值
- 2.如果没有setValue:，就在模型中查找_value属性
- 3.如果没有_value属性，就查找value属性
- 4.如果还没有就报错
<!--more-->
在和后台通信的JSON数据中，可能会看到这种JSON数据：<br>

```objc
{
    "id" : "tripleCC",
    "age" : "30",
    "address" : "杭州",
    "schooll" : "HDU"
    ...
}
```
其中的id是什么？是Objective-C关键字，也就是说我不能定义以下属性：

```objc
@property (nonatomic, strong) NSString *id;
```
由于数据模型名称没有和JSON的键值一一对应，我们不能使用以下方法，对模型中的成员变量进行统一设置：

```objc
- (void)setValuesForKeysWithDictionary:(NSDictionary *)keyedValues;
```
既然这样，可以选择手动一个个去实现。但是这样在数据少的时候可以试试，在数据比较多时就不太现实了，程序的可扩展性也不好。<br>
现在来了解下相对比较简单的两种解决方法：

## 方式1.重写setValue:forKey:
setValuesForKeysWithDictionary:的底层是调用setValue:forKey:的，所以可以考虑重写这个方法，并且判断其key是id时，手动转换成模型的成员变量名，这里假设把id对应成以下属性：

```objc
@property (nonatomic, strong) NSString *ID;
```
有了对应的属性名后，就可以重写底层方法了：
  - 如下所示，当判断到key的值为id时，我手动将key转换成了模型属性名，即ID

```objc
- (void)setValue:(id)value forKey:(NSString *)key
{
    if ([key isEqualToString:@"id"]) {
        [self setValue:value forKeyPath:@"ID"];
    }else{
        [super setValue:value forKey:key];

    }
}
```
这样，当使用setValuesForKeysWithDictionary:就不会出现模型中找不到对应的成员变量的错误了。

## 方式2.使用runtime
考虑到runtime和KVC的实现原理，可以使用另一种实现思路，就是`先在模型中找到对应的成员变量，然后从JSON字典中找到对应的数据进行赋值`。<br>
这里先要了解runtime的两个实例变量操作方法：

```objc
// 获取成员变量列表
Ivar * class_copyIvarList ( Class cls, unsigned int *outCount );
// 获取成员变量名
const char * ivar_getName ( Ivar v );
```
详细实现步骤：<br>

- 1.获取模型中的所有实例变量

```objc
    unsigned int outCount = 0;
    Ivar *ivars = class_copyIvarList(self, &outCount);
```
- 2.将获取出来以'_'开头的实例变量名去处'_'符号

```objc
   NSString *ivarName = @(ivar_getName(ivar));
   ivarName = [ivarName substringFromIndex:1];
```
- 3.获取JOSN字典中对应的value，如果没有，手动设置我们传入的字典映射，以指定对应的模型变量名，最后调用setValue:forKeyPath:设置模型实例变量值

```objc
    id value = dict[ivarName];
    // 由外界通知内部，模型中成员变量名对应字典里面的哪个key
    // 这里是ID -> id
    if (value == nil) {
        // 这里的mapDict就是外界传入的映射字典
        if (mapDict) {
            NSString *keyName = mapDict[ivarName];

            value = dict[keyName];
        }
    }
    [objc setValue:value forKeyPath:ivarName];
```
由于需要针对所有模型使用，可以将其设置为NSObject分类。以上步骤的完整代码为：

```objc
// dict  -> 资源文件提供的字典
// mapDict  -> 提供的key映射（实际变量名:资源文件key）
+ (instancetype)objcWithDict:(NSDictionary *)dict mapDict:(NSDictionary *)mapDict
{
    id objc = [[self alloc] init];


    // 遍历模型中成员变量
    unsigned int outCount = 0;
    Ivar *ivars = class_copyIvarList(self, &outCount);

    for (int i = 0 ; i < count; i++) {
        Ivar ivar = ivars[i];

        // 成员变量名称
        NSString *ivarName = @(ivar_getName(ivar));

        // 获取出来的是`_`开头的成员变量名，需要截取`_`之后的字符串
        ivarName = [ivarName substringFromIndex:1];

        id value = dict[ivarName];
        // 由外界通知内部，模型中成员变量名对应字典里面的哪个key
        // ID -> id
        if (value == nil) {
            if (mapDict) {
                NSString *keyName = mapDict[ivarName];

                value = dict[keyName];
            }
        }
        [objc setValue:value forKeyPath:ivarName];
    }
    return objc;
}
```
使用方法：

```objc

+ (instancetype)itemWithDict:(NSDictionary *)dict
{
    // 传入key和实例变量名的映射字典@{@"ID":@"id"}
    TPCItem *item = [TPCItem objcWithDict:dict mapDict:@{@"ID":@"id"}];

    return item;
}
```
看了一些相关框架的源码，有些框架的底层就是通过这种方式实现的，比如MJExtension就是通过获取对象里面的所有属性来进行操作的（这里个人感觉获取成员变量适用面会更广一点）
