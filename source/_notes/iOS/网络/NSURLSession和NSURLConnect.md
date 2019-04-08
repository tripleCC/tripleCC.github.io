**NSURLSession 有一个 session 用来统一定制名下所有的请求，而 NSURLConnect 没有这个能力**

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

#### NSURLSession 对请求的批量启动、挂起、取消更加友好

NSURLSession:

```objective-c
[session getTasksWithCompletionHandler:^(NSArray<NSURLSessionDataTask *> * _Nonnull dataTasks, NSArray<NSURLSessionUploadTask *> * _Nonnull uploadTasks, NSArray<NSURLSessionDownloadTask *> * _Nonnull downloadTasks) {
   // 调用 cancel
}];
```





### 资料

[What is the biggest difference between NSURLConnection and NSURLSession](https://stackoverflow.com/questions/28105504/what-is-the-biggest-difference-between-nsurlconnection-and-nsurlsession)