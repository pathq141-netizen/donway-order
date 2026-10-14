import {
requireAdmin,
json,
method,
fail
} from '../_lib/supabase.js';

export default async function handler(req, res) {
if (!method(req, res, ['GET'])) return;

try {
const auth = await requireAdmin(req);

if (auth.error) {
  return fail(res, auth.error);
}

const db = auth.sb;

const count = async (table, query = (q) => q) => {
  let q = db
    .from(table)
    .select('*', { count: 'exact', head: true });

  q = query(q);

  const result = await q;

  if (result.error) {
    console.error('[DONWAY SUMMARY QUERY ERROR]', {
      table,
      code: result.error.code,
      message: result.error.message,
      details: result.error.details,
      hint: result.error.hint
    });

    throw result.error;
  }

  return result.count || 0;
};

const [
  users,
  blocked,
  orders,
  pendingTopups,
  products,
  activities
] = await Promise.all([
  count('profiles'),
  count('profiles', (q) => q.eq('status', 'blocked')),
  count('orders'),
  count('topup_requests', (q) => q.eq('status', 'pending')),
  count('products', (q) => q.is('deleted_at', null)),
  db
    .from('admin_audit_logs')
    .select('id,action,entity_type,created_at,actor_id')
    .order('created_at', { ascending: false })
    .limit(10)
]);

if (activities.error) {
  console.error('[DONWAY SUMMARY QUERY ERROR]', {
    table: 'admin_audit_logs',
    code: activities.error.code,
    message: activities.error.message,
    details: activities.error.details,
    hint: activities.error.hint
  });

  throw activities.error;
}

return json(res, 200, {
  data: {
    users,
    blocked,
    orders,
    pendingTopups,
    products,
    activities: activities.data || []
  }
});

} catch (e) {
console.error('[DONWAY SUMMARY ERROR]', {
message: e?.message,
code: e?.code,
details: e?.details,
hint: e?.hint
});

return fail(res, {
  status: 500,
  code: 'SUMMARY_FAILED',
  message: 'Tidak dapat memuat ringkasan dashboard.'
});

}
}
