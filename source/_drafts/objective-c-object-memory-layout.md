---
title: Objective-C 对象内存布局
date: 2019-03-26 19:31:12
tags: [Interview,Objective-C]
---

ABI 安全

## 成员变量

Objective-C 只允许变更构造中的类的 ivar 列表，一旦类注册之后，ivar 列表就固定了。

## 布局调整

## 结构体的内存布局

结构体成员在内存中的布局是连续的，编译器会按照成员列表的顺序依次给每个成员分配内存，在一些成员不满足边界对齐条件时，编译器会分配额外的内存空间进行填充，并且结构体的地址和结构体的首个成员地址是一致的。

```
// 考虑边界对齐因素，获取成员的实际位置
// 编译器在执行以下代码时，会进行边界对齐，所以我们能得到对齐后的实际位置
// 返回值表示指定成员开始存储的位置距离结构体开始存储的位置偏移了几个字节
NSLog(@"%d", &((struct Animal *)0)->age);
NSLog(@"%d", offsetof(struct Animal, age));
```

C++ 结构体在没有虚函数表的情况下，布局和 C 的结构体一致。

```
@interface A : NSObject {
    int _i;
}
@end

struct NSObject {
    Class isa;
};

// 对于通过地址偏移访问方式
// 下面两个结构是没区别的
// 可以把继承的成员变量铺平了看
struct A {
    struct NSObject NSObject_IVARS;
    int _i;
};

struct A {
    Class isa;
    int _i;
};
```

## Non-fragile instance variables

Objective-C 2.0 provides non-fragile instance variables where supported by the runtime (i.e. when building code for 64-bit macOS, and all iOS). Under the modern runtime, an extra layer of indirection is added to instance variable access, allowing the dynamic linker to adjust instance layout at runtime. This feature allows for two important improvements to Objective-C code:

It eliminates the fragile binary interface problem; superclasses can change sizes without affecting binary compatibility.
It allows instance variables that provide the backing for properties to be synthesized at runtime without them being declared in the class's interface.

## `_class_ro_t` 生成

重写成 c++ 代码角度

```
clang -rewrite-objc main.m -o main.c
```

```
// 访问
static void _I_Animal_setAge_(Animal * self, SEL _cmd, int age) {
    (*(int *)((char *)self + OBJC_IVAR_$_Animal$_age)) = age;
}

extern "C" unsigned long int OBJC_IVAR_$_Animal$_age __attribute__ ((used, section ("__DATA,__objc_ivar"))) = __OFFSETOFIVAR__(struct Animal, _age);

static struct /*_ivar_list_t*/ {
	unsigned int entsize;  // sizeof(struct _prop_t)
	unsigned int count;
	struct _ivar_t ivar_list[1];
} _OBJC_$_INSTANCE_VARIABLES_Animal __attribute__ ((used, section ("__DATA,__objc_const"))) = {
	sizeof(_ivar_t),
	1,
	{{(unsigned long int *)&OBJC_IVAR_$_Animal$_age, "_age", "i", 2, 4}}
};


```

```
// 这里设置 offset 字段，即设置 OBJC_IVAR_$_Animal$_age 变量
for (const auto& ivar : *ro->ivars) {
    if (!ivar.offset) continue;  // anonymous bitfield
    *ivar.offset -= delta;
}
```

编译器角度

```
CGObjCNonFragileABIMac::GenerateClass

BuildClassObject

```

## 参考

[Objc Explain Non-pointer isa](http://www.sealiesoftware.com/blog/archive/2013/09/24/objc_explain_Non-pointer_isa.html)

[Non-fragile ivars](http://www.sealiesoftware.com/blog/archive/2009/01/27/objc_explain_Non-fragile_ivars.html)

[Objective-C Internals](http://algorithm.com.au/downloads/talks/objective-c-internals/objective-c-internals.pdf)