%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <symbole.c>
#include <symbole.h>

int yylex();
void yyerror(char const *s);
int label_count = 0;
%}

/*Définition des labels utilisé pour les structures de contrôle*/
%define int label_count 0
%define label_dowhile "dowhile_label_"
%define label_dofori "dofori_label_"
%define label_if "if_label_"
%define label_else "else_label_"
%define label_operateur "operateur_label_"
int path = 0; /* Variable pour récupérer les paramètres et les variables locales*/

%union {
    int integer;
    char* str;
}

/* Les tokens envoyés par Flex */
%token BEGIN_ALGO END_ALGO SET IF ELSE ELSEIF DOWHILE DOFORI CALL RETURN OD FI
%token <integer> INT
%token <str> ID
%type <integer> si_cond 
/* Priorités mathématiques */
%left '<' '>' '=' SOE IOE
%left '+' '-'
%left '*' '/'

/*Les booleans*/
%token TRUE FALSE
/* Le token de départ */

%start programme

%%

programme:
    algorithme appel_final
    ;

algorithme:
    BEGIN_ALGO '{' ID '}' 
    {
        // PASSAGE 1 : Enregistrement de la fonction
        if (path == 0) {
            ajouteIdentificateur($3, C_FONCTION, UNDEF_T, 0); 
        }
        
        entreeFonction(); // On ouvre le contexte local (Passage 1 ET 2)
        
        // Initialisation des compteurs d'offsets
        current_arg_offset = -4;  // Le 1er argument sera à bp - 4
        current_local_offset = 2; // La 1ère variable locale sera à bp + 2
    }
    '{' liste_arguments '}' 
    {
        // PASSAGE 2 : On génère le prologue de la fonction
        if (path == 1) {
            printf(":%s\n", $3);             // Label de l'algorithme
            
            // 1. Mise en place du Cadre d'Appel (Stack Frame)
            printf("\tpush bp\n");           // Sauvegarde de l'ancien bp
            printf("\tcp bp, sp\n");         // Le nouveau bp pointe au sommet actuel de la pile
            
            // 2. Réservation de l'espace pour les variables locales
            // Au passage 2, current_local_offset contient la valeur finale calculée au passage 1
            int nb_vars = (current_local_offset - 2) / 2; 
            
            if (nb_vars > 0) {
                printf("\tconst ax, 0\n");
                for(int i = 0; i < nb_vars; i++) {
                    printf("\tpush ax\n");   // On empile des zéros pour allouer l'espace
                }
            }
        }
    }
    liste_instructions 
    END_ALGO
    {
        // PASSAGE 2 : L'épilogue (Nettoyage avant de retourner)
        if (path == 1) {
            // 1. On détruit les variables locales en redescendant sp à bp
            printf("\tcp sp, bp\n"); 
            
            // 2. On restaure le bp de la fonction qui nous a appelé
            printf("\tpop bp\n");    
            
            // 3. L'instruction ret dépile l'adresse de retour (mise par le call) et saute [cite: 338, 339]
            printf("\tret\n");       
        }
        
        // On ferme la boîte dans la table des symboles (Passage 1 ET 2)
        sortieFonction(); 
    }
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
    |struct_dowhile
    |struct_dofori
    |struct_if
    |struct_return
    |appel_final
    |struct_end
    ;

affectation:
    SET '{' ID '}' '{' EXPR '}'{

        if (path == 0) {
            // PASSAGE 1 : On gère la table des symboles
            Symbole* s = rechercheDeclarative($3);
            if (s == NULL) {
                ajouteIdentificateur($3, C_VARIABLE, INT_T, current_local_offset);
                current_local_offset += 2; 
            }
        } 
        else if (path == 1) {
            // PASSAGE 2 : On écrit l'assembleur
            Symbole* s = rechercheExecutable($3);
            if (s == NULL) {
                fprintf(stderr, "Erreur : La variable '%s' n'existe pas.\n", $3);
                exit(EXIT_FAILURE);
            }

            int offset = s->adresse; 

            printf("\tpop ax\n"); 
            printf("\tcp bx, bp\n");          
            printf("\tconst cx, %d\n", offset); 
            printf("\tadd bx, cx\n");         
            printf("\tstorew ax, bx\n");      
        }
    }

