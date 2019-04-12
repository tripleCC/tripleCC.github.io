### TCP 三次握手 四次挥手

三次握手

- 信道不可靠，但是通信双方需要就某个问题达成一致，要解决这个问题，三次通信时理论上的最小值，三次握手不是 TCP 本身要求，而是为了满足 **“在不可靠信道上可靠地传输信息”**这一要求所导致的。

四次挥手

- TCP 是全双工的，需要有两次请求断开-确认的步骤来确认客户端->服务端、服务端->客户端的连接断开，FIN 和 ACK 分开是考虑到服务端可能还需要给客户端发送数据，三次握手把其中一次的 SYN 和 ACK 合并了。

ISN: 初始序列号，握手同步的就是 ISN



![Snip20190328_5](https://github.com/tripleCC/tripleCC.github.io/raw/hexo/source/images/Snip20190412_4.png)

### 四次挥手为什么要发送最后一次 ACK 

> 客户端在收到服务端 ACK 后，断开客户端->服务端的连接。（FIN_WAIT_2）
>
>  服务端在发送 FIN 后，断开服务端->客户端的连接。（LAST_ACK）

确保客户端收到服务端发送的 FIN 包，进入 TIME_WAIT 状态，如果客户端没有收到，可能一直挂在 FIN_WAIT_2 状态，这时候服务端就需要继续发送 FIN包，知道客户端确认收到或者超时。

### 为什么 TIME_WAIT 超时要 2MSL （max segments lifetime）在 CLOSED

> MSL: 报文在网络中能存活的最长时间

确保最后一个 ACK 到达后再 CLOSED

### 资料

[**TCP Connection Termination** ](<http://www.tcpipguide.com/free/t_TCPConnectionTermination-2.htm>)

[TCP连接的建立和关闭详解](<https://anonymalias.github.io/2017/04/07/tcp-create-close-note/>)

