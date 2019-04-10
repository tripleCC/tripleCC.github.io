---
title: Ruby 中的 Singleton Class 与 Objective-C 的 KVO
tags:
---

Ruby 是解释强类型动态语言，Objective-C 是编译弱类型(动态 & 静态)语言，两者看似没什么关联，但是实际上可以说是师出同门，它们很大程度上继承了 Smalltalk 的关键特性，所以很多设计理念是共通的，比如 Ruby 和 Objective-C 拥有相似的消息传递机制 (dynamic message dispatch)、对象模型 (object model —— object class metaclass)，并且都提供及其强大的运行时特性以及支撑运行时特性所需的接口等。


<!--more-->

## Ruby 的 Singleton Class

singleton class 区别于 singleton pattern 中创建的 class，在 Ruby 的对象模型中，singleton class 又可以称作 metaclass（元类）、eigenclasses（特征类），这里统一称做单件类。

![object-model-ruby](https://github.com/tripleCC/tripleCC.github.io/raw/hexo/source/images/object-model-ruby)

## Objective-C 的 KVO

![object-model-objective-c](https://github.com/tripleCC/tripleCC.github.io/raw/hexo/source/images/object-model-objective-c)

## 参考
[Smalltalk](https://en.wikipedia.org/wiki/Smalltalk)

[Metaclass](https://en.wikipedia.org/wiki/Metaclass#In_Objective-C)

[Objective-C isn't what you think it is (if you think like a Rubyist)](https://genius.com/Soroush-khanlou-objective-c-isnt-what-you-think-it-is-if-you-think-like-a-rubyist-annotated)

[In Ruby, are the terms “metaclass”, “eigenclass”, and “singleton class” completely synonymous and fungible?](https://stackoverflow.com/questions/25336033/in-ruby-are-the-terms-metaclass-eigenclass-and-singleton-class-complete)

[Demystifying Ruby Singleton Classes](<http://leohetsch.com/demystifying-ruby-singleton-classes/>)

[Understanding Ruby Singleton Classes](<https://www.devalot.com/articles/2008/09/ruby-singleton>)