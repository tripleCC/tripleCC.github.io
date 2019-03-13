---
layout: post
title: "用 Block 实现委托方法"
date: 2017-07-28 19:05:22 +0800
comments: true
categories: objective-c
tags: [objective-c,block,delegate]
---

Block 和 Delegate 是对象间传递消息的常用机制，这两个机制可以说是各有千秋。 Delegate 可以很方便把目标动作的执行过程划分为多个方法，以展现不同时间节点下特定的操作； Block 则擅长处理一个回调多个落点的情况，并且它可以通过捕捉上下文信息，来达到减少创建额外变量，集中消息处理逻辑的目的。

结合以上两种通信方式的特点，我们可以添加一些额外的桥接处理，让 Delegate 机制也能享有 Block 机制所拥有的部分优点。桥接处理的核心就是用 Block 实现委托方法。

<!--more-->
由于 Runtime 的存在，在消息转发的最后一步，开发者可以轻松地拦截对未定义方法的调用，并且针对当前消息做一些额外的处理，比如改变它的入参、设置另一个消息接受者等。借助于这一特性，我们可以创建一个统一的 Delegate 对象，并在这个对象的 `-forwardInvocation:` 方法中，用预先设置的 Block 替换对委托方法的调用，以达到用 Block 实现委托方法的目的。

## NSInvocation 基本使用

> NSInvocation objects are used to store and forward messages between objects and between applications

 
这是苹果官方对 NSInvocation 的用途给出的解释。一个 NSInvocation 对象包含了 Objective-C 消息的所有要素：消息接收对象、 方法选择器 (SEL) 、参数以及返回值，并且这些要素都可以由开发者直接设置。以下是使用 NSInvocation 的一个简单的例子：

```objc
NSString *foo = @"foo";
NSMethodSignature *signature = [foo methodSignatureForSelector:@selector(stringByAppendingString:)];
NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
invocation.selector = @selector(stringByAppendingString:);

NSString *bar = @"bar";
[invocation setArgument:&bar atIndex:2];
[invocation invokeWithTarget:foo];

void *result = nil;
[invocation getReturnValue:&result];

NSString *resultString = (__bridge NSString *)(result);
NSLog(@"%@", resultString);
```

上面代码块输出：
```
2017-08-01 15:07:51.131489+0800 [33240:7029681] foobar
```

可以看到，以上结果和执行 `[foo stringByAppendingString:bar]`  的结果是一致的。

关于 NSInvocation 的使用，需要留意以下两点：

1、一般方法的自定义参数从索引 2 开始，前两个分别是对象自身以及发送方法的 SEL 。<br>
2、从 `-getArgument:atIndex:` 和 `-getReturnValue:` 方法中获取的对象是不会被 retain 的，所以如果使用了 ARC ，那么以下代码都是错误的：

```
NSString *bar = nil;
[invocation getArgument:&bar atIndex:2];

NSString *result = nil;
[invocation getReturnValue:&result];
```
ARC 编译环境下局部对象默认具有 `__strong` 属性，它会针对这个对象添加 release 代码，所以这样的代码可能会因为 release 已经释放的对象而崩溃。正确代码如下：

```
void *bar = nil;
//__unsafe_unretained NSString *bar = nil;
//__weak NSString *bar = nil;
[invocation getArgument:&bar atIndex:2];

void *result = nil;
//__unsafe_unretained NSString *result = nil;
//__weak NSString *result = nil;
[invocation getReturnValue:&result];
```
3、如果是在两个 NSInvocation 对象间传递参数 /  返回值，那么可以直接传入指针获取并设置目标地址，以返回值为例：

```
....
NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
NSInvocation *shadowInvocation = [NSInvocation invocationWithMethodSignature:signature];
....
void *resultBuffer = malloc(invocation.methodSignature.methodReturnLength);
memset(resultBuffer, 0, invocation.methodSignature.methodReturnLength);

[invocation getReturnValue:resultBuffer];
[shadowInvocation setReturnValue:resultBuffer];
....
free(resultBuffer);
```
这时，如果返回值是一个 NSString 对象，那么 `resultBuffer` 实际上是指向 NSString 对象指针的指针，这时可以这样读取实际内容：

```
NSString *result = (__bridge NSString *)(*(void **)resultBuffer);
```
不过在已经知道返回值是一个对象时，一般会直接传入对象指针的地址，以便直接读取对象。

## 获取方法签名

NSMethodSignature 是创建一个有效 NSInvocation 对象的必要成分，它提供了方法调用所必须的参数和返回值信息。

