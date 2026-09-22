const CFG = window.APP_CONFIG;
const AUTH_BASE = `https://${CFG.hostedUiDomain}.auth.${CFG.region}.amazoncognito.com`;
const API = CFG.apiGatewayUrl.replace(/\/$/, '');

const $ = (id) => document.getElementById(id);

let accessToken = sessionStorage.getItem('access_token') || null;
let idToken = sessionStorage.getItem('id_token') || null;

/* ---------- PKCE helpers ---------- */

function randomString(bytes = 32) {
  const arr = crypto.getRandomValues(new Uint8Array(bytes));
  return btoa(String.fromCharCode(...arr))
    .replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

async function sha256base64url(input) {
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(input));
  return btoa(String.fromCharCode(...new Uint8Array(digest)))
    .replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function decodeJwt(token) {
  const payload = token.split('.')[1];
  const json = atob(payload.replace(/-/g, '+').replace(/_/g, '/'));
  return JSON.parse(json);
}

/* ---------- Login: Authorization Code + PKCE ---------- */

async function login() {
  const verifier = randomString(64);
  const challenge = await sha256base64url(verifier);
  const state = randomString(16);
  const nonce = randomString(16);

  sessionStorage.setItem('pkce_verifier', verifier);
  sessionStorage.setItem('oauth_state', state);
  sessionStorage.setItem('oauth_nonce', nonce);

  const params = new URLSearchParams({
    client_id: CFG.clientId,
    response_type: 'code',
    scope: CFG.scopes.join(' '),
    redirect_uri: CFG.redirectUri,
    code_challenge_method: 'S256',
    code_challenge: challenge,
    state,
    nonce,
  });
  window.location.href = `${AUTH_BASE}/oauth2/authorize?${params}`;
}

async function handleCallback() {
  const url = new URL(window.location.href);
  const code = url.searchParams.get('code');
  const state = url.searchParams.get('state');
  const error = url.searchParams.get('error');

  if (error) {
    showAlert(`Error OIDC: ${url.searchParams.get('error_description') || error}`);
    cleanUrl();
    return;
  }
  if (!code) return;

  const expectedState = sessionStorage.getItem('oauth_state');
  if (!state || state !== expectedState) {
    showAlert('Validación de state fallida: posible CSRF.');
    cleanUrl();
    return;
  }

  const verifier = sessionStorage.getItem('pkce_verifier');
  const nonce = sessionStorage.getItem('oauth_nonce');

  const body = new URLSearchParams({
    grant_type: 'authorization_code',
    client_id: CFG.clientId,
    code,
    redirect_uri: CFG.redirectUri,
    code_verifier: verifier,
  });

  const res = await fetch(`${AUTH_BASE}/oauth2/token`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body,
  });
  const tokens = await res.json();
  if (!res.ok) {
    showAlert(`Error al obtener token: ${tokens.error_description || tokens.error}`);
    cleanUrl();
    return;
  }

  const claims = decodeJwt(tokens.id_token);
  if (claims.nonce !== nonce) {
    showAlert('Validación de nonce fallida en el ID token.');
    cleanUrl();
    return;
  }

  accessToken = tokens.access_token;
  idToken = tokens.id_token;
  sessionStorage.setItem('access_token', accessToken);
  sessionStorage.setItem('id_token', idToken);
  sessionStorage.removeItem('pkce_verifier');
  sessionStorage.removeItem('oauth_state');
  sessionStorage.removeItem('oauth_nonce');

  cleanUrl();
  renderAuth();
  loadComputadores();
}

function cleanUrl() {
  window.history.replaceState({}, document.title, window.location.pathname);
}

function logout() {
  const params = new URLSearchParams({
    client_id: CFG.clientId,
    logout_uri: CFG.redirectUri,
  });
  sessionStorage.clear();
  accessToken = idToken = null;
  window.location.href = `${AUTH_BASE}/logout?${params}`;
}

/* ---------- Registro de cuenta en el tenant ---------- */

