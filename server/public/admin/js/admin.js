let currentPage = 1;
const pageSize = 15;
let currentStatus = 'all';
let currentSearch = '';
let searchDebounceTimer = null;

// DOM 元素
const statTotal = document.getElementById('statTotal');
const statToday = document.getElementById('statToday');
const statPending = document.getElementById('statPending');
const statResolved = document.getElementById('statResolved');
const searchInput = document.getElementById('searchInput');
const statusFilter = document.getElementById('statusFilter');
const refreshBtn = document.getElementById('refreshBtn');
const feedbackTableBody = document.getElementById('feedbackTableBody');
const pageInfo = document.getElementById('pageInfo');
const prevPageBtn = document.getElementById('prevPageBtn');
const nextPageBtn = document.getElementById('nextPageBtn');
const exportBtn = document.getElementById('exportBtn');
const logoutBtn = document.getElementById('logoutBtn');

// 格式化时间为友好字符串
function formatDateTime(dateStr) {
  if (!dateStr) return '-';
  const d = new Date(dateStr);
  if (isNaN(d.getTime())) return dateStr;
  const pad = (n) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())} ${pad(d.getHours())}:${pad(d.getMinutes())}`;
}

// 检查登录态并加载数据
async function checkAuthAndInit() {
  try {
    const res = await fetch('../../api/admin/check-auth');
    const data = await res.json();
    if (!data.authenticated) {
      window.location.replace('../login.html');
      return;
    }
    loadStats();
    loadFeedbacks();
  } catch (e) {
    window.location.replace('/admin/login.html');
  }
}

// 加载统计信息
async function loadStats() {
  try {
    const res = await fetch('../../api/admin/stats');
    if (res.status === 401) {
      window.location.replace('/admin/login.html');
      return;
    }
    const { data } = await res.json();
    if (data) {
      statTotal.textContent = data.total;
      statToday.textContent = data.today;
      statPending.textContent = data.pending;
      statResolved.textContent = data.resolved;
    }
  } catch (err) {
    console.error('加载统计失败:', err);
  }
}

// 加载反馈列表
async function loadFeedbacks() {
  feedbackTableBody.innerHTML = '<tr><td colspan="7" class="loading-td">加载中...</td></tr>';

  try {
    const params = new URLSearchParams({
      page: currentPage,
      pageSize,
      status: currentStatus,
      search: currentSearch
    });

    const res = await fetch(`../../api/admin/feedbacks?${params.toString()}`);
    if (res.status === 401) {
      window.location.replace('../login.html');
      return;
    }

    const { data } = await res.json();
    renderFeedbacks(data);
  } catch (err) {
    console.error('加载列表失败:', err);
    feedbackTableBody.innerHTML = '<tr><td colspan="7" class="loading-td">加载失败，请重试</td></tr>';
  }
}

// 渲染列表
function renderFeedbacks(data) {
  const { total, page, totalPages, items } = data;

  pageInfo.textContent = `第 ${page} / ${totalPages || 1} 页 (共 ${total} 条)`;
  prevPageBtn.disabled = page <= 1;
  nextPageBtn.disabled = page >= totalPages || totalPages === 0;

  if (!items || items.length === 0) {
    feedbackTableBody.innerHTML = '<tr><td colspan="7" class="empty-td">暂无匹配的用户反馈记录</td></tr>';
    return;
  }

  const html = items.map(item => {
    return `
      <tr data-id="${item.id}">
        <td>#${item.id}</td>
        <td class="content-cell">
          <div>${escapeHtml(item.content)}</div>
          ${item.device_info ? `<span class="device-badge">${escapeHtml(item.device_info)}</span>` : ''}
        </td>
        <td class="contact-cell">${escapeHtml(item.contact) || '<span style="color:#94a3b8">未留联系方式</span>'}</td>
        <td>
          <select class="status-select ${item.status}" onchange="handleStatusChange(${item.id}, this.value, this)">
            <option value="pending" ${item.status === 'pending' ? 'selected' : ''}>待处理</option>
            <option value="resolved" ${item.status === 'resolved' ? 'selected' : ''}>已处理</option>
            <option value="archived" ${item.status === 'archived' ? 'selected' : ''}>已归档</option>
          </select>
        </td>
        <td>
          <input 
            type="text" 
            class="note-input" 
            placeholder="点击输入备注..." 
            value="${escapeHtml(item.admin_note || '')}"
            onchange="handleNoteChange(${item.id}, this.value)"
          >
        </td>
        <td class="time-cell">${formatDateTime(item.created_at)}</td>
        <td>
          <button class="btn-del" onclick="handleDelete(${item.id})">删除</button>
        </td>
      </tr>
    `;
  }).join('');

  feedbackTableBody.innerHTML = html;
}

// 更新状态
window.handleStatusChange = async function(id, newStatus, selectEl) {
  selectEl.className = `status-select ${newStatus}`;
  try {
    const res = await fetch(`../../api/admin/feedbacks/${id}`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ status: newStatus })
    });
    if (res.ok) {
      loadStats();
    } else {
      alert('状态更新失败');
    }
  } catch (err) {
    alert('网络异常');
  }
};

// 更新备注
window.handleNoteChange = async function(id, note) {
  try {
    const res = await fetch(`../../api/admin/feedbacks/${id}`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ adminNote: note })
    });
    if (!res.ok) {
      alert('备注更新失败');
    }
  } catch (err) {
    alert('网络异常');
  }
};

// 删除一条反馈
window.handleDelete = async function(id) {
  if (!confirm(`确定要删除第 #${id} 号反馈记录吗？此操作无法撤销。`)) {
    return;
  }
  try {
    const res = await fetch(`../../api/admin/feedbacks/${id}`, { method: 'DELETE' });
    if (res.ok) {
      loadStats();
      loadFeedbacks();
    } else {
      alert('删除失败');
    }
  } catch (err) {
    alert('网络异常');
  }
};

// 搜索防抖
searchInput.addEventListener('input', (e) => {
  clearTimeout(searchDebounceTimer);
  searchDebounceTimer = setTimeout(() => {
    currentSearch = e.target.value.trim();
    currentPage = 1;
    loadFeedbacks();
  }, 350);
});

// 状态筛选
statusFilter.addEventListener('change', (e) => {
  currentStatus = e.target.value;
  currentPage = 1;
  loadFeedbacks();
});

// 手动刷新
refreshBtn.addEventListener('click', () => {
  loadStats();
  loadFeedbacks();
});

// 上一页/下一页
prevPageBtn.addEventListener('click', () => {
  if (currentPage > 1) {
    currentPage--;
    loadFeedbacks();
  }
});

nextPageBtn.addEventListener('click', () => {
  currentPage++;
  loadFeedbacks();
});

// 导出 CSV
exportBtn.addEventListener('click', () => {
  window.open('../../api/admin/export', '_blank');
});

// 退出登录
logoutBtn.addEventListener('click', async () => {
  try {
    await fetch('../../api/admin/logout', { method: 'POST' });
  } finally {
    window.location.replace('../login.html');
  }
});

// XSS 转义
function escapeHtml(str) {
  if (!str) return '';
  return String(str)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

// 页面加载入口
document.addEventListener('DOMContentLoaded', checkAuthAndInit);
