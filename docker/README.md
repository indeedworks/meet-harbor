# Docker 一键部署

支持 Linux 和 macOS。需要 Docker Engine 24+ 或 Docker Desktop，以及 Docker Compose 插件。

## 一键安装全部服务

```bash
./docker/install.sh
```

脚本会自动检测局域网 IPv4、生成数据库/Redis/LiveKit/JWT 密钥和管理员初始密码，然后构建并启动 PostgreSQL、Redis、LiveKit、Spring Boot 后端和 Vue 管理后台。

如果自动检测的地址不正确，可在首次运行前指定：

```bash
PUBLIC_HOST=192.168.1.10 ./docker/install.sh
```

生成的 `docker/.env` 含真实密钥，禁止提交 GitHub。修改端口、域名或密钥后，可再次执行安装脚本更新容器。

## 地址配置

`docker/.env` 中的 `PUBLIC_HOST` 必须是会议客户端能够访问的服务器 IP 或域名，不要包含协议和端口：

```dotenv
PUBLIC_HOST=47.93.100.194
```

`docker/compose.yml` 使用该值为后端设置：

```text
LIVEKIT_URL=ws://${PUBLIC_HOST}:${LIVEKIT_HTTP_PORT}
LIVEKIT_INTERNAL_URL=ws://livekit:7880
```

- `LIVEKIT_URL` 会通过加入会议接口返回给外部客户端，必须使用公网可达地址。
- `LIVEKIT_INTERNAL_URL` 只供后端容器调用 LiveKit 控制接口，不应改成公网地址。
- 云服务器自动检测到的地址可能是 VPC 内网地址。若出现 `172.17.x.x`、`10.x.x.x` 或 `192.168.x.x`，请改为公网 IP 或域名。
- 已存在的 `.env` 不会被安装脚本覆盖，必须直接修改文件并重建相关容器。

```bash
sed -i 's/^PUBLIC_HOST=.*/PUBLIC_HOST=你的公网IP或域名/' docker/.env

docker compose --env-file docker/.env -f docker/compose.yml \
  up -d --force-recreate livekit backend
```

检查最终生效值：

```bash
grep '^PUBLIC_HOST=' docker/.env

docker compose --env-file docker/.env -f docker/compose.yml \
  exec backend printenv LIVEKIT_URL

docker compose --env-file docker/.env -f docker/compose.yml \
  logs livekit | grep 'starting LiveKit server' | tail -1
```

## 常用命令

```bash
docker compose --env-file docker/.env -f docker/compose.yml ps
docker compose --env-file docker/.env -f docker/compose.yml logs -f
docker compose --env-file docker/.env -f docker/compose.yml down
```

升级源码后重新构建：

```bash
docker compose --env-file docker/.env -f docker/compose.yml up -d --build
```

删除数据库、Redis 和录制等全部持久化数据（不可恢复）：

```bash
docker compose --env-file docker/.env -f docker/compose.yml down -v
```

公网部署还需要配置域名、TLS/WSS、防火墙和 TURN；当前配置面向单机或局域网快速部署。防火墙至少需放行 TCP 8080、8088、7880、7881，以及 UDP 50000-50100（端口可在 `.env` 修改）。
