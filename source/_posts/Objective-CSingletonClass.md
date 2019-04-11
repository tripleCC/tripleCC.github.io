---
title: Ruby Singleton Class 与 Objective-C KVO
date: 2019-04-11 20:24:45
tags: [Ruby,Singleton Class, KVO]
---


Ruby 是解释强类型动态语言，Objective-C 是编译弱类型(动态 & 静态)语言，两者看似没什么关联，但是实际上可以说是师出同门，它们很大程度上继承了 Smalltalk 的关键特性，所以很多设计理念是共通的，比如 Ruby 和 Objective-C 拥有相似的消息传递机制 (dynamic message dispatch)、对象模型 (object model —— object class metaclass)，并且都提供及其强大的运行时特性以及支撑运行时特性所需的接口等。 Ruby 和 Objective-C 的异同其实有挺多可以说的，但是本文不会过多地去探讨，这里只是窥探下 singleton class 和 KVO 两个技术点间的联系。
<!--more-->

## 初始设定

假设当前有 Animal 类，Dog 类继承自 Animal，分别用 Ruby 和 Objective-C 创建 Dog 对象。

Ruby ：

```ruby
class Animal
  attr_accessor :name
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
@property (copy, nonatomic) NSString *name;
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

+ (void)clsBark {
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

在 Ruby 中，我们可以给特定对象定义专属的方法，可以知道的是，新定义的 `bark` 方法不在 Dog 类中，因为给 yourDog 发送 `bark` 消息后的输出并没有改变，这种针对单个对象定义的方法称为单件方法 (singleton method)。当我们定义单件方法或者调用 `singleton_class` 方法时，Ruby 会自动创建一个 "匿名类" 来保存单件方法（惰性求值），这个类就是单件类，我们可以通过 `singleton_class` 方法用来访问单件类。

除了使用上述的 `def` ，Ruby 还可以使用 `<<` 语法打开对象的单件类，并且可以在单件类中使用 `super` 访问其父类：

```ruby
class << myDog
  def bark
    super
    puts 'zizizi!'
  end
end

