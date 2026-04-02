/**
 * @file table_symboles.c
 * @brief Implémentation de la Table des Symboles pour AlgoSIPRO.
 * Gestion de la mémoire de compilation via des Environnements Chaînés.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "symbole.h"

// ============================================================================
// VARIABLES GLOBALES PRIVÉES (Encapsulation)
// ============================================================================

/*
 * Le pointeur 'contexte_courant' est déclaré static pour qu'il ne soit 
 * accessible QUE depuis ce fichier. Bison n'a pas le droit d'y toucher 
 * directement, il doit passer par les fonctions ci-dessous.
 */
static Env *contexte_courant = NULL;


// ============================================================================
// GESTION DU CYCLE DE VIE DES CONTEXTES
// ============================================================================

void initDico(void) {
    // 1. Allocation de la boîte globale
    contexte_courant = (Env *)malloc(sizeof(Env));
    if (contexte_courant == NULL) {
        fprintf(stderr, "Erreur fatale : Échec d'allocation mémoire pour le Dictionnaire Global.\n");
        exit(EXIT_FAILURE);
    }
    
    // 2. Initialisation
    contexte_courant->nb_symboles = 0;
    contexte_courant->parent = NULL; // C'est la racine de notre arbre
}

void entreeFonction(void) {
    // 1. Allocation de la nouvelle boîte locale
    Env *nouveau_contexte = (Env *)malloc(sizeof(Env));
    if (nouveau_contexte == NULL) {
        fprintf(stderr, "Erreur fatale : Échec d'allocation mémoire pour un Contexte Local.\n");
        exit(EXIT_FAILURE);
    }
    
    // 2. Chaînage : on accroche la nouvelle boîte à l'actuelle
    nouveau_contexte->nb_symboles = 0;
    nouveau_contexte->parent = contexte_courant;
    
    // 3. On "entre" dans la boîte
    contexte_courant = nouveau_contexte;
}

void sortieFonction(void) {
    // Sécurité : On s'assure qu'on ne brûle pas la boîte globale
    if (contexte_courant->parent == NULL) {
        fprintf(stderr, "Erreur interne du compilateur : Tentative de destruction du Contexte Global !\n");
        exit(EXIT_FAILURE);
    }
    
    Env *boite_a_detruire = contexte_courant;
    
    // 1. On remonte d'un niveau (Le post-it retourne sur la boîte parente)
    contexte_courant = boite_a_detruire->parent;
    
    // 2. Nettoyage profond : On libère toutes les chaînes allouées par strdup
    for (int i = 0; i < boite_a_detruire->nb_symboles; i++) {
        free(boite_a_detruire->symboles[i].nom);
    }
    
    // 3. Destruction finale de la boîte locale
    free(boite_a_detruire);
}


// ============================================================================
// AJOUT ET RECHERCHE DES SYMBOLES
// ============================================================================

Symbole* ajouteIdentificateur(char *nom, int classe, type_t type, int adresse) {
    // Sécurité : Vérification du débordement de la boîte
    if (contexte_courant->nb_symboles >= MAX_SYMBOLES_LOCAUX) {
        fprintf(stderr, "Erreur de compilation : Trop de variables locales/arguments dans cet algorithme (Max: %d).\n", MAX_SYMBOLES_LOCAUX);
        exit(EXIT_FAILURE);
    }
    
    int index = contexte_courant->nb_symboles;
    
    // strdup alloue dynamiquement de la mémoire pour copier le nom exactement.
    // Très important car le 'nom' envoyé par Flex/Bison est souvent écrasé à la lecture du mot suivant.
    contexte_courant->symboles[index].nom = strdup(nom);
    
    if (contexte_courant->symboles[index].nom == NULL) {
        fprintf(stderr, "Erreur fatale : Échec d'allocation mémoire pour l'identifiant '%s'.\n", nom);
        exit(EXIT_FAILURE);
    }
    
    contexte_courant->symboles[index].classe = classe;
    contexte_courant->symboles[index].type = type;
    contexte_courant->symboles[index].adresse = adresse;
    contexte_courant->symboles[index].nb_params = 0;
    
    
    contexte_courant->nb_symboles++;
    
    return &(contexte_courant->symboles[index]);
}

Symbole* rechercheExecutable(char *nom) {
    Env *env_recherche = contexte_courant;
    
    // On remonte l'arbre généalogique jusqu'au sommet
    while (env_recherche != NULL) {
        // On fouille la boîte actuelle
        for (int i = 0; i < env_recherche->nb_symboles; i++) {
            if (strcmp(env_recherche->symboles[i].nom, nom) == 0) {
                return &(env_recherche->symboles[i]); // Trouvé !
            }
        }
        // Si non trouvé, on passe au parent
        env_recherche = env_recherche->parent;
    }
    
    return NULL; // Identifiant inconnu dans tous les contextes
}

Symbole* rechercheDeclarative(char *nom) {
    // On fouille UNIQUEMENT la boîte courante (pas de boucle while)
    for (int i = 0; i < contexte_courant->nb_symboles; i++) {
        if (strcmp(contexte_courant->symboles[i].nom, nom) == 0) {
            return &(contexte_courant->symboles[i]); // Conflit : déjà déclaré !
        }
    }
    
    return NULL; // Voie libre
}
void fixerOffsetsArguments(int nb_args) {
    // Les arguments sont toujours les premiers symboles ajoutés dans le contexte
    for (int i = 0; i < nb_args; i++) {
        // Le dernier argument (index nb_args - 1) est à BP - 4
        // L'avant-dernier est à BP - 6, etc.
        contexte_courant->symboles[i].adresse = -4 - ((nb_args - 1 - i) * 2);
    }
}