async function signUp(email, password) {
  const res = await fetch(`https://cognito-idp.${CFG.region}.amazonaws.com/`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/x-amz-json-1.1',
      'X-Amz-Target': 'AWSCognitoIdentityProviderService.SignUp',
      'amz-sdk-invocation-id': crypto.randomUUID(),
      'amz-sdk-request': 'attempt=1; max=3',
    },
    body: JSON.stringify({
      ClientId: CFG.clientId,
      Username: email,
      Password: password,
      UserAttributes: [{ Name: 'email', Value: email }],
    }),
  });
  const data = await res.json();
  if (data.__type) throw new Error(data.message || data.__type);
  return data;
}

async function confirmSignUp(email, code) {
  const res = await fetch(`https://cognito-idp.${CFG.region}.amazonaws.com/`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/x-amz-json-1.1',
      'X-Amz-Target': 'AWSCognitoIdentityProviderService.ConfirmSignUp',
      'amz-sdk-invocation-id': crypto.randomUUID(),
      'amz-sdk-request': 'attempt=1; max=3',
    },
    body: JSON.stringify({ ClientId: CFG.clientId, Username: email, ConfirmationCode: code }),
  });
  const data = await res.json();
  if (data.__type) throw new Error(data.message || data.__type);
  return data;
}

/* ---------- Llamadas al backend a través del API Gateway ---------- */

async function apiCall(path, options = {}) {
  const res = await fetch(`${API}${path}`, {
    ...options,
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${idToken || accessToken}`,
      ...(options.headers || {}),
    },
  });
  if (res.status === 401 || res.status === 403) {
    const body = await res.text();
    throw Object.assign(new Error(`HTTP ${res.status}: ${body || 'no autorizado'}`), { status: res.status });
  }
  if (res.status === 204) return null;
  const data = await res.json().catch(() => null);
  if (!res.ok) throw new Error(data?.error || `HTTP ${res.status}`);
  return data;
}

const loadComputadores = () => apiCall('/api/computadores').then(renderTabla).catch(showApiError);

/* ---------- UI ---------- */

function showAlert(msg) {
  const el = $('api-msg');
  el.textContent = msg;
  el.className = 'alert alert-danger d-block';
}

function showOk(msg) {
  const el = $('api-msg');
  el.textContent = msg;
  el.className = 'alert alert-success d-block';
}

function showApiError(err) {
  const suffix = err.status ? ` (API Gateway rechazó con ${err.status})` : '';
  showAlert(`${err.message}${suffix}`);
}

function renderAuth() {
  const logged = Boolean(accessToken);
  $('btn-login').classList.toggle('d-none', logged);
  $('btn-logout').classList.toggle('d-none', !logged);
  $('crud-section').classList.toggle('d-none', !logged);
  $('signup-section').classList.toggle('d-none', logged);
  if (logged && idToken) {
    const claims = decodeJwt(idToken);
    $('user-info').textContent = claims.email || claims.sub;
    $('user-info').classList.remove('d-none');
  } else {
    $('user-info').classList.add('d-none');
  }
}

function renderTabla(rows) {
  const tbody = document.querySelector('#tabla tbody');
  tbody.innerHTML = '';
  for (const c of rows) {
    const tr = document.createElement('tr');
    tr.innerHTML = `
      <td>${c.id}</td><td>${esc(c.nombre)}</td><td>${esc(c.cpu)}</td><td>${c.ram}</td>
      <td>${esc(c.marca)}</td><td>${c.tipo_almacenamiento}</td>
      <td>${c.capacidad_ssd}</td><td>${c.capacidad_hdd}</td><td>${c.almacenamiento_total}</td>
      <td>
        <button class="btn btn-primary" data-edit="${c.id}">Editar</button>
        <button class="btn btn-danger" data-del="${c.id}">Eliminar</button>
      </td>`;
    tbody.appendChild(tr);
  }
}

function esc(s) {
  return String(s).replace(/[&<>"']/g, (ch) => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
  }[ch]));
}

function formPayload() {
  return {
    nombre: $('nombre').value.trim(),
    cpu: $('cpu').value.trim(),
    ram: Number($('ram').value),
    marca: $('marca').value.trim(),
    tipo_almacenamiento: $('tipo_almacenamiento').value,
    capacidad_ssd: Number($('capacidad_ssd').value || 0),
    capacidad_hdd: Number($('capacidad_hdd').value || 0),
  };
}

function toggleStorageFields() {
  const tipo = $('tipo_almacenamiento').value;
  $('ssd-field').classList.toggle('d-none', !(tipo === 'SSD' || tipo === 'HIBRIDO'));
  $('hdd-field').classList.toggle('d-none', !(tipo === 'HDD' || tipo === 'HIBRIDO'));
}

function openForm(comp = null) {
  $('comp-form').classList.remove('d-none');
  $('comp-id').value = comp ? comp.id : '';
  $('nombre').value = comp?.nombre || '';
  $('cpu').value = comp?.cpu || '';
  $('ram').value = comp?.ram || '';
  $('marca').value = comp?.marca || '';
  $('tipo_almacenamiento').value = comp?.tipo_almacenamiento || 'SSD';
  $('capacidad_ssd').value = comp?.capacidad_ssd ?? 0;
  $('capacidad_hdd').value = comp?.capacidad_hdd ?? 0;
  toggleStorageFields();
}

/* ---------- Eventos ---------- */

$('btn-login').addEventListener('click', login);
$('btn-logout').addEventListener('click', logout);
$('btn-new').addEventListener('click', () => openForm());
$('btn-cancel').addEventListener('click', () => $('comp-form').classList.add('d-none'));
$('tipo_almacenamiento').addEventListener('change', toggleStorageFields);

$('comp-form').addEventListener('submit', async (e) => {
  e.preventDefault();
  const id = $('comp-id').value;
  try {
    if (id) {
      await apiCall(`/api/computadores/${id}`, { method: 'PUT', body: JSON.stringify(formPayload()) });
      showOk(`Computador #${id} actualizado vía API Gateway`);
    } else {
      const created = await apiCall('/api/computadores', { method: 'POST', body: JSON.stringify(formPayload()) });
      showOk(`Computador #${created.id} creado vía API Gateway`);
    }
    $('comp-form').classList.add('d-none');
    await loadComputadores();
  } catch (err) {
    showApiError(err);
  }
});

