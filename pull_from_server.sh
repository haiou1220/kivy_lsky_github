#!/bin/bash
# =====================================================
# 脚本名称：pull_from_server.sh
# 功能描述：从云服务器拉取项目最新内容到本地（下载）
# 
# 使用前必须：
#   1. 在同目录下创建 rsync_config.env 文件
#   2. 根据你的实际环境填写该文件中的变量
#   3. 确保已配置 SSH 免密登录（或运行时会提示输入密码）
# =====================================================

# 获取脚本所在目录（支持软链接）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/rsync_config.env"

# 检查配置文件是否存在
if [ ! -f "$CONFIG_FILE" ]; then
    echo "错误：配置文件 rsync_config.env 不存在！"
    echo "请参考以下内容创建配置文件："
    echo "========================================="
    echo '# 云服务器登录用户名'
    echo 'SERVER_USER="your_username"'
    echo '# 云服务器公网 IP 或域名'
    echo 'SERVER_IP="your.server.ip"'
    echo '# 服务器端项目路径（绝对路径）'
    echo 'SERVER_PATH="/home/your_username/kivy_lsky_github"'
    echo '# 本地项目路径'
    echo 'LOCAL_PATH="$HOME/kivy_lsky_github"'
    echo "========================================="
    exit 1
fi

# 加载配置文件
source "$CONFIG_FILE"

# 检查必要变量是否已定义
if [ -z "$SERVER_USER" ] || [ -z "$SERVER_IP" ] || [ -z "$SERVER_PATH" ] || [ -z "$LOCAL_PATH" ]; then
    echo "错误：配置文件 rsync_config.env 中缺少必要的变量定义！"
    echo "请确保定义了：SERVER_USER, SERVER_IP, SERVER_PATH, LOCAL_PATH"
    exit 1
fi

# 颜色输出定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 检查 rsync 是否安装
if ! command -v rsync &> /dev/null; then
    echo -e "${RED}错误：rsync 未安装。请先安装：sudo apt install rsync${NC}"
    exit 1
fi

# 创建本地目录（如果不存在）
if [ ! -d "$LOCAL_PATH" ]; then
    echo -e "${YELLOW}本地目录不存在，正在创建：$LOCAL_PATH${NC}"
    mkdir -p "$LOCAL_PATH"
fi

# rsync 参数说明：
# -a  归档模式，保留权限、时间戳等
# -v  详细输出
# -z  压缩传输
# --delete  删除本地有而服务器上没有的文件（使两边完全一致）
# --progress 显示传输进度
# --exclude 排除不需要同步的目录/文件
RSYNC_OPTS="-avz --delete --progress --exclude='.git' --exclude='.buildozer' --exclude='venv' --exclude='__pycache__' --exclude='*.pyc' --exclude='.DS_Store' --exclude='rsync_config.env'"

echo -e "${GREEN}开始从服务器拉取更新...${NC}"
echo -e "源：${SERVER_USER}@${SERVER_IP}:${SERVER_PATH}/"
echo -e "目标：${LOCAL_PATH}/"
echo ""

# 执行拉取（注意源路径末尾的斜杠）
rsync $RSYNC_OPTS -e ssh ${SERVER_USER}@${SERVER_IP}:${SERVER_PATH}/ ${LOCAL_PATH}/

# 检查执行结果
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ 拉取完成！本地项目已与服务器同步。${NC}"
else
    echo -e "${RED}❌ 拉取失败，请检查：${NC}"
    echo "  1. 网络连接是否正常"
    echo "  2. SSH 能否免密登录（或密码是否正确）"
    echo "  3. 服务器路径是否正确（绝对路径）"
    exit 1
fi