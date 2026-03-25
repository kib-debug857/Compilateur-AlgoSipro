%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int yylex();
void yyerror(char const *s);
%}

%union {
    int integer;
    char* str;
}

/* Les tokens envoyés par Flex */
%token BEGIN_ALGO END_ALGO SET IF ELSE DOWHILE DOFORI CALL RETURN OD FI
%token <integer> INT
%token <str> ID

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
        printf("\tconst bx, %s\n", $3); 
        printf("\tstorew ax, bx\n");
     }
    ;

EXPR:
    EXPR '+' EXPR { 
        printf("\tpop bx\n");
        printf("\tpop ax\n");
        printf("\tadd ax, bx\n");
        printf("\tpush ax\n");
     }
  | EXPR '-' EXPR { 
        printf("\tpop bx\n");
        printf("\tpop ax\n");
        printf("\tsub ax, bx\n"); 
        printf("\tpush ax\n");
     }
  | EXPR '*' EXPR { 
        printf("\tpop bx\n");
        printf("\tpop ax\n");
        printf("\tmul ax, bx\n");
        printf("\tpush ax\n");
     }
  | EXPR '/' EXPR { 
        printf("\tpop bx\n");
        printf("\tpop ax\n");
        printf("\tdiv ax, bx\n");
        printf("\tpush ax\n");
     }
  | INT           { 
        printf("\tconst ax, %d\n", $1); 
        printf("\tpush ax\n");
     }
  | ID            { 
        printf("\tconst bx, %s\n", $1); 
        printf("\tloadw ax, bx\n");    
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