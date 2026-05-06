-- BJ Burguers menu seed
-- Idempotent seed for ingredients, products, and recipes.
-- Note: stock is intentionally left as NULL so you can enable it later from the app.

-- 0) REQUIRED UNIQUE INDEXES FOR IDEMPOTENT UPSERTS
ALTER TABLE public.ingredients
ADD COLUMN IF NOT EXISTS stock_quantity numeric(12, 3);

ALTER TABLE public.products
ADD COLUMN IF NOT EXISTS stock_quantity numeric(12, 3),
ADD COLUMN IF NOT EXISTS track_stock boolean NOT NULL DEFAULT false;

CREATE UNIQUE INDEX IF NOT EXISTS ingredients_name_uidx
ON public.ingredients (name);

CREATE UNIQUE INDEX IF NOT EXISTS products_name_uidx
ON public.products (name);

CREATE UNIQUE INDEX IF NOT EXISTS product_recipe_items_product_ingredient_uidx
ON public.product_recipe_items (product_id, ingredient_id);

-- 1) INGREDIENTS
INSERT INTO public.ingredients (name, unit_name, current_unit_cost)
VALUES
  ('Pan de hamburguesa', 'pieza', NULL),
  ('Pan de hot dog', 'pieza', NULL),
  ('Carne Angus', 'pieza', NULL),
  ('Queso americano', 'rebanada', NULL),
  ('Jamon', 'rebanada', NULL),
  ('Tocino', 'rebanada', NULL),
  ('Aros de cebolla', 'gramos', NULL),
  ('Salsa BBQ', 'ml', NULL),
  ('Pina asada', 'rebanada', NULL),
  ('Queso asadero', 'gramos', NULL),
  ('Salchicha premium', 'pieza', NULL),
  ('Salchichon', 'gramos', NULL),
  ('Mayonesa', 'ml', NULL),
  ('Mostaza', 'ml', NULL),
  ('Catsup', 'ml', NULL),
  ('Lechuga', 'gramos', NULL),
  ('Tomate', 'gramos', NULL),
  ('Cebolla', 'gramos', NULL),
  ('Cebolla caramelizada Jack Daniels', 'gramos', NULL),
  ('Papas', 'gramos', NULL),
  ('Coca-Cola 600ml', 'pieza', NULL),
  ('Coca-Cola Zero 600ml', 'pieza', NULL),
  ('Delaware 600ml', 'pieza', NULL),
  ('Manzanita 600ml', 'pieza', NULL),
  ('Fanta 600ml', 'pieza', NULL)
ON CONFLICT (name) DO UPDATE
SET unit_name = EXCLUDED.unit_name;

-- 2) PRODUCTS
INSERT INTO public.products (name, category_name, product_type, sale_price, direct_cost, stock_quantity, track_stock, display_order)
VALUES
  ('Clasica', 'Hamburguesas', 'recipe', 69, 0, NULL, false, 1),
  ('BBQ', 'Hamburguesas', 'recipe', 89, 0, NULL, false, 2),
  ('Hawaiana', 'Hamburguesas', 'recipe', 79, 0, NULL, false, 3),
  ('Salchiburger', 'Hamburguesas', 'recipe', 79, 0, NULL, false, 4),
  ('Mounstrosa', 'Hamburguesas', 'recipe', 169, 0, NULL, false, 5),

  ('Hot Dog Clasico', 'Hot Dogs', 'recipe', 49, 0, NULL, false, 10),
  ('Salchi-Dog', 'Hot Dogs', 'recipe', 69, 0, NULL, false, 11),
  ('Hot Dog Jack Daniels', 'Hot Dogs', 'recipe', 69, 0, NULL, false, 12),

  ('Orden de Papas (350gr)', 'Complementos', 'recipe', 45, 0, NULL, false, 20),
  ('Orden de Aros de Cebolla (250gr)', 'Complementos', 'recipe', 45, 0, NULL, false, 21),

  ('Porcion de Papas (150gr)', 'Extras', 'simple', 15, 0, NULL, true, 30),
  ('Tocino Extra', 'Extras', 'simple', 15, 0, NULL, true, 31),
  ('Queso Asadero Extra', 'Extras', 'simple', 15, 0, NULL, true, 32),
  ('Pina Asada Extra', 'Extras', 'simple', 15, 0, NULL, true, 33),
  ('Salchichon Extra', 'Extras', 'simple', 20, 0, NULL, true, 34),
  ('Carne Extra', 'Extras', 'simple', 25, 0, NULL, true, 35),

  ('Coca-Cola 600ml', 'Bebidas', 'simple', 35, 0, NULL, false, 40),
  ('Coca-Cola Zero 600ml', 'Bebidas', 'simple', 30, 0, NULL, false, 41),
  ('Delaware 600ml', 'Bebidas', 'simple', 30, 0, NULL, false, 42),
  ('Manzanita 600ml', 'Bebidas', 'simple', 30, 0, NULL, false, 43),
  ('Fanta 600ml', 'Bebidas', 'simple', 30, 0, NULL, false, 44)
ON CONFLICT (name) DO UPDATE
SET
  category_name = EXCLUDED.category_name,
  product_type = EXCLUDED.product_type,
  sale_price = EXCLUDED.sale_price,
  direct_cost = EXCLUDED.direct_cost,
  stock_quantity = EXCLUDED.stock_quantity,
  track_stock = EXCLUDED.track_stock,
  display_order = EXCLUDED.display_order;

