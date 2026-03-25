//  hashtable.c : partie implantation d'un module polymorphe pour la
//    spécification TABLE du TDA Table(T, T') dans le cas d'une table de hachage
//    par chainage séparé ainsi que pour une extension optionnelle.

#include <stdint.h>
#include "hashtable.h"

//  struct hashtable, hashtable : gestion du chainage séparé par liste dynamique
//    simplement chainée. Le composant compar mémorise la fonction de
//    comparaison des clés, hashfun, leur fonction de pré-hachage, lfmax,
//    le taux de remplissage maximum toléré de la table. Le tableau de hachage
//    est alloué dynamiquement ; son adresse et sa longueur (le nombre de
//    compartiments) sont mémorisés par les composants hasharray et nslots. Le
//    composant nentries mémorise le nombre d'entrées de la table.

typedef struct cell cell;

struct cell {
  const void *keyref;
  const void *valref;
  cell *next;
};

struct hashtable {
  int (*compar)(const void *, const void *);
  size_t (*hashfun)(const void *);
  double lfmax;
  cell **hasharray;
  size_t nslots;
  size_t nentries;
};

#define HASHVAL(__hashfun, __nslots, __keyref)                                 \
  (__hashfun(__keyref) % (__nslots))

//  hashtable__search : recherche dans la table de hachage associé à ht une clé
//    égale à keyref au sens de compar. Renvoie l'adresse du pointeur qui repère
//    la cellule qui contient cette occurrence si elle existe. Renvoie sinon
//    l'adresse du pointeur qui marque la fin de la liste.
static cell **hashtable__search(const hashtable *ht, const void *keyref) {
  cell * const *pp = &ht->hasharray[HASHVAL(ht->hashfun, ht->nslots, keyref)];
  while (*pp != nullptr && ht->compar(keyref, (*pp)->keyref) != 0) {
    pp = &(*pp)->next;
  }
  return (cell **) pp;
}

//  hashtable__increase : agrandit le tableau de hachage de la table de hachage
//    associée à ht. Renvoie une valeur non nulle en cas de dépassement de
//    capacité. Renvoie sinon zéro.
static int hashtable__increase(hashtable *ht) {
  size_t m_ = ht->nslots;
  size_t m = 2 * m_;
  cell **a;
  if (m > PTRDIFF_MAX / sizeof(cell *)
      || (a = realloc(ht->hasharray, m * sizeof(cell *))) == nullptr) {
    return -1;
  }
  for (size_t k_ = 0; k_ < m_; ++k_) {
    cell **pp_ = &a[k_];
    cell **pp = &a[k_ + m_];
    while (*pp_ != nullptr) {
      if (HASHVAL(ht->hashfun, m, (*pp_)->keyref) < m_) {
        pp_ = &(*pp_)->next;
      } else {
        *pp = *pp_;
        *pp_ = (*pp_)->next;
        pp = &(*pp)->next;
      }
    }
    *pp = nullptr;
  }
  ht->hasharray = a;
  ht->nslots = m;
  return 0;
}

hashtable *hashtable_empty(int (*compar)(const void *, const void *),
    size_t (*hashfun)(const void *), double lfmax) {
  //  Calcul du nombre de compartiments d'un tableau de hachage permettant de
  //    contenir au moins une entrée sous la contrainte du taux de remplissage
  //    maximum. Le résultat du calcul est la valeur finale de m.
  if (lfmax < 2 * sizeof(cell *) / (double) PTRDIFF_MAX) {
    return nullptr;
  }
  size_t m = 1;
  while ((double) m * lfmax < 1.0) {
    m *= 2;
  }
  hashtable *ht = malloc(sizeof(hashtable));
  cell **a = malloc(m * sizeof(cell *));
  if (ht == nullptr || a == nullptr) {
    free(ht);
    free(a);
    return nullptr;
  }
  for (size_t k = 0; k < m; ++k) {
    a[k] = nullptr;
  }
  ht->compar = compar;
  ht->hashfun = hashfun;
  ht->lfmax = lfmax;
  ht->hasharray = a;
  ht->nslots = m;
  ht->nentries = 0;
  return ht;
}

