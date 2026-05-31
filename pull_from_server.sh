#!/bin/bash
# =====================================================
# 脚本名称：pull_from_server.sh
# 功能描述：从云服务器拉取指定的文件到本地（仅同步以下文件）
#           不会删除本地其他文件，也不会同步其他文件
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

# 要同步的文件列表（相对于项目根目录，注意去重）
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

# 创建临时文件，保存需要同步的文件列表（相对路径）
TEMP_FILE_LIST=$(mktemp)
for file in "${FILES[@]}"; do
    echo "$file" >> "$TEMP_FILE_LIST"
done

echo -e "${GREEN}开始从服务器拉取指定文件（单次连接）...${NC}"
# 使用 --files-from 从临时文件读取文件列表
# 注意：源路径末尾的斜杠很重要，表示拷贝文件列表中的文件到目标目录
rsync -avz --files-from="$TEMP_FILE_LIST" -e ssh \
    "${SERVER_USER}@${SERVER_IP}:${SERVER_PATH}/" \
    "$LOCAL_PATH/"

RSYNC_EXIT=$?
rm -f "$TEMP_FILE_LIST"

if [ $RSYNC_EXIT -eq 0 ]; then
    echo -e "${GREEN}✅ 拉取完成。${NC}"
else
    echo -e "${RED}❌ 拉取失败，请检查网络或文件是否在服务器上存在。${NC}"
    exit 1
fi