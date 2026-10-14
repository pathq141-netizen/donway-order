import { createClient } from '@supabase/supabase-js';
export default async function handler(req,res){
 res.setHeader('Cache-Control','no-store');
 if(req.method!=='GET'){res.setHeader('Allow','GET');return res.status(405).json({error:'Metode tidak didukung.'});}
 const url=process.env.SUPABASE_URL, key=process.env.SUPABASE_SERVICE_ROLE_KEY;
 if(!url||!key)return res.status(503).json({error:'Katalog belum dikonfigurasi.'});
 try{
  const db=createClient(url,key,{auth:{autoRefreshToken:false,persistSession:false}});
  const [{data:categories,error:ce},{data:products,error:pe}]=await Promise.all([
   db.from('product_categories').select('id,name,slug,sort_order').eq('is_active',true).is('deleted_at',null).order('sort_order').order('name'),
   db.from('products').select('id,name,description,price,stock_quantity,image_path,banner_path,category_id,product_categories(name)').eq('is_active',true).is('deleted_at',null).order('sort_order').order('created_at',{ascending:false}).limit(500)
  ]);
  if(ce)throw ce;if(pe)throw pe;
  const publicUrl=path=>path?db.storage.from('donway-product-images').getPublicUrl(path).data.publicUrl:null;
  return res.status(200).json({categories:categories||[],products:(products||[]).map(p=>({id:p.id,name:p.name,description:p.description,price:Number(p.price),stock_quantity:p.stock_quantity,category_id:p.category_id,category:p.product_categories?.name||'Lainnya',icon:publicUrl(p.image_path),banner:publicUrl(p.banner_path)}))});
 }catch(e){console.error('[DONWAY CATALOG ERROR]',{message:e?.message,code:e?.code});return res.status(500).json({error:'Gagal memuat katalog.'});}
}
