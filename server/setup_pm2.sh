#!/usr/bin/env bash

set -e

echo "========================================="
echo "   用户反馈服务 (PM2 方案) 部署安装脚本   "
echo "========================================="

# 1. 检查 Node.js 环境
if ! command -v node &> /dev/null; then
    echo "❌ 未检测到 Node.js，请先安装 Node.js (推荐 v20 或以上版本)！"
    echo "   Ubuntu/Debian 快捷安装建议: curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash - && sudo apt-get install -y nodejs"
    echo "   CentOS/RHEL 快捷安装建议: curl -fsSL https://rpm.nodesource.com/setup_20.x | sudo bash - && sudo yum install -y nodejs"
    exit 1
fi

NODE_VERSION=$(node -v)
echo "✅ 检测到 Node.js: $NODE_VERSION"

# 2. 检查 .env 配置文件
if [ ! -f ".env" ]; then
    if [ -f ".env.example" ]; then
        echo "📝 未找到 .env，正在根据 .env.example 自动生成..."
        cp .env.example .env
        echo "✅ 已生成默认 .env 文件（如需修改端口或管理密码，请手动编辑 .env）"
    fi
fi

# 3. 创建日志和数据目录
mkdir -p logs data

# 4. 安装生产依赖
echo "📦 正在安装依赖包..."
npm ci --omit=dev

# 5. 检查与安装 PM2
if ! command -v pm2 &> /dev/null; then
    echo "⚙️ 未检测到 PM2，正在通过 npm 全局安装 PM2..."
    npm install -g pm2 || sudo npm install -g pm2
fi

echo "✅ PM2 就绪: $(pm2 -v)"

# 6. 使用 PM2 启动或重载服务
echo "🚀 正在启动服务..."
if pm2 describe feedback-server > /dev/null 2>&1; then
    pm2 reload ecosystem.config.js --update-env
    echo "🔄 服务已成功热重载！"
else
    pm2 start ecosystem.config.js
    echo "🎉 服务首次启动成功！"
fi

# 7. 保存进程列表以实现开机自启
pm2 save

echo "========================================="
echo "✅ 部署已完成！"
echo "🌐 本地测试: curl http://localhost:3000"
echo ""
echo "常用 PM2 管理命令:"
echo "  - 查看服务状态:   pm2 status"
echo "  - 查看运行日志:   pm2 logs feedback-server"
echo "  - 重启服务:       pm2 restart feedback-server"
echo "  - 停止服务:       pm2 stop feedback-server"
echo "========================================="
