---
layout: post
title: "C 表达式中 float 精度提升问题"
date: 2017-08-12 10:32:25 +0800
comments: true
categories: c
tags: [c,float]
---


对于这个问题的思考，起源于云风的这篇文章 [浮点运算潜在的结果不一致问题](http://blog.codingnow.com/2017/07/float_inconsistence.html#more)，其中有几个评论我比较在意：

```
stirp:
刚刚被小伙伴提示默认情况下float相乘是自动提升精度到double的，因此第一次输出就应该是对double取整的。

x87 浮点运算的效果是float相乘结果还是float么？本地不支持387，没法测试。

Cloud:

C 语言规范：表达式里最高精度是 float ，那么表达式的值精度就是 float 。没有相乘提升到 double 的说法。

第一个写成 (int)((float)(x * 0.01f)) 也是一样的，并不是对 double 取整的问题。

stirp:
多谢dwing，原来C89/90就已经不提升精度了。
```
<!--more-->

结合以前阅读《C专家编程》的模糊记忆，我记得在表达式中，float 会被提升为 double ，这样会让编译器处理起来更加方便。看了这几个评论信息后，我随即去查阅了《C A Reference Manual》，发现的确如 Cloud 所说，以二元操作符为例：

![](/images/Snip20170812_2.png)

可以看到，针对二元操作表达式，如果两边都是 float 类型，那么标准 C 已经不把精度提升为 double 了。
