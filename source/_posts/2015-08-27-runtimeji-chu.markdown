---
layout: post
title: "runtime基础"
date: 2015-07-10 20:14:17 +0800
comments: true
categories: runtime
tags: [Interview,objective-c,runtime]
---
Objective-C的runtime语言使它具备了动态语言的特性，也就是平时所说的“运行时”。在runtime的基础上，可以做很多平时难以想到事，或者化简原先 较为繁杂的解决方案。<br>
相对于静态语言，比如C以下程序

```objc
#include <stdio.h>
void run()
{}
int main()
{
	return 0;
}
```
<!--more-->

执行`clang -c`进行编译后，获取符号表`nm run.o`，可以得到全局唯一的符号`_run`，对函数run的调用直接参考链接后_run符号在代码段的地址

```objc
0000000000000010 T _main
0000000000000000 T _run
```
对比Objective-C的以下函数<br>

```objc
@implementation Dog : NSObject
- (void)run
{}
@end

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        Dog *dog = [[Dog alloc] init];
        [dog run];
    }
    return 0;
}

```
执行`clang -rewrite-objc main.m`将其转换成底层C++文件后可以得到

```objc
int main(int argc, const char * argv[]) {
    /* @autoreleasepool */ { __AtAutoreleasePool __autoreleasepool;
        Dog *dog = ((Dog *(*)(id, SEL))(void *)objc_msgSend)((id)((Dog *(*)(id, SEL))(void *)objc_msgSend)((id)objc_getClass("Dog"), sel_registerName("alloc")), sel_registerName("init"));
        ((void (*)(id, SEL))(void *)objc_msgSend)((id)dog, sel_registerName("run"));
    }
    return 0;
}
```
可以看到，对Objective-C编译前期，会将内部的方法调用，转换成调用`objc_msgSend`。也就是说，编译完成后，方法地址是不能确定的，需要在运行时，通过Selector进行查找，而这正是runtime的关键，也就是发送消息机制。

## runtime的基本要素

如上面例子所示，在编译后`[dog run]`被编译器转化成了

```objc
((void (*)(id, SEL))(void *)objc_msgSend)((id)dog, sel_registerName("run"));

// 假设能省略(void (*)(id, SEL))(void *)和id指针强转[实际上还是需要的]
// sel_registerName表示注册一个selector
objc_msgSend(dog, sel_registerName("run"));
```
将上面的情况抽取成统一的说法就是，在编译器编译后`[receiver message]`会被转化成以下形式

```objc
objc_msgSend(receiver, selector)
```
`objc_msgSend`是一个消息发送函数，它以消息接收者和方法名作为基础参数。<br>
在有参数的情况下，则会被转换为

```objc
objc_msgSend(receiver, selector, arg1, arg2, ...)
```
消息的接收者receiver在接受到消息后，查找对应selector的实现，根据查找的结果可以进行若干种种不同的处理。<br>
更深层的了解，需要了解下对应的数据结构

### id

上文中`objc_msgSend`的第一个参数有个强转类型，即id。id是可以指向对象的万能指针，查看runtime源码，得知其定义如下：

```objc
typedef struct objc_object *id;

// objc_object
struct objc_object {
private:
    isa_t isa;
}

// isa_t
union isa_t
{
    Class cls;
    uintptr_t bits;
}
```
根据`union`联合的存储空间以大成员的存储空间计算性质，可以猜测`isa_t`的作用只是真不同位数处理器的优化，我们可以直接这样表示：

```objc
struct objc_object {
private:
    Class isa;
}
```
可以看出，`id`是一个指向`objc_object`结构体的指针（注意，在runtime中对象可以用结构体进行表示）。<br>
`objc_object`结构体包含了`Class isa`成员，而`isa`就是我们常说的创建一个对象时，用来指向所属类的`指针`。因此根据`isa`就可以获取对应的类。
- 注：C++中结构的作用被拓宽了，也表示定义一个类的类型，struct和class的区别就在默认类型上一个是public,一个是private，这里就直接描述为结构体了

