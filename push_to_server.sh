#!/bin/bash
# =====================================================
# 脚本名称：push_to_server.sh
# 功能描述：将本地指定的文件上传到云服务器（仅同步以下文件）
#           不会删除服务器其他文件，也不会同步其他文件
# 同步文件列表：
#   README.md, lsky.kv, main.py, buildozer.spec,
#   lsky_config.py, wqy-microhei.ttc,
#   pull_from_server.sh, push_to_server.sh
# =====================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/rsync_config.env"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "错误：配置文件 rsync_config.env 不存在！请先创建。"
    exit 1
fi

source "$CONFIG_FILE"

if [ -z "$SERVER_USER" ] || [ -z "$SERVER_IP" ] || [ -z "$SERVER_PATH" ] || [ -z "$LOCAL_PATH" ]; then
    echo "错误：配置文件缺少变量。"
    exit 1
fi

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 要同步的文件列表（相对于项目根目录）
FILES=(
    "README.md"
    "lsky.kv"
    "main.py"
    "buildozer.spec"
    "lsky_config.py"
    "wqy-microhei.ttc"
    "pull_from_server.sh"
    "push_to_server.sh"
)

if ! command -v rsync &> /dev/null; then
    echo -e "${RED}错误：rsync 未安装。${NC}"
    exit 1
fi

if [ ! -d "$LOCAL_PATH" ]; then
    echo -e "${RED}错误：本地目录不存在：$LOCAL_PATH${NC}"
    exit 1
fi

echo -e "${GREEN}开始将本地指定文件推送到服务器...${NC}"
for file in "${FILES[@]}"; do
    SRC="${LOCAL_PATH}/${file}"
    DEST="${SERVER_USER}@${SERVER_IP}:${SERVER_PATH}/${file}"
    if [ -f "$SRC" ]; then
        echo "同步: $file"
        rsync -avz -e ssh "$SRC" "$DEST"
    else
        echo -e "${YELLOW}跳过：本地文件 $file 不存在${NC}"
    fi
done

echo -e "${GREEN}✅ 推送完成。${NC}"