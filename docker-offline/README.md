# 免源码离线部署包

本目录可以独立复制到服务器，不依赖上级目录或 sources 源码。包含部署配置和数据库初始化 SQL；镜像包由部署人员放入 images。适用于全新部署，不包含原服务器的数据卷。

## 镜像放置位置

```text
docker-offline/
├── compose.yml
├── .env.example
├── .env                       # 首次启动自动生成，不提交 Git
├── start.sh
├── sql/postgresql/init.sql
└── images/
    ├── base/                  # 4 个基础镜像，可合成一个 tar
    ├── backend/               # Java 后端成品镜像
    └── admin-web/             # 管理前端成品镜像
```

脚本读取这三个目录直属的 `.tar`、`.tar.gz`、`.tgz` 文件，文件名不限。不要同时放同一镜像的多个不同版本包，以免导入时覆盖标签。镜像包已通过本目录 `.gitignore` 排除，但仍可随部署目录一起用 tar 打包。

| 目录 | 必需镜像 |
| --- | --- |
| images/base/ | postgres:16-alpine |
| images/base/ | redis:7-alpine |
| images/base/ | livekit/livekit-server:v1.12.0 |
| images/base/ | livekit/egress:v1.9.0 |
| images/backend/ | remote-meeting-stack-backend:local |
| images/admin-web/ | remote-meeting-stack-admin-web:local |

在已有镜像的服务器执行以下命令，随后将三个文件放入对应目录：

```sh
docker save -o base-images.tar postgres:16-alpine redis:7-alpine livekit/livekit-server:v1.12.0 livekit/egress:v1.9.0
docker save -o backend.tar remote-meeting-stack-backend:local
docker save -o admin-web.tar remote-meeting-stack-admin-web:local
```

最终后端镜像已含 JRE 和 JAR，前端镜像已含 Nginx 和静态页面，不需要另外准备构建基础镜像或 Maven/npm 依赖。

## 配置和启动

PostgreSQL 服务设置了 `security_opt: [seccomp=unconfined]`，用于兼容已验证存在初始化写入 EPERM 问题的 CentOS 7 / Docker 26.1.4 / Alpine 3.24.1 组合。该设置仅关闭 PostgreSQL 容器的 seccomp 系统调用过滤，不等同于 privileged，也不改变其他服务的安全策略。通常可在其他 Linux Docker 环境运行，但会减少一层隔离保护；在现代宿主环境验证默认策略能正常初始化和运行后，可以移除此设置。组织的容器安全策略可能禁止 unconfined。

目标 Linux 服务器需提前安装 Docker Engine 和支持 `up --wait` 的 Compose v2 插件，并启动 Docker。镜像架构必须匹配目标服务器；预留镜像包、导入镜像和录制数据所需磁盘空间。本包不包含 Docker 安装程序。

```sh
cd docker-offline
# 首次部署先在模板中设置 PUBLIC_HOST
vi .env.example
sh start.sh
```

- `PUBLIC_HOST`：填写客户端可达的服务器 IP 或域名，不带协议、路径或端口，不能保留远程客户端无法访问的 127.0.0.1。
- 缺少 `.env` 时，脚本从模板自动生成配置，替换 PostgreSQL、Redis、LiveKit API key/secret、JWT secret 和管理员密码，权限为 600。优先使用 OpenSSL，无 OpenSSL 时使用 `/dev/urandom`。其他配置沿用模板，初始管理员密码在 `.env` 的 `ADMIN_PASSWORD` 中查看。
- 已有 `.env` 时保留原配置，不重新生成凭据；若仍含占位值则报错退出。已有数据卷时不要删除 `.env` 来重置密码，因为数据库中的密码不会随新配置改变。
- `BACKEND_IMAGE`、`ADMIN_WEB_IMAGE`：与导入的成品镜像标签一致，默认匹配目前准备的镜像。
- `PROJECT_NAME`：默认 `remote-meeting-offline`，与源码部署的默认项目名区分；它控制容器、网络和数据卷命名，不改变镜像名。同一服务器的端口仍可能冲突，需停用旧部署或调整端口。不要在已部署后随意更改项目名，否则会使用另一组数据卷。
- 默认 TCP 端口为 8088、8080、7880、7881，媒体 UDP 为 50000–50100，按实际配置放通；本配置本身不提供 HTTPS/WSS 证书终止。

脚本校验配置、导入镜像包、检查六个镜像均存在，再禁止拉取和构建地启动。重跑会重新导入现有包，保留命名数据卷。若镜像已导入，可移走镜像包后重跑。健康检查通过不代表录制和跨网音视频已验证，应使用客户端进行实际会议和录制验收。

## 运维和打包

在本目录执行：

```sh
docker compose --env-file .env -f compose.yml ps
docker compose --env-file .env -f compose.yml logs --tail=100 backend
docker compose --env-file .env -f compose.yml up -d --pull never --no-build
docker compose --env-file .env -f compose.yml down
```

`down` 保留数据卷；不要添加 `-v`，否则会删除本部署的数据卷。初始化 SQL 仅在 PostgreSQL 空数据目录首次启动时执行；更新 SQL 不会自动迁移已有数据库。修改 .env 的数据库密码也不会自动修改已初始化数据库中的密码。

在项目根目录打包通用交付包（不带真实环境凭据）：

```sh
tar --exclude='docker-offline/.env' -czf docker-offline.tar.gz docker-offline/
```

接收方解压、在 `.env.example` 中设置服务器地址后运行 `sh start.sh`。无需附带原 `docker/install.sh`（它会构建源码），也无需项目 sources 目录。Java JAR 和前端 JavaScript 仍属于运行镜像的一部分；免源码部署不代表这些产物不可查看。

维护此部署副本时，应同步原 docker/compose.yml 的运行配置和 sql/postgresql/init.sql 的数据库结构；本副本必须保持无 build、无上级目录挂载。
