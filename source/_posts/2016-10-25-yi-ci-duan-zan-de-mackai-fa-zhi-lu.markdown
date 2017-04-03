---
layout: post
title: "一次短暂的mac开发之旅"
date: 2016-10-22 22:43:37 +0800
comments: true
categories: 
---
回杭近一周，发现公司后台写的接口文档还是比较清晰的。特别是自己组负责的业务线，接口文档上的字段和实际返回的字段几乎没有差别。

询问了周围小伙伴如何写模型文件之后，发现无非三种方式：

- 手写啦＝＝
- `Xcode8`以前的用`ESJsonFormat`插件，`Xcode8`以后手写
- 用`JSONExport`生成

针对以上三种方式，我做了一个简短的分析：

- 这个不用说了，耗时费力不讨好。量少好说，量大就比较蛋疼了。
- `xcode8`之后，第三方插件被禁止了。虽说有方法能让`xcode8`重新用上这个插件，但是即使用上了这个插件，还是需要自己写注释，并且生成模型需要后台返回的`json`。
- 和上一个方式一样，只是从插件编程了`mac`软件

在打听完后，我随即产生了自己写一个转换工具的想法。

原因如下：

- 后台文档已经写的比较清晰，可以从网页上把这些数据都爬下来，然后生成含有注释的模型
- 可以自动将`Vo`结尾的模型和属性，转成`Model`结尾的模型和属性，并且生成`YYModel`需要的映射关系
- 因为接口文档都处于一个统一的`baseURL`下，加上模型名称就是完整路径，所以可以很方便地进行批量处理
-  不需要测试后台发布的接口后，再通过获取接口返回的`json`生成模型；只要接口文档一发布就可以生成模型
<!--more-->
然后我花了一个周末的时间，完成了一个简易的模型抓取生成工具。具体界面如下：<br>


![](/images/2016-10-30fetcher.png)

输入浏览公司内部资料所需要的用户名和密码，并且输入自己需要的抓取的模型名，点击开始抓取，然后就等桌面上生成对应的模型文件了。当然，在界面上的预览窗口可以看到生成文件的内容，以及生成文件的保存地址。

话不多说，接下来记录下自己写这个`mac`工具的过程。

###确认要抓取的内容及条件
下面是我根据实际接口样式模拟的一个接口的文档：<br>

![](/images/2016-10-30.png)

总结两点：

- 需要的数据有数字编号或者没有编号（也可以说从第二行开始＝＝）
- 需要的数据在表格的2、3、4行（对应1、2、3索引）

接下来再看下需要抓取内容的HTML:<br>

![](/images/2016-10-30xpath.png)

可以看到，拿到第一个标签为`table`、类名为`confluenceTable`的元素，然后再取第一个标签为`tbody`的元素即可获取所有需要的数据。

最后，查看接口需要在登录状态，所以得在`chrome`的开发者工具中获取登录请求的`URL`和参数。由于接口文档所在服务器搭在公司内网，所以并没有太过复杂的验证，还是比较方便的。

###确定使用的技术
由于对`Python`不是很熟悉，所以还是先使用`swift`来写。选用的框架如下：

- RxSwift
- Ji (HTML解析用)
- Moya

最后说下`mac`开发，我直接采用了`storyboard`的方式。主要是自己以前没有接触过`mac`开发，使用IB能降低难度和开发时间。

###实际开发过程

数据获取解析和软件界面逻辑编写的时间占比大概在7-3左右。<br>

#####数据获取解析
通过`Moya`请求获取`HTML`就不说了，主要记录下如何使用`Ji`来解析`HTML`。
 
获取第一个标签为`table`、类名为`confluenceTable`的元素代码如下：
 
```swift
extension TDFInterfaceFetcherHTMLParser  {
    var firstTableBody: [JiNode]? {
        return firstContentTable.flatMap{ $0.firstChildWithName("tbody")?.children }
    }
    
    private var firstContentTable: JiNode?{
        let lastTable = rootNode?
            .descendantsWithName("table")
            .filter{ $0.attributes["class"] == "confluenceTable" }
            .first
        return lastTable
    }
}
```
 
