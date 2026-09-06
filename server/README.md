# 用户反馈服务 (Feedback Server)

基于 **Node.js + Express + SQLite (better-sqlite3)** 构建的轻量级、自包含用户意见与反馈服务。

包含两大部分：
1. **用户端页面 & API**：供用户在网页端或直接通过 App (iOS/Android) 提交反馈与建议，无需注册。
2. **管理后台 & API**：供管理员登录、查看反馈列表、搜索、筛选处理状态、添加跟进备注、导出数据。

---

## 快速启动

### 1. 安装依赖

进入 `server` 目录后运行：

```bash
cd server
npm install
```

### 2. 启动服务

```bash
# 启动生产服务
npm start

# 或开发热重载模式 (Node 18+)
npm run dev
```

启动成功后，控制台会输出：
- 🌐 用户反馈页面：`http://localhost:3000`
- 🛡️ 管理后台地址：`http://localhost:3000/admin`
- 🔑 默认后台账号：`admin`
- 🔑 默认后台密码：`admin123`

---

## 📦 打包与远程服务器部署

本项目已预配置好 **一键打包** 与 **Docker 容器化** / **PM2** 两种部署方案。

### 步骤 1：本地一键打包

在本地项目的 `server` 目录下执行：

```bash
npm run package
```

执行后会在当前目录下生成轻量级部署压缩包：`feedback-server.tar.gz`（体积仅 ~30KB，已排除冗余的 `node_modules` 与本地开发数据）。

---

### 步骤 2：上传到远程服务器

通过 `scp` 将压缩包上传至远程服务器：

```bash
# 请将 your_user 和 your_server_ip 替换为你的服务器账号与IP
scp feedback-server.tar.gz your_user@your_server_ip:/home/your_user/
```

登录服务器并解压：

```bash
ssh your_user@your_server_ip
mkdir -p /home/your_user/feedback-server
tar -xzvf feedback-server.tar.gz -C /home/your_user/feedback-server
cd /home/your_user/feedback-server
```

---

### 步骤 3：在远程服务器上运行（二选一）

#### 选项 A：使用 Docker / Docker Compose 部署（强烈推荐，环境隔离且自动重启）

服务器只需安装了 Docker，进入解压目录后直接运行：

```bash
# 1. 启动容器并在后台运行
docker compose up -d --build

# 2. 查看容器运行日志
docker compose logs -f

# 3. 停止服务
docker compose down
```

> **数据持久化**：SQLite 数据库保存在服务器宿主机的 `./data/feedback.db`，即使容器升级重建，用户反馈数据也不会丢失。

#### 选项 B：传统 Node.js + PM2 部署

如果服务器上已安装 Node.js (推荐 v20+)：

```bash
# 1. 安装生产依赖
npm ci --omit=dev

# 2. 安装 PM2 进程守护工具（如果未安装）
npm install -g pm2

# 3. 启动后台守护进程
pm2 start server.js --name feedback-server

# 4. 设置开机自启
pm2 save
pm2 startup
```

---

### 步骤 4：配置域名与 Nginx 反向代理（可选）

若希望通过域名（例如 `feedback.yourdomain.com`）并通过 HTTPS 访问，可在服务器 Nginx 配置中增加：

```nginx
server {
    listen 80;
    server_name feedback.yourdomain.com;

    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_cache_bypass $http_upgrade;
    }
}
```

启用免费 SSL 证书（推荐使用 Certbot）：
```bash
sudo certbot --nginx -d feedback.yourdomain.com
```

---

## 环境变量配置 (.env)

你可以在 `server/.env` 文件中修改端口与管理员密码：

```env
PORT=3000
ADMIN_USERNAME=admin
ADMIN_PASSWORD=admin123
SESSION_SECRET=english_phonetic_feedback_secret_2026
```

---

## 目录结构

```
server/
├── server.js               # Express 主服务（路由、鉴权中间件）
├── db.js                   # SQLite 数据库与数据操作封装
├── data/
│   └── feedback.db         # SQLite 本地数据库文件（自动生成）
├── public/                 # 静态 Web 资源
│   ├── index.html          # 用户反馈提交页面（移动端适配）
│   ├── css/
│   │   └── style.css       # 用户端样式
│   ├── js/
│   │   └── app.js          # 用户端提交交互
│   └── admin/              # 管理后台
│       ├── login.html      # 管理员登录界面
│       ├── index.html      # 后台管理控制台
│       ├── css/
│       │   └── admin.css   # 后台样式
│       └── js/
│           └── admin.js    # 后台数据交互逻辑
├── package.json
└── README.md
```

---

## API 接口文档

### 1. 用户端接口

#### 提交反馈
- **URL**: `POST /api/feedback`
- **Headers**: `Content-Type: application/json`
- **Body**:
  ```json
  {
    "content": "发音声音有点小，希望能增加音量调节功能",
    "contact": "13800138000 / wechat_abc / user@example.com",
    "deviceInfo": "iOS 18.2 / iPhone 15 Pro"
  }
  ```
- **Response**:
  ```json
  {
    "success": true,
    "message": "反馈提交成功，非常感谢您的宝贵意见！",
    "id": 1
  }
  ```

---

### 2. 管理后台接口

| 接口 | 方法 | 说明 | 鉴权 |
|------|------|------|------|
| `/api/admin/login` | POST | 管理员登录（写入 HttpOnly Cookie） | 无 |
| `/api/admin/logout` | POST | 登出并清理 Cookie | 无 |
| `/api/admin/check-auth` | GET | 检查当前登录状态 | 无 |
| `/api/admin/stats` | GET | 获取统计指标（总数、今日新增、待处理） | 需要登录 |
| `/api/admin/feedbacks` | GET | 分页获取反馈列表，支持 `page`, `pageSize`, `status`, `search` 参数 | 需要登录 |
| `/api/admin/feedbacks/:id` | PATCH | 更新反馈状态 (`pending`/`resolved`/`archived`) 与备注 | 需要登录 |
| `/api/admin/feedbacks/:id` | DELETE | 删除指定 ID 的反馈 | 需要登录 |
| `/api/admin/export` | GET | 导出全部反馈为 CSV 文件（包含 UTF-8 BOM，Excel 直接打开不乱码） | 需要登录 |

---

## iOS App 中直接调用示例 (Swift)

在客户端（如 Swift / SwiftUI）中，你可以直接调用此 API 提交反馈：

```swift
import Foundation

struct FeedbackSubmission: Codable {
    let content: String
    let contact: String?
    let deviceInfo: String?
}

func submitFeedback(content: String, contact: String?, completion: @escaping (Bool, String?) -> Void) {
    guard let url = URL(string: "http://<YOUR_SERVER_IP>:3000/api/feedback") else { return }
    
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    
    let deviceInfo = "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion) (\(UIDevice.current.model))"
    let payload = FeedbackSubmission(content: content, contact: contact, deviceInfo: deviceInfo)
    
    do {
        request.httpBody = try JSONEncoder().encode(payload)
    } catch {
        completion(false, "编码失败")
        return
    }
    
    URLSession.shared.dataTask(with: request) { data, response, error in
        if let error = error {
            completion(false, error.localizedDescription)
            return
        }
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            completion(false, "服务器响应异常")
            return
        }
        completion(true, "提交成功")
    }.resume()
}
```
