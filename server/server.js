require('dotenv').config();
const express = require('express');
const path = require('path');
const cookieParser = require('cookie-parser');
const crypto = require('crypto');
const {
  insertFeedback,
  getFeedbacks,
  getStats,
  updateFeedback,
  deleteFeedback,
  getAllFeedbacksForExport
} = require('./db');

const app = express();
const PORT = process.env.PORT || 3000;

// 管理员凭据与密钥
const ADMIN_USERNAME = process.env.ADMIN_USERNAME || 'admin';
const ADMIN_PASSWORD = process.env.ADMIN_PASSWORD || 'admin123';
const JWT_SECRET = process.env.SESSION_SECRET || 'feedback_app_secret_key_change_in_prod';

// 中间件
app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use(cookieParser());

// 静态文件服务
app.use(express.static(path.join(__dirname, 'public')));

// 简易安全 Token 签名与验证
function generateToken(username) {
  const payload = `${username}:${Date.now() + 7 * 24 * 3600 * 1000}`; // 7天有效
  const hmac = crypto.createHmac('sha256', JWT_SECRET).update(payload).digest('hex');
  return Buffer.from(`${payload}:${hmac}`).toString('base64');
}

function verifyToken(token) {
  if (!token) return false;
  try {
    const raw = Buffer.from(token, 'base64').toString('utf8');
    const [username, expireStr, hmac] = raw.split(':');
    if (!username || !expireStr || !hmac) return false;
    if (Date.now() > Number(expireStr)) return false;

    const payload = `${username}:${expireStr}`;
    const expectedHmac = crypto.createHmac('sha256', JWT_SECRET).update(payload).digest('hex');
    if (crypto.timingSafeEqual(Buffer.from(hmac), Buffer.from(expectedHmac))) {
      return username === ADMIN_USERNAME;
    }
  } catch (err) {
    return false;
  }
  return false;
}

// 管理员鉴权中间件
function authMiddleware(req, res, next) {
  const token = req.cookies.admin_token;
  if (!verifyToken(token)) {
    return res.status(401).json({ success: false, message: '未授权或登录已过期，请重新登录' });
  }
  next();
}

// -------------------------------------------------------------
// 用户端接口
// -------------------------------------------------------------

/**
 * 提交用户反馈
 * POST /api/feedback
 * Body: { content: string, contact?: string, deviceInfo?: string }
 */
app.post('/api/feedback', (req, res) => {
  try {
    const { content, contact, deviceInfo } = req.body;

    if (!content || typeof content !== 'string' || !content.trim()) {
      return res.status(400).json({ success: false, message: '反馈内容不能为空' });
    }

    if (content.trim().length > 3000) {
      return res.status(400).json({ success: false, message: '反馈内容过长，请控制在 3000 字以内' });
    }

    const ip = req.headers['x-forwarded-for'] || req.socket.remoteAddress || '';
    const userAgent = req.headers['user-agent'] || '';

    const result = insertFeedback({
      content: content.trim(),
      contact: (contact || '').trim(),
      deviceInfo: (deviceInfo || '').trim(),
      ip,
      userAgent
    });

    return res.json({
      success: true,
      message: '反馈提交成功，非常感谢您的宝贵意见！',
      id: result.id
    });
  } catch (err) {
    console.error('提交反馈异常:', err);
    return res.status(500).json({ success: false, message: '服务器繁忙，请稍后再试' });
  }
});

// -------------------------------------------------------------
// 管理后台接口
// -------------------------------------------------------------

/**
 * 管理员登录
 * POST /api/admin/login
 * Body: { username, password }
 */
app.post('/api/admin/login', (req, res) => {
  const { username, password } = req.body;

  if (username === ADMIN_USERNAME && password === ADMIN_PASSWORD) {
    const token = generateToken(username);
    res.cookie('admin_token', token, {
      httpOnly: true,
      secure: process.env.NODE_ENV === 'production',
      sameSite: 'lax',
      maxAge: 7 * 24 * 3600 * 1000 // 7天
    });
    return res.json({ success: true, message: '登录成功' });
  }

  return res.status(401).json({ success: false, message: '用户名或密码错误' });
});

/**
 * 管理员退出登录
 * POST /api/admin/logout
 */
app.post('/api/admin/logout', (req, res) => {
  res.clearCookie('admin_token');
  res.json({ success: true, message: '已退出登录' });
});