- `descendantsWithName("table")`可以获取所有标签为`table`的元素
- `JiNode`的`attributes`是标签所有属性的键值对，这里过滤掉`class`不是`confluenceTable`的`JiNode`
- `JiNode`的`firstChildWithName("tbody").children`可以获取子节点中，第一个标签为`tbody`的元素的所有子节点。

得到所有目标子节点后，再通过以下方法获取叶子节点：

```swift
//1、是叶子节点，添加到数组
//2、不是叶子节点，遍历其所有子节点

extension JiNode {
    func allLeafNodes() -> [JiNode] {
        var leafNodes = [JiNode]()
        if !hasChildren {
            leafNodes.append(self)
        } else {
            children.forEach {
                leafNodes.append(contentsOf: $0.allLeafNodes())
            }
        }
        return leafNodes
    }
}
```

接下来通过`JiNode`的`value`属性获取所有叶子节点对应元素的内容就好了：

```swift
firstTableBody.map{ $0.allLeafNodes().flatMap{ $0.value } }
```

经过上面代码的处理，输出的数据如下：

```
["编号", "参数名（中文）", "参数名（英文）", "类型", "对应表", "对应字段", "备注"]
["1", "采购单ID", "id", "String", "purchase_info", "id", "　"]
...

```

OK！后面的事情就相对简单了，主要是结合`Objective-C`的语法以及自身采用的`JSON`转模型框架来对上面的数组进行加工。项目里采用的是YYModel，所以最终输出结果大致如下：

```objc
//======================================	
// TDFPurchaseModel.h 	
//======================================	
#import <Foundation/Foundation.h>	
	
@interface TDFPurchaseModel : NSObject	
/** 采购单ID */	
@property (nonatomic, copy) NSString *id;	
/** 所属实体ID */	
@property (nonatomic, copy) NSString *entityId;	
/** 自实体ID */	
@property (nonatomic, copy) NSString *selfEntityId;	
/** 自实体名称 */	
@property (nonatomic, copy) NSString *selfEntityName;	
/** 供应商Id */	
@property (nonatomic, copy) NSString *supplyId;
......

//======================================	
// TDFPurchaseModel.m 	
//======================================	
#import "TDFPurchaseModel.h"	
@implementation TDFPurchaseModel	
+ (nullable NSDictionary<NSString *, id> *)modelCustomPropertyMapper {	
	return @{	
		@"purchaseDetails" : @"purchaseDetailsVo"	
	};	
}	
@end


```
#####软件界面逻辑编写
`mac`界面的搭建，我主要参考了`JSONExport`。不过对于没有接触过`mac`开发的我来说，直接上手去拖拽控件还是出现了一些问题。

记忆最深的是在`mac`开发中，拖拽到`storyboard`中的控件，其内部可能内置多个子控件。当我直接以`iOS`开发在`storyboard`中拖拽控件的方式设置约束时，就会出现一些问题：

![](/images/Snip20161030_1.png)

这样的约束是针对内部的`NSTextView`设置的，当输入文本超过父控件时，依赖于`NSTextView`高度约束的控件会发生变化。所以应该像下面这样，在侧边栏设置：

![](/images/Snip20161030_3.png)

至于其它，由于只是搭了一个简单的界面，也不好说些啥。不过现在感觉做`iOS`开发的，上手`mac`开发还是相对容易一些。

最后挂下抓取结果图：

![](/images/2016-10-30result.png)
###总结

写这个软件大概花了我一天半的时间，不过应该能给身边的小伙伴省下一些不必要的时间开销，还是挺高兴的。<br>

感觉程序员还是要多思考，不过是对代码还是对业务流程。不能说以前的人这么写，或者这么做了，我就跟着这么做，而不加以思考这样的代码或者流程到底合不合理，是不是正确/最优的做法，否则很难跳出自己的舒适区域。



