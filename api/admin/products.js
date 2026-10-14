import { requireAdmin, json, method, fail } from '../_lib/supabase.js';

const validName = v => typeof v === 'string' && v.trim().length > 0 && v.trim().length <= 120;
const validImagePath = v => v == null || (typeof v === 'string' && v.length <= 700 && !v.startsWith('http'));
export default async function handler(req, res) {
  if (!method(req, res, ['GET','POST','PATCH','DELETE'])) return;
  const auth = await requireAdmin(req);
  if (auth.error) return fail(res, auth.error);
  const db = auth.sb;
  try {
    if (req.method === 'GET') {
      const { data, error } = await db.from('products')
        .select('id,name,description,price,stock_quantity,is_active,image_path,banner_path,category_id,sort_order,created_at,product_categories(name)')
        .is('deleted_at', null).order('sort_order').order('created_at',{ascending:false}).limit(200);
      if (error) throw error;
      return json(res,200,{data:data||[]});
    }
    const b = req.body || {};
    if (req.method === 'POST' || req.method === 'PATCH') {
      if (!validName(b.name) || !Number.isFinite(Number(b.price)) || Number(b.price)<0 ||
          !Number.isInteger(Number(b.stock_quantity)) || Number(b.stock_quantity)<0 ||
          !validImagePath(b.image_path) || !validImagePath(b.banner_path)) {
        return json(res,400,{error:{code:'VALIDATION_ERROR',message:'Periksa nama, harga, stok, atau path gambar.'}});
      }
      if (b.category_id) {
        const {data:cat,error:ce}=await db.from('product_categories').select('id,is_active').eq('id',b.category_id).is('deleted_at',null).maybeSingle();
        if(ce) throw ce;
        if(!cat) return json(res,400,{error:{code:'INVALID_CATEGORY',message:'Kategori tidak ditemukan.'}});
        if(!cat.is_active) await db.from('product_categories').update({is_active:true}).eq('id',cat.id);
      }
      const payload={
        name:b.name.trim(), description:typeof b.description==='string'?b.description.slice(0,3000):'',
        price:Number(b.price), stock_quantity:Number(b.stock_quantity), category_id:b.category_id||null,
        image_path:b.image_path||null, banner_path:b.banner_path||null,
        is_active:b.is_active===false?false:true, sort_order:Number.isInteger(b.sort_order)?b.sort_order:0
      };
      let result;
      if(req.method==='POST') result=await db.from('products').insert(payload).select('*').single();
      else {
        if(typeof b.id!=='string') return json(res,400,{error:{code:'VALIDATION_ERROR',message:'ID produk wajib diisi.'}});
        result=await db.from('products').update(payload).eq('id',b.id).is('deleted_at',null).select('*').single();
      }
      if(result.error) throw result.error;
      await db.from('admin_audit_logs').insert({actor_id:auth.user.id,action:req.method==='POST'?'product.create':'product.update',entity_type:'product',entity_id:result.data.id,metadata:{name:result.data.name,is_active:result.data.is_active}});
      return json(res,req.method==='POST'?201:200,{data:result.data});
    }
    const id=req.query?.id;
    if(typeof id!=='string'||!id) return json(res,400,{error:{code:'VALIDATION_ERROR',message:'ID produk wajib diisi.'}});
    const {data,error}=await db.from('products').update({deleted_at:new Date().toISOString(),is_active:false}).eq('id',id).is('deleted_at',null).select('id').maybeSingle();
    if(error) throw error;
    if(!data) return json(res,404,{error:{code:'NOT_FOUND',message:'Produk tidak ditemukan.'}});
    await db.from('admin_audit_logs').insert({actor_id:auth.user.id,action:'product.delete',entity_type:'product',entity_id:id});
    return json(res,200,{data:{id,deleted:true}});
  } catch(e) {
    console.error('[DONWAY PRODUCTS ERROR]',{message:e?.message,code:e?.code,details:e?.details,hint:e?.hint});
    return fail(res,{status:500,code:'PRODUCT_OPERATION_FAILED',message:'Operasi produk gagal. Periksa kolom database dan log server.'});
  }
}
