const path = require('path');
const fs = require('fs');

const dataDir = path.join(__dirname, 'data');
if (!fs.existsSync(dataDir)) {
  fs.mkdirSync(dataDir, { recursive: true });
}

const dbPath = path.join(dataDir, 'feedback.db');

let db;
// 优先使用 Node 原生内置的高性能 SQLite (Node 22+)
try {
  const { DatabaseSync } = require('node:sqlite');
  db = new DatabaseSync(dbPath);
} catch (e) {
  // 降级使用 better-sqlite3
  const BetterSqlite3 = require('better-sqlite3');
  db = new BetterSqlite3(dbPath);
}

// 开启 WAL 模式提升并发读写性能
try {
  db.exec('PRAGMA journal_mode = WAL;');
} catch (e) {
  // 忽略 pragma 异常
}

// 初始化数据表与索引
db.exec(`
  CREATE TABLE IF NOT EXISTS feedbacks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    content TEXT NOT NULL,
    contact TEXT,
    device_info TEXT,
    ip TEXT,
    user_agent TEXT,
    status TEXT DEFAULT 'pending',
    admin_note TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
  );

  CREATE INDEX IF NOT EXISTS idx_feedbacks_created_at ON feedbacks(created_at DESC);
  CREATE INDEX IF NOT EXISTS idx_feedbacks_status ON feedbacks(status);
`);

/**
 * 插入一条用户反馈
 */
function insertFeedback({ content, contact, deviceInfo, ip, userAgent }) {
  const stmt = db.prepare(`
    INSERT INTO feedbacks (content, contact, device_info, ip, user_agent)
    VALUES (?, ?, ?, ?, ?)
  `);
  const result = stmt.run(content, contact || '', deviceInfo || '', ip || '', userAgent || '');
  return { id: Number(result.lastInsertRowid) };
}

/**
 * 获取反馈列表（支持分页、搜索、状态过滤）
 */
function getFeedbacks({ page = 1, pageSize = 20, status = 'all', search = '' }) {
  const pageNum = Math.max(1, Number(page) || 1);
  const sizeNum = Math.max(1, Number(pageSize) || 20);
  const offset = (pageNum - 1) * sizeNum;
  const whereClauses = [];
  const params = [];

  if (status && status !== 'all') {
    whereClauses.push('status = ?');
    params.push(status);
  }

  if (search && search.trim()) {
    whereClauses.push('(content LIKE ? OR contact LIKE ? OR admin_note LIKE ?)');
    const keyword = `%${search.trim()}%`;
    params.push(keyword, keyword, keyword);
  }

  const whereSql = whereClauses.length > 0 ? `WHERE ${whereClauses.join(' AND ')}` : '';

  const countStmt = db.prepare(`SELECT COUNT(*) as total FROM feedbacks ${whereSql}`);
  const total = Number(countStmt.get(...params).total);

  const listStmt = db.prepare(`
    SELECT 
      id,
      content,
      contact,
      device_info,
      ip,
      user_agent,
      status,
      admin_note,
      created_at
    FROM feedbacks
    ${whereSql}
    ORDER BY id DESC
    LIMIT ? OFFSET ?
  `);

  const items = listStmt.all(...params, sizeNum, offset).map(row => ({
    ...row,
    id: Number(row.id)
  }));

  return {
    total,
    page: pageNum,
    pageSize: sizeNum,
    totalPages: Math.ceil(total / sizeNum),
    items
  };
}

/**
 * 获取统计数据
 */
function getStats() {
  const totalStmt = db.prepare('SELECT COUNT(*) as count FROM feedbacks');
  const pendingStmt = db.prepare("SELECT COUNT(*) as count FROM feedbacks WHERE status = 'pending'");
  const resolvedStmt = db.prepare("SELECT COUNT(*) as count FROM feedbacks WHERE status = 'resolved'");
  const todayStmt = db.prepare(`
    SELECT COUNT(*) as count FROM feedbacks 
    WHERE date(created_at, 'localtime') = date('now', 'localtime')
  `);

  return {
    total: Number(totalStmt.get().count),
    pending: Number(pendingStmt.get().count),
    resolved: Number(resolvedStmt.get().count),
    today: Number(todayStmt.get().count)
  };
}

/**
 * 更新反馈状态及备注
 */
function updateFeedback(id, { status, adminNote }) {
  const fields = [];
  const params = [];

  if (status !== undefined) {
    fields.push('status = ?');
    params.push(status);
  }

  if (adminNote !== undefined) {
    fields.push('admin_note = ?');
    params.push(adminNote);
  }

  if (fields.length === 0) return false;

  params.push(Number(id));
  const stmt = db.prepare(`UPDATE feedbacks SET ${fields.join(', ')} WHERE id = ?`);
  const result = stmt.run(...params);
  return Number(result.changes) > 0;
}

/**
 * 删除一条反馈
 */
function deleteFeedback(id) {
  const stmt = db.prepare('DELETE FROM feedbacks WHERE id = ?');
  const result = stmt.run(Number(id));
  return Number(result.changes) > 0;
}

/**
 * 获取所有反馈用于导出
 */
function getAllFeedbacksForExport() {
  const stmt = db.prepare(`
    SELECT id, content, contact, device_info, status, admin_note, created_at, ip
    FROM feedbacks
    ORDER BY id DESC
  `);
  return stmt.all().map(row => ({
    ...row,
    id: Number(row.id)
  }));
}

module.exports = {
  db,
  insertFeedback,
  getFeedbacks,
  getStats,
  updateFeedback,
  deleteFeedback,
  getAllFeedbacksForExport
};
