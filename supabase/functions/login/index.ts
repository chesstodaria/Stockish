// Edge Function login: gerbang NIK.
//
// Aplikasi hanya menampilkan NIK, sedangkan Supabase Auth memakai email.
// Fungsi ini satu-satunya tempat pemetaan itu terjadi, sehingga klien tidak
// pernah tahu email internal dan tidak bisa menebak NIK mana yang terdaftar:
// NIK tidak terdaftar dan kata sandi salah menghasilkan pesan yang sama
// (CONTEXT bagian 6).
//
// Deploy: `verify_jwt = false`, karena fungsi ini dipanggil sebelum pengguna
// punya token.

import { createClient } from "jsr:@supabase/supabase-js@2";

const json = (body: unknown, status: number) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json; charset=utf-8" },
  });

const INVALID = { code: "invalid", message: "NIK atau kata sandi salah." };

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return json({ code: "method", message: "Gunakan POST." }, 405);
  }

  let payload: { nik?: string; password?: string };
  try {
    payload = await req.json();
  } catch {
    return json(INVALID, 401);
  }

  const nik = String(payload.nik ?? "").trim();
  const password = String(payload.password ?? "");
  if (nik === "" || password === "") return json(INVALID, 401);

  try {
    const url = Deno.env.get("SUPABASE_URL")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const admin = createClient(url, serviceKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const { data: profile, error } = await admin
      .from("profiles")
      .select("nik, name, warehouse_code, is_active")
      .eq("nik", nik)
      .maybeSingle();

    if (error) {
      return json(
        { code: "unavailable", message: "Gagal memeriksa akun. Coba lagi." },
        500,
      );
    }
    if (!profile) return json(INVALID, 401);
    if (!profile.is_active) {
      return json({
        code: "inactive",
        message: "Akun Anda nonaktif. Hubungi admin gudang.",
      }, 403);
    }

    const email = nik + "@stockisi.local";
    const { data: signIn, error: authError } = await admin.auth
      .signInWithPassword({ email, password });
    if (authError || !signIn.session) return json(INVALID, 401);

    const { data: warehouse } = await admin
      .from("warehouses")
      .select("name")
      .eq("code", profile.warehouse_code)
      .maybeSingle();

    return json({
      access_token: signIn.session.access_token,
      refresh_token: signIn.session.refresh_token,
      expires_at: signIn.session.expires_at,
      profile: {
        nik: profile.nik,
        name: profile.name,
        warehouse_code: profile.warehouse_code,
        warehouse_name: warehouse?.name ?? profile.warehouse_code,
        is_active: profile.is_active,
      },
    }, 200);
  } catch (_e) {
    return json(
      { code: "unavailable", message: "Gagal memproses login. Coba lagi." },
      500,
    );
  }
});