struct_dowhile:
    DOWHILE
    /*D'apport je commence par définir mon point d'encrage c'est la que je vais revenir à chaque tour de boucle gestion du while  */
    {
        label_count++;
        printf("\t:%s%d\n", label_dowhile, label_count);
        $<integer>$ = label_count; /* Stocke le numéro de label pour ce DO-WHILE */
    } 
    liste_instructions
    '{'EXPR'}' OD
    {
        /*Dans l'odre il faut récupérer le résultat de l'expression puis faire le test avec la boucle et si il est vrai retourner au point d'encrage sinon sortir de la boucle */
        printf("\tpop ax\n"); /* Récupère le résultat de l'expression */
        printf("\tconst bx,1\n"); /* définit en dur la valeur 1 pour la comparaison dans le registre bx */
        printf("\tcmp ax,bx\n"); /* Compare le résultat de l'expression avec 1 si les deux sont à 1 alors on continue sinon cela veut dire que ax n'est pas vrai */

        print("\tconst dx,%s%d\n", label_dowhile, $<integer>$); /* Définit le label de saut pour la boucle DO-WHILE dans le registre dx*/
        printf("\tjmpc dx\n"); /* Si l'expression est vraie, retourne au point d'encrage */
    }
    ;

struct_dofori:
    DOFORI '{' ID '}' '{' EXPR '}' 
    //On commence par créer le point d'encrage de la boucle fori
    {   
        int l_debut = label_count++;
        int l_fin = label_count++;
        
        printf("\tpop ax\n"); 
        printf("\tconst bx, %s\n", $3); 
        printf("\tstorew ax, bx\n");   // On range la valeur de départ dans ax 

    }
    '{' EXPR '}' 
    {
        printf("\t:%s%d\n", label_dofori, l_debut);

        printf("\tpop ax\n");
        printf("\tconst bx,%s\n",$9);
        printf("\tsless ax,bx\n");

        /*Retour au début label*/
        printf("\tconst dx,%s%d\n",label_dofori,l_debut);
        printf("\tjumpc dx\n");


        /*Fin de la boucle*/
        printf("\tconst dx,%s%d\n", label_dofori, l_fin);
        printf("\tjmp dx\n");


    }liste_instructions OD
    {

    }
    ;
    
struct_if:
    IF '{' EXPR '}' liste_instructions  suite_if FI 
    {   
        int l_if = label_count++;
        int l_else = label_count++;


        printf("\tpop ax\n"); /*Evaluation de l'expression*/
        printf("\tconst bx, 1\n"); /*On définit la valeur 1 pour la comparaison*/
        printf("\tcmp ax,bx"); /* On vérifie si la valeur est vrais */

        /*Cas de figure numéro 1 c'est vrais alors on saute dans l_if*/
        printf("\tconst dx, :%s%d\n",label_if,l_if);
        printf("\tjumpc,")

        /*Cas de figure numéro 2 c'est faux alors on saute dans l_else*/
        printf("\tconst dx, :%s%d\n", label_else, l_else);
        printf("\tjmp dx\n");

    }

    suite_if:
        /* vide */  
        |ELSE liste_instructions 
        {   
            printf("\tpop ax\n");
            printf("\tconst bx, 1\n");
            printf("\tcmp ax,bx\n");

            /*Cas de figure numéro 1 c'est vrais alors on saute dans l_else*/
            printf("\tconst dx, %s%d\n", label_else, label_else);
            printf("\tjmp dx\n");


        }
        |ELSEIF '{' EXPR '}' liste_instructions suite_if
        {

        }

    ;

struct_return :
    RETURN '{' EXPR '}' 
    {
        printf("\tpop ax\n");
    }

