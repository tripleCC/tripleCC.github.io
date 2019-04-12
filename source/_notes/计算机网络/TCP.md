### TCP 三次握手 四次挥手

三次握手

- 信道不可靠，但是通信双方需要就某个问题达成一致，要解决这个问题，三次通信时理论上的最小值，三次握手不是 TCP 本身要求，而是为了满足 **“在不可靠信道上可靠地传输信息”**这一要求所导致的。

四次挥手

- TCP 是全双工的，需要有两次请求断开-确认的步骤来确认客户端->服务端、服务端->客户端的连接断开，FIN 和 ACK 分开是考虑到可能 服务端还需要给客户端发送数据，三次握手把其中一次的 SYN 和 ACK 合并了。

ISN: 初始序列号，握手同步的就是 ISN



![Snip20190328_5](https://github.com/tripleCC/tripleCC.github.io/raw/hexo/source/images/Snip20190412_4.png)

### 资料

[**TCP Connection Termination** ](<http://www.tcpipguide.com/free/t_TCPConnectionTermination-2.htm>)



