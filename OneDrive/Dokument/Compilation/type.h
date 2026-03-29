#ifndef TYPE_H
#define TYPE_H

typedef enum {
    INT_T,
    BOOL_T,
    UNDEF
} type_t;

#endif

/*yyval : est une variable globale (tuyau) par lequel flex fait passer les informations
 *à bison. par défaut il est calibré pour faire passer les int. Maintenant
 *qu'on définit un nouveau type type_t il faut pouvoir faire comprendre à yyval
 *le nouveau type de donnée qu'il va reccevoir.
 *En plus de recevoir des int il peut aussi faire passer des éléments de type_t
 */

/*yytext est le texte exact que flex vient de lire sur la sortie ou dans le code qu'on veut compiler*/
 
