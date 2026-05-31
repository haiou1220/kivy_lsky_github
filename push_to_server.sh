#!/bin/bash
# =====================================================
# 脚本名称：push_to_server.sh
# 功能描述：将本地项目修改上传到云服务器（推送）
# 
# 使用前必须：
#   1. 在同目录下创建 rsync_config.env 文件
#   2. 根据你的实际环境填写该文件中的变量
#   3. 确保已配置 SSH 免密登录（或运行时会提示输入密码）
# =====================================================

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/rsync_config.env"

# 检查配置文件
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

# 加载配置
source "$CONFIG_FILE"

# 验证必要变量
if [ -z "$SERVER_USER" ] || [ -z "$SERVER_IP" ] || [ -z "$SERVER_PATH" ] || [ -z "$LOCAL_PATH" ]; then
    echo "错误：配置文件 rsync_config.env 中缺少必要的变量定义！"
    echo "请确保定义了：SERVER_USER, SERVER_IP, SERVER_PATH, LOCAL_PATH"
    exit 1
fi

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 检查 rsync
if ! command -v rsync &> /dev/null; then
    echo -e "${RED}错误：rsync 未安装。请先安装：sudo apt install rsync${NC}"
    exit 1
fi

# 检查本地目录
if [ ! -d "$LOCAL_PATH" ]; then
    echo -e "${RED}错误：本地目录不存在：$LOCAL_PATH${NC}"
    exit 1
fi

# rsync 参数（与拉取相同，排除配置文件自身）
RSYNC_OPTS="-avz --delete --progress --exclude='.git' --exclude='.buildozer' --exclude='venv' --exclude='__pycache__' --exclude='*.pyc' --exclude='.DS_Store' --exclude='rsync_config.env'"

echo -e "${GREEN}开始将本地修改推送到服务器...${NC}"
echo -e "源：${LOCAL_PATH}/"
echo -e "目标：${SERVER_USER}@${SERVER_IP}:${SERVER_PATH}/"
echo ""

# 执行推送
rsync $RSYNC_OPTS -e ssh ${LOCAL_PATH}/ ${SERVER_USER}@${SERVER_IP}:${SERVER_PATH}/

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ 推送完成！服务器项目已更新。${NC}"
    echo -e "${YELLOW}提醒：若需要重新打包 APK，请在服务器上执行 buildozer android debug${NC}"
else
    echo -e "${RED}❌ 推送失败，请检查网络、SSH 连接及路径是否正确。${NC}"
    exit 1
fi