### 从对象中获取方法签名

NSObject 类用以下两个方法获取实例方法的方法签名：

```
- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector OBJC_SWIFT_UNAVAILABLE("");

+ (NSMethodSignature *)instanceMethodSignatureForSelector:(SEL)aSelector OBJC_SWIFT_UNAVAILABLE("");
```

既然类也是对象，那么类方法的方法签名也就可以通过 `-methodSignatureForSelector:` 方法获取了。

### 从协议中获取方法签名

由于协议定义了接口的参数和返回值信息，所以从协议中也可以获取到特定方法的方法签名。利用 `protocol_getMethodDescription` 函数，可以获取到描述类型的 C 字符串，再通过这个字符串构造方法签名。针对协议中的接口有 `required` 和 `optional` 两种，并且不允许重复这一特点，可以创建构造方法签名的函数：

```objc
static NSMethodSignature *tbv_getProtocolMethodSignature(Protocol *protocol, SEL selector, BOOL isInstanceMethod) {
    struct objc_method_description methodDescription = protocol_getMethodDescription(protocol, selector, YES, isInstanceMethod);
    if (!methodDescription.name) {
        methodDescription = protocol_getMethodDescription(protocol, selector, NO, isInstanceMethod);
    }
    return [NSMethodSignature signatureWithObjCTypes:methodDescription.types];
}
```

### 从 Block 中获取方法签名

