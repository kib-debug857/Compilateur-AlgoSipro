//  hashtable.h : partie interface d'un module polymorphe pour la spécification
//    TABLE du TDA Table(T, T') dans le cas d'une table de hachage par chainage
//    séparé ainsi que pour une extension optionnelle.

//  AUCUNE MODIFICATION DE CE SOURCE N'EST AUTORISÉE.

//  Fonctionnement général :
//  - la structure de données ne stocke pas d'objets mais des références vers
//      ces objets. Les références sont du type générique « void * » ;
//  - si des opérations d'allocation dynamique sont effectuées, elles le sont
//      pour la gestion propre de la structure de données, et en aucun cas pour
//      réaliser des copies ou des destructions d'objets ;
//  - les fonctions qui possèdent un paramètre de type « hashtable * » ou
//      « hashtable ** » ont un comportement indéterminé lorsque ce paramètre ou
//      sa déréférence n'est pas l'adresse d'un contrôleur préalablement
//      renvoyée avec succès par la fonction hashtable_empty et non révoquée
//      depuis par la fonction hashtable_dispose ;
//  - aucune fonction ne peut ajouter un pointeur nul en tant que référence de
//      valeur à la structure de données ;
//  - les fonctions de type de retour « void * » renvoient un pointeur nul en
//      cas d'échec. En cas de succès, elles renvoient une référence de valeur
//      actuellement ou auparavant stockée par la structure de données ;
//  - l'implantation des fonctions dont la spécification ne précise pas qu'elles
//      doivent gérer les cas de dépassement de capacité ne doivent avoir
//      affaire à aucun problème de la sorte.

//  L'extension est formée des éventuelles déclarations et définitions qui
//    figurent aux lignes 112-136.

//  Les identificateurs introduits par l'extension ainsi que les identificateurs
//    de macro HASHTABLE_EXT et WANT_HASHTABLE_EXT sont réservés pour être
//    utilisés comme indiqué ci-après :
//  - lorsque le module peut mettre l'intégralité de l'extension à disposition
//      de l'utilisateurice, la macro HASHTABLE_EXT doit être définie dans
//      l'en-tête "hashtable_ip.h" ;
//  - dans le cas contraire, la macro HASHTABLE_EXT n'est pas définie dans
//      l'en-tête "hashtable_ip.h" et ne doit pas l'être au sein de l'unité de
//      traduction de prétraitement  ;
//  - la visibilité et l'implantation de l'extension ne sont effectives qu'à la
//      double condition que la macro HASHTABLE_EXT soit définie dans l'en-tête
//      "hashtable_ip.h" et que la macro WANT_HASHTABLE_EXT soit définie par
//      l'utilisateurice ;
//  - aucune modification du statut défini/non défini des macros HASHTABLE_EXT
//      et WANT_HASHTABLE_EXT ne doit intervenir au sein de l'unité de
//      traduction de prétraitement après que le présent en-tête ait été inclus
//      pour la première fois.

//- STANDARD --v---v---v---v---v---v---v---v---v---v---v---v---v---v---v---v---v

#ifndef HASHTABLE__H
#define HASHTABLE__H

#include <stdlib.h>

//  struct hashtable, hashtable : type et nom de type d'un contrôleur regroupant
//    les informations nécessaires pour gérer une table de références de clés et
//    valeurs quelconques.
typedef struct hashtable hashtable;

//  hashtable_empty :  tente d'allouer les ressources nécessaires pour gérer une
//    nouvelle table de hachage initialement vide. La fonction de comparaison
//    des clés via leurs références est pointée par compar et leur fonction de
//    pré-hachage est pointée par hashfun. La valeur de loadfactmax spécifie le
//    taux de remplissage maximum de la table. Renvoie un pointeur nul en cas de
//    dépassement de capacité. Renvoie sinon un pointeur vers le contrôleur
//    associé à la table.
extern hashtable *hashtable_empty(int (*compar)(const void *, const void *),
    size_t (*hashfun)(const void *), double loadfactmax);

//  hashtable_dispose : sans effet si *htptr vaut un pointeur nul. Libère sinon
//    les ressources allouées à la gestion de la table de hachage associée à
//    *htptr puis affecte un pointeur nul à *htptr.
extern void hashtable_dispose(hashtable **htptr);

//  hashtable_add : renvoie un pointeur nul si valref vaut un pointeur nul.
//    Recherche sinon dans la table de hachage associée à ht la référence d'une
//    clé égale à celle de référence keyref au sens de la fonction de
//    comparaison. Si la recherche est positive, remplace la référence de la
//    valeur correspondante par valref et renvoie la référence de la valeur qui
//    était auparavant associée à la clé trouvée. Tente sinon d'ajouter le
//    couple (keyref, valref) à la table ; renvoie un pointeur nul en cas de
//    dépassement de capacité ; renvoie sinon valref.
extern void *hashtable_add(hashtable *ht, const void *keyref,
    const void *valref);

//  hashtable_remove : recherche dans la table de hachage associée à ht la
//    référence d'une clé égale à celle de référence keyref au sens de la
//    fonction de comparaison. Si la recherche est négative, renvoie un pointeur
//    nul. Retire sinon le couple (fkeyref, fvalref) de la table, où fkeyref est
//    la référence de la clé trouvée et fvalref la référence de la valeur
//    correspondante puis renvoie fvalref.
extern void *hashtable_remove(hashtable *ht, const void *keyref);

//  hashtable_search :  recherche dans la table de hachage associée à ht la
//    référence d'une clé égale à celle de référence keyref au sens de la
//    fonction de comparaison. Renvoie un pointeur nul si la recherche est
//    négative, la référence de la valeur correspondante sinon.
extern void *hashtable_search(hashtable *ht, const void *keyref);

//- STANDARD --^---^---^---^---^---^---^---^---^---^---^---^---^---^---^---^---^

#undef HASHTABLE_EXT
#include "hashtable_ip.h"

#if defined HASHTABLE_EXT && defined WANT_HASHTABLE_EXT

//- EXTENSION -v---v---v---v---v---v---v---v---v---v---v---v---v---v---v---v---v

//  Sont ajoutées au standard une structure et deux fonctions qui peuvent être
//    utiles.

#include <stdio.h>

//  struct hashtable_stats : structure regroupant quelques informations qui
//    constituent un bilan de santé d'une table de hachage.
struct hashtable_stats {
  size_t nslots;    //  nombre de compartiments
  size_t nentries;  //  nombre de clés
  double lfmax;     //  taux de remplissage maximum toléré
  double lfcurr;    //  taux de remplissage courant
  size_t maxlen;    //  maximum des longueurs des listes
  double postheo;   //  nombre moyen théorique de comparaisons dans le cas d'une
                    //    recherche positive
  double poscurr;   //  nombre moyen courant de comparaisons dans le cas d'une
                    //    recherche positive
};

//  hashtable_get_stats : effectue un bilan de santé pour la table de hachage
//    associée à ht et affecte le résultat à *htsptr.
extern void hashtable_get_stats(hashtable *ht, struct hashtable_stats *htsptr);

//  hashtable_fprint_stats : effectue un bilan de santé pour la table de hachage
//    associée à ht  et écrit le résultat dans le flot texte lié au contrôleur
//    pointé par textstream. Renvoie une valeur non nulle si une erreur en
//    écriture survient. Renvoie sinon zéro.
extern int hashtable_fprint_stats(hashtable *ht, FILE *textstream);

//- EXTENSION -^---^---^---^---^---^---^---^---^---^---^---^---^---^---^---^---^

#endif

#endif
