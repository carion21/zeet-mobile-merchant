# API Endpoints — ZEET Partner/Merchant Mobile

Document de suivi de l'intégration des endpoints API dans l'application mobile merchant.
Mis à jour après chaque groupe d'intégration.

---

## Auth (4 endpoints)

| # | Méthode | Path | Description | Status |
|---|---------|------|-------------|--------|
| 1 | POST | `/v1/auth/login` | Login phone/password (surface=partner) | Implémenté |
| 2 | POST | `/v1/auth/refresh` | Rafraîchir le token | Implémenté |
| 3 | POST | `/v1/auth/logout` | Déconnexion | Implémenté |
| 4 | GET | `/v1/auth/me` | Profil partner enrichi | Implémenté |

## Profile (6 endpoints)

| # | Méthode | Path | Description | Status |
|---|---------|------|-------------|--------|
| 5 | GET | `/v1/partner/profile` | Récupérer profil | Implémenté |
| 6 | PATCH | `/v1/partner/profile` | Mettre à jour profil | Implémenté |
| 7 | GET | `/v1/partner/commission-rate` | Taux de commission | Implémenté |
| 8 | PATCH | `/v1/partner/availability` | Horaires d'ouverture (schedules) | Implémenté |
| 9 | POST | `/v1/partner/profile/logo` | Upload logo (multipart) | Implémenté |
| 10 | DELETE | `/v1/partner/profile/logo` | Supprimer logo | Implémenté |

## Dashboard (1 endpoint)

| # | Méthode | Path | Description | Status |
|---|---------|------|-------------|--------|
| 11 | GET | `/v1/partner/dashboard/summary` | KPIs : commandes, revenus, rating, paniers actifs, top produits | Implémenté |

## Stats (6 endpoints)

| # | Méthode | Path | Description | Status |
|---|---------|------|-------------|--------|
| 12 | GET | `/v1/partner/stats/revenue` | Revenus (date_from, date_to) | Implémenté |
| 13 | GET | `/v1/partner/stats/orders` | Stats commandes (date_from, date_to) | Implémenté |
| 14 | GET | `/v1/partner/stats/rating` | Stats notes | Implémenté |
| 15 | GET | `/v1/partner/stats/top-products` | Top produits (limit, dates) | Implémenté |
| 16 | GET | `/v1/partner/stats/top-categories` | Top catégories (limit, dates) | Implémenté |
| 17 | GET | `/v1/partner/stats/top-customers` | Top clients (limit, dates) | Implémenté |

## Menus (6 endpoints)

| # | Méthode | Path | Description | Status |
|---|---------|------|-------------|--------|
| 18 | GET | `/v1/partner/menus` | Lister les menus (paginé, search) | Implémenté |
| 19 | POST | `/v1/partner/menus` | Créer un menu | Implémenté |
| 20 | GET | `/v1/partner/menus/:id` | Détail menu | Implémenté |
| 21 | PATCH | `/v1/partner/menus/:id` | Modifier menu | Implémenté |
| 22 | PATCH | `/v1/partner/menus/:id/publish` | Publier menu | Implémenté |
| 23 | DELETE | `/v1/partner/menus/:id` | Supprimer menu | Implémenté |

## Product Categories (8 endpoints)

| # | Méthode | Path | Description | Status |
|---|---------|------|-------------|--------|
| 24 | GET | `/v1/partner/product-categories/select` | Dropdown catégories | Implémenté |
| 25 | GET | `/v1/partner/product-categories` | Lister (paginé, search) | Implémenté |
| 26 | GET | `/v1/partner/product-categories/:id` | Détail catégorie + produits | Implémenté |
| 27 | POST | `/v1/partner/product-categories` | Créer catégorie | Implémenté |
| 28 | PATCH | `/v1/partner/product-categories/:id` | Modifier catégorie | Implémenté |
| 29 | DELETE | `/v1/partner/product-categories/:id` | Supprimer catégorie | Implémenté |
| 30 | POST | `/v1/partner/product-categories/:id/picture` | Upload image catégorie | Implémenté |
| 31 | DELETE | `/v1/partner/product-categories/bulk` | Suppression en masse | Implémenté |

## Products (11 endpoints)

| # | Méthode | Path | Description | Status |
|---|---------|------|-------------|--------|
| 32 | GET | `/v1/partner/products` | Lister (paginé, filtrable par catégorie) | Implémenté |
| 33 | POST | `/v1/partner/products` | Créer produit | Implémenté |
| 34 | GET | `/v1/partner/products/:id` | Détail produit | Implémenté |
| 35 | PATCH | `/v1/partner/products/:id` | Modifier produit | Implémenté |
| 36 | PATCH | `/v1/partner/products/:id/availability` | Toggle disponibilité | Implémenté |
| 37 | DELETE | `/v1/partner/products/:id` | Supprimer produit | Implémenté |
| 38 | POST | `/v1/partner/products/:id/pictures` | Upload image produit | Implémenté |
| 39 | GET | `/v1/partner/products/:id/pictures` | Lister images (URLs MinIO) | Implémenté |
| 40 | DELETE | `/v1/partner/products/:id/pictures/:pic_id` | Supprimer image | Implémenté |
| 41 | PATCH | `/v1/partner/products/bulk` | Action en masse (activate/deactivate/delete) | Implémenté |
| 42 | POST | `/v1/partner/products/:id/duplicate` | Dupliquer produit | Implémenté |

## Product Variants (4 endpoints)