### Class

上文中，`isa`为`Class`类型，而`Class`则是`objc_class`指针类型的别名：

```objc
typedef struct objc_class *Class;
```
而`objc_class`具体的定义如下：

```objc
struct objc_class : objc_object {
    // Class ISA;
    Class superclass;
    cache_t cache;             // formerly cache pointer and vtable
    class_data_bits_t bits;    // class_rw_t * plus custom rr/alloc flags
}

// class_data_bits_t
struct class_data_bits_t {
    ...
public:
    class_rw_t* data() {
        return (class_rw_t *)(bits & FAST_DATA_MASK);
    }
    ...
}

// class_rw_t
struct class_rw_t {
    uint32_t flags;
    uint32_t version;

    const class_ro_t *ro;

    union {
        method_list_t **method_lists;  // RW_METHOD_ARRAY == 1
        method_list_t *method_list;    // RW_METHOD_ARRAY == 0
    };
    struct chained_property_list *properties;
    const protocol_list_t ** protocols;

    Class firstSubclass;
    Class nextSiblingClass;

    char *demangledName;
}

// class_ro_t
struct class_ro_t {
    uint32_t flags;
    uint32_t instanceStart;
    uint32_t instanceSize;
#ifdef __LP64__
    uint32_t reserved;
#endif

    const uint8_t * ivarLayout;

    const char * name;
    const method_list_t * baseMethods;
    const protocol_list_t * baseProtocols;
    const ivar_list_t * ivars;

    const uint8_t * weakIvarLayout;
    const property_list_t *baseProperties;
};
```
在上文中已经介绍过`objc_object`结构体，`objc_class`继承自结构体`objc_object`。可以看出`objc_object`的`isa`为`private`类型成员变量，`objc_class`继承后无法访问，所以`objc_object`提供了以下两个成员函数:

```objc
Class ISA();

// getIsa内部调用ISA返回isa_t联合中cls成员
Class getIsa();
```
所以，对`objc_class`重要的成员变量进行下解释:

- `isa`为指向对象对应类的指针（这里注意一点，由于类也是一个对象（单例），所以这个单例中也有一个`isa`指针指向类对象所属的类->`metaClass`，即元类）
- `superclass`为指向父类的指针
- `cache`用于对调用方法的缓存，类似CPU先访问L1、L2、L3缓存的目的相似，它也是推断`最近调用的方法极有可能被二次调用`，并将其存入`cache`，在二次调用时先在`cache`查找方法，而不是直接在类的方法列表中查找
- `properties`为属性列表
- `protocols`为协议列表
- `method_lists`/`method_list`为方法列表
- `ivars`为成员变量列表
- `class_ro_t`结构体中存储的都是类基本的东西，比如获取`'load'`方法时，是从`baseMethods`获取相应的IMP函数实现的：

```objc
IMP objc_class::getLoadMethod()
{
    rwlock_assert_locked(&runtimeLock);

    const method_list_t *mlist;
    uint32_t i;

    assert(isRealized());
    assert(ISA()->isRealized());
    assert(!isMetaClass());
    assert(ISA()->isMetaClass());

    mlist = ISA()->data()->ro->baseMethods;
    if (mlist) {
        for (i = 0; i < mlist->count; i++) {
            method_t *m = method_list_nth(mlist, i);
            const char *name = sel_cname(m->name);
            if (0 == strcmp(name, "load")) {
                return m->imp;
            }
        }
    }

    return nil;
}
```

其中先了解下`ivar_list_t`、`method_list_t`、`cache_t`的结构定义：<br>

`ivar_list_t`的结构为：

  - `ivar_t`就是对应的成员变量

```objc
struct ivar_list_t {
    uint32_t entsize;
    uint32_t count;
    ivar_t first;
};
```

`method_list_t`为：

  - 其中`method_iterator`为结构体自己构造的一个迭代器，用来访问方法，可以看到，构造的迭代器结构体中包含了`method`成员变量

