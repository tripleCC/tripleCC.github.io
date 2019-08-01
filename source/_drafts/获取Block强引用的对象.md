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



[Circle - a cycle collector for Objective-C ARC](https://github.com/mikeash/Circle/blob/master/Circle/CircleIVarLayout.m)

[FBRetainCycleDetector](https://github.com/mikeash/Circle/blob/master/Circle/CircleIVarLayout.m)


https://blog.csdn.net/21aspnet/article/details/6729724#comments