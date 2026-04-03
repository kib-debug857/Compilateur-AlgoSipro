<H1>Compilateur Asipro pour fichier Latex</H1>

<H2>Les fonctionnalités implémentées</H2>

- Les commandes utilisables :
  - \SET
      - Affectation de variable (vérification stricte du type(inférence à la 1ère affectation))
  - \IF && \ELSE
    - Il est possible d'écrire une condition simple avec un simple IF comme une condition complexe avec un IF/ELSE. La condition doit être obligatoirement de type BOOL_T
  - \DOWHILE
    -   Il est possible d'imbriqué plusieurs boucles entre elles (dofori && dowhile).
  - \DOFORI
    - Gère l'incrémentation automatique et la borne de fin. 
  - \CALL
    - Gére le cas des appeles récurssif et des appeles d'autre fonctions   
  - \RETURN
    - Retourne forcément un entier, nous n'avons pas implémenté la fonctionnalité de déduire la valeur de retour en fonction des paramètres   

<H2>La table des symboles</H2>
L'implémentation de la table des symboles (symbole.c/.h) est l'un des piliers du projet. Elle gère la portée lexicale de manière dynamique :

- Structure Hiérarchique : Chaque algorithme possède son propre environnement (Env) relié à un parent (le contexte global). Cela permet d'isoler les variables locales et d'autoriser la récursivité.
- Gestion des Portées : Les fonctions entreeFonction() et sortieFonction() ouvrent et ferment les contextes lors de la détection des balises \begin{algo} et \end{algo}.
- Modèle Mémoire : Les adresses sont calculées en offsets relatifs par rapport au registre de base BP :
  - Arguments : Offsets positifs (ex: BP + 4, BP + 6).
  - Variables locales : Offsets négatifs (ex: BP - 2, BP - 4). 

<H2>Guide d'Exécution</H2>

**Prérequis matériels**

Pour compiler et exécuter ce projet, vous devez avoir installé l'environnement SIPRO sur votre machine :

- asipro : L'assembleur pour transformer votre code .asm en binaire.
- sipro : L'émulateur (processeur virtuel 16 bits) pour exécuter le programme final.
- Flex & Bison : Pour la génération de l'analyseur lexical et syntaxique.
- Bien penser à éxécuter :
  - ```bash make clean ```
  - ```bash make ``` 


| Etape| Code| Description|
| :--- | :--- | :---|
| 1.Compilation | ```./compil test.algo > test.asm```  |Traduit le code Argo en assembleur SIPRO.|
| 2.Assemblage | ```  asipro test.asm test.sipro```|Génère le fichier binaire exécutable.|
| 2.Exécution | ``` sipro test.sipro ``` |Lance l'émulateur et affiche le résultat final.|


<H2>Sécurité Sémantique Interne</H2>
Le compilateur intègre des routines de gestion d'erreurs : 

  - **Division par zéro** : Branchement automatique vers :erreur_div0
  - **Débordement (Overflow)** : Détecté lors des additions et multiplications. 
  - **Typage** : Les opérations arithmétiques rejettent les booléens
