#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
cd "$SCRIPT_DIR"

die() { echo "错误：$*" >&2; exit 1; }
command -v docker >/dev/null 2>&1 || die "请先安装 Docker Engine。"
docker compose version >/dev/null 2>&1 || die "请先安装 Docker Compose 插件。"
docker info >/dev/null 2>&1 || die "Docker 未运行或当前用户无访问权限。"
[ -f sql/postgresql/init.sql ] || die "缺少 sql/postgresql/init.sql。"

random_hex() {
  bytes=$1
  if command -v openssl >/dev/null 2>&1; then
    value=$(openssl rand -hex "$bytes") || die "随机密钥生成失败。"
  else
    value=$(od -An -N "$bytes" -tx1 /dev/urandom | tr -d ' \n') || die "随机密钥生成失败。"
  fi
  [ "${#value}" -eq "$((bytes * 2))" ] || die "随机密钥长度异常。"
  case "$value" in *[!0-9a-f]*) die "随机密钥格式异常。" ;; esac
  printf '%s' "$value"
}

if [ ! -e .env ] && [ ! -L .env ]; then
  [ -f .env.example ] || die "缺少 .env.example，无法初始化配置。"
  umask 077
  postgres_password=$(random_hex 24)
  redis_password=$(random_hex 24)
  livekit_key="lk_$(random_hex 8)"
  livekit_secret=$(random_hex 32)
  jwt_secret=$(random_hex 32)
  admin_password=$(random_hex 12)
  env_tmp=$(mktemp "$SCRIPT_DIR/.env.init.XXXXXX")
  trap 'rm -f "$env_tmp"' EXIT
  trap 'exit 1' HUP INT TERM
  sed \
    -e "s|^POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=$postgres_password|" \
    -e "s|^REDIS_PASSWORD=.*|REDIS_PASSWORD=$redis_password|" \
    -e "s|^LIVEKIT_API_KEY=.*|LIVEKIT_API_KEY=$livekit_key|" \
    -e "s|^LIVEKIT_API_SECRET=.*|LIVEKIT_API_SECRET=$livekit_secret|" \
    -e "s|^JWT_SECRET=.*|JWT_SECRET=$jwt_secret|" \
    -e "s|^ADMIN_PASSWORD=.*|ADMIN_PASSWORD=$admin_password|" \
    .env.example > "$env_tmp"
  # 原子发布，不覆盖并发启动时已创建的配置。
  ln "$env_tmp" .env || die ".env 已被其他进程创建，请重新运行脚本。"
  rm -f "$env_tmp"
  trap - EXIT HUP INT TERM
  echo "已从 .env.example 生成 .env，随机凭据已写入，权限为 600。"
  echo "PUBLIC_HOST 沿用模板，请确认它是客户端可访问的服务器地址。"
else
  [ -f .env ] || die ".env 不是有效的配置文件。"
  echo "复用已有 .env，不更改现有密码和密钥。"
fi

if grep -q 'replace-with-' .env; then
  die ".env 中仍有凭据占位值，请全部替换后再启动。"
fi
chmod 600 .env

compose() { docker compose --env-file .env -f compose.yml "$@"; }
compose config --quiet

# 每个分类目录可放一个合并包，也可放多个单镜像包。
for category in base backend admin-web; do
  for archive in "images/$category/"*.tar "images/$category/"*.tar.gz "images/$category/"*.tgz; do
    [ -f "$archive" ] || continue
    echo "导入镜像包：$archive"
    docker load -i "$archive"
  done
done

# 导入后检查全部镜像，缺少时禁止拉取或启动不完整的服务栈。
images=$(compose config --images)
[ -n "$images" ] || die "Compose 未解析出镜像。"
for image in $images; do
  docker image inspect "$image" >/dev/null 2>&1 ||
    die "缺少镜像 $image；请补充镜像包，或核对 .env 中的应用镜像名称。"
done

compose up -d --pull never --no-build --wait --wait-timeout 180
compose ps
echo "离线部署已启动。访问地址和管理员初始凭据见 .env。"
