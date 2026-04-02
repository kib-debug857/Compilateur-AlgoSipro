/**
 * @file symbole.h
 * @brief Interface de la Table des Symboles pour le compilateur AlgoSIPRO.
 * * Ce module gère la portée lexicale des variables et des fonctions via une
 * architecture en Environnements Chaînés. Il permet d'associer des identifiants
 * textuels à des adresses relatives (offsets) calculées par rapport au registre
 * de base (BP) de la machine virtuelle SIPRO.
 */


#ifndef SYMBOLE_H
#define SYMBOLE_H
#include "type.h"

/** * @name Classes d'Identifiants
 * Définissent le rôle sémantique du symbole pour calculer l'adresse 
 * et sécuriser les opérations (ex: empêcher l'affectation à une fonction).
 * @{
 */
#define C_FONCTION 1  ///< Algorithme (ex: "puissance")
#define C_VARIABLE 2  ///< Variable locale (déclarée via \SET ou \DOFORI)
#define C_ARGUMENT 3  ///< Paramètre d'un algorithme (ex: "a", "b")
/** @} */


/** Nombre maximum de symboles autorisés dans un seul algorithme (sécurité) */
#define MAX_SYMBOLES_LOCAUX 100


/**
 * @struct Symbole
 * @brief Enregistrement d'un identifiant unique dans la table.
 */

typedef struct {
    char *nom;       ///< Chaîne de caractères de l'identifiant (ex: "p")
    int classe;      ///< C_FONCTION, C_VARIABLE, ou C_ARGUMENT
    type_t type;     ///< INT_T ou BOOL_T pour le typage strict des expressions
    int adresse;     ///< Offset relatif par rapport à BP (ex: 2, 4, -4, -6)
    int nb_params;
} Symbole;

/**
 * @struct Env
 * @brief Contexte local (portée lexicale) représentant un algorithme.
 */
typedef struct Env {
    Symbole symboles[MAX_SYMBOLES_LOCAUX]; ///< Tableau des symboles de CE contexte
    int nb_symboles;                       ///< Nombre actuel de symboles
    struct Env *parent;                    ///< Pointeur vers l'environnement englobant
} Env;



//pour la pile d'exécution : la pile physique est dans l'émulateur 
//mais c'est le programmeur qui la gère dans bison.
//En gros je dis à l'émulateurr de mettre un mot reonnu à tel endroit de la pile 
//grâce à la table des symboles 

//Gestion des contextes

/**
 * @brief Initialise la table des symboles.
 * Crée le Contexte Global. À appeler une seule fois avant la compilation.
 */
void initDico();

/**
 * @brief Ouvre une nouvelle portée lexicale.
 * Alloue un nouvel environnement local et le relie au contexte courant.
 * À appeler lors de la détection de \begin{algo}.
 */
void entreeFonction();

/**
 * @brief Ferme la portée lexicale courante.
 * Détruit l'environnement local et libère la mémoire. 
 * À appeler lors de la détection de \end{algo}.
 */
void sortieFonction();

//Gestion des symboles

/**
 * @brief Ajoute un nouvel identifiant dans le contexte COURANT.
 * @param nom La chaîne de caractères de l'identifiant.
 * @param classe C_FONCTION, C_VARIABLE, ou C_ARGUMENT.
 * @param type INT_T, BOOL_T, ou UNDEF.
 * @param adresse L'offset calculé pour l'émulateur SIPRO.
 * @return Pointeur vers le symbole créé (stoppe le programme en cas de débordement).
 */
Symbole* ajouteIdentificateur(char *nom, int classe, type_t type, int adresse);

/**
 * @brief Cherche la déclaration d'un identifiant pour son utilisation.
 * Scrutera le contexte local, puis remontera au contexte global si non trouvé.
 * @param nom L'identifiant à chercher (ex: lors d'un calcul ou d'un CALL).
 * @return Pointeur vers le symbole, ou NULL s'il est inconnu.
 */
Symbole* rechercheExecutable(char *nom);

/**
 * @brief Cherche un identifiant UNIQUEMENT dans le contexte courant.
 * Utilisé pour empêcher la double déclaration d'une variable dans un même algorithme.
 * @param nom L'identifiant à vérifier.
 * @return Pointeur vers le symbole s'il y a conflit, NULL si la déclaration est possible.
 */
Symbole* rechercheDeclarative(char *nom);

void fixerOffsetsArguments(int nb_args);

#endif 
