#!/bin/bash
# =====================================================
# 脚本名称：push_to_server.sh
# 功能描述：将本地指定的文件上传到云服务器（仅同步以下文件）
#           使用单个 rsync 进程，只建立一个 SSH 连接，避免重复输入密码
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

# 创建临时文件列表（本地文件必须存在）
TEMP_FILE_LIST=$(mktemp)
for file in "${FILES[@]}"; do
    if [ -f "$LOCAL_PATH/$file" ]; then
        echo "$file" >> "$TEMP_FILE_LIST"
    else
        echo -e "${YELLOW}警告：本地文件 $file 不存在，已跳过。${NC}"
    fi
done

echo -e "${GREEN}开始将本地指定文件推送到服务器（单次连接）...${NC}"
rsync -avz --files-from="$TEMP_FILE_LIST" -e ssh \
    "$LOCAL_PATH/" \
    "${SERVER_USER}@${SERVER_IP}:${SERVER_PATH}/"

RSYNC_EXIT=$?
rm -f "$TEMP_FILE_LIST"

if [ $RSYNC_EXIT -eq 0 ]; then
    echo -e "${GREEN}✅ 推送完成。${NC}"
else
    echo -e "${RED}❌ 推送失败。${NC}"
    exit 1
fi