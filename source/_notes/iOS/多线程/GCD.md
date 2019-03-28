## 概念

### 并行串行队列、同步异步派发

> 前者关乎任务启动是否需要等上一个任务完成
>
> 后者关乎派发其他任务是否会阻塞当前任务

一个任务：`|———|` 。下面为任务启动时间点。

**并行队列（serial）**：

```
|———|
 |———|
  |———|
```

**串行队列（concurrent）**：

```
|———|
    |———|
        |———|
```

同一时间点，

并行队列中可以有多个任务在运行；

串行队列只能有一个任务在运行。

**同步（sync）**：

```
|-    --|
 |   | 
 |---|
```

**异步（async）**：

```
|---|
 || 
 |---|
```

同步派发需要等派发任务执行完成后，才能继续执行当前任务；

异步派发任务后，不阻塞当前任务的执行。

## 易忘API

### dispatch_queue_create

>  创建派发队列

创建多个同步队列，**这些同步队列中的任务可并行执行**，因为**每个同步队列对应着一个线程**。

创建并发队列的线程数由系统决定。

### dispatch_set_target_queue

> 变更自定义派发队列的执行优先级
>
> 变更自定义派发队列中任务执行所在队列

如果把多个具有并行运行任务能力的队列 target 设置成一个串行队列，那么这个队列中的任务就会串行执行。

### dispatch_group_t

```objective-c
dispatch_queue_t q = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
dispatch_group_t g = dispatch_group_create();
dispatch_group_async(g, q, ^{ NSLog(@"1"); });
dispatch_group_async(g, q, ^{ NSLog(@"2"); });
dispatch_group_notify(g, q, ^{ NSLog(@"done"); });
// 输出
// 2
// 1
// done
```

`dispatch_group_notify` 等 group 中的任务都执行完成，触发一个回调。

`dispatch_group_async`  相当于 `dispatch_group_enter` + `dispatch_group_leave` + `dispatch_async` : 

```
dispatch_async(q, ^{
    dispatch_group_enter(g)
    block();
    dispatch_group_leave(g)
})
```

后者更加灵活，可以处理**任务中嵌套异步处理**的场景，在设计批量请求时可加以应用。

调用 `dispatch_group_wait` 会阻塞当前线程。

### dispatch_barrier_async

> 队列中先于此函数添加任务的任务执行完成后，才执行后续任务

```objective-c
dispatch_queue_t q = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
dispatch_async(q, ^{ NSLog(@"1"); });
dispatch_barrier_async(q, ^{ NSLog(@"barrier"); });
dispatch_async(q, ^{ NSLog(@"2"); });
// 输出
// 1
// barrier
// 2
```

和 group 的区别：**会阻塞 queue 执行后续的任务**

### dispatch_suspend / dispatch_resume

> 恢复 / 挂起指定队列

对队列中已经执行的任务没有影响，只影响还未执行的任务

### dispatch_semaphore_t

```objective-c
dispatch_queue_t q = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
dispatch_semaphore_t s = dispatch_semaphore_create(1);
for (int i = 0; i < 10; i++) {
    dispatch_async(q, ^{
        dispatch_semaphore_wait(s, DISPATCH_TIME_FOREVER);
        NSLog(@"%d", i);
        dispatch_semaphore_signal(s);
    });
}
// 输出
// 有序 0 - 9 
```

`dispatch_semaphore_create` 创建值为 1 的信号量

`dispatch_semaphore_wait` 在信号量大于等于 1 时，将信号量值减 1 （获取资源）后返回，否则会一直等下去

`dispatch_semaphore_signal`将信号量的值加 1 （释放资源）