| # | Méthode | Path | Description | Status |
|---|---------|------|-------------|--------|
| 43 | GET | `/v1/partner/products/:id/variants` | Lister variantes | Implémenté |
| 44 | POST | `/v1/partner/products/:id/variants` | Créer variante | Implémenté |
| 45 | PATCH | `/v1/partner/products/:id/variants/:vid` | Modifier variante | Implémenté |
| 46 | DELETE | `/v1/partner/products/:id/variants/:vid` | Supprimer variante | Implémenté |

## Product Option Groups + Items (8 endpoints)

| # | Méthode | Path | Description | Status |
|---|---------|------|-------------|--------|
| 47 | GET | `/v1/partner/products/:id/option-groups` | Lister groupes d'options | Implémenté |
| 48 | POST | `/v1/partner/products/:id/option-groups` | Créer groupe | Implémenté |
| 49 | PATCH | `/v1/partner/products/:id/option-groups/:gid` | Modifier groupe | Implémenté |
| 50 | DELETE | `/v1/partner/products/:id/option-groups/:gid` | Supprimer groupe | Implémenté |
| 51 | GET | `/v1/partner/products/:id/option-groups/:gid/items` | Lister items d'option | Implémenté |
| 52 | POST | `/v1/partner/products/:id/option-groups/:gid/items` | Créer item | Implémenté |
| 53 | PATCH | `/v1/partner/products/:id/option-groups/:gid/items/:iid` | Modifier item | Implémenté |
| 54 | DELETE | `/v1/partner/products/:id/option-groups/:gid/items/:iid` | Supprimer item | Implémenté |

## Product Stats (2 endpoints)

| # | Méthode | Path | Description | Status |
|---|---------|------|-------------|--------|
| 55 | GET | `/v1/partner/products/:id/stats` | Stats d'un produit | Implémenté |
| 56 | GET | `/v1/partner/product-stats/ranking` | Classement produits | Implémenté |

## Orders (12 endpoints)

| # | Méthode | Path | Description | Status |
|---|---------|------|-------------|--------|
| 57 | GET | `/v1/partner/orders` | Lister commandes (paginé, filtrable) | Implémenté |
| 58 | GET | `/v1/partner/orders/counts-by-status` | Compteurs par statut | Implémenté |
| 59 | GET | `/v1/partner/orders/select/statuses` | Dropdown statuts | Implémenté |
| 60 | GET | `/v1/partner/orders/transitions` | Transitions dispo par statut | Implémenté |
| 61 | GET | `/v1/partner/orders/actions` | Actions dispo par statut | Implémenté |
| 62 | GET | `/v1/partner/orders/:id` | Détail commande (expanded) | Implémenté |
| 63 | POST | `/v1/partner/orders/:id/confirm` | Confirmer (estimated_minutes) | Implémenté |
| 64 | POST | `/v1/partner/orders/:id/preparing` | En préparation (trigger dispatch) | Implémenté |
| 65 | POST | `/v1/partner/orders/:id/ready` | Prête pour collecte | Implémenté |
| 66 | POST | `/v1/partner/orders/:id/cancel` | Annuler (cancel_reason) | Implémenté |
| 67 | GET | `/v1/partner/orders/:id/pickup-otp` | Récupérer OTP collecte | Implémenté |
| 68 | POST | `/v1/partner/orders/:id/pickup-otp/resend` | Renvoyer OTP collecte | Implémenté |

## Support Tickets (10 endpoints)

| # | Méthode | Path | Description | Status |
|---|---------|------|-------------|--------|
| 69 | POST | `/v1/partner/tickets` | Créer ticket | À implémenter |
| 70 | GET | `/v1/partner/tickets` | Lister tickets (paginé) | À implémenter |
| 71 | GET | `/v1/partner/tickets/select/priorities` | Dropdown priorités | À implémenter |
| 72 | GET | `/v1/partner/tickets/:id` | Détail ticket | À implémenter |
| 73 | GET | `/v1/partner/tickets/:id/logs` | Logs activité ticket | À implémenter |
| 74 | GET | `/v1/partner/tickets/:id/messages` | Messages conversation | À implémenter |
| 75 | GET | `/v1/partner/tickets/:id/mentionable-users` | Users mentionnables | À implémenter |
| 76 | POST | `/v1/partner/tickets/:id/messages` | Envoyer message (multipart) | À implémenter |
| 77 | PATCH | `/v1/partner/tickets/:id/messages/read` | Marquer messages lus | À implémenter |
| 78 | GET | `/v1/partner/tickets/:id/messages/unread-count` | Compteur non lus | À implémenter |

## Carts (2 endpoints)

| # | Méthode | Path | Description | Status |
|---|---------|------|-------------|--------|
| 79 | GET | `/v1/partner/carts` | Paniers actifs (paginé) | Implémenté |
| 80 | GET | `/v1/partner/carts/stats` | Stats paniers | Implémenté |

---

## Résumé

| Domaine | Endpoints | Implémentés | Restants |
|---------|-----------|-------------|----------|
| Auth | 4 | 4 | 0 |
| Profile | 6 | 6 | 0 |
| Dashboard | 1 | 1 | 0 |
| Stats | 6 | 6 | 0 |
| Menus | 6 | 6 | 0 |
| Product Categories | 8 | 8 | 0 |
| Products | 11 | 11 | 0 |
| Product Variants | 4 | 4 | 0 |
| Option Groups/Items | 8 | 8 | 0 |
| Product Stats | 2 | 2 | 0 |
| Orders | 12 | 12 | 0 |
| Support Tickets | 10 | 0 | 10 |
| Carts | 2 | 2 | 0 |
| **Total** | **80** | **70** | **10** |

*Derniere mise a jour : 2026-03-27 (Stats 6/6 + Product Stats 2/2 + Carts 2/2)*
