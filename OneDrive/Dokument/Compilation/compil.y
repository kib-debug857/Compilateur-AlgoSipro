%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int yylex();
void yyerror(char const *s);
int label_count = 0;
%}

%union {
    int integer;
    char* str;
}

/* Les tokens envoyés par Flex */
%token BEGIN_ALGO END_ALGO SET IF ELSE DOWHILE DOFORI CALL RETURN OD FI
%token <integer> INT
%token <str> ID
%type <integer> si_cond 
/* Priorités mathématiques */
%left '+' '-'
%left '*' '/'

%start programme

%%

programme:
    algorithme appel_final
    ;

algorithme:
    BEGIN_ALGO '{' ID '}' '{' liste_arguments '}' 
    liste_instructions 
    END_ALGO
    { printf("=> SUCCES : Fin de la lecture de l'algo '%s'\n", $3); }
    ;

liste_arguments:
    /* vide */
    | ID
    | liste_arguments ',' ID
    ;

liste_instructions:
    /* vide */
    | liste_instructions instruction
    ;

instruction:
    affectation
    /* On ajoutera les autres instructions ici plus tard */
    ;

affectation:
    SET '{' ID '}' '{' EXPR '}'{
        printf("\tpop ax\n");         
        printf("\tconst bx,%s\n", $3); 
        printf("\tstorew ax,bx\n");
     }
    ;
si_cond: 
    IF '{' EXPR  '=' EXPR'}'{
        $$ = ++label_count; /* Génère le numéro unique, par ex: 1 */
        
        printf("\n\t; --- Évaluation de la condition IF ---\n");
        printf("\tpop bx\n");
        printf("\tpop ax\n");
        printf("\tcmp ax,bx\n");
        
        printf("\tjmpc L_VRAI_%d\n", $$); /* Si Vrai, on saute dans le bloc IF */
        printf("\tjmp L_FAUX_%d\n", $$);  /* Si Faux, on saute au bloc ELSE (ou à la fin) */
        
        printf(":L_VRAI_%d\n", $$);       /* Pancarte du début du code VRAI */
    }
    ;
bloc_if:
    /* CAS 1 : IF tout court (sans ELSE) */
    si_cond liste_instructions FI {
        printf("\n\t; --- Fin du IF (sans ELSE) ---\n");
        printf(":L_FAUX_%d\n", $1); /* S'il n'y a pas de ELSE, L_FAUX sert de fin ! */
    }
    
    /* CAS 2 : IF avec un ELSE */
  | si_cond liste_instructions ELSE {
        /* On arrive ici quand les instructions du IF (Vrai) sont terminées */
        printf("\tjmp L_FIN_%d\n", $1); /* On a fini le Vrai, on saute par-dessus le Else ! */
        
        printf("\n\t; --- Début du ELSE ---\n");
        printf(":L_FAUX_%d\n", $1);     /* C'est ici qu'on atterrit si la condition était fausse */
        
    } 
    liste_instructions FI {
        /* On arrive ici à la toute fin */
        printf("\n\t; --- Fin du bloc IF/ELSE ---\n");
        printf(":L_FIN_%d\n", $1);      /* La pancarte de fin générale */
    }
    ;
EXPR:
    EXPR '+' EXPR { 
        printf("\tpop bx\n");
        printf("\tpop ax\n");
        printf("\tadd ax,bx\n");
        printf("\tpush ax\n");
     }
  | EXPR '-' EXPR { 
        printf("\tpop bx\n");
        printf("\tpop ax\n");
        printf("\tsub ax,bx\n"); 
        printf("\tpush ax\n");
     }
  | EXPR '*' EXPR { 
        printf("\tpop bx\n");
        printf("\tpop ax\n");
        printf("\tmul ax,bx\n");
        printf("\tpush ax\n");
     }
  | EXPR '/' EXPR { 
        printf("\tpop bx\n");
        printf("\tpop ax\n");
        printf("\tdiv ax,bx\n");
        printf("\tpush ax\n");
     }
  | INT           { 
        printf("\tconst ax,%d\n", $1); 
        printf("\tpush ax\n");
     }
  | ID            { 
        printf("\tconst bx,%s\n", $1); 
        printf("\tloadw ax,bx\n");    
        printf("\tpush ax\n");
     }
  | '(' EXPR ')'  { printf("Expression parenthésée\n"); }
  ;

appel_final:
    CALL '{' ID '}' '{' liste_valeurs '}'
    { printf("=> SUCCES : Appel final de l'algo '%s'\n", $3); }
    ;

liste_valeurs:
    /* vide */
    | INT
    | liste_valeurs ',' INT
    ;

%%

void yyerror(char const *s) {
    fprintf(stderr, "Erreur syntaxique : %s\n", s);
}

int main() {
    printf("Début de la compilation...\n");
    yyparse();
    printf("Compilation terminée sans erreur syntaxique !\n");
    return EXIT_SUCCESS;
}