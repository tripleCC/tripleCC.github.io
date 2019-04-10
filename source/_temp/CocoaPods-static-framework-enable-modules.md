---
date: 2019-02-20 10:21:09 +0800
comments: true
categories: cocoapods 
tags: [CocoaPods,Ruby]
---


A, B, C ;  B 依赖 A , C 依赖 B

1. A 二进制，B 二进制 ，或者同是源码，不会 non modular header

2. A 源码，B 二进制 ，可能会 non modular header。 A modulemap 中 header 为 A-umbrella.h ，改为 A.h / @import 或者 B 引用改为 A-umbrella.h 可规避错误。 

B target 类型，没有 Enable Modules 选项 -》视作没开吧，那 B 使用 A 源码 #import <A/A.h> 就会有问题，因为实际 modulemap 暴露的是 A-umbrella.h ，A.h 是找不到的，而且由于  Enable Modules 没开，编译器没有把 #import <A/A.h> 换成 @import ，所以导致编译出错

https://stackoverflow.com/questions/18947516/import-vs-import-ios-7

https://clang.llvm.org/docs/Modules.html#includes-as-imports

```
Instead, modules automatically translate #include directives into the corresponding module import
```


明天试着关掉源码 Pods 的 Enable Modules 看看

