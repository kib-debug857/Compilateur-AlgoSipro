#ifndef SYMBOLE_H
#define SYMBOLE_H

/*C'est symbole qui utilise le module hashtable */

#define C_VARIABLE_GLOBALE 1
#define C_VARIABLE_LOCALE 2
#define C_ARGUMENT 3

/* Les types simples de notre langage AlgoSIPRO */
#define T_ENTIER 1
#define T_BOOLEEN 2

/* La structure de données pour chaque symbole */
typedef struct {
    char* nom;
    int classe;      // GLOBALE, LOCALE ou ARGUMENT
    int type;        // ENTIER ou BOOLEEN
    int adresse_rel; // Le décalage (+ ou -) par rapport à BP
} desc_identif;


/* Initialisation au lancement du compilateur */
void init_symboles();

/* Gestion des contextes (pour le \begin{algo} et \end{algo}) */
void entrer_contexte();
void sortir_contexte();

/* Fonctions d'ajout */
desc_identif* ajouter_algorithme(char* nom);
desc_identif* ajouter_argument(char* nom);
desc_identif* ajouter_variable_locale(char* nom);

/* Fonction de recherche (cherche d'abord en local, puis en global) */
desc_identif* chercher_variable(char* nom);

#endif // SYMBOLE_H