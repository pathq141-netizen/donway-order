-- DONWAY: support banner images for catalog products.
alter table public.products add column if not exists banner_path text;
