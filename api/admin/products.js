import { requireAdmin, json, method, fail } from '../_lib/supabase.js';
const validText=(v,max=160)=>typeof v==='string'&&v.trim().length>0&&v.trim().length<=max;
export default async function handler(req,res){
 const auth=await requireAdmin(req);if(auth.error)return fail(res,auth.error);
 const db=auth.sb;
 try{
  if(req.method==='GET'){
   const {data,error}=await db.from('products').select('id,name,description,price,stock_quantity,is_active,image_path,category_id,sort_order,created_at').is('deleted_at',null).order('sort_order').limit(200);
   if(error)throw error;return json(res,200,{data:data||[]});
  }
  if(req.method==='POST'){
   const b=req.body||{};if(!validText(b.name,120)||!Number.isFinite(b.price)||b.price<0||!Number.isInteger(b.stock_quantity)||b.stock_quantity<0)return json(res,400,{error:{code:'VALIDATION_ERROR',message:'Nama, harga, atau stok tidak valid.'}});
   const payload={name:b.name.trim(),description:typeof b.description==='string'?b.description.slice(0,3000):'',price:b.price,stock_quantity:b.stock_quantity,is_active:false,category_id:b.category_id||null,image_path:null,sort_order:Number.isInteger(b.sort_order)?b.sort_order:0};
   const {data,error}=await db.from('products').insert(payload).select().single();if(error)throw error;
   await db.from('admin_audit_logs').insert({actor_id:auth.user.id,action:'product.create',entity_type:'product',entity_id:data.id,metadata:{name:data.name}});
   return json(res,201,{data});
  }
  return method(req,res,['GET','POST'])?json(res,405,{error:{code:'METHOD_NOT_ALLOWED',message:'Metode tidak didukung.'}}):undefined;
 }catch(e){return fail(res,{status:500,code:'PRODUCT_OPERATION_FAILED',message:'Operasi produk gagal. Periksa migrasi dan validasi data.'});}
}