struct_end :
    END_ALGO 
    {
        printf("\tend\n");
    }

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

  | EXPR '<' EXPR{
        int lv = label_count++;
        int lf = label_count++;
        
        printf("\tpop bx\n");
        printf("\tpop ax\n");
        printf("\tuless ax,bx\n");
       
        /*Cas de figure numéro 1 c'est vrais alors on saute dans lv*/
        printf("\tconst dx, %s%d\n", label_operateur, lv); /*Ce code est toujours le même*/
        printf("\tjmpc dx\n"); 

        /*Cas de figure numéro 2 c'est faux alors on saute dans lf*/
        printf("\tconst ax, 0\n");
        printf("\tconst dx, %s%d\n", label_operateur, lf); /*Ce code est toujours le même*/ 
        printf("\tjmp dx\n");


        /*On créer les endroits de sauts*/

        printf(":%s%d\n", label_operateur, lv); /*Label pour le cas ou c'est vrais*/
        printf("\tconst ax, 1\n");

        printf(":%s%d\n", label_operateur, lf); /*Label pour le cas ou c'est faux*/
        printf("\tpush ax\n");
    }
    | EXPR '>' EXPR{
        int lv = label_count++;
        int lf = label_count++;
        
        printf("\tpop bx\n");
        printf("\tpop ax\n");
        printf("\tsless bx,ax\n");
       
        /*Cas de figure numéro 1 c'est vrais alors on saute dans lv*/
        printf("\tconst dx,%s%d\n", label_operateur, lv); /*Ce code est toujours le même*/
        printf("\tjmpc dx\n"); 

        /*Cas de figure numéro 2 c'est faux alors on saute dans lf*/
        printf("\tconst ax, 0\n");
        printf("\tconst dx, %s%d\n", label_operateur, lf); /*Ce code est toujours le même*/ 
        printf("\tjmp dx\n");


        /*On créer les endroits de sauts*/

        printf(":%s%d\n", label_operateur, lv); /*Label pour le cas ou c'est vrais*/
        printf("\tconst ax, 1\n");

        printf(":%s%d\n", label_operateur, lf); /*Label pour le cas ou c'est faux*/
        printf("\tpush ax\n");
    }

    | EXPR '=' EXPR{
        int lv = label_count++;
        int lf = label_count++;
        
        printf("\tpop bx\n");
        printf("\tpop ax\n");
        printf("\tcmp ax,bx\n");
       
        /*Cas de figure numéro 1 c'est vrais alors on saute dans lv*/
        printf("\tconst dx, %s%d\n", label_operateur, lv); /*Ce code est toujours le même*/
        printf("\tjmpc dx\n"); 

        /*Cas de figure numéro 2 c'est faux alors on saute dans lf*/
        printf("\tconst ax, 0\n");
        printf("\tconst dx, %s%d\n", label_operateur, lf); /*Ce code est toujours le même*/ 
        printf("\tjmp dx\n");


        /*On créer les endroits de sauts*/

        printf(":%s%d\n", label_operateur, lv); /*Label pour le cas ou c'est vrais*/
        printf("\tconst ax, 1\n");

        printf(":%s%d\n", label_operateur, lf); /*Label pour le cas ou c'est faux*/
        printf("\tpush ax\n");
    }
    | EXPR SOE EXPR{
            int lv = label_count++;
            int lf = label_count++;
            int lfin = label_count++;

            printf("\tpop bx\n");
            printf("\tpop ax\n");
            printf("\tsless ax, bx\n");

            /*Cas de figure numéro 1 c'est vrais alors on saute dans lf car c'est faux */
            printf("\tconst dx, %s%d\n", label_operateur, lf); /*Ce code est toujours le même*/
            printf("\tjmpc dx\n");


            /*Cas de figure numéro 2 c'est faux alors on saute dans lv*/
            printf("\tconst dx,%s%d\n", label_operateur, lv); /*Ce code est toujours le même*/
            printf("\tjmp dx\n");


            printf(":%s%d\n", label_operateur, lv); /*Label pour le cas ou c'est vrais*/
            printf("\tconst ax, 1\n");
            printf("\tconst dx, %s%d\n", label_operateur, lfin);
            printf("\tjmp dx");

            printf(":%s%d\n", label_operateur, lf); /*Label pour le cas ou c'est faux*/
            printf("\tconst ax, 0\n");
            printf("\tconst dx, %s%d\n", label_operateur, lfin);
            printf("\tjmp dx");
        

            printf(":%s%d\n", label_operateur, lfin); /*Label de fin pour les deux cas*/
            printf("\tpush ax\n");
         }


    | EXPR IOE EXPR{
            int lv = label_count++;
            int lf = label_count++;
            int lfin = label_count++;

            printf("\tpop bx\n");
            printf("\tpop ax\n");
            printf("\tluess ax, bx\n");

            /*Cas de figure numéro 1 c'est vrais alors on saute dans lf car c'est faux */
            printf("\tconst dx, %s%d\n", label_operateur, lf); /*Ce code est toujours le même*/
            printf("\tjmpc dx\n");


            /*Cas de figure numéro 2 c'est faux alors on saute dans lv*/
            printf("\tconst dx,%s%d\n", label_operateur, lv); /*Ce code est toujours le même*/
            printf("\tjmp dx\n");


            printf(":%s%d\n", label_operateur, lv); /*Label pour le cas ou c'est vrais*/
            printf("\tconst ax, 1\n");
            printf("\tconst dx, %s%d\n", label_operateur, lfin);
            printf("\tjmp dx");

            printf(":%s%d\n", label_operateur, lf); /*Label pour le cas ou c'est faux*/
            printf("\tconst ax, 0\n");
            printf("\tconst dx, %s%d\n", label_operateur, lfin);
            printf("\tjmp dx");
        

            printf(":%s%d\n", label_operateur, lfin); /*Label de fin pour les deux cas*/
            printf("\tpush ax\n");
         }

  ;

appel_final:
    CALL '{' ID '}' '{' liste_valeurs '}'
    {
        printf("\tpop ax\n");
    }
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
    if(yyparse() == 0){
        return EXIT_FAILURE;
    }
    path++;
    yyparse();
    printf("Compilation terminée sans erreur syntaxique !\n");
    return EXIT_SUCCESS;
}