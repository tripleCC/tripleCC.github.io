### 什么是 Promise

Promise 是一种**异步编程解决方案**，可以将**异步操作以同步操作的流程表达出来**。

Promise 对象本质上是对异步操作的封装，使用者可以通过固定接口获取异步操作结果。

### Promise 的特点

Promise 对象有以下两个特点：

- 对象状态不受外界影响，并且**只有其封装操作的结果可以变更对象状态**，具体有三种状态
  - pending，进行中
  - fulfilled，已成功
  - rejected，已失败
- 状态只会变更一次，变更后称之为 resolved，并且会一直保持此结果，状态的变更只有两种可能
  - pending -> fulfilled
  - pending -> rejected

Promise 对象**创建之后就会执行**，不需要外界触发（区别 Rx 中的冷信号），执行完成之后会保存操作结果，等待外界"消费"。

### 接口

这里主要理解  then 就好，其他方法看资料中的文章。

#### 对象方法

##### then

then 方法为 Promise 对象添加状态变更时的回调函数（resolved 之后才会调用），其返回一个新的 Promise 对象。

传入回调函数的返回值类型可分为两种：

- Promise 对象 （说明还有异步操作）
  - 后一个回调函数需要等此 Promise 对象状态发生变化才会被调用
- 非 Promise 对象（说明没有异步操作了）
  - 直接使用此返回值作为异步操作结果

##### catch

catch 方法指定发布错误回调。

Promise 对象错误具有冒泡性质，错误总会被下一个 catch 语句捕获。

##### finally

设置不管状态如何，都会执行的回调函数



### 简单实现

这里不管 reject。

```objective-c

typedef enum : NSUInteger {
    Pending,
    Fulfilled,
    Rejected,
} State;

@interface Promise : NSObject
@property (assign, nonatomic) State state;
@property (strong, nonatomic) id value;
//状态变更回调函数
@property (copy, nonatomic) id (^resolvedBlock)(id value);
- (instancetype)initWithBlock:(void (^)(void (^resolve)(id value)))block;
- (instancetype)then:(id (^)(id))resolved;
@end
@implementation Promise
- (instancetype)initWithBlock:(void (^)(void (^)(id)))block {
    self = [super init];
    self.state = Pending;
    // 变更对象状态函数
    __weak typeof(self) wself = self;
    void (^resolve)(id value) = ^(id value){
        __strong typeof(wself) sself = wself;
        sself.state = Fulfilled;
        sself.value = value;
        if (sself.resolvedBlock) {
            sself.resolvedBlock(value);
        }
    };
    
    block(resolve);
    
    return self;
}

- (instancetype)then:(id (^)(id))resolved {
    if (self.state == Pending) {
        //  如果是未处理状态，保存回调函数，等待状态变更后调用
        return [[Promise alloc] initWithBlock:^(void (^resolve)(id value)) {
            [self setResolvedBlock:^id(id value) {
                id r = resolved(value);
                if ([r isKindOfClass:[Promise class]]) {
                    // 如果 r 是 Promise 对象，
                    // 在此对象的状态变更函数中，
                    // 调用当前构建 Promise 对象的 resolve 函数，
                    // 以变更当前对象的状态
                    [r then:^id(id value) {
                        resolve(value);
                        return nil;
                    }];
                } else {
                    resolve(r);
                }
                return nil;
            }];
        }];
    } else if (self.state == Fulfilled) {
        //  如果是成功状态，直接调用回调函数
        return [[Promise alloc] initWithBlock:^(void (^resolve)(id value)) {
            id r = resolved(self.value);
            if ([r isKindOfClass:[Promise class]]) {
                [r then:^id(id value) {
                    resolve(value);
                    return nil;
                }];
            } else {
                resolve(r);
            }
        }];
    }
    return [[Promise alloc] initWithBlock:^(void (^resolve)(id value)) {
    }];
}

@end
```

resolve 函数负责变更 Promise 状态，触发状态变更回调函数。

then 函数负责添加状态变更回调函数。

### 资料

[Promise 对象](<http://es6.ruanyifeng.com/#docs/promise>)