stack overflow:  [Xcode: What is a target and scheme in plain language?](https://stackoverflow.com/questions/20637435/xcode-what-is-a-target-and-scheme-in-plain-language)

翻译：

- **Workspace** - 包含一个或多个工程 projects，工程之间通常存在依赖关系
- **Project** - 包含代码和资源等
- **Target** - 每个 project 都有一个或多个 targets
  - 每个 target 针对 project 定义了一系列 build setting
  - 每个 target 定义了编译时需要使用 classes、资源、自定义脚本等
  - 多个 target 通常用来区分同个 project 的不同分发路径
    - 比如，一个工程有两个 targets ，一个内测，一个发布，有个 debugger 工具，我们就可以在内测 target 中加上这些文件，发布 target 不加这些文件
    - 添加 tests ，也会添加新的 target
- **Scheme** - 定义当我们执行 `Build`、`Test`、`Profile` 等操作时的具体动作
  - 通常来说，一个 target 至少有一个 scheme
  - 通过 `Autocreate Schemes Now` 我们可以自动创建 schemes 

![Snip20190328_3](/Users/songruiwang/Pictures/Snip20190328_3.png)

![Snip20190328_4](/Users/songruiwang/Pictures/Snip20190328_4.png)

![Snip20190328_5](/Users/songruiwang/Pictures/Snip20190328_5.png)