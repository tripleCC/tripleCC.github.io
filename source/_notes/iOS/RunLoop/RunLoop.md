RunLoop 本质是为了保活线程来尽可能多地处理事务的一种技术手段。



####RunLoop 启动三种方式

- 无条件
- 超时
- 指定模式

其中无条件会使线程陷入真正的死循环，无法退出：

```swift
public func run() {
    while run(mode: .defaultRunLoopMode, before: Date.distantFuture) { }
}
public func run(mode: RunLoopMode, before limitDate: Date) -> Bool {
    if _cfRunLoop !== CFRunLoopGetCurrent() {
        return false
    }
    let modeArg = mode._cfStringUniquingKnown
    if _CFRunLoopFinished(_cfRunLoop, modeArg) {
        return false
    }

    let limitTime = limitDate.timeIntervalSinceReferenceDate
    let ti = limitTime - CFAbsoluteTimeGetCurrent()
    CFRunLoopRunInMode(modeArg, ti, true)
    return true
}
```

可以看到，while 的条件始终为 true



#### Source0上的回调如何被触发执行

```c
static Boolean __CFRunLoopDoSource0(CFRunLoopSourceRef rls) {
    
    Boolean sourceHandled = false;
    __CFRunLoopSourceLock(rls);
    if (__CFRunLoopSourceIsSignaled(rls)) {
        __CFRunLoopSourceUnsetSignaled(rls);
        if (__CFIsValid(rls)) {
            __CFRunLoopSourceUnlock(rls);
            void *perform = rls->_context.version0.perform;
            void *info = rls->_context.version0.info;
            cf_trace(KDEBUG_EVENT_CFRL_IS_CALLING_SOURCE0 | DBG_FUNC_START, perform, info, 0, 0);
            __CFRUNLOOP_IS_CALLING_OUT_TO_A_SOURCE0_PERFORM_FUNCTION__(perform, info);
            cf_trace(KDEBUG_EVENT_CFRL_IS_CALLING_SOURCE0 | DBG_FUNC_END, perform, info, 0, 0);
            CHECK_FOR_FORK();
            sourceHandled = true;
        } else {
            __CFRunLoopSourceUnlock(rls);
        }
    } else {
        __CFRunLoopSourceUnlock(rls);
    }
    
    
    return sourceHandled;
}
```

如果 __CFRunLoopSourceIsSignaled 被设置了，runloop 循环则会执行 source0 上面的回调。所以如果其他线程的事务处理完成，需要目标线程执行回调，只需要将 signaled 设置为 true 即可让目标线程的 runloop 执行 source0 上的回调。（这里多线程访问 singaled，所以会在读写操作上加锁）