# SamaStock — Liaison et Configuration Supabase

Guide complet pour connecter votre projet SamaStock à une base de données **Supabase**.

---

## 📋 Prérequis

- Un compte sur [Supabase.com](https://supabase.co) (gratuit).
- Le fichier `index.html` de votre projet SamaStock.
- Le fichier `schema.sql` inclus dans ce dépôt.

---

## 🚀 Étape 1 : Créer un projet Supabase

1. Connectez-vous sur [Supabase Dashboard](https://database.new) et cliquez sur **New Project**.
2. Renseignez :
   - **Name** : `samastock` (ou le nom de votre choix).
   - **Database Password** : Définissez un mot de passe sécurisé.
   - **Region** : Choisissez la région la plus proche (ex. *Europe West - Frankfurt*).
3. Cliquez sur **Create new project** et patientez 1 à 2 minutes le temps que la base de données soit initialisée.

---

## 🗄️ Étape 2 : Exécuter le script de base de données (`schema.sql`)

1. Dans le menu de gauche sur Supabase, cliquez sur **SQL Editor** (icône `>/_`).
2. Cliquez sur **New Query**.
3. Ouvrez le fichier `schema.sql` présent à la racine de ce dépôt, copiez tout son contenu et collez-le dans l'éditeur SQL de Supabase.
4. Cliquez sur le bouton **Run** (ou `Ctrl + Enter` / `Cmd + Enter`).
5. Vous devez voir le message `Success. No rows returned`.

> **Ce que fait ce script :**
> - Active l'extension `uuid-ossp`.
> - Crée les tables : `shops`, `subscriptions`, `products`, `customers`, `sales`, `sale_items`, `stock_movements`, `debt_payments`.
> - Crée la vue `customer_balances` pour calculer les dettes des clients.
> - Configure les procédures stockées (`record_sale`, `record_stock_movement`).
> - Déclenche automatiquement un essai gratuit de 30 jours à la création d'une boutique (`handle_new_shop`).
> - Active la sécurité **Row Level Security (RLS)** pour isoler les données de chaque utilisateur.

---

## 🔑 Étape 3 : Récupérer les clés API Supabase

1. Dans votre projet Supabase, allez dans **Project Settings** (icône d'engrenage ⚙️ en bas à gauche) > **API**.
2. Récupérez les informations suivantes :
   - **Project URL** (ex. `https://xxxx.supabase.co`).
   - **anon public key** (clé publique qui commence par `eyJ...` ou `sb_publishable_...`).

---

## ⚙️ Étape 4 : Configurer `index.html`

Ouvrez le fichier `index.html` dans votre éditeur de code et modifiez les variables au début du script JS (vers la ligne 170) :

```javascript
var SB_URL = 'https://VOTRE_PROJET.supabase.co'; // Remplacez par votre Project URL
var SB_KEY = 'VOTRE_CLÉ_ANON_PUBLIC';            // Remplacez par votre clé publique (anon)
```

---

## 📧 Étape 5 : Configuration de l'Authentification (Optionnel)

Par défaut, l'authentification par e-mail / mot de passe est activée sur Supabase.
Si vous désirez désactiver la confirmation par e-mail obligatoire pour les nouveaux utilisateurs lors des tests :
1. Dans Supabase, allez dans **Authentication** > **Providers** > **Email**.
2. Décochez **Confirm email**.
3. Cliquez sur **Save**.

---

## 📦 Structure des données dans Supabase

- `shops` : Boutiques créées par les utilisateurs (`owner_id`).
- `products` : Stock des produits avec prix d'achat, de vente, quantité et seuil d'alerte.
- `customers` : Liste des clients.
- `sales` & `sale_items` : Historique des ventes et détails des articles vendus.
- `stock_movements` : Entrées et sorties de stock.
- `debt_payments` : Historique des remboursements de dettes.
- `subscriptions` : Suivi des abonnements (`gratuit`, `essai`, `pro`).
