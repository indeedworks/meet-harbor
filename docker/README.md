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

