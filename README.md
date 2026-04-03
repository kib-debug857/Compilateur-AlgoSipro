# 🎓 Compilateur AlgoSIPRO (LaTeX vers Assembleur)

[cite_start]Ce projet implémente un compilateur complet pour le langage Argo (format LaTeX), ciblant l'architecture virtuelle 16 bits SIPRO [cite: 179-182].

## 🚀 Fonctionnalités implémentées

[cite_start]Le compilateur traite des fichiers contenant un ou plusieurs algorithmes, suivis d'un appel final.

* **Gestion des Algorithmes :**
    * Support des définitions multiples (`\begin{algo} ... \end{algo}`).
    * [cite_start]**Appels récursifs** et appels de fonctions tierces.
    * Gestion des arguments (offsets positifs par rapport à BP) et des variables locales (offsets négatifs).
* **Structures de contrôle :**
    * [cite_start]`\SET` : Affectation avec inférence de type et vérification stricte [cite: 33-35].
    * [cite_start]`\IF` / `\ELSE` / `\FI` : Conditionnelles imbriquées (type `BOOL_T` requis) [cite: 41-42].
    * [cite_start]`\DOWHILE` / `\OD` : Boucles conditionnelles [cite: 49-55].
    * [cite_start]`\DOFORI` / `\OD` : Boucles itératives avec gestion automatique de l'itérateur [cite: 55-74].
* [cite_start]**Entrées/Sorties :** Affichage automatique du résultat du dernier `\CALL` (Entier ou Booléen)[cite: 195].

## 🏗️ Architecture Technique

* [cite_start]**Analyse en deux passes :** La première passe (`path=0`) construit la table des symboles et calcule les offsets ; la seconde passe (`path=1`) génère le code assembleur SIPRO [cite: 3, 153-157].
* **Table des Symboles :** Utilisation d'environnements chaînés pour gérer la portée lexicale et les variables locales.
* **Modèle de Pile :**
    * Arguments : `BP + 4`, `BP + 6`...
    * Locales : `BP - 2`, `BP - 4`...
    * [cite_start]Sauvegarde du contexte (BP) à chaque entrée de fonction[cite: 19, 23].

## 🛡️ Sécurité Sémantique

Le compilateur injecte des routines de sécurité directement dans l'assembleur généré :
* [cite_start]**Division par zéro** : Interception et arrêt propre avec message d'erreur [cite: 122, 160-161].
* [cite_start]**Overflow** : Détection des dépassements d'entiers 16 bits (`jmpe`)[cite: 111, 118].
* [cite_start]**Vérification de type** : Rejet des opérations arithmétiques sur booléens et des conditions sur entiers [cite: 109-121].

## ⚙️ Guide d'Exécution

### Installation
```bash
make clean
make
