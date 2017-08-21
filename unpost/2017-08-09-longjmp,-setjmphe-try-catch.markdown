---
layout: post
title: "longjmp、setjmp和try-catch"
date: 2017-08-09 10:01:19 +0800
comments: true
categories: 
---

```
clang version 3.0 (tags/RELEASE_30/final)
Target: x86_64-apple-darwin16.6.0
Thread model: posix
```

```
int main(int argc, const char * argv[]) {
    @autoreleasepool {
        /* @try scope begin */ {
            struct _objc_exception_data {
                int buf[18/*32-bit i386*/];
                char *pointers[4];} _stack;
            id volatile _rethrow = 0;
            objc_exception_try_enter(&_stack);
            if (!_setjmp(_stack.buf)) /* @try block continue */
            {
                
            } /* @catch begin */ else {
                id _caught = objc_exception_extract(&_stack);
                objc_exception_try_enter (&_stack);
                if (_setjmp(_stack.buf))
                    _rethrow = objc_exception_extract(&_stack);
                else { /* @catch continue */
                    if (1) { id a = _caught;
                        
                    } /* last catch end */
                    else {
                        _rethrow = _caught;
                        objc_exception_try_exit(&_stack);
                    } } /* @catch end */
            } /* @finally */ { if (!_rethrow) objc_exception_try_exit(&_stack);
                
                
                if (_rethrow) objc_exception_throw(_rethrow);
            } } /* @try scope end */
        
    }
    return 0;
}
```

[Objective-C try/catch异常处理机制原理](http://www.cnblogs.com/markhy/p/3169035.html)<br>
[Exception safety in Objective-C](http://newsgroups.derkeiler.com/Archive/Comp/comp.sys.mac.programmer.help/2007-08/msg00020.html)<br>
[Exceptions in C with Longjmp and Setjmp](http://www.di.unipi.it/~nids/docs/longjump_try_trow_catch.html)<br>
[UNIX 环境高级编程](https://book.douban.com/subject/1788421/)<br>
[C 专家编程](https://book.douban.com/subject/2377310/)<br>