苹果并没有提供一个开放的接口，供开发者获取 Block 的方法签名。不过根据 [LLVM 对 Block 结构的描述](https://clang.llvm.org/docs/Block-ABI-Apple.html)，我们可以通过操作指针获取签名字符串。以下是 Block 的结构：

```objc
// Block internals.
typedef NS_OPTIONS(int, TBVBlockFlags) {
    TBVBlockFlagsHasCopyDisposeHelpers = (1 << 25),
    TBVBlockFlagsHasSignature          = (1 << 30)
};
typedef struct tbv_block {
    __unused Class isa;
    TBVBlockFlags flags;
    __unused int reserved;
    void (__unused *invoke)(struct tbv_block *block, ...);
    struct {
        unsigned long int reserved;
        unsigned long int size;
        // requires TBVBlockFlagsHasCopyDisposeHelpers
        void (*copy)(void *dst, const void *src);
        void (*dispose)(const void *);
        // requires TBVBlockFlagsHasSignature
        const char *signature;
        const char *layout;
    } *descriptor;
    // imported variables
} *TBVBlockRef;
```
可以看到，只要获取 `descriptor` 指针，然后根据不同条件添加特定的偏移量，就可以获取到 `signature` 了：

```objc
static NSMethodSignature *tbv_signatureForBlock(id block) {
    TBVBlockRef layout = (__bridge TBVBlockRef)(block);
    
    // 没有签名，直接返回空
    if (!(layout->flags & TBVBlockFlagsHasSignature)) {
        return nil;
    }
    
    // 获取 descriptor 指针
    void *desc = layout->descriptor;
    
    // 跳过 reserved 和 size 成员
    desc += 2 * sizeof(unsigned long int);
    
    // 如果有 Helpers 函数， 跳过 copy 和 dispose 成员
    if (layout->flags & TBVBlockFlagsHasCopyDisposeHelpers) {
        desc += 2 * sizeof(void *);
    }
    
    // desc 为 signature 指针的地址，转换下给 objcTypes
    char *objcTypes = (*(char **)desc);
    
    return [NSMethodSignature signatureWithObjCTypes:objcTypes];
}

```

## 方法调用 -> Block 调用

经过上文的探索，已经可以获取到 Block 和接口方法的签名信息了，下面要做的就是根据这个签名信息，结合方法对应的 NSInvocation 对象，创建和 Block 关联的 NSInvocation 对象。

### 存储 Block 信息

首先要做的是，存储 Block 的签名信息，并且和接口方法的签名信息做匹配处理。因为在调用前，需要将接口方法得到的参数转换成 Block 的入参，调用之后，需要将 Block 的返回值重新传给接口方法，所以必须确保两者的签名信息在一定程度上是兼容的。

```objc
- (instancetype)initWithMethodSignature:(NSMethodSignature *)methodSignature block:(id)block {
    return [self initWithMethodSignature:methodSignature blockSignature:tbv_signatureForBlock(block) block:block];
}

- (instancetype)initWithMethodSignature:(NSMethodSignature *)methodSignature blockSignature:(NSMethodSignature *)blockSignature block:(id)block {
    NSAssert(tbv_isCompatibleBlockSignature(blockSignature, methodSignature), @"Block signature %@ is not compatible with method signature %@", blockSignature, methodSignature);
    
    if (self = [super init]) {
        _methodSignature = methodSignature;
        _blockSignature = blockSignature;
        _block = block;
    }
    
    return self;
}
```

### 签名匹配

Block 的签名信息相较于方法的签名信息，只在参数类型上少了 SEL 。方法的签名信息如果要获取自定义参数类型的话，需要从索引 2 开始，而 Block 的自定义参数类型信息则从索引 1 开始。

```objc
static BOOL tbv_isCompatibleBlockSignature(NSMethodSignature *blockSignature, NSMethodSignature *methodSignature) {
    NSCParameterAssert(blockSignature);
    NSCParameterAssert(methodSignature);
    
    if ([blockSignature isEqual:methodSignature]) {
        return YES;
    }
    
    // block 参数个数需要小于 method 的参数个数 (针对 block 调用替换 method 调用)
    // 两者返回类型需要一致
    if (blockSignature.numberOfArguments >= methodSignature.numberOfArguments ||
        blockSignature.methodReturnType[0] != methodSignature.methodReturnType[0]) {
        return NO;
    }
    
    // 参数类型需要一致
    BOOL compatibleSignature = YES;
    
    // 自定义参数从第二个开始
    for (int idx = 2; idx < blockSignature.numberOfArguments; idx++) {

        // block 相比 method ，默认参数少了 SEL
        // method: id(@) SEL(:) ....
        // block: block(@?) ....
        const char *methodArgument = [methodSignature getArgumentTypeAtIndex:idx];
        const char *blockArgument = [blockSignature getArgumentTypeAtIndex:idx - 1];
        if (!methodArgument || !blockArgument || methodArgument[0] != blockArgument[0]) {
            compatibleSignature = NO;
            break;
        }
    }
    
    return compatibleSignature;
}
```

### Invocation 调用

得到了有效的 Block 签名信息，就可以构造 NSInvocation 对象了，不过还需要接口方法的实参信息，这可以通过让外部传入接口方法的 NSInvocation 对象实现。

```objc
- (void)invokeWithMethodInvocation:(NSInvocation *)methodInvocation {
    NSParameterAssert(methodInvocation);
    NSAssert([self.methodSignature isEqual:methodInvocation.methodSignature], @"Method invocation's signature is not compatible with block signature");
    
    NSMethodSignature *methodSignature = methodInvocation.methodSignature;
    NSInvocation *blockInvocation = [NSInvocation invocationWithMethodSignature:self.blockSignature];
    
    void *argumentBuffer = NULL;
    for (int idx = 2; idx < methodSignature.numberOfArguments; idx++) {
        
        // 获取参数类型
        const char *type = [methodSignature getArgumentTypeAtIndex:idx];
        NSUInteger size = 0;
        
        // 获取参数大小
        NSGetSizeAndAlignment(type, &size, NULL);
        
        // 参数缓存
        if (!(argumentBuffer = reallocf(argumentBuffer, size))) {
            return;
        }
        
        // 把 method 的参数传递给 block
        [methodInvocation getArgument:argumentBuffer atIndex:idx];
        [blockInvocation setArgument:argumentBuffer atIndex:idx - 1];
    }
    
    // 调用 block
    [blockInvocation invokeWithTarget:self.block];
    
    // 返回值缓存
    if (methodSignature.methodReturnLength &&
        (argumentBuffer = reallocf(argumentBuffer, methodSignature.methodReturnLength))) {
        
        // 把 block 的返回值传递给 method
        [blockInvocation getReturnValue:argumentBuffer];
        [methodInvocation setReturnValue:argumentBuffer];
    }
    
    // 释放缓存
    free(argumentBuffer);
}
```
顺带说下 `reallocf` 函数是 `realloc` 函数的增强版，它可以在后者无法申请到堆空间时，释放旧的堆空间：

```objc
void *reallocf(void *p, size_t s) {
    void *tmp = realloc(p, s);
    if(tmp) return tmp;
    free(p);
    return NULL;
}
```
这样就可以直接用 `argumentBuffer = reallocf(argumentBuffer, size)` 形式的语句，否则如果使用 `realloc`, 一旦返回的是 `NULL`，会造成旧的堆空间无法释放的问题。

## 实现委托方法

现在已经可以构造 Block 的 NSInvocation 对像，就缺携带参数和返回值信息的接口方法 NSInvocation 对象了。接下来就针对实例方法，简单地实现动态委托类。

### 储存 Block Invocation 信息

这里简单地以接口方法选择器对应的字符串为 Key，以 Block 对应的 Invocation 封装类为 Value 储存调用信息。

```objc
- (instancetype)initWithProtocol:(Protocol *)protocol {
    _protocol = protocol;
    _selectorInvocationMap = [NSMutableDictionary dictionary];
    return self;
}

- (void)implementInstanceMethodOfSelector:(SEL)selector withBlock:(id)block {
    NSMethodSignature *methodSignature = tbv_getProtocolMethodSignature(self.protocol, selector, YES);
    TBVBlockInvocation *invocation = [[TBVBlockInvocation alloc] initWithMethodSignature:methodSignature block:block];
    self.selectorInvocationMap[NSStringFromSelector(selector)] = invocation;
}

``` 


### 消息转发

向动态委托类发送委托消息后，会触发消息转发机制。在消息转发的最后一步，可以构造委托方法对应的 NSInvocation 对象，这个对像可供**Invocation 调用**一节中描述的 Block Invocation 使用。

```objc
- (void)forwardInvocation:(NSInvocation *)invocation {
    TBVBlockInvocation *blockInvocation = self.selectorInvocationMap[NSStringFromSelector(invocation.selector)];
    [blockInvocation invokeWithMethodInvocation:invocation];
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)sel {
    return self.selectorInvocationMap[NSStringFromSelector(sel)].methodSignature;
}

- (BOOL)respondsToSelector:(SEL)aSelector {
    return !!self.selectorInvocationMap[NSStringFromSelector(aSelector)];
}
```


## 实例

最后看下如何使用这个动态委托类。


```objc
@class Computer;
@protocol ComputerDelegate <NSObject>
@required
- (void)computerWillStart:(Computer *)computer;
- (BOOL)computerShouldBeLocked:(Computer *)computer;
@end

@interface Computer : NSObject
@property (weak, nonatomic) id <ComputerDelegate> delegate;

- (void)start;
- (void)lock;
@end
@implementation Computer
- (void)start {
    [self.delegate computerWillStart:self];
    
    // start
}

- (void)lock {
    __unused BOOL locked = [self.delegate computerShouldBeLocked:self];
    
    printf("computer should be locked: %d \n", locked);
    
    // lock
}
@end
```

下面是应用代码：

```objc
TBVDynamicDelegate <ComputerDelegate> *dynamicDelegate = (id)[[TBVDynamicDelegate alloc] initWithProtocol:@protocol(ComputerDelegate)];
[dynamicDelegate implementInstanceMethodOfSelector:@selector(computerWillStart:) withBlock:^(Computer *c) {
    NSLog(@"%@ will start", c);
}];
[dynamicDelegate implementInstanceMethodOfSelector:@selector(computerShouldBeLocked:) withBlock:^BOOL(Computer *c) {
    NSLog(@"%@ should not be locked", c);
    return NO;
}];

Computer *computer = [Computer new];
computer.delegate = dynamicDelegate;
[computer start];
[computer lock];
```

输出结果：
```
2017-08-01 14:44:29.814871+0800 [19950:6944265] <Computer: 0x100405ce0> will start
2017-08-01 14:44:29.815827+0800 [19950:6944265] <Computer: 0x100405ce0> should not be locked
computer should be locked: 0 
```

## 小结

其实用 Block 实现委托方法的开源方案在比较早的时候就已经出来了，本文的实现就是 [BlocksKit](https://github.com/BlocksKit/BlocksKit) 的 A2BlockInvocation 和 A2DynamicDelegate 类的简易版本，其中省略了类方法以及一些边界条件的处理，不过大体的思路基本是一致的，还是围绕 NSInvocation 和消息转发在走。


## 参考 
[Aspects](https://github.com/steipete/Aspects)<br>
[BlocksKit](https://github.com/BlocksKit/BlocksKit)<br>	
[Hands-On Objective-C 2.0: Blocks](http://www.informit.com/articles/article.aspx?p=1620076&seqNum=3)<br>
[Generic Block Proxying](https://www.mikeash.com/pyblog/friday-qa-2011-10-28-generic-block-proxying.html)<br>
[NSInvocation returns value but makes app crash with EXC_BAD_ACCESS](https://stackoverflow.com/questions/22018272/nsinvocation-returns-value-but-makes-app-crash-with-exc-bad-access)<br>
