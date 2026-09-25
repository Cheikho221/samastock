# SamaStock — Logiciel de Gestion de Stock & Ventes pour Commerçants et Grossistes au Sénégal

**SamaStock** est une application SaaS mobile-first conçue pour les détaillants, dem-grossistes et grossistes au Sénégal.

---

## ✨ Fonctionnalités Principales

- **📦 Gestion de Stock & Réapprovisionnements** : Suivi en temps réel des stocks, entrées et sorties, seuils d'alerte configurables et alertes de rupture.
- **🏷️ Tarification Dégressive Grossiste** : Support des prix de vente au détail et des prix de vente en gros avec seuil de quantité minimale (ex. prix de gros s'appliquant dès 10 unités).
- **💰 Caisse & Ventes** : Vente au comptant ou à crédit client en quelques clics, calcul automatique des totaux et des bénéfices estimés.
- **👥 Clients & Crédits (Carnet de Dettes)** : Gestion des clients, suivi des dettes, enregistrement des versements et relances clients directes sur WhatsApp.
- **🏭 Fournisseurs & Achats** : Suivi des fournisseurs, bons de livraison/achats, enregistrement du montant payé/crédit et suivi des dettes fournisseurs.
- **💳 Abonnements adaptés au Sénégal** :
  - **Starter** : 5 000 FCFA/mois (Jusqu'à 25 produits, 10 clients, 5 fournisseurs)
  - **Business** : 10 000 FCFA/mois (Jusqu'à 100 produits, 50 clients, 25 fournisseurs)
  - **Pro Grossiste** : 15 000 FCFA/mois (Illimité + Tarification & Ventes en gros dégressives)
- **🇸🇳 Paiements Locaux** : Intégration Wave, Orange Money et PayDunya.

---

## 🗄️ Structure de la Base de Données (`schema.sql`)

- `shops` : Boutiques / commerces.
- `subscriptions` : Suivi des offres (`starter`, `business`, `pro_grossiste`, `essai`).
- `products` : Fiche produit (prix d'achat, prix détail, `wholesale_price`, `wholesale_min_qty`, quantité stock, seuil alerte).
- `customers` & `customer_balances` : Clients et calcul du reste à payer.
- `suppliers` & `supplier_balances` : Fournisseurs et suivi des dettes envers eux.
- `sales` & `sale_items` : Transactions de vente avec application automatique du prix gros.
- `supplier_purchases` & `supplier_payments` : Achats de réapprovisionnement auprès des fournisseurs et paiements.
- `stock_movements` : Mouvements de stock (entrées / sorties).

---

## 🚀 Installation & Configuration Supabase

1. Exécutez le contenu de `schema.sql` dans l'éditeur SQL de votre projet Supabase (**SQL Editor**).
2. Dans `index.html`, renseignez vos identifiants Supabase :
   ```javascript
   var SB_URL = 'https://VOTRE_PROJET.supabase.co';
   var SB_KEY = 'VOTRE_CLE_ANON_PUBLIC';
   ```
3. Ouvrez `index.html` dans n'importe quel navigateur mobile ou desktop.