void hashtable_dispose(hashtable **htptr) {
  if (*htptr == nullptr) {
    return;
  }
  for (size_t k = 0; k < (*htptr)->nslots; ++k) {
    cell *p = (*htptr)->hasharray[k];
    while (p != nullptr) {
      cell *t = p;
      p = p->next;
      free(t);
    }
  }
  free((*htptr)->hasharray);
  free(*htptr);
  *htptr = nullptr;
}

void *hashtable_add(hashtable *ht, const void *keyref, const void *valref) {
  if (valref == nullptr) {
    return nullptr;
  }
  cell **pp = hashtable__search(ht, keyref);
  if (*pp != nullptr) {
    const void *r = (*pp)->valref;
    (*pp)->valref = valref;
    return (void *) r;
  }
  if ((double) ht->nentries >= ht->lfmax * (double) ht->nslots) {
    if (hashtable__increase(ht) != 0) {
      return nullptr;
    }
    pp = hashtable__search(ht, keyref);
  }
  cell *p = malloc(sizeof(cell));
  if (p == nullptr) {
    return nullptr;
  }
  p->keyref = keyref;
  p->valref = valref;
  p->next = *pp;
  *pp = p;
  ht->nentries += 1;
  return (void *) valref;
}

void *hashtable_remove(hashtable *ht, const void *keyref) {
  cell **pp = hashtable__search(ht, keyref);
  if (*pp == nullptr) {
    return nullptr;
  }
  cell *p = *pp;
  const void *r = p->valref;
  *pp = p->next;
  free(p);
  ht->nentries -= 1;
  return (void *) r;
}

void *hashtable_search(hashtable *ht, const void *keyref) {
  const cell *p = *hashtable__search(ht, keyref);
  return p == nullptr ? nullptr : (void *) p->valref;
}

#if defined HASHTABLE_EXT && defined WANT_HASHTABLE_EXT

void hashtable_get_stats(hashtable *ht,
    struct hashtable_stats *htsptr) {
  size_t m = ht->nslots;
  size_t g = 0;
  double s = 0.0;
  for (size_t k = 0; k < m; ++k) {
    size_t f = 0;
    const cell *p = ht->hasharray[k];
    while (p != nullptr) {
      ++f;
      p = p->next;
    }
    if (f > g) {
      g = f;
    }
    s += (double) f * (double) (f + 1) / 2.0;
  }
  size_t n = ht->nentries;
  double r = (double) n / (double) m;
  *htsptr = (struct hashtable_stats) {
    .nslots = m,
    .nentries = n,
    .lfmax = ht->lfmax,
    .lfcurr = r,
    .maxlen = g,
    .postheo = (n == 0 ? 0.0 : 1.0 + (r - 1.0 / (double) m) / 2.0),
    .poscurr = s / (double) n,
  };
}

#define P_TITLE(textstream, name) \
  fprintf(textstream, "--- Info: %s\n", name)
#define P_VALUE(textstream, name, format, value) \
  fprintf(textstream, "%16s\t" format "\n", name, value)

int hashtable_fprint_stats(hashtable *ht, FILE *textstream) {
  struct hashtable_stats hts;
  hashtable_get_stats(ht, &hts);
  return 0 > P_TITLE(textstream, "Hashtable stats")
    || 0 > P_VALUE(textstream, "n.slots", "%zu", hts.nslots)
    || 0 > P_VALUE(textstream, "n.entries", "%zu", hts.nentries)
    || 0 > P_VALUE(textstream, "load.fact.max", "%lf", hts.lfmax)
    || 0 > P_VALUE(textstream, "load.fact.curr", "%lf", hts.lfcurr)
    || 0 > P_VALUE(textstream, "max.len", "%zu", hts.maxlen)
    || 0 > P_VALUE(textstream, "pos.theo", "%lf", hts.postheo)
    || 0 > P_VALUE(textstream, "pos.curr", "%lf", hts.poscurr);
}

#endif
