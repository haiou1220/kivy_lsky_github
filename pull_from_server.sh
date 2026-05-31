#!/bin/bash
# =====================================================
# 脚本名称：pull_from_server.sh
# 功能描述：从云服务器拉取指定的文件到本地（仅同步以下文件）
#           不会删除本地其他文件，也不会同步其他文件
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

# 验证必要变量
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

# 检查 rsync
if ! command -v rsync &> /dev/null; then
    echo -e "${RED}错误：rsync 未安装。${NC}"
    exit 1
fi

# 确保本地目录存在
mkdir -p "$LOCAL_PATH"

echo -e "${GREEN}开始从服务器拉取指定文件...${NC}"
for file in "${FILES[@]}"; do
    # 源路径（服务器端文件）
    SRC="${SERVER_USER}@${SERVER_IP}:${SERVER_PATH}/${file}"
    # 目标路径（本地文件）
    DEST="${LOCAL_PATH}/${file}"
    echo "同步: $file"
    rsync -avz -e ssh "$SRC" "$DEST"
    if [ $? -ne 0 ]; then
        echo -e "${YELLOW}警告：$file 同步失败（可能服务器上不存在）${NC}"
    fi
done

echo -e "${GREEN}✅ 拉取完成。${NC}"