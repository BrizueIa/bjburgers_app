-- BJ Burguers menu seed
-- Idempotent seed for ingredients, products, and recipes.
-- Safe to run multiple times if unique constraints exist on:
--   public.ingredients(name)
--   public.products(name)
-- and on:
--   public.product_recipe_items(product_id, ingredient_id)

-- Recommended unique constraints if not created yet:
-- ALTER TABLE public.ingredients ADD CONSTRAINT ingredients_name_key UNIQUE (name);
-- ALTER TABLE public.products ADD CONSTRAINT products_name_key UNIQUE (name);

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
INSERT INTO public.products (name, category_name, product_type, sale_price, direct_cost, display_order)
VALUES
  ('Clasica', 'Hamburguesas', 'recipe', 69, 0, 1),
  ('BBQ', 'Hamburguesas', 'recipe', 89, 0, 2),
  ('Hawaiana', 'Hamburguesas', 'recipe', 79, 0, 3),
  ('Salchiburger', 'Hamburguesas', 'recipe', 79, 0, 4),
  ('Mounstrosa', 'Hamburguesas', 'recipe', 169, 0, 5),

  ('Hot Dog Clasico', 'Hot Dogs', 'recipe', 49, 0, 10),
  ('Salchi-Dog', 'Hot Dogs', 'recipe', 69, 0, 11),
  ('Hot Dog Jack Daniels', 'Hot Dogs', 'recipe', 69, 0, 12),

  ('Orden de Papas (350gr)', 'Complementos', 'simple', 45, 0, 20),
  ('Orden de Aros de Cebolla (250gr)', 'Complementos', 'simple', 45, 0, 21),

  ('Porcion de Papas (150gr)', 'Extras', 'simple', 15, 0, 30),
  ('Tocino Extra', 'Extras', 'simple', 15, 0, 31),
  ('Queso Asadero Extra', 'Extras', 'simple', 15, 0, 32),
  ('Pina Asada Extra', 'Extras', 'simple', 15, 0, 33),
  ('Salchichon Extra', 'Extras', 'simple', 20, 0, 34),
  ('Carne Extra', 'Extras', 'simple', 25, 0, 35),

  ('Coca-Cola 600ml', 'Bebidas', 'simple', 35, 0, 40),
  ('Coca-Cola Zero 600ml', 'Bebidas', 'simple', 30, 0, 41),
  ('Delaware 600ml', 'Bebidas', 'simple', 30, 0, 42),
  ('Manzanita 600ml', 'Bebidas', 'simple', 30, 0, 43),
  ('Fanta 600ml', 'Bebidas', 'simple', 30, 0, 44)
ON CONFLICT (name) DO UPDATE
SET
  category_name = EXCLUDED.category_name,
  product_type = EXCLUDED.product_type,
  sale_price = EXCLUDED.sale_price,
  direct_cost = EXCLUDED.direct_cost,
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
    ('Hot Dog Jack Daniels','Cebolla caramelizada Jack Daniels',30,false)
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
