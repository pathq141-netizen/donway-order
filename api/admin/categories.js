import { requireAdmin, json, method, fail } from '../_lib/supabase.js';
const slugify=s=>s.toLowerCase().normalize('NFKD').replace(/[\\u0300-\\u036f]/g,'').replace(/[^a-z0-9]+/g,'-').replace(/^-|-$/g,'').slice(0,90);
export default async function handler(req,res){
 if(!method(req,res,['GET','POST','PATCH','DELETE'])) return;
 const auth=await requireAdmin(req); if(auth.error)return fail(res,auth.error);
 const db=auth.sb;
 try{
  if(req.method==='GET'){const {data,error}=await db.from('product_categories').select('id,name,slug,description,is_active,sort_order').is('deleted_at',null).order('sort_order').order('name');if(error)throw error;return json(res,200,{data:data||[]});}
  const b=req.body||{};
  if(req.method==='POST'||req.method==='PATCH'){
   if(typeof b.name!=='string'||!b.name.trim()||b.name.trim().length>100)return json(res,400,{error:{code:'VALIDATION_ERROR',message:'Nama kategori wajib diisi (maksimal 100 karakter).'}});
   const payload={name:b.name.trim(),slug:slugify(b.name.trim())||('kategori-'+Date.now()),description:typeof b.description==='string'?b.description.slice(0,500):'',is_active:b.is_active!==false,sort_order:Number.isInteger(b.sort_order)?b.sort_order:0};
   let result;
   if(req.method==='POST') result=await db.from('product_categories').insert(payload).select('*').single();
   else {if(typeof b.id!=='string')return json(res,400,{error:{code:'VALIDATION_ERROR',message:'ID kategori wajib diisi.'}});result=await db.from('product_categories').update(payload).eq('id',b.id).is('deleted_at',null).select('*').single();}
   if(result.error)throw result.error;
   await db.from('admin_audit_logs').insert({actor_id:auth.user.id,action:req.method==='POST'?'category.create':'category.update',entity_type:'product_category',entity_id:result.data.id,metadata:{name:result.data.name}});
   return json(res,req.method==='POST'?201:200,{data:result.data});
  }
  const id=req.query?.id;if(typeof id!=='string'||!id)return json(res,400,{error:{code:'VALIDATION_ERROR',message:'ID kategori wajib diisi.'}});
  const {count,error:ce}=await db.from('products').select('id',{count:'exact',head:true}).eq('category_id',id).is('deleted_at',null);if(ce)throw ce;
  if(count>0)return json(res,409,{error:{code:'CATEGORY_IN_USE',message:'Kategori masih dipakai produk. Pindahkan produk dahulu.'}});
  const {data,error}=await db.from('product_categories').update({deleted_at:new Date().toISOString(),is_active:false}).eq('id',id).is('deleted_at',null).select('id').maybeSingle();if(error)throw error;if(!data)return json(res,404,{error:{code:'NOT_FOUND',message:'Kategori tidak ditemukan.'}});
  await db.from('admin_audit_logs').insert({actor_id:auth.user.id,action:'category.delete',entity_type:'product_category',entity_id:id});
  return json(res,200,{data:{id,deleted:true}});
 }catch(e){console.error('[DONWAY CATEGORIES ERROR]',{message:e?.message,code:e?.code,details:e?.details,hint:e?.hint});return fail(res,{status:500,code:'CATEGORY_OPERATION_FAILED',message:'Operasi kategori gagal. Periksa log server.'});}
}
