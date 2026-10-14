// Deprecated intentionally: old endpoint accepted arbitrary browser data and could forward credentials/PINs.
export default function handler(req,res){
 res.setHeader('Cache-Control','no-store');
 if(req.method!=='POST'){res.setHeader('Allow','POST');return res.status(405).json({error:{code:'METHOD_NOT_ALLOWED',message:'Metode tidak didukung.'}})}
 return res.status(410).json({error:{code:'LEGACY_ENDPOINT_DISABLED',message:'Endpoint Telegram lama dinonaktifkan demi keamanan. Notifikasi hanya boleh dibuat backend melalui outbox terautentikasi.'}});
}
