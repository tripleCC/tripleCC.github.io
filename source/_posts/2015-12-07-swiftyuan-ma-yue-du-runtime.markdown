---
layout: post
title: "Swift源码阅读Runtime"
date: 2015-12-07 21:46:23 +0800
comments: true
categories: 
---

Swift开源之后，虽然大部分代码对于作为应用程序猿的我来说，花费大量时间去阅读，性价比有点不高，但是阅读下Foundation，学习学习Swift的编码范式还是不错的。

#####NSEnumerator.swift
######1.遵循多个约束<br>
其中范型NSGeneratorEnumerator定义如下：

```swift
internal class NSGeneratorEnumerator<Base : GeneratorType where Base.Element : AnyObject> : NSEnumerator {
    var generator : Base
    init(_ generator: Base) {
        self.generator = generator
    }
    
    override func nextObject() -> AnyObject? {
        return generator.next()
    }
}
```
上面有一点，就是范型类型的约束：遵守协议GeneratorType，并且是AnyObject类型。这个上次写的时候忘了，刚好这次记下这种写法。

<!--more-->
#####NSObjCRuntime.swift
######1.实现OC中NS_OPTIONS效果的swift形式的Option<br>

```
public struct NSSortOptions : OptionSetType {
    public let rawValue : UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }
    
    public static let Concurrent = NSSortOptions(rawValue: UInt(1 << 0))
    public static let Stable = NSSortOptions(rawValue: UInt(1 << 4))
}
```
以上是swift中很典型的Options，包括常见的UIViewAnimationOptions等。Concurrent和Stable是以静态属性存在的，所以可以直接使用`NSSortOptions.属性名`访问，在知道类型后，也可以简写`.属性名`。

遵守OptionSetType表示NSSortOptions可以进行集合及位运算，也就是`[.Concurrent, .Stable]`等。所以为了实现以前OC中的NS_OPTIONS的`位与`效果，可以实现一个遵循OptionSetType协议的结构体:

```
public struct AnyOption: OptionSetType {
	public let rawValue: UInt
	public init(rawValue: UInt)  { self.rawValue = rawVale }  // 这个struct会自动构造，可以省略
	
	public static let TypeOne = AnyOption(rawValue: UInt(1 << 0))
	...
}
```
值得注意的一点是，在OC中使用`kNilOptions`来表示NoneOption，swift中则是实用`[]`。<br>
所以可以进行`位与`操作的选项最好创建成遵守OptionSetType的struct，而不是enum。
######2.范型协议

```
internal protocol _CFBridgable {
    typealias CFType
    var _cfObject: CFType { get }
}
```
在swift中，协议的范型是通过`typealias`关键字来实现的，而类、数组、方法和函数则是通过类型参数来实现：

```
func geneticFunction<T>(p: [T]) -> Bool {
	return true
}
```
遵守范型协议后可以这样来实现相应的属性：

```
class MyClass: Type {
    typealias MyType = String // 这句也可以省略
    var _type: String {
        return ""
    }
}
```
可以使用`Self`表示遵守范型协议的类型：

```
protocol EquatableSelf {
	func equals(other: Self) -> Bool
}

struct ImplicitStruct: EquatableSelf {
	var val: Int64
	func equals(other: ImplicitStruct) -> Bool {
		return self.val == other.val
	}
}
```
在不使用`Self`关键字的情况下，可以使用以下方式实现同样的类型：