document.querySelector('#tabla tbody').addEventListener('click', async (e) => {
  const editId = e.target.dataset.edit;
  const delId = e.target.dataset.del;
  try {
    if (editId) {
      const comp = await apiCall(`/api/computadores/${editId}`);
      openForm(comp);
    } else if (delId) {
      if (!confirm('¿Eliminar este computador?')) return;
      await apiCall(`/api/computadores/${delId}`, { method: 'DELETE' });
      showOk(`Computador #${delId} eliminado vía API Gateway`);
      await loadComputadores();
    }
  } catch (err) {
    showApiError(err);
  }
});

$('signup-form').addEventListener('submit', async (e) => {
  e.preventDefault();
  const email = $('su-email').value.trim();
  const password = $('su-password').value;
  try {
    await signUp(email, password);
    $('su-email-shown').textContent = email;
    $('confirm-form').classList.remove('d-none');
    $('signup-msg').textContent = 'Cuenta creada. Revisa tu email para el código de verificación.';
    $('signup-msg').className = 'alert alert-success d-block';
  } catch (err) {
    $('signup-msg').textContent = err.message;
    $('signup-msg').className = 'alert alert-danger d-block';
  }
});

$('confirm-form').addEventListener('submit', async (e) => {
  e.preventDefault();
  const email = $('su-email').value.trim();
  try {
    await confirmSignUp(email, $('su-code').value.trim());
    $('signup-msg').textContent = 'Cuenta confirmada. Ya puedes iniciar sesión.';
    $('signup-msg').className = 'alert alert-success d-block';
    $('confirm-form').classList.add('d-none');
    $('signup-form').classList.add('d-none');
  } catch (err) {
    $('signup-msg').textContent = err.message;
    $('signup-msg').className = 'alert alert-danger d-block';
  }
});

/* ---------- Init ---------- */

(async function init() {
  await handleCallback();
  renderAuth();
  if (accessToken) await loadComputadores();
})();
