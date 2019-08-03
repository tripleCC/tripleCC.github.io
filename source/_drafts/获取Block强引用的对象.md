---
title: 获取 Block 强引用的对象
tags:
---


[捕获实体排序方式](https://github.com/llvm-mirror/clang/blob/e870496ea61feb01aa0eb4dc599be0ddf2d03878/lib/CodeGen/CGBlocks.cpp#L366-L384)如下，在对齐字节数 (alignment) 不相等时，捕获的实体按照 alignment 降序排序；否则按照以下类型进行排序

1. `__strong` 修饰对象指针变量
2. `__block` 修饰对象指针变量
3. `__weak` 修饰对象指针变量
4. 其他变量

`__attribute__ ((__packed__))`


`x/16xb`


ivar layout 

描述 strong ivar 的数量和索引信息

uint8 在 16 进制下占用 2 位，以 2 位为一组，组内首位描述非 strong ivar 个数，次位为 strong ivar 个数，最后一组如果 strong ivar 个数为 0，则忽略，且 layout 以 0x00 结尾。

```
// 0x0100
@interface A : NSObject {
    __strong NSObject *s1;
}
@end

// 0x0100
@interface A : NSObject {
    __strong NSObject *s1;
    __weak NSObject *w1;
}
@end

// 0x011100
@interface A : NSObject {
    __strong NSObject *s1;
    __weak NSObject *w1;
    __strong NSObject *s2;
}
@end

// 0x211100
@interface A : NSObject {
    int i1;
    void *p1;
    __strong NSObject *s1;
    __weak NSObject *w1;
    __strong NSObject *s2;
}
@end
```


[Circle - a cycle collector for Objective-C ARC](https://github.com/mikeash/Circle/blob/master/Circle/CircleIVarLayout.m)

[FBRetainCycleDetector](https://github.com/facebook/FBRetainCycleDetector)


https://blog.csdn.net/21aspnet/article/details/6729724#comments

https://code.fb.com/ios/automatic-memory-leak-detection-on-ios/

https://blog.sunnyxx.com/2015/09/13/class-ivar-layout/