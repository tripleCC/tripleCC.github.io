建立在 HTTP 基础上的协议，连接发起方仍是客户端。

- 推送功能
- 减少通信量

#### "握手”建立过程

- 建立 HTTP 连接
- 发送握手请求，包含 Upgrade 首部字段，告知服务器协议变更为 websocket （要指定 Connection 字段为 Upgrade ，表示 Upgrade 字段不转发给代理，第一个接收的服务器会会删除 Upgrade 字段再进行转发）
- 响应握手请求，服务器返回状态码 101 switching protocols 响应
- 发送数据，使用 WebSocket 独立的数据帧，不再使用 HTTP 数据帧



