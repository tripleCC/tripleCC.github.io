API 在源码层面上，规定开发者调用程序的接口，

ABI 在机器码层面上，规定独立编译的二进制模块数据的访问接口，是平台相关的



### API: Application Program Interface

This is the set of public types/variables/functions that you expose from your application/library.

In C/C++ this is what you expose in the header files that you ship with the application.

### ABI: Application Binary Interface

> C++ 的 extern "C" 就是适配 C 的 ABI

This is how the compiler builds an application. 定义编译器如何构建出目标应用/二进制文件
It defines things (but is not limited to):

- How parameters are passed to functions (registers/stack).
- Who cleans parameters from the stack (caller/callee).
- Where the return value is placed for return.
- How exceptions propagate.
- 对象内存布局等



An *ABI* defines how data structures or computational routines are accessed in [machine code](https://en.wikipedia.org/wiki/Machine_code), which is a low-level, hardware-dependent format; in contrast, an [*API*](https://en.wikipedia.org/wiki/Application_programming_interface) defines this access in [source code](https://en.wikipedia.org/wiki/Source_code), which is a relatively high-level, hardware-independent, often [human-readable](https://en.wikipedia.org/wiki/Human-readable) format。



### 资料

[What is an application binary interface (ABI)?](https://stackoverflow.com/questions/2171177/what-is-an-application-binary-interface-abi)

[Difference between API and ABI](https://stackoverflow.com/questions/3784389/difference-between-api-and-abi)

[Application binary interface](<https://en.wikipedia.org/wiki/Application_binary_interface>)

[Swift ABI 稳定对我们到底意味着什么](<https://onevcat.com/2019/02/swift-abi/>)