```objc
struct method_list_t {
    uint32_t entsize_NEVER_USE;  // high bits used for fixup markers
    uint32_t count;
    method_t first;

    // iterate methods, taking entsize into account
    // fixme need a proper const_iterator
    struct method_iterator {
    	uint32_t entsize;
        uint32_t index;  // keeping track of this saves a divide in operator-
        method_t* method;
    ...
    }
```

`cache_t`为：

  - 可以看出`bucket_t`包含了一个`IMP`类型的私有成员，供查找后调用实现
  - `_occupied`和`_mask`分别表示`实际占用`的缓存_buckets总数和`分配`的缓存_buckets总数

```objc
struct cache_t {
    struct bucket_t *_buckets;
    mask_t _mask;
    mask_t _occupied;
...
}

// bucket_t
struct bucket_t {
private:
    cache_key_t _key;
    IMP _imp;
...
}
```

上文还涉及到了一个概念`metaClass`元类，元类为类对象所属的类，以实例解释：<br>
当我们调用类方法时，消息的接收者即为类，如文中一开始的代码：

```objc
Dog *dog = [[Dog alloc] init];
```
这里的`alloc`消息即发送给了`Dog`类，编译转换后的代码为:

```objc
Dog *dog = ((Dog *(*)(id, SEL))(void *)objc_msgSend)((id)((Dog *(*)(id, SEL))(void *)objc_msgSend)((id)objc_getClass("Dog"), sel_registerName("alloc")), sel_registerName("init"));
```
我们只需要关注这一行：

  - 这里获取到的是类对象，只要再获取一次就得到了元类

```objc
// objc_getClass表示根据对象名获取对应的类
objc_getClass("Dog")

// 获取元类
objc_getClass(objc_getClass("Dog"))
```
关于元类，苹果提供了这么一张表：<br>
![](/images/Snip20150711_1.png)<br>
图中的实线是`superclass`指针，虚线是`isa`指针。可以看到，根元类的超类`NSObject`(Root class)并没有对应的超类，并且，它的`isa`指针指向了自己。
总结一下：

- 每个实例对象的`isa`都指向了所属的`类`
- 每个类对象的`isa`都指向了所属的类，即`元类`，其`superclass`指针指向继承的`父类`
- 每个元类的`isa`都指向了`超类`，即`NSObject`

### Ivar

`Ivar`，我把它理解成`instance variable`，也就是实例变量，可以观察它的定义：

