# FreeMan

这是一份来自其他项目的改造项目，原因是原来的项目已经不在维护升级。

原项目：[transponder](https://gitee.com/stlswm/transponder.git)

### 介绍

工具分两个部分，内网部分和外网部分，内外网部分通过TCP连接，外网是server，内网是client。独立使用各自的配置文件`inner.config.json`和`outer.config.json`。

工具主要解决一个问题，内网服务需要暴露给外网使用，但内网服务没有独立的外网ip。通过p2p中继方式转发外网请求至内部服务。

### 配置

```json
/* inner.config.json*/
{
  // 转发流量的外网服务地址
  "RegisterAddress": "tcp://120.0.0.1:9090",
  // 被代理的真实内网服务地址
  "ProxyAddress": "tcp://127.0.0.1:80",
  // 连接认证密码
  "AuthKey": "123456",
  // 常驻可用空闲连接
  "MaxFreeConn": 50
}
```

```json
// outer.config.json
{
  // 暴露给内网的流量转发服务地址
  "InnerServerAddress": "tcp://0.0.0.0:9090",
  // 暴露给外网访问的代理地址
  "OuterServerAddress": "tcp://127.0.0.1:8000",
  // 连接认证密码
  "AuthKey": "123456"
}
```

