#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ENV_FILE="$SCRIPT_DIR/.env"
COMPOSE_FILE="$SCRIPT_DIR/compose.yml"

usage() {
  cat <<'EOF'
用法：
  ./update-public-host.sh [公网 IP、域名或完整 URL]

示例：
  ./update-public-host.sh 47.93.100.194
  ./update-public-host.sh meeting.example.com
  ./update-public-host.sh https://meeting.example.com

不传参数时，脚本会交互式询问新地址。
输入 https:// 会同时启用 HTTPS 和 WSS；输入 http:// 会使用 HTTP 和 WS。
EOF
}

die() {
  echo "错误：$*" >&2
  exit 1
}

set_env_value() {
  key=$1
  value=$2
  temp_file="${ENV_FILE}.tmp.$$"

  awk -v key="$key" -v value="$value" '
    BEGIN { found = 0 }
    index($0, key "=") == 1 {
      print key "=" value
      found = 1
      next
    }
    { print }
    END {
      if (!found) print key "=" value
    }
  ' "$ENV_FILE" > "$temp_file"
  chmod 600 "$temp_file"
  mv "$temp_file" "$ENV_FILE"
}

case "${1:-}" in
  -h|--help)
    usage
    exit 0
    ;;
esac

[ -f "$ENV_FILE" ] || die "未找到 docker/.env，请先运行 docker/install.sh 完成初始化。"
command -v docker >/dev/null 2>&1 || die "未找到 Docker。"
docker compose version >/dev/null 2>&1 || die "未安装 Docker Compose 插件。"

input=${1:-}
if [ -z "$input" ]; then
  printf '请输入新的公网 IP、域名或完整 URL：'
  IFS= read -r input
fi

input=$(printf '%s' "$input" | tr -d '[:space:]')
[ -n "$input" ] || die "入口地址不能为空。"

public_scheme=""
livekit_scheme=""
case "$input" in
  https://*)
    public_scheme=https
    livekit_scheme=wss
    host=${input#https://}
    ;;
  http://*)
    public_scheme=http
    livekit_scheme=ws
    host=${input#http://}
    ;;
  *://*)
    die "只支持 http:// 或 https://，也可以直接输入 IP/域名。"
    ;;
  *)
    host=$input
    public_scheme=$(sed -n 's/^PUBLIC_SCHEME=//p' "$ENV_FILE" | tail -n 1)
    livekit_scheme=$(sed -n 's/^LIVEKIT_PUBLIC_SCHEME=//p' "$ENV_FILE" | tail -n 1)
    public_scheme=${public_scheme:-http}
    livekit_scheme=${livekit_scheme:-ws}
    ;;
esac

# PUBLIC_HOST 只保存主机名或 IP；端口由 docker/.env 中对应端口项管理。
host=${host%%/*}
case "$host" in
  ""|*[!A-Za-z0-9._:-]*) die "地址包含不支持的字符：$host" ;;
esac

set_env_value PUBLIC_HOST "$host"
set_env_value PUBLIC_SCHEME "$public_scheme"
set_env_value LIVEKIT_PUBLIC_SCHEME "$livekit_scheme"

docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" config >/dev/null

echo "正在应用新的公网入口地址……"
docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" \
  up -d --force-recreate livekit backend admin-web

backend_port=$(sed -n 's/^BACKEND_PORT=//p' "$ENV_FILE" | tail -n 1)
livekit_port=$(sed -n 's/^LIVEKIT_HTTP_PORT=//p' "$ENV_FILE" | tail -n 1)
backend_port=${backend_port:-8080}
livekit_port=${livekit_port:-7880}

echo
echo "修改完成："
echo "  后端入口：${public_scheme}://${host}:${backend_port}"
echo "  LiveKit： ${livekit_scheme}://${host}:${livekit_port}"
echo
echo "客户端的“服务端地址”请填写：${public_scheme}://${host}:${backend_port}"
