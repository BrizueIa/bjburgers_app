grant usage on schema public to anon, authenticated;

grant select, insert, update, delete on table public.settings to anon, authenticated;
grant select, insert, update, delete on table public.ingredients to anon, authenticated;
grant select, insert, update, delete on table public.products to anon, authenticated;
grant select, insert, update, delete on table public.product_recipe_items to anon, authenticated;
grant select, insert, update, delete on table public.ingredient_purchases to anon, authenticated;
grant select, insert, update, delete on table public.orders to anon, authenticated;
grant select, insert, update, delete on table public.order_items to anon, authenticated;
grant select, insert, update, delete on table public.sales to anon, authenticated;
grant select, insert, update, delete on table public.sale_items to anon, authenticated;
grant select, insert, update, delete on table public.cash_sessions to anon, authenticated;
grant select, insert, update, delete on table public.cash_movements to anon, authenticated;
grant select, insert, update, delete on table public.app_assets to anon, authenticated;
grant select, insert, update, delete on table public.sync_queue to anon, authenticated;

alter table public.settings enable row level security;
alter table public.ingredients enable row level security;
alter table public.products enable row level security;
alter table public.product_recipe_items enable row level security;
alter table public.ingredient_purchases enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;
alter table public.sales enable row level security;
alter table public.sale_items enable row level security;
alter table public.cash_sessions enable row level security;
alter table public.cash_movements enable row level security;
alter table public.app_assets enable row level security;
alter table public.sync_queue enable row level security;

drop policy if exists settings_open_access on public.settings;
create policy settings_open_access on public.settings
for all
to anon, authenticated
using (true)
with check (true);

drop policy if exists ingredients_open_access on public.ingredients;
create policy ingredients_open_access on public.ingredients
for all
to anon, authenticated
using (true)
with check (true);

drop policy if exists products_open_access on public.products;
create policy products_open_access on public.products
for all
to anon, authenticated
using (true)
with check (true);

drop policy if exists product_recipe_items_open_access on public.product_recipe_items;
create policy product_recipe_items_open_access on public.product_recipe_items
for all
to anon, authenticated
using (true)
with check (true);

drop policy if exists ingredient_purchases_open_access on public.ingredient_purchases;
create policy ingredient_purchases_open_access on public.ingredient_purchases
for all
to anon, authenticated
using (true)
with check (true);

drop policy if exists orders_open_access on public.orders;
create policy orders_open_access on public.orders
for all
to anon, authenticated
using (true)
with check (true);

drop policy if exists order_items_open_access on public.order_items;
create policy order_items_open_access on public.order_items
for all
to anon, authenticated
using (true)
with check (true);

drop policy if exists sales_open_access on public.sales;
create policy sales_open_access on public.sales
for all
to anon, authenticated
using (true)
with check (true);

drop policy if exists sale_items_open_access on public.sale_items;
create policy sale_items_open_access on public.sale_items
for all
to anon, authenticated
using (true)
with check (true);

drop policy if exists cash_sessions_open_access on public.cash_sessions;
create policy cash_sessions_open_access on public.cash_sessions
for all
to anon, authenticated
using (true)
with check (true);

drop policy if exists cash_movements_open_access on public.cash_movements;
create policy cash_movements_open_access on public.cash_movements
for all
to anon, authenticated
using (true)
with check (true);

drop policy if exists app_assets_open_access on public.app_assets;
create policy app_assets_open_access on public.app_assets
for all
to anon, authenticated
using (true)
with check (true);

drop policy if exists sync_queue_open_access on public.sync_queue;
create policy sync_queue_open_access on public.sync_queue
for all
to anon, authenticated
using (true)
with check (true);
