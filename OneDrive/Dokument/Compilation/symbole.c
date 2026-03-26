#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "symbole.h"
#include "hashtable.h"

/* --- Variables Globales Privées --- */
static hashtable *table_globale = NULL;
static hashtable *table_locale = NULL;

/* Compteurs pour les adresses sur la pile SIPRO (mots de 2 octets) */
static int offset_local; 
static int offset_argument; 

/* --- Fonctions requises par la HashTable pour les chaînes de caractères --- */
static int cmp_str(const void *a, const void *b) {
    return strcmp((const char *)a, (const char *)b);
}

static size_t hash_str(const void *str) {
    size_t hash = 5381;
    int c;
    const char *s = (const char *)str;
    while ((c = *s++)) {
        hash = ((hash << 5) + hash) + c; 
    }
    return hash;
}

/* --- Implémentation de l'API --- */

void init_symboles() {
    // Création de la table globale (pour les noms d'algorithmes)
    table_globale = hashtable_empty(cmp_str, hash_str, 0.75);
}

void entrer_contexte() {
    // Appelé quand on lit \begin{algo}
    // On crée la table locale pour cette fonction
    table_locale = hashtable_empty(cmp_str, hash_str, 0.75);
    
    // Initialisation des compteurs d'adresses (SIPRO empile par sauts de 2)
    offset_local = 2;       // Les variables locales monteront: BP+2, BP+4...
    offset_argument = -4;   // Les arguments descendront: BP-4, BP-6...
                            // (-2 est réservé pour l'adresse de retour IP)
}

void sortir_contexte() {
    // Appelé quand on lit \end{algo}
    // On détruit la table locale, libérant ainsi la mémoire !
    if (table_locale != NULL) {
        hashtable_dispose(&table_locale);
        table_locale = NULL;
    }
}

desc_identif* ajouter_algorithme(char* nom) {
    desc_identif* nv_algo = malloc(sizeof(desc_identif));
    strcpy(nv_algo->nom, nom);
    nv_algo->classe = C_VARIABLE_GLOBALE;
    nv_algo->type = T_ENTIER; 
    nv_algo->adresse_rel = 0; // Pas de sens pour un algo
    
    hashtable_add(table_globale, nv_algo->nom, nv_algo);
    return nv_algo;
}

desc_identif* ajouter_argument(char* nom) {
    desc_identif* nv_arg = malloc(sizeof(desc_identif));
    strcpy(nv_arg->nom, nom);
    nv_arg->classe = C_ARGUMENT;
    nv_arg->type = T_ENTIER;
    
    // On attribue l'adresse négative, puis on décale de 2 octets pour le suivant
    nv_arg->adresse_rel = offset_argument;
    offset_argument -= 2; 
    
    hashtable_add(table_locale, nv_arg->nom, nv_arg);
    return nv_arg;
}

desc_identif* ajouter_variable_locale(char* nom) {
    // On vérifie qu'elle n'existe pas déjà pour éviter les doublons
    desc_identif* existante = hashtable_search(table_locale, nom);
    if (existante != NULL) return existante;

    desc_identif* nv_var = malloc(sizeof(desc_identif));
    strcpy(nv_var->nom, nom);
    nv_var->classe = C_VARIABLE_LOCALE;
    nv_var->type = T_ENTIER;
    
    // On attribue l'adresse positive, puis on décale de 2 octets pour la suivante
    nv_var->adresse_rel = offset_local;
    offset_local += 2;
    
    hashtable_add(table_locale, nv_var->nom, nv_var);
    return nv_var;
}

desc_identif* chercher_variable(char* nom) {
    desc_identif* resultat = NULL;
    
    // Règle de la Diapo 16 : On cherche d'abord en local
    if (table_locale != NULL) {
        resultat = hashtable_search(table_locale, nom);
    }
    
    // Si on n'a rien trouvé, on cherche en global
    if (resultat == NULL && table_globale != NULL) {
        resultat = hashtable_search(table_globale, nom);
    }
    
    return resultat;
}