---
layout: post
title: "Objective-C"
date: 2017-07-04 20:53:58 +0800
comments: true
categories: 
---

## 多播代理 (GCDMulticastDelegate)
 
## 代理转发 (IGListAdapterProxy) 

##  
[浅谈一种解决多线程野指针的新思路](http://satanwoo.github.io/2016/10/23/multithread-dangling-pointer/)

## 针对协议的依赖注入

## JSPatch ForwardInvocation实现

## Aspects https://wereadteam.github.io/2016/06/30/Aspects/

## NSUndoManagerProxy

依赖注入 + 消息转发 + 动态创建属性  -> 多继承


- (void)forwardInvocation:(NSInvocation *)invocation {
	[_manager _forwardTargetInvocation:invocation]
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector {
	return [_manager _methodSignatureForTargetSelector:aSelector];
}


0x00000000006bc000