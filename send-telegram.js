// Legacy Telegram sender disabled. The old implementation forwarded passwords/PINs.
// Keep this file only as a compatibility notice; no outbound request is performed.
export default function handler(req,res){
 res.setHeader('Cache-Control','no-store');
 if(req.method!=='POST'){res.setHeader('Allow','POST');return res.status(405).json({error:{code:'METHOD_NOT_ALLOWED',message:'Metode tidak didukung.'}})}
 return res.status(410).json({error:{code:'LEGACY_ENDPOINT_DISABLED',message:'Pengirim Telegram lama telah dinonaktifkan demi keamanan.'}});
}
