---
title: Objective-C 对象内存布局
date: 2019-03-26 19:31:12
tags: [Interview,Objective-C]
---


## Non-fragile instance variables

Objective-C 2.0 provides non-fragile instance variables where supported by the runtime (i.e. when building code for 64-bit macOS, and all iOS). Under the modern runtime, an extra layer of indirection is added to instance variable access, allowing the dynamic linker to adjust instance layout at runtime. This feature allows for two important improvements to Objective-C code:

It eliminates the fragile binary interface problem; superclasses can change sizes without affecting binary compatibility.
It allows instance variables that provide the backing for properties to be synthesized at runtime without them being declared in the class's interface.

## `_class_ro_t` 生成

重写成 c 代码角度

```
clang -rewrite-objc main.m -o main.c
```

编译器角度

```
CGObjCNonFragileABIMac::GenerateClass

BuildClassObject

```

## 参考

[Objc Explain Non-pointer isa](http://www.sealiesoftware.com/blog/archive/2013/09/24/objc_explain_Non-pointer_isa.html)
