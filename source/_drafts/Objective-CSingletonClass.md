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

```ruby
class << myDog
  def bark
    puts 'zizizi!'
  end
end
```


根据最新的示例代码，可以得到 Ruby 的对象模型图：

![object-model-ruby](https://github.com/tripleCC/tripleCC.github.io/raw/hexo/source/images/object-model-ruby-n.png)

需要注意的是，和 myDog 对象不一样，yourDog 对象还没有 #yourDog 单件类，其 `klass` (Objective-C 中的 isa) 还是直接指向 Dog 类 (测试方法在文末 《Ruby 调用 C 扩展一节》 给出)。

如模型图所示，类对象天然拥有一个对应的单件类 (对比 Objective-C 创建类时，必须同时创建元类)，也就是说我们定义的类方法都是单件方法，直接存放在类对象的单件类中。采用下面几种方式定义类方法，其结果都是一致的：

```ruby
class Dog < Animal
  def self.create 
  end
end

####################

class Dog < Animal
  class << self
    def create
    end
  end
end

####################

def Dog.create
end

####################

class << Dog
  def create
  end
end
```

简单来说，Ruby 中的单件类是只属于一个对象的类，它负责描述此对象的行为。

## Objective-C 的 KVO

![object-model-objective-c](https://github.com/tripleCC/tripleCC.github.io/raw/hexo/source/images/object-model-objective-c-n.png)

## 小结

## Ruby 调用 C 扩展

Ruby 可以通过扩展调用 C 函数，从而打印出内存中对象所属的类。

创建 real_klass.c 文件 ：

```c
#include <ruby.h> 

VALUE real_klass(VALUE self) {
  return RBASIC(self)->klass;
}

void Init_real_klass() {
  rb_define_method(rb_cObject,"real_klass",real_klass,0);
}
```

创建 extconf.rb 文件 ：

```ruby
require 'mkmf'
    
extension_name = 'real_klass'
dir_config(extension_name)
create_makefile(extension_name)
```

生成扩展模块 ：

```shell
$ ruby extconf.rb && make
$ ls
Makefile           real_klass.bundle real_klass.o
extconf.rb         real_klass.c      animal.rb
```

编辑 animal.rb 引入 real_class 模块 :

```ruby
require './real_klass.bundle'

... 

myDog = Dog.new
class << myDog
  def bark
    puts 'zizizi!'
  end
end

myDog.bark # zizizi!
yourDog = Dog.new
yourDog.bark # wangwang!

# myDog 对象单例类已创建，klass 指向单例类
p myDog.real_klass                 # #<Class:#<Dog:0x007fcae98f1d10>>
p myDog.singleton_class            # #<Class:#<Dog:0x007fcae98f1d10>>
# myDog 对象单例类的 klass 指向 Dog 类对象的单例类
# (在 myDog.singleton_class 没有创建属于它的单例类的情况下)
p Dog.singleton_class              # #<Class:Dog>
p myDog.singleton_class.real_klass # #<Class:Dog>

# yourDog 对象单例类还未创建，klass 指向 Dog 类对象
p yourDog.real_klass      # Dog
# yourDog 对象单例类已创建，klass 指向单例类
p yourDog.singleton_class # #<Class:#<Dog:0x007fdb2f049518>>
p yourDog.real_klass      # #<Class:#<Dog:0x007fdb2f049518>>
```

更健全的 Ruby 对象模型可以查看 [wiki 上的示意图](https://en.wikipedia.org/wiki/Metaclass#/media/File:Ruby-metaclass-sample.svg) 。

## 参考
[objc kvo简单探索](https://blog.sunnyxx.com/2014/03/09/objc_kvo_secret/)

[Smalltalk](https://en.wikipedia.org/wiki/Smalltalk)

[Metaclass](https://en.wikipedia.org/wiki/Metaclass#In_Objective-C)

[Objective-C isn't what you think it is (if you think like a Rubyist)](https://genius.com/Soroush-khanlou-objective-c-isnt-what-you-think-it-is-if-you-think-like-a-rubyist-annotated)

[In Ruby, are the terms “metaclass”, “eigenclass”, and “singleton class” completely synonymous and fungible?](https://stackoverflow.com/questions/25336033/in-ruby-are-the-terms-metaclass-eigenclass-and-singleton-class-complete)

[Classes and Objects](https://ruby-doc.com/docs/ProgrammingRuby/html/classes.html)

[Demystifying Ruby Singleton Classes](<http://leohetsch.com/demystifying-ruby-singleton-classes/>)

[Understanding Ruby Singleton Classes](<https://www.devalot.com/articles/2008/09/ruby-singleton>)

[The Ruby Object Model - Structure and Semantics ](https://hokstad.com/ruby-object-model)