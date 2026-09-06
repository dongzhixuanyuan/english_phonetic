document.addEventListener('DOMContentLoaded', () => {
  const form = document.getElementById('feedbackForm');
  const contentInput = document.getElementById('content');
  const contactInput = document.getElementById('contact');
  const charCount = document.getElementById('charCount');
  const submitBtn = document.getElementById('submitBtn');
  const contentError = document.getElementById('contentError');
  const formCard = document.getElementById('formCard');
  const successCard = document.getElementById('successCard');
  const resetBtn = document.getElementById('resetBtn');

  // 字数统计与实时清理校验报错
  contentInput.addEventListener('input', () => {
    const len = contentInput.value.length;
    charCount.textContent = len;
    if (len > 0 && contentError.classList.contains('visible')) {
      contentError.classList.remove('visible');
      contentError.textContent = '';
    }
  });

  // 简要获取客户端环境信息（辅助定位问题）
  function getDeviceInfo() {
    const screenInfo = `${window.screen.width}x${window.screen.height}`;
    return `Screen: ${screenInfo}, Language: ${navigator.language || ''}`;
  }

  // 表单提交
  form.addEventListener('submit', async (e) => {
    e.preventDefault();

    const content = contentInput.value.trim();
    const contact = contactInput.value.trim();

    // 校验
    if (!content) {
      contentError.textContent = '请填写您的反馈内容';
      contentError.classList.add('visible');
      contentInput.focus();
      return;
    }

    if (content.length > 2000) {
      contentError.textContent = '反馈内容请保持在 2000 字以内';
      contentError.classList.add('visible');
      return;
    }

    // 设置 loading 状态
    submitBtn.disabled = true;
    submitBtn.classList.add('loading');
    submitBtn.querySelector('.btn-text').textContent = '提交中...';

    try {
      const response = await fetch('api/feedback', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          content,
          contact,
          deviceInfo: getDeviceInfo()
        })
      });

      const data = await response.json();

      if (response.ok && data.success) {
        // 提交成功，切换到成功视图
        formCard.style.display = 'none';
        successCard.style.display = 'block';
        form.reset();
        charCount.textContent = '0';
      } else {
        alert(data.message || '提交失败，请稍后重试');
      }
    } catch (err) {
      console.error('提交失败:', err);
      alert('网络连接异常，请检查网络后重试');
    } finally {
      submitBtn.disabled = false;
      submitBtn.classList.remove('loading');
      submitBtn.querySelector('.btn-text').textContent = '提交反馈';
    }
  });

  // 再提一条
  resetBtn.addEventListener('click', () => {
    successCard.style.display = 'none';
    formCard.style.display = 'block';
    contentInput.focus();
  });
});