```objc
typedef struct ivar_t *Ivar;

// ivar_t
struct ivar_t {
    int32_t *offset;
    const char *name;
    const char *type;
    // alignment is sometimes -1; use alignment() instead
    uint32_t alignment_raw;
    uint32_t size;
	// 内存中数据对齐（如字对齐、半字对齐等）
    uint32_t alignment() {
        if (alignment_raw == ~(uint32_t)0) return 1U << WORD_SHIFT;
        return 1 << alignment_raw;
    }
};
```
`Ivar`其实是指向`ivar_t`结构体的指针，它包含了实例变量名（name）、类型（type）、相对对象地址偏移（offset）以及内存数据对齐等信息。<br>
跟多关于实例变量的剖析可以查看[Objective-C类成员变量深度剖析](http://quotation.github.io/objc/2015/05/21/objc-runtime-ivar-access.html)

### Method

从以下定义的结构体可以看出，`Method`主要住用为关联了方法名`SEL`和方法的实现`IMP`，当遍通过`Method`自己的定义的迭代器查找方法名`SEL`时，就可以找到对应的方法实现`IMP`，从而调用方法的实现执行相关的操作。`types`表示方法实现的参数以及返回值类型。

```objc
typedef struct method_t *Method;

// method_t
struct method_t {
    SEL name;
    const char *types;
    IMP imp;
    ...
}
```

### SEL

`SEL`为方法选择器，观察下它的定义：

```objc
typedef struct objc_selector *SEL;
```
可以看出`SEL`实际是`objc_selector`指针类型的别名，它用于表示运行时方法的名字，以便进行方法实现的查找。因为要对应方法实现，所以每一个方法对应的`SEL`都是唯一的。因此它不具备C++可以进行函数重载的特性，当两个方法名一样时，会发生编译错误，即使参数不一样。

### IMP

`IMP`的定义如下：

```objc
#if !OBJC_OLD_DISPATCH_PROTOTYPES
typedef void (*IMP)(void /* id, SEL, ... */ );
#else
typedef id (*IMP)(id, SEL, ...);
#endif
```
可以看出`IMP`其实就是一个函数指针的别名，也可以把它理解为函数名。它有两个必须的参数：<br>

- `id`，为`self`指针，表示消息接收者
- `SEL`，方法选择器，表示一个方法的`selector`指针
- 后面的为传送消息的一些参数<br>

在某些情况下，通过获取`IMP`而直接调用方法实现，可以直接跳过消息传递机制，像C语言调用函数那样，在一定程度上，可以提供程序的性能。

### 消息传递

了解完runtime中一些必要的元素，继续回到文章开头的代码：

```objc
@implementation Dog : NSObject
- (void)run
{}
@end

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        Dog *dog = [[Dog alloc] init];
        [dog run];
    }
    return 0;
}

```
编译器将其转换成了：
  - 为了看起来简洁点，我把一些强制转换变为别名

```objc
typedef (Dog *(*)(id, SEL))(void *) MyImp;

int main(int argc, const char * argv[]) {
    /* @autoreleasepool */ { __AtAutoreleasePool __autoreleasepool;
        Dog *dog = ((MyImp)objc_msgSend)((id)((MyImp)objc_msgSend)((id)objc_getClass("Dog"), sel_registerName("alloc")), sel_registerName("init"));
        ((MyImp)objc_msgSend)((id)dog, sel_registerName("run"));
    }
    return 0;
}
```
从上面的代码可以看出，第二个`objc_msgSend`返回值是作为第一个`objc_msgSend`的首个参数的。<br>
上文已经说过，`[receiver message]`会被转化成以下形式

```objc
objc_msgSend(receiver, selector, ...)
```

接下来看看它主要做了哪几件事情：

- 根据`receiver`的`isa`指针，获取到所属类，先在类的`cache`即缓存中查找`selector`，如果没有找到，再在类的`method_lists`即方法列表中查找
- 如果没有找到`selector`，则会沿着下图类的联系路径一直查找，直到`NSObject`类
- 如果找到了`selector`，则获取实现方法并调用，并传入接收者对象以及方法的所有参数；没有找到时走方法解析和消息转发流程。
- 将实现的返回值作为它自己的返回值<br>
![](/images/Snip20150711_2.png)

除此之外，`objc_msgSend`还会传递两个隐藏参数：

- 消息接收对象（`self`引用的对象）
- 方法选择器（`_cmd`，调用的方法）

`objc_msgSend`找到方法实现后，会在调用该实现时，传入这两个隐藏参数，这样就能够在方法实现里面里面获取消息接受对象，即方法调用者了。<br>
`隐藏参数`表示这两个参数在源代码方法的定义中并没有声明这两个参数，这两个参数是在`代码编译期间`，被`插入`到实现中的。

### self和super的联系

> 2019.5.28 勘误，下面都是错的，self 从本类查找方法，super 从父类查找方法，最终因为 class 只有根类 NSObject 实现，所以都调用的 object_getClass(self)，最后的值也一样

根据上文对`objc_msgSend`的了解，可以解决以下代码输出一致问题

```objc
@implementation Dog : NSObject

- (void)run
{
    NSLog(@"%@", [self class]);
    NSLog(@"%@", [super class]);
}

@end

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        Dog *dog = [[Dog alloc] init];

        [dog run];
    }
    return 0;
}
```

输出为：

```objc
[5491:173185] Dog
[5491:173185] Dog
```

这是为什么呢？先来看看编译后的`-run`方法的情况:

```objc
static void _I_Dog_run(Dog * self, SEL _cmd) {
    NSLog((NSString *)&__NSConstantStringImpl__var_folders_50_3f5nr6h10h1csn8byghy30q80000gn_T_main_d06ff4_mi_0, ((Class (*)(id, SEL))(void *)objc_msgSend)((id)self, sel_registerName("class")));
    NSLog((NSString *)&__NSConstantStringImpl__var_folders_50_3f5nr6h10h1csn8byghy30q80000gn_T_main_d06ff4_mi_1, ((Class (*)(__rw_objc_super *, SEL))(void *)objc_msgSendSuper)((__rw_objc_super){ (id)self, (id)class_getSuperclass(objc_getClass("Dog")) }, sel_registerName("class")));
}
```
这里面只要关注两句：

```objc
// [self class]
((Class (*)(id, SEL))(void *)objc_msgSend)((id)self, sel_registerName("class"))

// [super class]
((Class (*)(__rw_objc_super *, SEL))(void *)objc_msgSendSuper)((__rw_objc_super){ (id)self, (id)class_getSuperclass(objc_getClass("Dog")) }, sel_registerName("class"))
```
首先我们需要了解`self`和`super`的差异：

- `super`：`编译标识符`，告诉编译器，调用方法时，去调用父类的方法，而不是本类的方法
- `self`：`隐藏参数`，每个方法的实现第一个参数就是`self`

这里可以看出，编译后，经过`super`标识符修饰的方法调用，会调用`objc_msgSendSuper`函数来进行消息的发送，而不是`objc_msgSend`。先来了解下`objc_msgSendSuper`的声明：

```
id objc_msgSendSuper ( struct objc_super *super, SEL op, ... );
```
其中`objc_super`的定义为：

```
// receiver   消息实际接收者
// class      指向当前类的父类
struct objc_super { id receiver; Class class; };
```
结合以上信息，我们可以知道：

```
(__rw_objc_super){ (id)self, (id)class_getSuperclass(objc_getClass("Dog")) }
```
就是对结构体`objc_super`的赋值，也就是说`objc_super->receiver=self`。到这里可能就有点明了了，`super`只是告诉编译器，去查找父类中的`class`方法，当找到之后，使用`objc_super->receiver`即`self`进行调用。用流程表示就是：<br>
`[super class]->objc_msgSendSuper(objc_super{self, superclass)}, sel_registerName("class"))->objc_msgSend(objc_super->self, sel_registerName("class"))＝[self class]`。<br>
可以看出两者输出结果一致的关键就是，`[self class]`的消息接收者和`[super class]`的消息接收者一样，都是调用方法的实例对象。

### 方法解析和消息转发

当上文`objc_msgSend`处理流程中，`selector`没有找到时，会触发三个阶段，在这三个阶段都可以进行相关处理使程序不抛出异常：
- Method Resolution  (动态方法解析)
- Fast Forwarding    (备用接收者)
- Normal Forwarding  (完整转发)<br>

由于实际代码中很少有看到这种操作，所以这里不做详细解释，参考这个资料即可[Objective-C Runtime 运行时之三：方法与消息](http://southpeak.github.io/blog/2014/11/03/objective-c-runtime-yun-xing-shi-zhi-san-:fang-fa-yu-xiao-xi-zhuan-fa/)


### 参考

[Objective-C Runtime 运行时之一：类与对象](http://southpeak.github.io/blog/2014/10/25/objective-c-runtime-yun-xing-shi-zhi-lei-yu-dui-xiang/)<br>
[Objective-C Runtime](http://yulingtianxia.com/blog/2014/11/05/objective-c-runtime/)<br>
[What is a meta-class in Objective-C?](https://www.cocoawithlove.com/2010/01/what-is-meta-class-in-objective-c.html)<br>