/**
 * 检查登录状态
 * GET /api/admin/check-auth
 */
app.get('/api/admin/check-auth', (req, res) => {
  const isAuthed = verifyToken(req.cookies.admin_token);
  res.json({ authenticated: isAuthed });
});

/**
 * 获取统计数据
 * GET /api/admin/stats
 */
app.get('/api/admin/stats', authMiddleware, (req, res) => {
  try {
    const stats = getStats();
    res.json({ success: true, data: stats });
  } catch (err) {
    console.error('获取统计异常:', err);
    res.status(500).json({ success: false, message: '获取统计失败' });
  }
});

/**
 * 获取反馈列表
 * GET /api/admin/feedbacks?page=1&pageSize=20&status=all&search=
 */
app.get('/api/admin/feedbacks', authMiddleware, (req, res) => {
  try {
    const { page, pageSize, status, search } = req.query;
    const data = getFeedbacks({ page, pageSize, status, search });
    res.json({ success: true, data });
  } catch (err) {
    console.error('获取反馈列表异常:', err);
    res.status(500).json({ success: false, message: '获取反馈列表失败' });
  }
});

/**
 * 更新反馈状态和管理员备注
 * PATCH /api/admin/feedbacks/:id
 * Body: { status?: 'pending'|'resolved'|'archived', adminNote?: string }
 */
app.patch('/api/admin/feedbacks/:id', authMiddleware, (req, res) => {
  try {
    const { id } = req.params;
    const { status, adminNote } = req.body;
    const ok = updateFeedback(Number(id), { status, adminNote });
    if (ok) {
      res.json({ success: true, message: '更新成功' });
    } else {
      res.status(404).json({ success: false, message: '未找到指定反馈' });
    }
  } catch (err) {
    console.error('更新反馈异常:', err);
    res.status(500).json({ success: false, message: '更新失败' });
  }
});

/**
 * 删除单条反馈
 * DELETE /api/admin/feedbacks/:id
 */
app.delete('/api/admin/feedbacks/:id', authMiddleware, (req, res) => {
  try {
    const { id } = req.params;
    const ok = deleteFeedback(Number(id));
    if (ok) {
      res.json({ success: true, message: '删除成功' });
    } else {
      res.status(404).json({ success: false, message: '未找到指定反馈' });
    }
  } catch (err) {
    console.error('删除反馈异常:', err);
    res.status(500).json({ success: false, message: '删除失败' });
  }
});

/**
 * 导出反馈为 CSV
 * GET /api/admin/export
 */
app.get('/api/admin/export', authMiddleware, (req, res) => {
  try {
    const rows = getAllFeedbacksForExport();
    const headers = ['ID', '反馈内容', '联系方式', '设备信息', '状态', '管理员备注', '提交时间', 'IP'];
    
    // 转义 CSV 单元格
    const escapeCsv = (str) => {
      if (str === null || str === undefined) return '""';
      const s = String(str).replace(/"/g, '""');
      return `"${s}"`;
    };

    let csvContent = '\uFEFF'; // UTF-8 BOM 确保 Excel 打开中文不乱码
    csvContent += headers.join(',') + '\n';

    rows.forEach(r => {
      const line = [
        r.id,
        escapeCsv(r.content),
        escapeCsv(r.contact),
        escapeCsv(r.device_info),
        escapeCsv(r.status),
        escapeCsv(r.admin_note),
        escapeCsv(r.created_at),
        escapeCsv(r.ip)
      ].join(',');
      csvContent += line + '\n';
    });

    res.setHeader('Content-Type', 'text/csv; charset=utf-8');
    res.setHeader('Content-Disposition', `attachment; filename=feedbacks_${Date.now()}.csv`);
    res.send(csvContent);
  } catch (err) {
    console.error('导出反馈异常:', err);
    res.status(500).json({ success: false, message: '导出失败' });
  }
});

// 启动服务
app.listen(PORT, () => {
  console.log(`=============================================`);
  console.log(`🚀 用户反馈服务已成功启动！`);
  console.log(`🌐 用户反馈页面: http://localhost:${PORT}`);
  console.log(`🛡️  管理后台地址: http://localhost:${PORT}/admin`);
  console.log(`🔑 默认后台账号: ${ADMIN_USERNAME} / 默认密码: ${ADMIN_PASSWORD}`);
  console.log(`=============================================`);
});
