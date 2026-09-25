-- Schema Supabase pour SamaStock
-- Exécutez ce script dans l'éditeur SQL de votre projet Supabase.

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. Table Shops (Boutiques)
CREATE TABLE IF NOT EXISTS public.shops (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. Table Subscriptions (Abonnements)
CREATE TABLE IF NOT EXISTS public.subscriptions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    shop_id UUID NOT NULL UNIQUE REFERENCES public.shops(id) ON DELETE CASCADE,
    plan TEXT NOT NULL DEFAULT 'essai', -- 'gratuit', 'essai', 'pro'
    ends_at TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '30 days'),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 3. Table Products (Produits)
CREATE TABLE IF NOT EXISTS public.products (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    shop_id UUID NOT NULL REFERENCES public.shops(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    buy_price INTEGER NOT NULL DEFAULT 0,
    sell_price INTEGER NOT NULL DEFAULT 0,
    qty INTEGER NOT NULL DEFAULT 0,
    alert_threshold INTEGER NOT NULL DEFAULT 10,
    archived BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 4. Table Customers (Clients)
CREATE TABLE IF NOT EXISTS public.customers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    shop_id UUID NOT NULL REFERENCES public.shops(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    phone TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 5. Table Sales (Ventes)
CREATE TABLE IF NOT EXISTS public.sales (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    shop_id UUID NOT NULL REFERENCES public.shops(id) ON DELETE CASCADE,
    customer_id UUID REFERENCES public.customers(id) ON DELETE SET NULL,
    total INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 6. Table Sale Items (Lignes de vente)
CREATE TABLE IF NOT EXISTS public.sale_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    sale_id UUID NOT NULL REFERENCES public.sales(id) ON DELETE CASCADE,
    product_id UUID REFERENCES public.products(id) ON DELETE SET NULL,
    product_name TEXT NOT NULL,
    qty INTEGER NOT NULL DEFAULT 1,
    buy_price INTEGER NOT NULL DEFAULT 0,
    sell_price INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 7. Table Stock Movements (Mouvements de stock)
CREATE TABLE IF NOT EXISTS public.stock_movements (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    shop_id UUID NOT NULL REFERENCES public.shops(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
    kind TEXT NOT NULL CHECK (kind IN ('entree', 'sortie')),
    qty INTEGER NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 8. Table Debt Payments (Paiements de dettes)
CREATE TABLE IF NOT EXISTS public.debt_payments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    shop_id UUID NOT NULL REFERENCES public.shops(id) ON DELETE CASCADE,
    customer_id UUID NOT NULL REFERENCES public.customers(id) ON DELETE CASCADE,
    amount INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 9. Vue Customer Balances (Solde des dettes clients)
CREATE OR REPLACE VIEW public.customer_balances AS
SELECT
    c.id AS customer_id,
    c.shop_id,
    c.name,
    c.phone,
    COALESCE(sales_total.total_credit, 0) - COALESCE(payments_total.total_paid, 0) AS balance
FROM public.customers c
LEFT JOIN (
    SELECT customer_id, SUM(total) AS total_credit
    FROM public.sales
    WHERE customer_id IS NOT NULL
    GROUP BY customer_id
) sales_total ON sales_total.customer_id = c.id
LEFT JOIN (
    SELECT customer_id, SUM(amount) AS total_paid
    FROM public.debt_payments
    GROUP BY customer_id
) payments_total ON payments_total.customer_id = c.id;

-- 10. Trigger automatique à la création d'une boutique pour démarrer l'essai gratuit
CREATE OR REPLACE FUNCTION public.handle_new_shop()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.subscriptions (shop_id, plan, ends_at)
    VALUES (NEW.id, 'essai', NOW() + INTERVAL '30 days');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_shop_created ON public.shops;
CREATE TRIGGER on_shop_created
    AFTER INSERT ON public.shops
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_shop();

-- 11. RPC: Enregistrer un mouvement de stock
CREATE OR REPLACE FUNCTION public.record_stock_movement(
    p_shop_id UUID,
    p_product_id UUID,
    p_kind TEXT,
    p_qty INT
)
RETURNS VOID AS $$
DECLARE
    v_current_qty INT;
BEGIN
    IF p_qty <= 0 THEN
        RAISE EXCEPTION 'La quantité doit être supérieure à 0';
    END IF;

    SELECT qty INTO v_current_qty
    FROM public.products
    WHERE id = p_product_id AND shop_id = p_shop_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Produit non trouvé';
    END IF;

    IF p_kind = 'sortie' THEN
        IF v_current_qty < p_qty THEN
            RAISE EXCEPTION 'Stock insuffisant';
        END IF;
        UPDATE public.products
        SET qty = qty - p_qty
        WHERE id = p_product_id;
    ELSIF p_kind = 'entree' THEN
        UPDATE public.products
        SET qty = qty + p_qty
        WHERE id = p_product_id;
    ELSE
        RAISE EXCEPTION 'Type de mouvement invalide';
    END IF;

    INSERT INTO public.stock_movements (shop_id, product_id, kind, qty)
    VALUES (p_shop_id, p_product_id, p_kind, p_qty);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 12. RPC: Enregistrer une vente
CREATE OR REPLACE FUNCTION public.record_sale(
    p_shop_id UUID,
    p_customer_id UUID,
    p_items JSONB
)
RETURNS UUID AS $$
DECLARE
    v_sale_id UUID;
    v_item JSONB;
    v_product RECORD;
    v_total_sale INT := 0;
    v_item_qty INT;
BEGIN
    IF JSONB_ARRAY_LENGTH(p_items) = 0 THEN
        RAISE EXCEPTION 'Le panier est vide';
    END IF;

    -- Vérifier le stock pour tous les articles
    FOR v_item IN SELECT * FROM JSONB_ARRAY_ELEMENTS(p_items) LOOP
        v_item_qty := (v_item->>'qty')::INT;

        SELECT name, buy_price, sell_price, qty
        INTO v_product
        FROM public.products
        WHERE id = (v_item->>'product_id')::UUID AND shop_id = p_shop_id;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'Produit non trouvé';
        END IF;

        IF v_product.qty < v_item_qty THEN
            RAISE EXCEPTION 'Stock insuffisant pour le produit %', v_product.name;
        END IF;

        v_total_sale := v_total_sale + (v_product.sell_price * v_item_qty);
    END LOOP;

    -- Créer la vente
    INSERT INTO public.sales (shop_id, customer_id, total)
    VALUES (p_shop_id, p_customer_id, v_total_sale)
    RETURNING id INTO v_sale_id;

    -- Insérer les éléments de la vente, réduire le stock et enregistrer le mouvement
    FOR v_item IN SELECT * FROM JSONB_ARRAY_ELEMENTS(p_items) LOOP
        v_item_qty := (v_item->>'qty')::INT;

        SELECT name, buy_price, sell_price
        INTO v_product
        FROM public.products
        WHERE id = (v_item->>'product_id')::UUID AND shop_id = p_shop_id;

        INSERT INTO public.sale_items (sale_id, product_id, product_name, qty, buy_price, sell_price)
        VALUES (v_sale_id, (v_item->>'product_id')::UUID, v_product.name, v_item_qty, v_product.buy_price, v_product.sell_price);

        UPDATE public.products
        SET qty = qty - v_item_qty
        WHERE id = (v_item->>'product_id')::UUID;

        INSERT INTO public.stock_movements (shop_id, product_id, kind, qty)
        VALUES (p_shop_id, (v_item->>'product_id')::UUID, 'sortie', v_item_qty);
    END LOOP;

    RETURN v_sale_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 13. Activer Row Level Security (RLS) sur toutes les tables
ALTER TABLE public.shops ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sales ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sale_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stock_movements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.debt_payments ENABLE ROW LEVEL SECURITY;

-- Helper Function pour vérifier la propriété de la boutique
CREATE OR REPLACE FUNCTION public.user_owns_shop(p_shop_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.shops
        WHERE id = p_shop_id AND owner_id = auth.uid()
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RLS Policies
-- Shops
CREATE POLICY "Les utilisateurs gèrent leurs propres boutiques" ON public.shops
    FOR ALL USING (owner_id = auth.uid());

-- Subscriptions
CREATE POLICY "Les utilisateurs voient l'abonnement de leur boutique" ON public.subscriptions
    FOR ALL USING (public.user_owns_shop(shop_id));

-- Products
CREATE POLICY "Les utilisateurs gèrent les produits de leur boutique" ON public.products
    FOR ALL USING (public.user_owns_shop(shop_id));

-- Customers
CREATE POLICY "Les utilisateurs gèrent les clients de leur boutique" ON public.customers
    FOR ALL USING (public.user_owns_shop(shop_id));

-- Sales
CREATE POLICY "Les utilisateurs gèrent les ventes de leur boutique" ON public.sales
    FOR ALL USING (public.user_owns_shop(shop_id));

-- Sale Items
CREATE POLICY "Les utilisateurs gèrent les articles de vente de leur boutique" ON public.sale_items
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.sales s
            WHERE s.id = sale_items.sale_id AND public.user_owns_shop(s.shop_id)
        )
    );

-- Stock Movements
CREATE POLICY "Les utilisateurs gèrent les mouvements de stock de leur boutique" ON public.stock_movements
    FOR ALL USING (public.user_owns_shop(shop_id));

-- Debt Payments
CREATE POLICY "Les utilisateurs gèrent les paiements de dettes de leur boutique" ON public.debt_payments
    FOR ALL USING (public.user_owns_shop(shop_id));
