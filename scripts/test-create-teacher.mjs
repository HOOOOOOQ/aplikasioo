#!/usr/bin/env node
/**
 * Uji end-to-end Edge Function create-teacher (tanpa Flutter).
 *
 * Pemakaian:
 *   SUPABASE_URL="https://xxxx.supabase.co" \
 *   SUPABASE_ANON_KEY="sb_publishable_... / anon key" \
 *   ADMIN_EMAIL="admin@sekolah.id" ADMIN_PASSWORD="..." \
 *   node scripts/test-create-teacher.mjs
 *
 * Opsional (pengujian negatif & pembuatan akun uji):
 *   GURU_EMAIL / GURU_PASSWORD   -> memastikan non-admin ditolak 403
 *   CREATE_TEST_TEACHER=1        -> benar-benar membuat akun guru uji (200)
 *
 * Script ini TIDAK PERNAH mencetak access token, password, anon key, atau
 * service_role key. Secara default ia hanya menguji jalur negatif (401/403)
 * agar tidak membuat data baru di database.
 */

const env = process.env;
const SUPABASE_URL = (env.SUPABASE_URL ?? '').replace(/\/+$/, '');
const ANON_KEY = env.SUPABASE_ANON_KEY ?? '';
const ADMIN_EMAIL = env.ADMIN_EMAIL ?? '';
const ADMIN_PASSWORD = env.ADMIN_PASSWORD ?? '';
const GURU_EMAIL = env.GURU_EMAIL ?? '';
const GURU_PASSWORD = env.GURU_PASSWORD ?? '';
const CREATE = env.CREATE_TEST_TEACHER === '1';

const results = [];

function fail(message) {
  console.error(`\n✗ ${message}`);
  process.exit(1);
}

if (!SUPABASE_URL || !ANON_KEY) fail('SUPABASE_URL dan SUPABASE_ANON_KEY wajib diisi.');
if (!SUPABASE_URL.includes('.supabase.co') && !SUPABASE_URL.startsWith('http')) {
  fail('SUPABASE_URL tidak terlihat valid.');
}

async function signIn(email, password) {
  const res = await fetch(`${SUPABASE_URL}/auth/v1/token?grant_type=password`, {
    method: 'POST',
    headers: { apikey: ANON_KEY, 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password }),
  });
  const body = await res.json().catch(() => ({}));
  if (!res.ok || !body.access_token) {
    return { ok: false, status: res.status, error: body.error_description ?? body.msg ?? body.error ?? 'login gagal' };
  }
  return { ok: true, status: res.status, accessToken: body.access_token, userId: body.user?.id };
}

async function invoke(token) {
  const headers = { apikey: ANON_KEY, 'Content-Type': 'application/json' };
  if (token) headers.Authorization = `Bearer ${token}`;
  const suffix = CREATE ? Date.now().toString(36) : 'dryrun';
  const res = await fetch(`${SUPABASE_URL}/functions/v1/create-teacher`, {
    method: 'POST',
    headers,
    body: JSON.stringify({
      email: `guru.uji.${suffix}@example.com`,
      password: 'UjiCoba123!',
      full_name: 'Guru Uji E2E',
    }),
  });
  const text = await res.text();
  let body = text;
  try {
    body = JSON.parse(text);
  } catch (_) {
    /* biarkan string */
  }
  return { status: res.status, body };
}

function record(name, expected, actual, ok, note = '') {
  results.push({ name, expected, actual, ok, note });
  console.log(`${ok ? '✓' : '✗'} ${name} — expected ${expected}, dapat ${actual}${note ? ` (${note})` : ''}`);
}

function safeDetail(body) {
  if (!body || typeof body !== 'object') return '';
  const code = body.code ?? '';
  const message = String(body.message ?? body.error ?? '').slice(0, 120);
  return [code, message].filter(Boolean).join(' — ');
}

(async () => {
  console.log(`Menguji ${SUPABASE_URL}/functions/v1/create-teacher\n`);

  // 1) Tanpa token -> gateway/function harus menolak 401.
  const noAuth = await invoke(null);
  record('Request tanpa Authorization', 401, noAuth.status, noAuth.status === 401, safeDetail(noAuth.body));

  // 2) Token palsu -> 401.
  const badAuth = await invoke('invalid.jwt.token');
  record('Request dengan token palsu', 401, badAuth.status, badAuth.status === 401, safeDetail(badAuth.body));

  // 3) Login admin (jika kredensial tersedia).
  let adminToken = null;
  if (ADMIN_EMAIL && ADMIN_PASSWORD) {
    const admin = await signIn(ADMIN_EMAIL, ADMIN_PASSWORD);
    if (!admin.ok) {
      record('Login admin', 200, admin.status, false, admin.error);
    } else {
      adminToken = admin.accessToken;
      record('Login admin', 200, admin.status, true);

      const profileRes = await fetch(
        `${SUPABASE_URL}/rest/v1/profiles?select=role,is_active&id=eq.${admin.userId}`,
        { headers: { apikey: ANON_KEY, Authorization: `Bearer ${adminToken}` } },
      );
      const profile = await profileRes.json().catch(() => []);
      const row = Array.isArray(profile) ? profile[0] : null;
      const isAdmin = row?.role === 'admin' && row?.is_active === true;
      record('Profil admin (role=admin, is_active=true)', true, isAdmin, isAdmin);

      if (isAdmin && CREATE) {
        const created = await invoke(adminToken);
        record('Admin membuat akun guru', 200, created.status, created.status === 200, safeDetail(created.body));
        if (created.status === 200) {
          console.log('  ℹ Akun guru uji dibuat. Hapus manual via Dashboard → Authentication → Users jika tidak dipakai.');
        }
      } else if (isAdmin) {
        console.log('  ℹ CREATE_TEST_TEACHER != 1 → pembuatan akun guru dilewati (aman, tanpa data baru).');
      }
    }
  } else {
    console.log('  ℹ ADMIN_EMAIL/ADMIN_PASSWORD tidak diisi → pengujian jalur admin dilewati.');
  }

  // 4) Non-admin harus 403 (bukan 401 dan bukan 200).
  if (GURU_EMAIL && GURU_PASSWORD) {
    const guru = await signIn(GURU_EMAIL, GURU_PASSWORD);
    if (!guru.ok) {
      record('Login guru (non-admin)', 200, guru.status, false, guru.error);
    } else {
      const forbidden = await invoke(guru.accessToken);
      record('Guru mencoba membuat akun guru', 403, forbidden.status, forbidden.status === 403, safeDetail(forbidden.body));
    }
  } else {
    console.log('  ℹ GURU_EMAIL/GURU_PASSWORD tidak diisi → pengujian non-admin 403 dilewati.');
  }

  const failed = results.filter((r) => !r.ok);
  console.log(`\n${results.length - failed.length}/${results.length} pemeriksaan lulus.`);
  if (failed.length > 0) {
    console.error('\nPemeriksaan gagal:');
    for (const f of failed) console.error(`- ${f.name}: expected ${f.expected}, dapat ${f.actual}`);
    process.exit(1);
  }
  console.log('Semua pemeriksaan lulus.');
})().catch((e) => {
  console.error('Error tak terduga saat pengujian:', e instanceof Error ? e.message : e);
  process.exit(1);
});