```
protocol EquatableTypealias {
	typealias EquatableType
	func equals(other : EquatableType) -> Bool
}

struct ExplicitStruct : EquatableTypealias {
	typealias EquatableType = ExplicitStruct
	var val : Int64
	func equals(other: ExplicitStruct) -> Bool {
		return self.val == other.val;
	}
}
```
这里有一篇不错的文章，对范型协议进行了介绍[Swift Generic Protocols
](http://milen.me/writings/swift-generic-protocols/)

#####NSObject.swift
######1.运算符重载

```
public func ==(lhs: NSObject, rhs: NSObject) -> Bool {
    return lhs.isEqual(rhs)
}
```
重载了两个NSObject对象的`==`运算符，实际上是使用swift中的`===`判断对象是否相等：

```
public func isEqual(object: AnyObject?) -> Bool {
	return object === self
}
```
需要注意的是上面对于NSObject重载的等价运算符是`全局函数`。

在实现运算符重载时，需要注意对`前后缀运算符`重载，需要添加`prefix`和`postfix`关键字：

```
prefix func - (vector: Vector2D) -> Vector2D {	return Vector2D(x: -vector.x, y: -vector.y)}
```
对`改变左表达式`的复合运算符，需要在对应的参数中添加`inout`关键字:

```
func += (inout left: Vector2D, right: Vector2D) {	left = left + right}
```

#####NSSwiftRuntime.swift
这个文件主要实现了Swift对于NS基础类型映射（基本也只能摸个大概，大部分还是不懂= =）。

其中有一个`__CFInitializeSwift`函数，本分函数体如下:

```
internal func __CFInitializeSwift() {
    _CFRuntimeBridgeTypeToClass(CFStringGetTypeID(), unsafeBitCast(_NSCFString.self, UnsafePointer<Void>.self))
    _CFRuntimeBridgeTypeToClass(CFArrayGetTypeID(), unsafeBitCast(_NSCFArray.self, UnsafePointer<Void>.self))
    _CFRuntimeBridgeTypeToClass(CFDictionaryGetTypeID(), unsafeBitCast(_NSCFDictionary.self, UnsafePointer<Void>.self))
    ....
    __CFSwiftBridge.NSObject.isEqual = _CFSwiftIsEqual
    __CFSwiftBridge.NSObject.hash = _CFSwiftGetHash
    __CFSwiftBridge.NSObject._cfTypeID = _CFSwiftGetTypeID
    ....
}
```
其中`_CFRuntimeBridgeTypeToClass`主要作用是使用对应ID为索引，将对应的类地址，存入一个全局的数组中。类似Objective-C中实例对象中的isa指向的东西，这样就可以根据这个索引对应的内容，来创建实例对象了。

```
void _CFRuntimeBridgeTypeToClass(CFTypeID cf_typeID, const void *cls_ref) {
    __CFLock(&__CFBigRuntimeFunnel);
    __CFRuntimeObjCClassTable[cf_typeID] = (uintptr_t)cls_ref;
    __CFUnlock(&__CFBigRuntimeFunnel);
}
```
而`_CFSwiftBridge`是一个全局变量，其类型定义如下：

```
struct _CFSwiftBridge {
    struct _NSObjectBridge NSObject;
    struct _NSArrayBridge NSArray;
    struct _NSMutableArrayBridge NSMutableArray;
    struct _NSDictionaryBridge NSDictionary;
    struct _NSMutableDictionaryBridge NSMutableDictionary;
    struct _NSSetBridge NSSet;
    struct _NSMutableSetBridge NSMutableSet;
    struct _NSStringBridge NSString;
    struct _NSMutableStringBridge NSMutableString;
};
```
可以看到其成员对应的NS基础类型。取NSObject，类型定义如下：

```
struct _NSObjectBridge {
    CFTypeID (*_cfTypeID)(CFTypeRef object);
    CFHashCode (*hash)(CFTypeRef object);
    bool (*isEqual)(CFTypeRef object, CFTypeRef other);
};
```
可以看到其成员都是函数指针，在`__CFInitializeSwift`中对它们进行了初始化。比如`_CFSwiftIsEqual`，就是用Swift定义的判断两个对象是否相等的函数，其定义如下：

```
internal func _CFSwiftIsEqual(cf1: AnyObject, cf2: AnyObject) -> Bool {
    return (cf1 as! NSObject).isEqual(cf2)
}
```
最后`__CFInitializeSwift`在CFRuntime.c文件中的__CFInitialize函数即CoreFoundation初始化函数中进行调用：

```
....
extern void __CFInitializeSwift();
__CFInitializeSwift();
....
```
好了...但是基本还是云里雾里...