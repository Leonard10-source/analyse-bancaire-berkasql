# Dictionnaire de données — schéma `berka`

Document descriptif dérivé du schéma SQL `01_create_schema.sql` et des vues `05_views.sql`. Les valeurs de cardinalité ci-dessous ont été vérifiées dans MySQL Workbench.

## Tables métier

| Objet | Grain (une ligne par…) | Clé primaire | Références principales | Lignes |
|---|---|---|---|---:|
| `district` | district administratif | `district_id` | — | 77 |
| `account` | compte bancaire | `account_id` | `district_id → district` | 4 500 |
| `client` | client | `client_id` | `district_id → district` | 5 369 |
| `disp` | droit d'un client sur un compte | `disp_id` | `client_id → client`, `account_id → account` | 5 369 |
| `card` | carte bancaire | `card_id` | `disp_id → disp` | 892 |
| `loan` | prêt | `loan_id` | `account_id → account` | 682 |
| `orders` | ordre permanent | `order_id` | `account_id → account` | 6 471 |
| `trans` | écriture de transaction | `trans_id` | `account_id → account` | 1 056 320 |
| `ref_loan_status` | code de statut de prêt | `status` | jointure logique sur `loan.status` (pas de FK déclarée dans le script) | 4 |
| `quality_log` | exécution d'un contrôle | `log_id` | table technique indépendante | 1 enregistrement montré |

## Attributs sensibles pour l'analyse

| Attribut | Sens | Type SQL |
|---|---|---|
| `account.opened_date` | Date d'ouverture du compte | `DATE` |
| `account.frequency` | Fréquence de facturation | `VARCHAR(20)` |
| `client.birth_date` | Date de naissance dérivée du code source | `DATE` |
| `client.gender` | Sexe dérivé du code source | `CHAR(1)` |
| `disp.disp_type` | `OWNER` (titulaire) ou `DISPONENT` (mandataire) | `VARCHAR(10)` |
| `loan.loan_date` | Date d'octroi | `DATE` |
| `loan.amount` | Montant initial accordé | `DECIMAL(12,2)` |
| `loan.duration` | Durée en mois : 12/24/36/48/60 | `SMALLINT` |
| `loan.status` | Statut A/B/C/D | `CHAR(1)` |
| `trans.trans_date` | Date de la transaction | `DATE` |
| `trans.trans_type` | `PRIJEM` (entrée), `VYDAJ` / `VYBER` (sorties) | `VARCHAR(10)` |
| `trans.amount` | Montant non signé de l'écriture | `DECIMAL(12,2)` |
| `trans.balance` | Solde après mouvement enregistré | `DECIMAL(12,2)` |
| `district.region` | Grande région de rattachement | `VARCHAR(50)` |
| `district.avg_salary` | Salaire moyen dans le district | `INT` |

## Statuts des prêts

| Code | Libellé français dans la base | `is_finished` | `is_problem` |
|---|---|---:|---:|
| A | Terminé, remboursé | 1 | 0 |
| B | Terminé, non remboursé | 1 | 1 |
| C | En cours, sain | 0 | 0 |
| D | En cours, en difficulté | 0 | 1 |

**Note :** la table `loan` impose `status IN ('A','B','C','D')`, mais `loan.status` n'a pas de clé étrangère vers `ref_loan_status` dans la définition disponible. Les quatre correspondances ont été vérifiées sur les données chargées.

## Vues analytiques

| Vue | Grain | Colonnes principales | Lignes vérifiées |
|---|---|---|---:|
| `v_loan_360` | un prêt | statut, montant, durée, profil du titulaire, district | 682 |
| `v_monthly_flows` | un mois | entrées, sorties, nombre de transactions, comptes actifs | 72 |
| `v_account_summary` | un compte | nombre de transactions, cumuls des flux, nombre de prêts | 4 500 |

**Précaution de modélisation :** ne pas joindre naïvement des tables de faits de granularités différentes (`loan`, `trans`, `orders`) en une seule requête d'agrégation : la multiplication des lignes peut fausser les montants. Les vues existantes évitent ce piège par agrégation au bon grain.
