# 使用轻量级 Node 22 Alpine 镜像（内置稳定原生 SQLite）
FROM node:22-alpine

# 设置工作目录
WORKDIR /app

# 设置生产环境变量
ENV NODE_ENV=production
ENV PORT=3000

# 复制依赖定义文件
COPY package*.json ./

# 安装生产依赖
RUN npm ci --omit=dev

# 复制源代码及静态资源
COPY server.js db.js ./
COPY public ./public
COPY .env.example ./.env

# 创建数据挂载目录
RUN mkdir -p /app/data

# 暴露服务端口
EXPOSE 3000

# 启动服务
CMD ["node", "server.js"]
