---
layout: post
title: "iOS知识碎片二"
date: 2015-09-30 23:08:45 +0800
comments: true
categories: 碎片系列
---
1、UITableView点击Cell不触发tableView: didSelectRowAtIndexPath:问题<br>
2、高德、百度地图定位不准确问题<br>
3、tableView在Group模式下section从1开始<br>
4、UIActionSheet和UIAlertView出现边角抖动情况<br>
5、WKWebView开启新页面时无法跳转
<!--more-->

## UITableView点击Cell不触发tableView: didSelectRowAtIndexPath:问题
今天解决了一个奇怪的问题。老代码使用UITableView来进行类似网易新闻首页的TitleIndex的切换（UITableView旋转90度，cell也相应旋转，主要说是因为这样不用计算contentSize；个人比较喜欢直接用UIScrollView或者UICollectionView），然后会存在一个奇怪的bug：<br>

当drag到顶部或者底部时，再drag一次或以上，然后点击对应的cell，会出现第一次点击没有效果（cell使用touchBegin可以捕获到），第二次才调用tableView: didSelectRowAtIndexPath:的情况。<br>

找了一下午，也在stackoverflow上找了一些答案，但是大都是说UIScrollView和UITableView混用造成，而且问题现象也有点区别。<br>

后来发现是因为设计了一个属性：bounces，UITableView设置了这个属性之后，就会出现以上现象，以下就是下午的DEMO：

```objc
- (void)viewDidLoad {
    [super viewDidLoad];

    UITableView *tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 40, 100, 500)];
    tableView.delegate = self;
    tableView.dataSource = self;
    // 就是因为这一句
    tableView.bounces = NO;
    [self.view addSubview:tableView];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 15;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSInteger i = 0;
    
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.textLabel.text = [NSString stringWithFormat:@"%ld", i++];
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSLog(@"%zd", indexPath.row);
}

```
如果设置bounces为NO，就会出现上面所说的bug。去除的话就会出现两边有弹性的情况。所以解决方案有以下几种：<br>

1. 更改方案，不用UITableView，改用UICollection、UIScrollView<br>
2. 在cell中设置tap手势，点击时使用代理传出，然后进行手动调用<br>
3. 接受有弹性的情况

最后我采用的情况3，因为最方便，也不会造成大影响～～

## 高德、百度地图定位不准确问题
APP中需要向百度和高德传递一个目的地坐标，但是发现百度和高德的定位坐标都是不准确的Bug，只有苹果自带地图才是正确的。然后搜索了下得知关于`火星坐标`、`地球坐标`、`百度坐标`的一些信息。<br>

原先不知道后台传递过来的是火星坐标还是地球坐标，所以先将后台传递的坐标给打印出来，并且在网页高德地图中输入打印的坐标，然后和网页地图中搜索对应的地址相对比，发现基本无偏差，所以确认后台传递过来的是火星地图（高德地图用的火星坐标）<br>

然后就是百度地图了，因为就使用一个地图坐标转换的功能，所以不想引入整个百度SDK。上网搜了下对应的坐标转换算法，如下：<br>

```objc
const double x_pi = 3.14159265358979324 * 3000.0 / 180.0;

void bd_encrypt(double gg_lat, double gg_lon, double *bd_lat, double *bd_lon)
{
    double x = gg_lon, y = gg_lat;
    double z = sqrt(x * x + y * y) + 0.00002 * sin(y * x_pi);
    double theta = atan2(y, x) + 0.000003 * cos(x * x_pi);
    *bd_lon = z * cos(theta) + 0.0065;
    *bd_lat = z * sin(theta) + 0.006;
}
```
这是从火星坐标转换到百度坐标的函数（作者从百度SDK中逆向出来的代码）。<br>

将后台传送的坐标通过如上函数的转换，就可以在百度地图APP中精确地进行显示了。

