**NSURLSession 有一个 session 用来统一定制名下所有的请求，而 NSURLConnect 没有这个能力**

![Snip20190328_4](https://github.com/tripleCC/tripleCC.github.io/raw/hexo/source/images/Snip20190408_2.png)

### NSURLSession 和 NSURLConnection 区别

#### NSURLConnection 发起后台请求需要手动保活这个线程直到代理回调结束，NSURLSession 则不需要

AFNetworking 2.0 使用 NSURLConnection ，所以需要常驻线程来接收代理回调。AFNetworking 3.0  使用 NSURLSession 后就直接使用 NSOperationQueue 执行代理回调了，去除了常驻线程。

```
// NSURLConnection
Delegate methods are called on the same thread that called this method. For the connection to work correctly, the calling thread’s run loop must be operating in the default run loop mode.
```

默认情况下 NSURLConnection 代理回调在创建 NSURLConnection 对象的线程中执行，

[深入理解RunLoop](<https://blog.ibireme.com/2015/05/18/runloop/>) 中关于网络请求一节有对 NSURLConnection 原理探讨。



虽然 5.0 版本之后 NSURLConnection 也提供了`setDelegateQueue：` 接口设置回调执行的 Queue，但是还是需要创建 NSURLConnection 对象的线程存活 。

```
dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
      NSOperationQueue *queue = [[NSOperationQueue alloc] init];
      NSURLConnection *c = [NSURLConnection connectionWithRequest:request delegate:dog];
      [c setDelegateQueue:queue];
      [c start];
  });
```

上面这种请求方式，回调是无法执行的，需要执行所在线程的 RunLoop ，通过 RunLoop 执行网络回调，因为网络事件也是 Source0 ，所以需要 RunLoop 进行处理。NSURLSession 的回调貌似不走 RunLoop 这一路径了，至少在调用栈上面没看出来，在回调执行前，调用栈都在 com.apple.NSURLSession-work 这个 queue 上。

通过给 **breakpoint set -r '\[__NSCFLocalSessionTask connection:didReceiveData:completion:\]$'** 设置断点，可以看到没有经过 RunLoop，由 CFNetwork.Connection 直接向 com.apple.NSURLSession-work 队列派发任务。[lldb breakpoint on all methods in class objective c](https://stackoverflow.com/questions/29687504/lldb-breakpoint-on-all-methods-in-class-objective-c)

#### NSURLSession 可以针对同个 session 创建的请求 task 提供统一的配置，比如请求头、cookie、认证信息等

NSURLSession：

```objective-c
// 可以在这里设置 session 的统一配置，比如 header、cookie 等
NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
//    configuration.HTTPAdditionalHeaders = @{};
//    configuration.HTTPCookieStorage =
NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration];
NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:@"http://gank.io/api/history/content/2/1"]];
// 后面通过这个 session 创建出的 task （另一个请求） 都会有上面的配置
NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
    NSLog(@"%@", data);
}];
[task resume];
```

NSURLConnection:

```objective-c
NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:@"http://gank.io/api/history/content/2/1"]];
// NSURLConnection 创建的请求，请求信息只能通过 request 配置（NSMutableURLRequest）
[NSURLConnection sendAsynchronousRequest:request queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse * _Nullable response, NSData * _Nullable data, NSError * _Nullable connectionError) {
    NSLog(@"%@", data);
}];

```

#### NSURLSession 支持后台下载（在其他进程下载）

NSURLSession：

```objective-c
// 创建如下配置的 session 即可
NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:@"xxxxxxxxx"];
configuration.sessionSendsLaunchEvents = YES;
configuration.discretionary = YES;
NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration delegate:self delegateQueue:[NSOperationQueue mainQueue]];
NSURLSessionDownloadTask *task = [session downloadTaskWithRequest:request];
[task resume];
```

在后台下载时，如果是系统杀死了 App，并且后台 session 中有正在进行的下载任务，那么下载任务会继续。

如果是用户手动杀死 App ，那么所有的下载任务会被取消。

详情： [backgroundSessionConfigurationWithIdentifier:](<https://developer.apple.com/documentation/foundation/nsurlsessionconfiguration/1407496-backgroundsessionconfigurationwi?language=objc>)

#### NSURLSession 对请求的批量启动、挂起、取消更加友好

NSURLSession:

```objective-c
[session getTasksWithCompletionHandler:^(NSArray<NSURLSessionDataTask *> * _Nonnull dataTasks, NSArray<NSURLSessionUploadTask *> * _Nonnull uploadTasks, NSArray<NSURLSessionDownloadTask *> * _Nonnull downloadTasks) {
   // 调用 cancel
}];
```





### 资料

[What is the biggest difference between NSURLConnection and NSURLSession](https://stackoverflow.com/questions/28105504/what-is-the-biggest-difference-between-nsurlconnection-and-nsurlsession)