---
layout: post
title: "MQTT使用小记"
date: 2016-05-12 17:12:43 +0800
comments: true
categories: mqtt
tags: [Swift,MQTT]
---
MQTT全称Message Queue Telemetry Transport，是一个针对轻量级的发布/订阅式消息传输场景的协议，同时也是被推崇的物联网传输协议。MQTT详细的介绍文章可以从[官方网站](http://mqtt.org/)获得，所以这里就不进行详细的展开了，而是针对这些天的使用经历与感受做一番纪录。

MQTT开源的iOS客户端有以下几种：

```
|MQTTKit  |Marquette|Moscapsule|Musqueteer|MQTT-Client|MqttSDK|CocoaMQTT|
|---------|---------|----------|----------|-----------|-------|---------|
|Obj-C    |Obj-C    |Swift     |Obj-C     |Obj-C      |Obj-C  |Swift    |
|Mosquitto|Mosquitto|Mosquitto |Mosquitto |native     |native |native   |
```
以上开源库我只看过部分MQTTKit、MQTT-Client、CocoaMQTT的开源代码，总体来说MQTT-Client支持的功能更多全面一些。如果只是对协议本身进行学习不考虑功能的话，可以阅读CocoaMQTT，也可以阅读我重写的[SwiftMQTT](https://github.com/tripleCC/SwiftMQTT)，因为代码量相对前面两个库少了很多。

而MQTT的broker一般选择[Mosquitto](http://mosquitto.org/)，Mosquitto是一个由C编写的集客户端和服务端为一体的开源项目，所以相对来说风格较为友好，可以无障碍地阅读并调试源码（[开源地址](https://github.com/eclipse/mosquitto)）。可以看到，以上客户端开源库中的前四种就是基于Mosquitto的一层封装。
<!--more-->

#### Mosquitto的安装和使用
Mosquitto在Linux下的安装相对比Mac-OS简单很多，主要是因为openssl的一些路径问题，后者需要多一些步骤。Mac-OS下可以通过两种方法运行Mosquitto，一种是通过brew命令安装Mosquitto:

```swift
brew install mosquitto
```
安装完成后就可以在mosquitto.conf文件中更改相应的配置了。接着进入根目录（也可以指定$PATH到mosquitto可执行文件的目录），执行以下命令运行mosquitto：

```swift
// -c 读取配置
// -d 后台运行
// -v 打印详细日志
./sbin/mosquitto -c etc/mosquitto/mosquitto.conf -d -v
```
如果要重启mosquitto服务，可以先kill掉，再重启：

```swift
tripleCC:1.4.8 songruiwang$ ps -A | grep mosquitto
55417 ??         0:00.05 ./sbin/mosquitto -c etc/mosquitto/mosquitto.conf -d -v
tripleCC:1.4.8 songruiwang$ kill -9 55417
```

现在要说明的是第二种方式，通过源码编译生成mosquitto可执行文件（好处是可以通过lldb对mosquitto进行调试，能更好地熟悉运行机制）。

下载mosquitto源码后进入根目录，然后执行以下命令：

```swift
// 禁用TLS_PSK，并且声称Debug版本（后续lldb调试需要用到符号表）
// 如果openssl是通过brew进行安装，就需要手动指定OPENSSL_ROOT_DIR和OPENSSL_INCLUDE_DIR环境变量
// 但是后来发现即使指定了，在编译时符号表中还是找不到TLS_PSK相关的函数
cmake -DWITH_TLS_PSK=OFF -DWITH_TLS=OFF -DCMAKE_BUILD_TYPE=Debug 
make install
```
终端会提示无法拷贝可执行文件mosquitto，这个问题无伤大雅。可以手动拷贝到$PATH指定的目录下，也可以直接进入mosquitto所在目录运行：

```swift
tripleCC:src songruiwang$ lldb mosquitto
(lldb) target create "mosquitto"
Current executable set to 'mosquitto' (x86_64).
(lldb) b mqtt3_packet_handle
Breakpoint 1: where = mosquitto`mqtt3_packet_handle + 16 at read_handle.c:36, address = 0x0000000100018eb0
(lldb) r
```
这样当客户端连接到broker时，就可以对mosquitto进行逐行调试了：

```swift
Process 57680 launched: '/Users/songruiwang/Desktop/mosquitto/src/mosquitto' (x86_64)
1463049645: mosquitto version 1.4.8 (build date 2016-05-12 18:36:15+0800) starting
1463049645: Using default config.
1463049645: Opening ipv4 listen socket on port 1883.
1463049645: Opening ipv6 listen socket on port 1883.
1463049659: New connection from 127.0.0.1 on port 1883.
Process 57680 stopped
* thread #1: tid = 0xba449, 0x0000000100018eb0 mosquitto`mqtt3_packet_handle(db=0x000000010002f4f0, context=0x0000000100201990) + 16 at read_handle.c:36, queue = 'com.apple.main-thread', stop reason = breakpoint 1.1
    frame #0: 0x0000000100018eb0 mosquitto`mqtt3_packet_handle(db=0x000000010002f4f0, context=0x0000000100201990) + 16 at read_handle.c:36
   33  	
   34  	int mqtt3_packet_handle(struct mosquitto_db *db, struct mosquitto *context)
   35  	{
-> 36  		if(!context) return MOSQ_ERR_INVAL;
   37  	
   38  		switch((context->in_packet.command)&0xF0){
   39  			case PINGREQ:
(lldb) p *context
(mosquitto) $0 = {
  sock = 6
  protocol = mosq_p_invalid
  address = 0x0000000100200db0 "127.0.0.1"
  id = 0x0000000000000000 <no value available>
  username = 0x0000000000000000 <no value available>
  password = 0x0000000000000000 <no value available>
  keepalive = 60
  last_mid = 0
  state = mosq_cs_new
  last_msg_in = 39584
  last_msg_out = 39584
  ......
```
这里安利一款代码阅读器Understand（和window下的SourceInsight很相似，都很强大！）<br>
lldb很多命令和gdb相似，具体更多命令可以在lldb中执行help进行查看。
更加详细的使用教程可以参考[Mosquitto简要教程（安装/使用/测试）](http://blog.csdn.net/shagoo/article/details/7910598)

#### 使用Wireshark抓取报文
测试时使用的host一般为lo0，即本地回环地址，所以选择对应的过滤器：

![](/images/Snip20160512_2.png)

对端口进行过滤（这里使用的是1883端口）：

![](/images/Snip20160512_3.png)

然后连接客户端和服务端，就可以看见对应的MQTT报文了：

![](/images/Snip20160512_4.png)

在一些linux嵌入式环境下，无法通过Wireshark抓取报文，可以使用tcpdump抓取生成pcap文件，然后使用ftp等协议将文件传回到电脑，再使用Wireshark打开：

```swift
// 这里还是用回环地址举例
tcpdump -i lo0 'tcp port 1883' -s 65535 -w packet.pcap
```
#### MQTT协议的实践
##### MQTT协议消息类型
为了能够更好地熟悉协议，我用struct+protocol的方式重写了CocoaMQTT的代码（[SwiftMQTT](https://github.com/tripleCC/SwiftMQTT)）。CocoaMQTT库使用的是传统的面相对象编程方式，所以阅读起来并没有什么障碍，只不过小小吐槽下代码风格。<br>

MQTT协议总共有14种消息类型，使用枚举表示如下：

```swift
public enum SwiftMQTTMessageType : UInt8 {
    case Connect        = 0x10
    case ConnAck        = 0x20
    case Publish        = 0x30
    case PubAck         = 0x40
    case PubRec         = 0x50
    case PubRel         = 0x60
    case PubComp        = 0x70
    case Subscribe      = 0x80
    case SubAck         = 0x90
    case Unsubscribe    = 0xA0
    case UnsubBack      = 0xB0
    case PingReq        = 0xC0
    case PingResp       = 0xD0
    case Disconnect     = 0xE0
}
```

以上消息可由"固定报头"+"可变报头"+"有效载荷"三部分组成。<br>

固定报头由"类型+标志位"+"剩余长度"组成，可以使用protocol表示第一部分：

```swift
public protocol SwiftMQTTCommandProtocol {
    var command: UInt8 {get set}
    var messageType: SwiftMQTTMessageType {get set}
    var dupFlag: Bool {get set}
    var qosLevel: SwiftMQTTQosLevel {get set}
    var retain: Bool {get set}
}

extension SwiftMQTTCommandProtocol {
    /**
     * +---------------+----------+-----------+--------+
     * |    7 6 5 4    |     3    |    2 1    |   0    |
     * |  Message Type | DUP flag | QoS level | RETAIN |
     * +---------------+----------+-----------+--------+
     */
    public var messageType: SwiftMQTTMessageType {
        get { return SwiftMQTTMessageType(rawValue: command & 0xF0) ?? .Connect }
        set { command = newValue.rawValue | (command & 0x0F) }
    }
    public var dupFlag: Bool {
        get { return Bool((command >> 3) & 0x01) }
        set { command = (UInt8(newValue) << 3) | (command & 0xF7) }
    }
    public var qosLevel: SwiftMQTTQosLevel {
        get { return SwiftMQTTQosLevel(rawValue: (command >> 1) & 0x03) ?? .AtMostOnce }
        set { command = newValue.rawValue << 1 | (command & 0xF9 ) }
    }
    public var retain: Bool {
        get { return Bool(command & 0x01) }
        set { command = UInt8(newValue) | (command & 0xFE) }
    }
}

```
剩余长度等于"可变报头"+"有效载荷"各自的长度相加，这两者表示如下:

```swift
public protocol SwiftMQTTVariableHeaderProtocol {
     var variableHeader: NSData {get}
}

extension SwiftMQTTVariableHeaderProtocol {
    public var variableHeader: NSData { return NSData() }
}

public protocol SwiftMQTTPayloadProtocol {
    var payload: NSData {get}
}

extension SwiftMQTTPayloadProtocol {
    public var payload: NSData { return NSData() }
}
```
为了减少没有这两个部分的消息结构体的代码量，所以协议扩展中先返回空数据。<br>
然后就可以定义并实现一个固定报头的总协议了：

```swift
public protocol SwiftMQTTFixedHeaderProtocol : SwiftMQTTCommandProtocol, SwiftMQTTVariableHeaderProtocol, SwiftMQTTPayloadProtocol {
    var remainingLength: UInt32 {get}
}

extension SwiftMQTTFixedHeaderProtocol {
    public var remainingLength: UInt32 {
        let remainingLength = variableHeader.length + payload.length
        guard remainingLength <= kSwiftMQTTMaxRemainingLength else {
            SMPrint("the size of remaining length field should be below \(kSwiftMQTTMaxRemainingLength).")
            return UInt32(kSwiftMQTTMaxRemainingLength)
        }
        return UInt32(remainingLength)
    }
}
```
有了所有发送消息的组成部分之后，就可以对数据进行编码了：

```swift
public protocol SwiftMQTTMessageProtocol : SwiftMQTTFixedHeaderProtocol {
    var data: NSData {get}
}

extension SwiftMQTTMessageProtocol {
    public var data: NSData {
        let data = NSMutableData()
        data.appendByte(command)
        data.appendData(remainingLength.data)
        data.appendData(variableHeader)
        data.appendData(payload)
        return data
    }
}
```
这里以Connect报文为例，结合以上协议，构成一个有效的消息结构体。<br>
首先让SwiftMQTTConnectMessage遵守SwiftMQTTMessageProtocol协议，以此获得固定报头解析以及编码等能力：

```swift
public struct SwiftMQTTConnectMessage : SwiftMQTTMessageProtocol {
	public var command = UInt8(0x00)
	...
}
```
由于command是固定报头类型和标志的必要载体，所以必须在结构体中实现。那么问题来了，MQTT协议的消息有14种，于是就需要在14种结构体种都实现一次这个成员变量，如果使用面向对象的方式，在公共子类中呈现这个成员变量就行了。这里是第一个让我感觉面向协议方式在实现MQTT不顺手的地方。<br>
Connect报文的可变报头中分为四个部分:协议名，协议级别，连接标志和保持连接。这几个部分可以使用两个协议来实现：

```swift
public protocol SwiftMQTTConnectFlagProtocol {
    var connectFlag: UInt8 {get set}
    var usernameFlag: Bool {get set}
    var passwordFlag: Bool {get set}
    var willRetain: Bool {get set}
    var willQos: SwiftMQTTQosLevel {get set}
    var willFlag: Bool {get set}
    var cleanSession: Bool {get set}
}

extension SwiftMQTTConnectFlagProtocol {
    /**
     * +----------+----------+------------+---------+----------+--------------+----------+
     * |     7    |    6     |      5     |  4  3   |     2    |       1      |     0    |
     * | username | password | willretain | willqos | willflag | cleansession | reserved |
     * +----------+----------+------------+---------+----------+--------------+----------+
     */
    public var usernameFlag: Bool {
        get { return Bool((connectFlag & 0x80) >> 7) }
        set { connectFlag = (UInt8(newValue) << 7) | (connectFlag & 0x7F) }
    }
    public var passwordFlag: Bool {
        get { return Bool((connectFlag & 0x40) >> 6) }
        set { connectFlag = (UInt8(newValue) << 6) | (connectFlag & 0xBF) }
    }
    public var willRetain: Bool {
        get { return Bool((connectFlag & 0x20) >> 5) }
        set { connectFlag = (UInt8(newValue) << 5) | (connectFlag & 0xDF) }
    }
    public var willQos: SwiftMQTTQosLevel {
        get { return SwiftMQTTQosLevel(rawValue: (connectFlag & 0x18) >> 3) ?? .AtMostOnce }
        set { connectFlag = (UInt8(newValue.rawValue) << 3) | (connectFlag & 0xE7) }
    }
    public var willFlag: Bool {
        get { return Bool((connectFlag & 0x08) >> 2) }
        set { connectFlag = (UInt8(newValue) << 2) | (connectFlag & 0xFA) }
    }
    public var cleanSession: Bool {
        get { return Bool((connectFlag & 0x04) >> 1) }
        set { connectFlag = (UInt8(newValue) << 1) | (connectFlag & 0xFD) }
    }
}

protocol SwiftMQTTClientProtocol {
    var protocolName: String {get}
    var protocolLevel: UInt8 {get}
    var keepalive: UInt16 {get}
    var clientId: String {get}
    var account: SwiftMQTTAccount? {get}
    var will: SwiftMQTTWill? {get}
}

extension SwiftMQTTClientProtocol {
    var protocolName: String { return "MQTT" }
    var protocolLevel: UInt8 { return 0x04 }
    var keepalive: UInt16 { return 60 }
}
```
这样Connect报文结构体已经有了所有需要的协议，接下来主要的工作就是实现真正的variableHeader和payload了：

```swift
public var variableHeader: NSData {
    let variableHeader = NSMutableData()
    variableHeader.appendMQTTString(protocolName)
    variableHeader.appendByte(protocolLevel)
    variableHeader.appendByte(connectFlag)
    variableHeader.appendUInt16(keepalive)
    return variableHeader
}
public var payload: NSData {
    let payload = NSMutableData()
    // 客户端标识符->遗嘱主题->遗嘱消息->用户名->密码
    payload.appendMQTTString(clientId)
    if let willTopic = will?.willTopic {
        payload.appendMQTTString(willTopic)
    }
    if let willMessage = will?.willMessage {
        payload.appendMQTTString(willMessage)
    }
    if let username = account?.username {
        payload.appendMQTTString(username)
    }
    if let password = account?.password {
        payload.appendMQTTString(password)
    }
    return payload
}
```
至此，Connect的主要部分都已经构建完成。接下来以ConAck报文为例，实现从broker中返回的报文。<br>
由于需要解析从broker中返回的报文，所以定义一个返回消息类型协议：

```swift
public protocol SwiftMQTTAckMessageProtocol: SwiftMQTTCommandProtocol {
    init?(_ bytes: [UInt8], command: UInt8)
}
```
最终SwiftMQTTConnAckMessage结构体如下：

```swift
public struct SwiftMQTTConnAckMessage : SwiftMQTTAckMessageProtocol {
    public var command = UInt8(0x00)
    public var sessionPresent: Bool
    public var connectReturnCode: SwiftMQTTConnectReturnCode
    public init?(_ bytes: [UInt8], command: UInt8) {
        guard bytes.count == 2 else { return nil }
        sessionPresent = Bool(bytes[0])
        connectReturnCode = SwiftMQTTConnectReturnCode(rawValue: bytes[1]) ?? .Accepted
        self.command = command
    }
}
```
这里又产生了第二个让我不是很舒服的地方：在protocol extension中实现有效的init非常麻烦（暂且不论在protocol extension中实现init的必要性）。下面是一个不完全的实现方式：

```swift
protocol MessageProtocol {
    var messageId : UInt16 { get set }
    init()
    init?(_ bytes: [UInt8])
}

extension Message {
    init?(_ bytes: [UInt8]) {
        guard bytes.count == 2 else { return nil }
        messageId = UInt16(bytes[0]) << 8 + UInt16(bytes[1])
    }
}

struct Message: MessageProtocol {
    var messageId: UInt16
    init() {
        messageId = 0
    }
}
```
为了能在protocol extension实现一个默认的init?(_ bytes: [UInt8])方法，就必须要多定义一个没什么意义的init()方法。这让我直接放弃了这个念头，转而直接在每个消息类型的struct中实现对应的解析init方法，虽然这样会让部分代码重复。<br>
至此，MQTT协议的消息类型实现差不多完成了，因为后续的12种消息和前面这2种大同小异。<br>

##### MQTT协议消息解析
和CocoaMQTT一样，SwiftMQTT也是使用GCDAsyncSocket来进行socket通信。在调用GCDAsyncSocket实例的readData系列方法并读取到数据后，便可以从以下代理方法中解析读取到的数据：

```swift
- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
```
需要注意的是，如果使用的是按照缓存排列每次读取固定子节的方法：

```swift
- (void)readDataToLength:(NSUInteger)length withTimeout:(NSTimeInterval)timeout tag:(long)tag;
```
那么只要有一次读取错误，就会影响到后续所有数据的读取。<br>
解析返回报文的主要方法如下：

```swift
mutating func unpackData(data: NSData, part: SwiftMQTTMessagePart, nextReader:SwiftMQTTMessageDecoderNextReader) {
    let bytes = data.bytesArray
    switch part {
    case .Header:
        messageHeader = unpackHeader(bytes)
        // 读取一个字节的剩余长度
        nextReader(length: 1, part: .Length)
    case .Length:
        messageLengthBytes.appendContentsOf(bytes)
        // 如果最高位为0，则剩余长度已确定
        if Bool(bytes[0] & 0x80) {
            // 继续读取一个字节的剩余长度
            nextReader(length: 1, part: .Length)
        } else {
            // 获取剩余长度
            let messageLength = unpackLength(messageLengthBytes)
            if messageLength > 0 {
                // 读取可变报头和payload
                nextReader(length: messageLength, part: .Content)
            } else {
                // 没有可变报头和payload，不需要再进行读取操作，直接解包
                unpackContent()
            }
            // 重置长度缓存
            messageLengthBytes.removeAll()
        }
    case .Content:
        // 解析可变报头和payload
        unpackContent(bytes)
    }
}
```
报文分三个部分进行读取。需要注意的是读取剩余长度时，需要循环读取一个字节，以便确定剩余长度的最高字节。

#### 小结
最后对比各个协议库，如果需要使用到MQTT的大部分功能，那么阅读Mosquitto源码会是个不错的选择，毕竟其实现的功能还是相对完善的。<br>
而对于这次实践，总感觉有些地方使用面向协议没有面向对象来的更加简洁，不过这也是利弊的权衡吧，还是在可以接受的范围。

#### 参考链接
[MosquittoDocumentation](http://mosquitto.org/documentation/)<br>
[MQTT中文文档](https://mcxiaoke.gitbooks.io/mqtt-cn/content/)<br>
[MQTT英文文档](http://docs.oasis-open.org/mqtt/mqtt/v3.1.1/os/mqtt-v3.1.1-os.html)