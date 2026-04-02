<H1>Compilateur Asipro pour fichier Latex</H1>

<H2>Les fonctionnalités implémentées</H2>

- Les commandes utilisables :
  - \SET
      - Pour affecter une valeur à une variable il faut concerver le type de celle ci (un Entier restera un Entier).
  - \IF && \ELSE
    - Il est possible d'écrire une condition simple avec un simple IF comme une condition complexe avec un IF/ELSE.
  - \DOWHILE
    -   
  - \DOFORI
  - \CALL
  - \RETURN


<H2>Guide d'Exécution</H2>

**Prérequis matériels**

Pour compiler et exécuter ce projet, vous devez avoir installé l'environnement SIPRO sur votre machine :

- asipro : L'assembleur pour transformer votre code .asm en binaire.
- sipro : L'émulateur (processeur virtuel 16 bits) pour exécuter le programme final.
- Flex & Bison : Pour la génération de l'analyseur lexical et syntaxique.


| Etape| Code| Description|
| :--- | :--- | :---|
| 1.Compilation | ```bash ./compil test.algo > test.asm```  |Traduit le code Argo en assembleur SIPRO.|
| 2.Assemblage | ```bash asipro test.asm test.sipro```|Génère le fichier binaire exécutable.|
| 2.Exécution | ```bash sipro test.sipro ``` |Lance l'émulateur et affiche le résultat final.|
