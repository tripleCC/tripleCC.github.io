> 使用低流量模式，再去 applestore下载，下载前可以看到实际app的下载大小

 [WWDC 2019 Keynote — Apple 29:25 分钟](https://www.youtube.com/watch?v=psL_5RIBqnY) 中表明，首次下载大小降低 50%，更新大小降低 60%。 


#### appstoreconnect 数据更新问题 

是因为 iOS 13 的原因：Performance Apps open up to two times faster in iOS 13, and apps from the App Store are packaged in a new way that makes them up to 50 percent smaller.，这个是 apple ios13 的优化，但是到 1月底了 appleconnect 后台才实际更新下载大小好像。我今天用 X 和 8 下载快手，都是 70M+，iPhone11 以上设备，因为是 19 年 9月份推出，上面预置的就是 iOS13以上系统，所以 appleconnect 后台直接显示针对 iOS13 优化后的大小，而以前的设备可能安装还是 iOS 13 以下系统，所以苹果展示的是最大的 size ，也就是以前的 156M+。


##### 猜测新打包方式影响的部分

我又看了相关WWDC 视频 & 苹果升级文档，除了说明下载大小降低比例之外，并没有透露更多信息关于新的打包方式和以前有什么具体区别 查阅了一些资料 / 论坛提问，解读只是停留在 swift runtime ，ABI 稳定上面，不过现在 app 里面没有使用 swift ，所以实际并不是这个原因 为了估计新的打包方式对下载大小的哪部分有影响，我打了两种包，一种纯资源，一种纯代码。纯资源的，虽然针对不同系统和设备采用的图片算法不一样，线上包下载大小和本地瘦身之后的还是一致的，甚至直接打开 ipa 看 car 文件，都和线上下载大小差不多，这里猜测新的打包方式不影响资源这块。纯代码这块，就可以直接看出来，iPhone11 iOS 13 上本地瘦身的大小，和远程的几乎一致 （都是 1.7M），这个在以前是会因为苹果加密 macho 导致压缩算法对这部分的压缩比会比较低，一般会比本地的大 2 倍以上 （iPhone11 iOS12 上就 3.8M）。 所以这一块是猜测可能苹果针对 iOS 13 改变了压缩算法，让加密后的 macho 压缩率和没加密时差不多。 至于我们的 app iOS 13 之后比头条多降低了 10M ，这个不同的代码加密之后的压缩比本身应该是不一致的，就像 flutter 引擎的压缩比就比普通代码低一些。 不过上面目前还是我的猜测，苹果目前还没有列出具体的建议如果让压缩率提高，这块后面我看苹果会不会放出新文档，再继续跟进吧 `

