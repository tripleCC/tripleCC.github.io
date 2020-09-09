## Flutter 动态化支持 JIT 是怎么回事

> The Dart VM has a just-in-time compiler (JIT) that supports both pure interpretation (as required on iOS devices, for example) and runtime optimization.

Dart VM 支持纯解释，所以 iOS 上无法开启真正的 JIT

但是在调试状态下， Dart VM 在 iOS 以真正的 JIT 模式运行，从 [Why Dart VM keep emitting native code running in Debug mode on iOS?](https://github.com/flutter/flutter/issues/57111) issue 中可以看出，调试状态下，iOS 的权限提升，可以申请 WX 的内存，所以支持了 JIT，具体可以查看 [Jailed Just-in-Time Compilation on iOS](https://saagarjha.com/blog/2020/02/23/jailed-just-in-time-compilation-on-ios/)

iOS 上，要支持 JIT 需要 `dynamic-codesigning entitlement` 证书，在使用 `mmap’s MAP_JIT` 会去校验这个证书。比如 JavaScriptCore ，在**系统进程**中运行时，就可以使用 JIT （WKWebView），单独在应用中直接使用 JavaScriptCore ，JavaScriptCore 不会以 JIT 模式 运行。