```objc
NSString *urlString = [[NSString stringWithFormat:@"baidumap://map/direction?origin=latlng:%lf,%lf|name:我的位置&destination=latlng:%f,%f|name:%@&mode=driving", location.coordinate.latitude, location.coordinate.longitude, bdlat, bdlon, title] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
[[UIApplication sharedApplication] openURL:[NSURL URLWithString:urlString]];`
```

但是发现高德地图还是显示不正确，然后查看了高德地图的API文档，发现是老代码有一个参数传错了：dev=0，原来传的是1，表示再进行一次国测转换（如果传的是地球坐标，那么这里传1）。

```objc
NSString *urlString = [[NSString stringWithFormat:@"iosamap://navi?sourceApplication=%@&backScheme=%@&poiname=%@&lat=%lf&lon=%lf&dev=0&style=2", @"FANCY", @"mudlab-manhattan", title, lat, lng] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
[[UIApplication sharedApplication] openURL:[NSURL URLWithString:urlString]];
```

以下是相应资料：

[火星坐标系 (GCJ-02) 与百度坐标系 (BD-09) 的转换算法](http://blog.csdn.net/coolypf/article/details/8569813)

[Objective-C上地球坐标系到火星坐标系转换算法](http://blog.csdn.net/zhaoxy_thu/article/details/17033347)

[iOS 火星坐标相关整理及解决方案汇总](http://blog.csdn.net/jiajiayouba/article/details/25140967)

相关地图拾取器：

[百度](http://api.map.baidu.com/lbsapi/getpoint/index.html)
[高德](http://lbs.amap.com/console/show/picker)
[google](https://www.google.com/maps)

地图客户端url跳转:

[苹果](https://developer.apple.com/library/ios/featuredarticles/iPhoneURLScheme_Reference/MapLinks/MapLinks.html)
[百度](http://lbsyun.baidu.com/index.php?title=uri/api/ios)
[高德](http://lbs.amap.com/api/uri-api/ios-uri-explain/)

url跳转资料:

[URI跳转方式地图导航的代码实践](http://adad184.com/2015/08/11/practice-in-mapview-navigation-with-URI/)

## tableView在Group模式下section从1开始
在设置sectionHeaderHeight为固定值后，发现viewForHeaderInSection是从section为1开始的，很疑惑，然后google了下原因，stackoverflow上已经有了答案：[解决方案](http://stackoverflow.com/questions/18932476/in-ios-7-viewforheaderinsection-section-is-starting-from-1-not-from-0)

还有手册中对于这个方法的说明：
![](/images/Snip20151118_2.png)

## UIActionSheet和UIAlertView出现边角抖动情况
如下情况：

![](/images/2015-11-19.gif)

被这个问题困扰了很久，因为在iOS7和iOS8中，现象都没那么明显，所以忽略了，但是在iOS9中就特别明显，虽然不影响用户的正常使用，优先级并不高，但总归是需要解决的bug。在stackoverflow询问后之后，很久才有人回复，原因是`UIViewEdgeAntialiasing`，如果有设置过这个字段为true，就会出现这样的问题，所以只要把它设置为false即可。[更多解释](http://stackoverflow.com/questions/19960108/renders-with-edge-antialiasing-causes-delay-in-uialertview-in-ios-7)

## WKWebView开启新页面时无法跳转
使用WKWebView发现某些界面无法跳转，然后试了下UIWebView是可以的，使用浏览器打开，发现是打开一个新界面。于是就去google了下，发现了以下解决方法：

```
webView.UIDelegate = self


func webView(webView: WKWebView, createWebViewWithConfiguration configuration: WKWebViewConfiguration, forNavigationAction navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
	if navigationAction.targetFrame?.mainFrame ?? true {
		webView.loadRequest(navigationAction.request)
	}
	return nil
}
```
这是swift版本的，对应的[stackoverflow上的回答](http://stackoverflow.com/questions/25713069/why-is-wkwebview-not-opening-links-with-target-blank)