-- 3) RECIPES
WITH recipe_data(product_name, ingredient_name, quantity, is_optional) AS (
  VALUES
    -- CLASICA
    ('Clasica','Pan de hamburguesa',1,false),
    ('Clasica','Carne Angus',1,false),
    ('Clasica','Queso americano',1,false),
    ('Clasica','Jamon',1,false),
    ('Clasica','Lechuga',20,true),
    ('Clasica','Tomate',20,true),
    ('Clasica','Cebolla',15,true),
    ('Clasica','Mayonesa',10,true),
    ('Clasica','Mostaza',5,true),
    ('Clasica','Catsup',10,true),

    -- BBQ
    ('BBQ','Pan de hamburguesa',1,false),
    ('BBQ','Carne Angus',1,false),
    ('BBQ','Queso americano',1,false),
    ('BBQ','Tocino',2,false),
    ('BBQ','Aros de cebolla',40,false),
    ('BBQ','Salsa BBQ',20,false),

    -- HAWAIANA
    ('Hawaiana','Pan de hamburguesa',1,false),
    ('Hawaiana','Carne Angus',1,false),
    ('Hawaiana','Queso americano',1,false),
    ('Hawaiana','Pina asada',1,false),
    ('Hawaiana','Queso asadero',30,false),
    ('Hawaiana','Jamon',1,false),

    -- SALCHIBURGER
    ('Salchiburger','Pan de hamburguesa',1,false),
    ('Salchiburger','Carne Angus',1,false),
    ('Salchiburger','Queso americano',1,false),
    ('Salchiburger','Salchichon',40,false),
    ('Salchiburger','Queso asadero',30,false),

    -- MOUNSTROSA
    ('Mounstrosa','Pan de hamburguesa',1,false),
    ('Mounstrosa','Carne Angus',2,false),
    ('Mounstrosa','Queso americano',2,false),
    ('Mounstrosa','Salchichon',50,false),
    ('Mounstrosa','Queso asadero',40,false),
    ('Mounstrosa','Aros de cebolla',50,false),
    ('Mounstrosa','Tocino',3,false),

    -- HOT DOG CLASICO
    ('Hot Dog Clasico','Pan de hot dog',1,false),
    ('Hot Dog Clasico','Salchicha premium',1,false),
    ('Hot Dog Clasico','Mayonesa',10,true),
    ('Hot Dog Clasico','Mostaza',5,true),
    ('Hot Dog Clasico','Catsup',10,true),
    ('Hot Dog Clasico','Tomate',15,true),
    ('Hot Dog Clasico','Cebolla',15,true),

    -- SALCHI-DOG
    ('Salchi-Dog','Pan de hot dog',1,false),
    ('Salchi-Dog','Salchicha premium',1,false),
    ('Salchi-Dog','Salchichon',40,false),
    ('Salchi-Dog','Queso asadero',30,false),
    ('Salchi-Dog','Tocino',2,false),

    -- JACK DANIELS
    ('Hot Dog Jack Daniels','Pan de hot dog',1,false),
    ('Hot Dog Jack Daniels','Salchicha premium',1,false),
    ('Hot Dog Jack Daniels','Tocino',2,false),
    ('Hot Dog Jack Daniels','Queso asadero',30,false),
    ('Hot Dog Jack Daniels','Salsa BBQ',20,false),
    ('Hot Dog Jack Daniels','Cebolla caramelizada Jack Daniels',30,false),

    -- COMPLEMENTOS COMO RECETA
    ('Orden de Papas (350gr)','Papas',350,false),
    ('Orden de Aros de Cebolla (250gr)','Aros de cebolla',250,false)
)
INSERT INTO public.product_recipe_items (product_id, ingredient_id, quantity_used, is_optional)
SELECT
  p.id,
  i.id,
  r.quantity,
  r.is_optional
FROM recipe_data r
JOIN public.products p ON p.name = r.product_name
JOIN public.ingredients i ON i.name = r.ingredient_name
ON CONFLICT (product_id, ingredient_id) DO UPDATE
SET
  quantity_used = EXCLUDED.quantity_used,
  is_optional = EXCLUDED.is_optional;

-- 4) BASES OBLIGATORIAS (HAMBURGUESAS Y HOT DOGS)
WITH burger_base(ingredient_name, quantity_used, is_optional) AS (
  VALUES
    ('Pan de hamburguesa', 1, false),
    ('Carne Angus', 1, false),
    ('Queso americano', 1, false),
    ('Lechuga', 20, true),
    ('Tomate', 20, true),
    ('Cebolla', 15, true),
    ('Mayonesa', 10, true),
    ('Mostaza', 5, true),
    ('Catsup', 10, true)
),
hotdog_base(ingredient_name, quantity_used, is_optional) AS (
  VALUES
    ('Pan de hot dog', 1, false),
    ('Salchicha premium', 1, false),
    ('Tomate', 15, true),
    ('Cebolla', 15, true),
    ('Mayonesa', 10, true),
    ('Mostaza', 5, true),
    ('Catsup', 10, true)
)
INSERT INTO public.product_recipe_items (
  product_id,
  ingredient_id,
  quantity_used,
  is_optional
)
SELECT
  p.id,
  i.id,
  base.quantity_used,
  base.is_optional
FROM public.products p
JOIN burger_base base ON p.category_name = 'Hamburguesas'
JOIN public.ingredients i ON i.name = base.ingredient_name
LEFT JOIN public.product_recipe_items pri
  ON pri.product_id = p.id AND pri.ingredient_id = i.id
WHERE pri.id IS NULL
UNION ALL
SELECT
  p.id,
  i.id,
  base.quantity_used,
  base.is_optional
FROM public.products p
JOIN hotdog_base base ON p.category_name = 'Hot Dogs'
JOIN public.ingredients i ON i.name = base.ingredient_name
LEFT JOIN public.product_recipe_items pri
  ON pri.product_id = p.id AND pri.ingredient_id = i.id
WHERE pri.id IS NULL;
