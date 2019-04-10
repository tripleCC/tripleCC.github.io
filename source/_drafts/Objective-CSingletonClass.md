---
title: Ruby 中的 Singleton Class 与 Objective-C 的 KVO
tags:
---

Ruby 是解释强类型动态语言，Objective-C 是编译弱类型(动态 & 静态)语言，两者看似没什么关联，但是实际上可以说是师出同门，它们很大程度上继承了 Smalltalk 的关键特性，所以很多设计理念是共通的，比如 Ruby 和 Objective-C 拥有相似的消息传递机制 (dynamic message dispatch)、对象模型 (object model —— object class metaclass)，并且都提供及其强大的运行时特性以及支撑运行时特性所需的接口等。 Ruby 和 Objective-C 的异同其实有挺多可以说的，但是本文不会过多地去探讨，这里只是窥探下 singleton class 和 KVO 两个技术点间的联系。
<!--more-->

## 初始设定

假设当前有 Animal 类，Dog 类继承自 Animal，分别用 Ruby 和 Objective-C 创建 Dog 对象。

Ruby ：

```ruby
class Animal
end

class Dog < Animal
  def bark
    puts 'wangwang!'
  end
end

myDog = Dog.new
myDog.bark # wangwang!
```

Objective-C：

```objc
@interface Animal : NSObject
@end
@implementation Animal
@end

@interface Dog : Animal
- (void)bark;
@end
@implementation Dog
- (void)bark {
    NSLog(@"wangwang!"); 
}
@end

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        Dog *myDog = [Dog new];
        [myDog bark]; // wangwang!
    }
}
```

其中变量 myDog 指向的对象（下文为了方便统一用 myDog 对象描述）无法像 Dog 类对象一样，创建其他对象，所以这里将 myDog 对象称为终端对象 (terminal object)。

既然师承 Smalltalk ，根据其对象模型，Dog 类就会负责描述 myDog 对象的行为，即 `bark` 方法将会保存在 Dog 类中，Dog 类也会是一个对象，并且 Dog 类对象也有对应的类用以描述自身行为，在 Ruby 中，这个创建 Dog 类实例的类叫 singleton class ，Objecitve-C 中则称为 metaclass 。Ruby 中的终端对象也可以有 singleton class ，Objecitve-C 在语言层面上并没有实现这一点。

## Ruby 的 Singleton Class

首先要明确的是 singleton class 区别于 singleton pattern 中创建的 class，在 Ruby 的对象模型中，singleton class 又可以称作 metaclass（元类）、eigenclasses（特征类），这里统一称做单件类。

考虑以下代码：

```ruby
myDog = Dog.new

def myDog.bark
  puts 'zizizi!'
end

myDog.bark # zizizi!

yourDog = Dog.new
yourDog.bark # wangwang!
```

在 Ruby 中，我们可以给特定对象定义专属的方法，可以知道的是，新定义的 `bark` 方法不在 Dog 类中，因为给 yourDog 发送 `bark` 消息后的输出并没有改变，这种针对单个对象定义的方法称为单件方法 (singleton method)。当我们定义单件方法或者调用 `singleton_class` 方法时，Ruby 会自动创建一个 "匿名类" 来保存单件方法，这个类就是单件类，`singleton_class` 方法用来访问单件类。

除了使用上述的 `def` ，Ruby 还可以使用 `<<` 打开对象的单件类：

```
class << myDog
  def bark
    puts 'zizizi!'
  end
end
```


根据最新的示例代码，得到 Ruby 的对象模型图：

![object-model-ruby](https://github.com/tripleCC/tripleCC.github.io/raw/hexo/source/images/object-model-ruby.png)

需要注意的是，yourDog 对象是没有 #yourDog 单件类的，

## Objective-C 的 KVO

![object-model-objective-c](https://github.com/tripleCC/tripleCC.github.io/raw/hexo/source/images/object-model-objective-c.png)

## 参考
[objc kvo简单探索](https://blog.sunnyxx.com/2014/03/09/objc_kvo_secret/)

[Smalltalk](https://en.wikipedia.org/wiki/Smalltalk)

[Metaclass](https://en.wikipedia.org/wiki/Metaclass#In_Objective-C)

[Objective-C isn't what you think it is (if you think like a Rubyist)](https://genius.com/Soroush-khanlou-objective-c-isnt-what-you-think-it-is-if-you-think-like-a-rubyist-annotated)

[In Ruby, are the terms “metaclass”, “eigenclass”, and “singleton class” completely synonymous and fungible?](https://stackoverflow.com/questions/25336033/in-ruby-are-the-terms-metaclass-eigenclass-and-singleton-class-complete)

[Classes and Objects](https://ruby-doc.com/docs/ProgrammingRuby/html/classes.html)

[Demystifying Ruby Singleton Classes](<http://leohetsch.com/demystifying-ruby-singleton-classes/>)

[Understanding Ruby Singleton Classes](<https://www.devalot.com/articles/2008/09/ruby-singleton>)