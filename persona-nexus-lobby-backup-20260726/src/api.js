function getToken() {
  return localStorage.getItem('token');
}

function decodeToken(token) {
  const payloadPart = token.split('.')[1];
  const base64 = payloadPart.replace(/-/g, '+').replace(/_/g, '/');
  return JSON.parse(atob(base64));
}

export function getCurrentUserId() {
  const token = getToken();
  if (!token) return null;

  try {
    return decodeToken(token).id ?? null;
  } catch {
    return null;
  }
}

export async function listMyCharacters() {
  const token = getToken();
  const userId = getCurrentUserId();
  console.log(`📤 [api.js] 即將送出請求，注入 Authorization header，token 是否存在：${!!token}`);

  const response = await fetch(`/api/characters?authorId=${encodeURIComponent(userId)}`, {
    headers: { 'Authorization': `Bearer ${token}` }
  });

  if (!response.ok) {
    const error = await response.json().catch(() => ({ message: '未知錯誤' }));
    throw new Error(error.message || `HTTP ${response.status}`);
  }

  return response.json();
}