myDog.bark 
# wangwang!
# zizizi!
```


根据最新的示例代码，可以得到 Ruby 的对象模型图：

![object-model-ruby](https://github.com/tripleCC/tripleCC.github.io/raw/hexo/source/images/object-model-ruby-n1.png)

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

简单来说，**Ruby 中的单件类是只属于一个对象的类，它负责描述此对象的行为**。

## Objective-C 的 KVO

Objective-C 可以支持多个根类 (NSObject、NSProxy、或者使用 OBJC_ROOT_CLASS 宏自行创建的根类)，这里使用了 NSObject 作为根类，针对初始设定的示例代码，可以得到以下对象模型图：

![object-model-objective-c](https://github.com/tripleCC/tripleCC.github.io/raw/hexo/source/images/object-model-objective-c-n.png)

可以看到，对于终端对象 myDog 来说，其 `isa` 指向的是 Dog 类，这和上述 Ruby 实现中 yourDog 对象的 `kclass` 指向一致。接下来，我们给 myDog 添加一个观察者 ：

```objc
@interface Observer : NSObject
@end
@implementation Observer
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    Class cls = object_getClass(object);
    Class superCls = class_getSuperclass(cls);
    // cls: NSKVONotifying_Dog, super cls Dog
    NSLog(@"cls: %@, super cls %@", cls, superCls); 
}
@end

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        Dog *myDog = [Dog new];

        Observer *observer = [Observer new];
        [myDog addObserver:observer forKeyPath:@"name" options:NSKeyValueObservingOptionNew context:nil];

        myDog.name = @"Bob";
    }
}
```

KVO 对属性监听的实现，本质上是对监听属性 setter 方法的切片，Objective-C 中实现方法切片最直接的方式是 method swizzling ，不过由于 setter 实例方法保存在监听对象所属类中，如果直接替换，势必会影响这个类后续的实例化操作，于是 Objective-C 在这里采用了另一种方式————继承 + 多态。在添加观察者之后，Objective-C 会创建 Dog 类的子类 NSKVONotifying_Dog ，并将 myDog 对象的 `isa` 指向 NSKVONotifying_Dog 类，接着在 NSKVONotifying_Dog 类中重写监听属性的 setter 方法，变更之后的对象模型图如下 ：

![object-model-objective-c](https://github.com/tripleCC/tripleCC.github.io/raw/hexo/source/images/object-model-objective-c-kvo.png)

可以看到，NSKVONotifying_Dog 类的功能几乎和 Ruby 实现中 #myDog 单件类一致了，我们可以在这个类中给 myDog 对象添加实例方法，而不会对 Dog 类实例化的其他对象产生影响，这个类只负责描述 myDog 对象。

一旦实现了属性的监听，剩下的就是处理监听者和监听属性的关系了，最直接的实现就是在监听对象中维护一个 Map ，根据 Map 的值去派发属性变更消息，这一块还是比较直观的。

## Aspects 中 hook 对象方法

Aspects 是针对 Objective-C 的 AOP 库，我们可以使用 Aspects 做三件事情 ([这里的实例方法和类方法所属描述，建立在从逻辑上讲实例方法属于类实例化的对象，从物理实现上讲属于类的这一假设之上](http://math.hws.edu/javanotes/c5/s1.html))：

- hook 单个终端对象的实例方法
- hook 某个类所有实例化对象的实例方法
- hook 某个类的类方法

其中 hook 单个终端对象的实例方法，本质上也属于 hook 某个类所有实例化对象的实例方法，只不过这个类只会有 hook 对象这一个实例。三种 hook 的示例代码如下 ：

```objc
Dog *myDog = [Dog new];
[myDog aspect_hookSelector:@selector(bark) withOptions:AspectPositionAfter usingBlock:^(id <AspectInfo> info){
    NSLog(@"zizizi!");
} error:nil];
[myDog bark]; 
// wangwang!
// zizizi!
####################
[Dog aspect_hookSelector:@selector(bark) withOptions:AspectPositionAfter usingBlock:^(id <AspectInfo> info){
    NSLog(@"zizizi!");
} error:nil];
Dog *myDog = [Dog new];
[myDog bark];
// wangwang!
// zizizi!
####################
id meta = object_getClass([Dog class]);
[meta aspect_hookSelector:@selector(clsBark) withOptions:AspectPositionAfter usingBlock:^(id <AspectInfo> info){
    NSLog(@"zizizi!");
} error:nil];
[Dog clsBark];
// wangwang!
// zizizi!
```

第一种 hook 和 KVO 面临一样的问题，所以需要做子类化处理，而第二种和第三种 hook 因为影响范围都是全局的，所以可以直接操作类 / 元类的方法列表，在知道 hook 具体方法的前提下，我们也可以直接用 method swizzling 来替换 Aspects 的后两种 hook 方式。

Aspects 创建了 [aspect_hookClass](https://github.com/steipete/Aspects/blob/c3125c5063748c6aa80f18cce54ecc128b51ba8f/Aspects.m#L350-L388) 函数来处理这几种 hook ，这个函数大概做了这么几件准备工作：

- 如果传入对象所属类有 `_Aspects_` 专属前缀，直接返回这个类 (这个对象为终端对象)
- 如果传入对象为类 / 元类，则直接执行替换消息转发入口函数操作，并返回这个类 / 元类 (类和元类执行 `object_getClass` 后返回的都是元类，后者为 NSObject 元类)
- 如果传入对象所属类和 class 返回的类不一致，则直接执行替换消息转发入口函数操作，并返回对象所属类 (这里考虑了 KVO 已经创建了 “单件类”，并且重写了 class 方法，所以直接操作这个“单件类”)
- 惰性创建 `_Aspects_` 前缀的子类 (“单件类”)，其父类为传入对象所属类，并且设置传入对象所属类为刚创建的子类 (这个对象为终端对象，此步骤和 KVO 实现一致)

可以看到，hook 终端对象时，为了变更范围能局限在终端对象中，Aspects 也创建了属于 Objective-C 的“单件类”。


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

更完善的 Ruby 对象模型可以查看 [wiki 上的示意图](https://en.wikipedia.org/wiki/Metaclass#/media/File:Ruby-metaclass-sample.svg) 。


## 小结

如果要在不影响一个类实例化其他对象前提下，给这个了创建的某个对象添加专属的实例方法，在 Ruby 中我们可以通过将实例方法添加到对象的单件类中解决这个需求，并且 Ruby 在语言层面上就可以提供终端对象的单件类，而 Objective-C 没有提供，在了解了 Ruby 单件类的实现之后，借助 Objective-C 强大的运行时能力，我们可以自己去实现这个“语言特性”，主要有两个关键步骤： 

- 创建终端对象所属类的子类 
- 设置终端对象的类为刚创建的子类



## 参考

[Classes and metaclasses](http://www.sealiesoftware.com/blog/archive/2009/04/14/objc_explain_Classes_and_metaclasses.html)

[objc kvo简单探索](https://blog.sunnyxx.com/2014/03/09/objc_kvo_secret/)

[Smalltalk](https://en.wikipedia.org/wiki/Smalltalk)

[Metaclass](https://en.wikipedia.org/wiki/Metaclass#In_Objective-C)

[Objective-C isn't what you think it is (if you think like a Rubyist)](https://genius.com/Soroush-khanlou-objective-c-isnt-what-you-think-it-is-if-you-think-like-a-rubyist-annotated)

[In Ruby, are the terms “metaclass”, “eigenclass”, and “singleton class” completely synonymous and fungible?](https://stackoverflow.com/questions/25336033/in-ruby-are-the-terms-metaclass-eigenclass-and-singleton-class-complete)

[Classes and Objects](https://ruby-doc.com/docs/ProgrammingRuby/html/classes.html)

[Demystifying Ruby Singleton Classes](<http://leohetsch.com/demystifying-ruby-singleton-classes/>)

[Understanding Ruby Singleton Classes](<https://www.devalot.com/articles/2008/09/ruby-singleton>)

[The Ruby Object Model - Structure and Semantics ](https://hokstad.com/ruby-object-model)