import { createClient } from '@supabase/supabase-js';

export function json(res, status, payload) {
  res.setHeader('Content-Type', 'application/json; charset=utf-8');
  res.setHeader('Cache-Control', 'no-store');
  return res.status(status).json(payload);
}
export function method(req, res, allowed) {
  if (!allowed.includes(req.method)) { res.setHeader('Allow', allowed.join(', ')); json(res,405,{error:{code:'METHOD_NOT_ALLOWED',message:'Metode tidak didukung.'}}); return false; }
  return true;
}
export function clients(token) {
  const url=process.env.SUPABASE_URL;
  const key=process.env.SUPABASE_SERVICE_ROLE_KEY;
  if(!url||!key) throw new Error('Konfigurasi Supabase server belum lengkap.');
  const admin=createClient(url,key,{auth:{autoRefreshToken:false,persistSession:false}});
  const user=token?createClient(url,process.env.SUPABASE_ANON_KEY||process.env.SUPABASE_PUBLISHABLE_KEY,{auth:{autoRefreshToken:false,persistSession:false}}):null;
  return {admin,user};
}
export function bearer(req){const h=req.headers.authorization||''; return h.startsWith('Bearer ')?h.slice(7):null;}
export async function requireUser(req){
  const token=bearer(req); if(!token) return {error:{status:401,code:'UNAUTHENTICATED',message:'Silakan login terlebih dahulu.'}};
  const url=process.env.SUPABASE_URL,key=process.env.SUPABASE_ANON_KEY||process.env.SUPABASE_PUBLISHABLE_KEY;
  if(!url||!key) return {error:{status:503,code:'CONFIG_MISSING',message:'Supabase belum dikonfigurasi.'}};
  const sb=createClient(url,key,{auth:{autoRefreshToken:false,persistSession:false}});
  const {data,error}=await sb.auth.getUser(token);
  if(error||!data?.user) return {error:{status:401,code:'INVALID_SESSION',message:'Sesi tidak valid atau kedaluwarsa.'}};
  return {user:data.user,token};
}
export async function requireAdmin(req){
  const auth=await requireUser(req); if(auth.error)return auth;
  const url=process.env.SUPABASE_URL,key=process.env.SUPABASE_SERVICE_ROLE_KEY;
  if(!url||!key)return {error:{status:503,code:'CONFIG_MISSING',message:'Supabase server belum dikonfigurasi.'}};
  const sb=createClient(url,key,{auth:{autoRefreshToken:false,persistSession:false}});
  const {data:profile,error}=await sb.from('profiles').select('id,role,status').eq('id',auth.user.id).maybeSingle();
  if(error)return {error:{status:500,code:'PROFILE_LOOKUP_FAILED',message:'Gagal memeriksa otorisasi.'}};
  if(!profile||profile.role!=='admin'||profile.status!=='active')return {error:{status:403,code:'FORBIDDEN',message:'Akses khusus admin.'}};
  return {...auth,profile,sb};
}
export function fail(res,error){return json(res,error.status||500,{error:{code:error.code||'INTERNAL_ERROR',message:error.message||'Terjadi kesalahan.'}});}
