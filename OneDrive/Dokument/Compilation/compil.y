%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "type.h"    // <-- NOUVEAU : Inclusion indispensable pour type_t
#include "symbole.h" 

int yylex();
void yyerror(char const *s);
extern FILE *yyin;
extern void yyrestart(FILE *input_file);

// --- VARIABLES GLOBALES POUR LA GÉNÉRATION DE CODE ---
int label_count = 0;
int path = 0; 
// Gestion de la mémoire de la machine SIPRO
int offset_courant = 2; 
int memoire_locales[100]; 
int index_algo_p1 = 0;    
int index_algo_p2 = 0;    

/* DÉFINITION DES LABELS POUR L'ASSEMBLEUR */
#define label_dowhile "dowhile_label_"
#define label_dofori "dofori_label_"
#define label_if "if_label_"
#define label_else "else_label_"
#define label_operateur "operateur_label_"
%}

%union {
    int integer;
    char* str;
    type_t type_expr; // <-- NOUVEAU : Transport du type
}
/* La suite de ton code avec les %token ... */

/* Les tokens envoyés par Flex */
%token BEGIN_ALGO END_ALGO SET IF ELSE DOWHILE DOFORI CALL RETURN OD FI
%token <integer> INT
%token <str> ID
%token TRUE FALSE

/* Types pour les règles qui remontent des valeurs */
%type <integer> liste_arguments liste_param_call 
%type <type_expr> EXPR // <-- NOUVEAU : EXPR a un type

/* Priorités mathématiques */
%left '<' '>' '=' SOE IOE
%left '+' '-'
%left '*' '/'

%start programme

%%

/* ========================================================================== */
/* STRUCTURE GLOBALE DU PROGRAMME                                             */
/* ========================================================================== */

programme:
    liste_algorithmes 
    {
        if (path == 1) {
            printf(":debut_programme\n");
        }
    }
    appel_final
    ;

liste_algorithmes:
    algorithme
    | liste_algorithmes algorithme
    ;

/* ========================================================================== */
/* DÉFINITION D'UN ALGORITHME                                                 */
/* ========================================================================== */

algorithme:
    BEGIN_ALGO '{' ID '}' '{' 
    {
        // --- SÉCURITÉ : Unicité des fonctions (Règle L III) ---
        if (path == 0) {
            Symbole *existant = rechercheExecutable($3);
            if (existant != NULL && existant->classe == C_FONCTION) {
                fprintf(stderr, "Erreur sémantique : La fonction '%s' est déjà déclarée.\n", $3);
                exit(EXIT_FAILURE);
            }
            ajouteIdentificateur($3, C_FONCTION, UNDEF, 0); 
        }

        entreeFonction();   
        offset_courant = 2; 
    }
    liste_arguments '}' 
    {
        // --- SÉCURITÉ : Enregistrement du nombre d'arguments ---
        if (path == 0) {
            Symbole *func_symb = rechercheExecutable($3);
            if (func_symb != NULL) {
                func_symb->nb_params = $7;
            }
        }

        fixerOffsetsArguments($7);
        if(path == 1){
            printf(":%s\n", $3);             
            printf("\tpush bp\n");           
            printf("\tcp bp,sp\n");         
            
            int espace = memoire_locales[index_algo_p2];
            if (espace > 0) {
                printf("\tconst cx,%d\n", espace);
                printf("\tadd sp,cx\n");    
            }
            index_algo_p2++;
        }
    }
    liste_instructions 
    END_ALGO
    { 
        if (path == 0) {
            memoire_locales[index_algo_p1] = offset_courant - 2;
            index_algo_p1++;
        } else {
            printf("\tcp sp,bp\n");
            printf("\tpop bp\n");
            printf("\tret\n");
        }
        sortieFonction(); 
    }
    ;

liste_arguments:
    /* vide */ { $$ = 0; }
    | ID 
    {
        ajouteIdentificateur($1, C_ARGUMENT, INT_T, 0); 
        $$ = 1;
    }
    | liste_arguments ',' ID
    {
        ajouteIdentificateur($3, C_ARGUMENT, INT_T, 0);
        $$ = $1 + 1; 
    }
    ;

/* ========================================================================== */
/* INSTRUCTIONS                                                               */
/* ========================================================================== */

liste_instructions:
    instruction
    | liste_instructions instruction
    ;

instruction:
    affectation
    | struct_if
    | struct_dowhile
    | struct_dofori
    | struct_return
    | appel_proc
    ;

affectation:
    SET '{' ID '}' '{' EXPR '}' 
    {
        Symbole *symb = rechercheExecutable($3);
        
        // --- SÉCURITÉ : Inférence ou vérification de type ---
        if (symb == NULL) {
            // Inférence
            symb = ajouteIdentificateur($3, C_VARIABLE, $6, offset_courant);
            offset_courant += 2; 
        } else {
            // Vérification
            if (symb->type != $6) {
                fprintf(stderr, "Erreur sémantique : Incompatibilité de type. La variable '%s' ne peut pas changer de type.\n", $3);
                exit(EXIT_FAILURE);
            }
        }
        
        if (path == 1) {
            printf("\tpop ax\n");                      
            printf("\tcp bx,bp\n"); 
            if (symb->adresse < 0) {
                printf("\tconst cx,%d\n", -symb->adresse);
                printf("\tsub bx,cx\n");                   
            } else {
                printf("\tconst cx,%d\n", symb->adresse);
                printf("\tadd bx,cx\n");                   
            }
            printf("\tstorew ax,bx\n");               
        }
    }
    ;

struct_return:
    RETURN '{' EXPR '}' 
    {
        if (path == 1) {
            printf("\tpop ax\n");      
            printf("\tcp sp,bp\n");   
            printf("\tpop bp\n");      
            printf("\tret\n");         
        }
    }
    ;

/* --- IF / ELSE --- */
struct_if:
    IF '{' EXPR '}' 
    {   
        // --- SÉCURITÉ : La condition doit être booléenne ---
        if ($3 != BOOL_T) {
            fprintf(stderr, "Erreur sémantique : La condition du IF doit être booléenne.\n");
            exit(EXIT_FAILURE);
        }

        if (path == 1) {
            int l_sinon = ++label_count;
            int l_fin = ++label_count;
            $<integer>$ = (l_sinon << 16) | (l_fin & 0xFFFF);
            
            printf("\tpop ax\n");          
            printf("\tconst bx,0\n");     
            printf("\tconst dx,%s%d\n", label_else, l_sinon); // CONST AVANT CMP !
            printf("\tcmp ax,bx\n");      
            printf("\tjmpc dx\n");        
        }
    }
    liste_instructions 
    {
        if (path == 1) {
            int l_sinon = ($<integer>5 >> 16) & 0xFFFF;
            int l_fin = $<integer>5 & 0xFFFF;
            
            printf("\tconst dx,%s%d\n", label_if, l_fin);
            printf("\tjmp dx\n");          
            printf(":%s%d\n", label_else, l_sinon);
        }
    }
    suite_if FI 
    {
        if (path == 1) {
            int l_fin = $<integer>5 & 0xFFFF;
            printf(":%s%d\n", label_if, l_fin);
        }
    }
    ;

suite_if:
    /* vide */  
    | ELSE liste_instructions 
    ;

/* --- DOWHILE --- */
struct_dowhile:
    DOWHILE 
    {
        if (path == 1) {
            int l_debut = ++label_count;
            int l_fin = ++label_count;
            $<integer>$ = (l_debut << 16) | (l_fin & 0xFFFF);
            printf(":%s%d\n", label_dowhile, l_debut);
        }
    }
    '{' EXPR '}' 
    {
        // --- SÉCURITÉ : La condition doit être booléenne ---
        if ($4 != BOOL_T) {
            fprintf(stderr, "Erreur sémantique : La condition du DOWHILE doit être booléenne.\n");
            exit(EXIT_FAILURE);
        }

        if (path == 1) {
            int l_fin = $<integer>2 & 0xFFFF;
            printf("\tpop ax\n");
            printf("\tconst bx,0\n");
            printf("\tconst dx,%s%d\n", label_dowhile, l_fin); // CONST AVANT CMP
            printf("\tcmp ax,bx\n");
            printf("\tjmpc dx\n"); 
        }
    }
    liste_instructions OD
    {
        if (path == 1) {
            int l_debut = ($<integer>2 >> 16) & 0xFFFF;
            int l_fin = $<integer>2 & 0xFFFF;
            
            printf("\tconst dx,%s%d\n", label_dowhile, l_debut);
            printf("\tjmp dx\n"); 
            printf(":%s%d\n", label_dowhile, l_fin); 
        }
    }
    ;

/* --- DOFORI --- */
struct_dofori:
    DOFORI '{' ID '}' '{' EXPR '}' 
    {   
        // --- SÉCURITÉ : Borne début doit être entière ---
        if ($6 != INT_T) {
            fprintf(stderr, "Erreur sémantique : La borne de début du DOFORI doit être un entier.\n");
            exit(EXIT_FAILURE);
        }

        Symbole *symb = rechercheExecutable($3);
        if (symb == NULL) {
            symb = ajouteIdentificateur($3, C_VARIABLE, INT_T, offset_courant);
            offset_courant += 2;
        } else if (symb->type != INT_T) {
            fprintf(stderr, "Erreur sémantique : L'itérateur '%s' n'est pas un entier.\n", $3);
            exit(EXIT_FAILURE);
        }

        if(path == 1) {
            int l_debut = ++label_count; 
            int l_fin = ++label_count;
            $<integer>$ = (l_debut << 16) | (l_fin & 0xFFFF); 

            printf("\tpop ax\n");                      
            printf("\tcp bx,bp\n"); 
            
            // CORRECTION : Prise en charge des adresses négatives (arguments)
            if (symb->adresse < 0) {
                printf("\tconst cx,%d\n", -symb->adresse);
                printf("\tsub bx,cx\n");
            } else {
                printf("\tconst cx,%d\n", symb->adresse); 
                printf("\tadd bx,cx\n");                  
            }
            printf("\tstorew ax,bx\n");               
            printf(":%s%d\n", label_dofori, l_debut);
        }
    }
    '{' EXPR '}' 
    {
        // --- SÉCURITÉ : Borne fin doit être entière ---
        if ($10 != INT_T) {
            fprintf(stderr, "Erreur sémantique : La borne de fin du DOFORI doit être un entier.\n");
            exit(EXIT_FAILURE);
        }

        if (path == 1) {
            int l_fin = $<integer>8 & 0xFFFF; 
            Symbole *symb = rechercheExecutable($3);
            
            printf("\tpop bx\n"); 
            printf("\tcp cx,bp\n"); 
            
            // CORRECTION
            if (symb->adresse < 0) {
                printf("\tconst dx,%d\n", -symb->adresse);
                printf("\tsub cx,dx\n");
            } else {
                printf("\tconst dx,%d\n", symb->adresse); 
                printf("\tadd cx,dx\n");      
            }
            printf("\tloadw ax,cx\n");    

            printf("\tconst dx,%s%d\n", label_dofori, l_fin); // CONST AVANT SLESS
            printf("\tsless bx,ax\n");    
            printf("\tjmpc dx\n");         
        }
    }
    liste_instructions OD
    {
        if (path == 1) {
            int l_debut = ($<integer>8 >> 16) & 0xFFFF;
            int l_fin = $<integer>8 & 0xFFFF;
            Symbole *symb = rechercheExecutable($3);
            
            printf("\tcp cx,bp\n"); 
            
            // CORRECTION
            if (symb->adresse < 0) {
                printf("\tconst dx,%d\n", -symb->adresse);
                printf("\tsub cx,dx\n");
            } else {
                printf("\tconst dx,%d\n", symb->adresse); 
                printf("\tadd cx,dx\n");
            }
            printf("\tloadw ax,cx\n");    
            printf("\tconst bx,1\n");
            printf("\tadd ax,bx\n");      
            printf("\tstorew ax,cx\n");   
            
            printf("\tconst dx,%s%d\n", label_dofori, l_debut);
            printf("\tjmp dx\n");
            printf(":%s%d\n", label_dofori, l_fin);
        }
    }
    ;

/* ========================================================================== */
/* APPEL DE FONCTION ET EXPR                                                  */
/* ========================================================================== */

appel_final:
    CALL '{' ID '}' '{' liste_param_call '}'
    {
        // --- SÉCURITÉ : Appel Final ---
        Symbole *func_symb = rechercheExecutable($3);
        if (func_symb == NULL || func_symb->classe != C_FONCTION) {
            fprintf(stderr, "Erreur sémantique : La fonction '%s' n'existe pas.\n", $3);
            exit(EXIT_FAILURE);
        }
        if (func_symb->nb_params != $6) {
            fprintf(stderr, "Erreur : %d argument(s) attendu(s) pour '%s', %d fourni(s).\n", func_symb->nb_params, $3, $6);
            exit(EXIT_FAILURE);
        }

        if (path == 1) {
            printf("\tconst dx,%s\n", $3);
            printf("\tcall dx\n");
            
            int nb_args = $6; 
            for(int i = 0; i < nb_args; i++) {
                printf("\tpop cx\n"); 
            }
            
            printf("\tpush ax\n");         
            printf("\tcp bx,sp\n");       
            printf("\tcallprintfd bx\n");  
            printf("\tpop ax\n");       
        }
    }
    ;

appel_proc:
    CALL '{' ID '}' '{' liste_param_call '}'
    {
        // --- SÉCURITÉ : Appel Procédure ---
        Symbole *func_symb = rechercheExecutable($3);
        if (func_symb == NULL || func_symb->classe != C_FONCTION) {
            fprintf(stderr, "Erreur sémantique : La fonction '%s' n'existe pas.\n", $3);
            exit(EXIT_FAILURE);
        }
        if (func_symb->nb_params != $6) {
            fprintf(stderr, "Erreur : %d argument(s) attendu(s) pour '%s', %d fourni(s).\n", func_symb->nb_params, $3, $6);
            exit(EXIT_FAILURE);
        }

        if (path == 1) {
            printf("\tconst dx,%s\n", $3);
            printf("\tcall dx\n");
            int nb_args = $6; 
            for(int i = 0; i < nb_args; i++) printf("\tpop cx\n");
        }
    }
    ;

liste_param_call:
    /* vide */ { $$ = 0; }
    | EXPR { $$ = 1; }
    | liste_param_call ',' EXPR { $$ = $1 + 1; }
    ;

EXPR:
    INT 
    { 
        if(path == 1) {
            printf("\tconst ax,%d\n", $1);
            printf("\tpush ax\n");
        }
        $$ = INT_T; // Typage
    }
    | TRUE
    {
        if(path == 1) {
            printf("\tconst ax,1\n");
            printf("\tpush ax\n");
        }
        $$ = BOOL_T; // Typage
    }
    | FALSE
    {
        if(path == 1) {
            printf("\tconst ax,0\n");
            printf("\tpush ax\n");
        }
        $$ = BOOL_T; // Typage
    }
    | ID 
    { 
        // --- SÉCURITÉ : La variable doit exister ---
        Symbole *symb = rechercheExecutable($1);
        if (symb == NULL) {
            fprintf(stderr, "Erreur sémantique : La variable '%s' est lue avant d'être affectée.\n", $1);
            exit(EXIT_FAILURE);
        }

        $$ = symb->type; // On fait remonter le type

        if (path == 1) {
            printf("\tcp bx,bp\n");
            if (symb->adresse < 0) {
                printf("\tconst cx,%d\n", -symb->adresse);
                printf("\tsub bx,cx\n");
            } else {
                printf("\tconst cx,%d\n", symb->adresse);
                printf("\tadd bx,cx\n");
            }
            printf("\tloadw ax,bx\n");
            printf("\tpush ax\n");
        }
    }
    | CALL '{' ID '}' '{' liste_param_call '}'
    {
        // --- SÉCURITÉ : Appel Fonction dans EXPR ---
        Symbole *func_symb = rechercheExecutable($3);
        if (func_symb == NULL || func_symb->classe != C_FONCTION) {
            fprintf(stderr, "Erreur sémantique : La fonction '%s' n'existe pas.\n", $3);
            exit(EXIT_FAILURE);
        }
        if (func_symb->nb_params != $6) {
            fprintf(stderr, "Erreur : %d argument(s) attendu(s) pour '%s', %d fourni(s).\n", func_symb->nb_params, $3, $6);
            exit(EXIT_FAILURE);
        }

        $$ = INT_T; // On assume que toutes les fonctions retournent des entiers (AlgoSIPRO)

        if (path == 1) {
            printf("\tconst dx,%s\n", $3);
            printf("\tcall dx\n");
            
            int nb_args = $6; 
            for(int i = 0; i < nb_args; i++) {
                printf("\tpop cx\n");
            }
            printf("\tpush ax\n"); 
        }
    }
    | EXPR '+' EXPR 
    {   
        // --- SÉCURITÉ MATHÉMATIQUE ---
        if ($1 != INT_T || $3 != INT_T) {
            fprintf(stderr, "Erreur de typage : L'addition requiert deux entiers.\n");
            exit(EXIT_FAILURE);
        }
        $$ = INT_T;
        if(path == 1) {
            printf("\tpop bx\n");
            printf("\tpop ax\n");
            printf("\tconst dx,erreur_add_mul\n");
            printf("\tadd ax,bx\n");
            printf("\tjmpe dx\n");
            printf("\tpush ax\n");
        }
    }
    | EXPR '-' EXPR 
    {
        if ($1 != INT_T || $3 != INT_T) {
            fprintf(stderr, "Erreur de typage : La soustraction requiert deux entiers.\n");
            exit(EXIT_FAILURE);
        }
        $$ = INT_T;

        if(path == 1) {
            printf("\tpop bx\n");
            printf("\tpop ax\n");
            printf("\tsub ax,bx\n");
            printf("\tpush ax\n");
        }
    }
    | EXPR '*' EXPR 
    {
        if ($1 != INT_T || $3 != INT_T) {
            fprintf(stderr, "Erreur de typage : La multiplication requiert deux entiers.\n");
            exit(EXIT_FAILURE);
        }
        $$ = INT_T;

        if(path == 1) {
            printf("\tpop bx\n");
            printf("\tpop ax\n");
            printf("\tconst dx,erreur_add_mul\n");
            printf("\tmul ax,bx\n");
            printf("\tjmpe dx\n");
            printf("\tpush ax\n");
        }
    }
    | EXPR '/' EXPR 
    {
        if ($1 != INT_T || $3 != INT_T) {
            fprintf(stderr, "Erreur de typage : La division requiert deux entiers.\n");
            exit(EXIT_FAILURE);
        }
        $$ = INT_T;

        if(path == 1) {
            printf("\tpop bx\n");
            printf("\tpop ax\n");
            printf("\tconst dx,erreur_div0\n");
            printf("\tdiv ax,bx\n");
            printf("\tjmpe dx\n");
            printf("\tpush ax\n");
        }
    }
   |EXPR '<' EXPR{

        if ($1 != INT_T || $3 != INT_T) {
            fprintf(stderr, "Erreur de typage : Les comparaisons de grandeurs requièrent deux entiers.\n");
            exit(EXIT_FAILURE);
        }
        $$ = BOOL_T;
        if(path ==1){
            int lv = label_count++;
            int lf = label_count++;
            
            printf("\tpop bx\n");
            printf("\tpop ax\n");
            printf("\tconst dx,%s%d\n", label_operateur, lv); // AVANT SLESS
            printf("\tsless ax,bx\n"); // CORRECTION: sless au lieu de uless
            printf("\tjmpc dx\n"); 

            printf("\tconst ax,0\n");
            printf("\tconst dx,%s%d\n", label_operateur, lf);  
            printf("\tjmp dx\n");

            printf(":%s%d\n", label_operateur, lv); 
            printf("\tconst ax,1\n");

            printf(":%s%d\n", label_operateur, lf); 
            printf("\tpush ax\n");
        }
    }
    | EXPR '>' EXPR 
    {
        if ($1 != INT_T || $3 != INT_T) {
            fprintf(stderr, "Erreur de typage : Les comparaisons de grandeurs requièrent deux entiers.\n");
            exit(EXIT_FAILURE);
        }
        $$ = BOOL_T;

        if(path == 1){
            int lv = label_count++;
            int lf = label_count++;
            
            printf("\tpop bx\n");
            printf("\tpop ax\n");
            printf("\tconst dx,%s%d\n", label_operateur, lv); // AVANT SLESS
            printf("\tsless bx,ax\n"); 
            printf("\tjmpc dx\n"); 

            printf("\tconst ax,0\n");
            printf("\tconst dx,%s%d\n", label_operateur, lf);  
            printf("\tjmp dx\n");

            printf(":%s%d\n", label_operateur, lv); 
            printf("\tconst ax,1\n");

            printf(":%s%d\n", label_operateur, lf); 
            printf("\tpush ax\n");
        }
    }
    | EXPR '=' EXPR 
    {
        if ($1 != $3) {
            fprintf(stderr, "Erreur de typage : L'égalité requiert deux éléments du même type.\n");
            exit(EXIT_FAILURE);
        }
        $$ = BOOL_T;

        if(path ==1){
            int lv = label_count++;
            int lf = label_count++;
            
            printf("\tpop bx\n");
            printf("\tpop ax\n");
            printf("\tconst dx,%s%d\n", label_operateur, lv); // AVANT CMP
            printf("\tcmp ax,bx\n");
            printf("\tjmpc dx\n"); 

            printf("\tconst ax,0\n");
            printf("\tconst dx,%s%d\n", label_operateur, lf);  
            printf("\tjmp dx\n");

            printf(":%s%d\n", label_operateur, lv); 
            printf("\tconst ax,1\n");

            printf(":%s%d\n", label_operateur, lf); 
            printf("\tpush ax\n");
        }
    }
    | EXPR SOE EXPR 
    { 
        if ($1 != INT_T || $3 != INT_T) {
            fprintf(stderr, "Erreur de typage : Les comparaisons de grandeurs requièrent deux entiers.\n");
            exit(EXIT_FAILURE);
        }
        $$ = BOOL_T;

        if(path == 1){
            int lv = label_count++;
            int lf = label_count++;
            int lfin = label_count++;

            printf("\tpop bx\n");
            printf("\tpop ax\n");
            
            // CORRECTION : Ordre inversé, const dx préparé pour FAUX (lf)
            printf("\tconst dx,%s%d\n", label_operateur, lf); 
            printf("\tsless bx,ax\n"); 
            printf("\tjmpc dx\n"); 
            
            // Sinon (ax <= bx), c'est VRAI
            printf("\tconst dx,%s%d\n", label_operateur, lv);
            printf("\tjmp dx\n");
            
            printf(":%s%d\n", label_operateur, lv); // Cas VRAI
            printf("\tconst ax,1\n");
            printf("\tconst dx,%s%d\n", label_operateur, lfin);
            printf("\tjmp dx\n");

            printf(":%s%d\n", label_operateur, lf); // Cas FAUX
            printf("\tconst ax,0\n");
            printf("\tconst dx,%s%d\n", label_operateur, lfin);
            printf("\tjmp dx\n");
        
            printf(":%s%d\n", label_operateur, lfin); 
            printf("\tpush ax\n");
        }
    }
    | EXPR IOE EXPR 
    {
        if ($1 != INT_T || $3 != INT_T) {
            fprintf(stderr, "Erreur de typage : Les comparaisons de grandeurs requièrent deux entiers.\n");
            exit(EXIT_FAILURE);
        }
        $$ = BOOL_T;

        if(path == 1){
            int lv = label_count++;
            int lf = label_count++;
            int lfin = label_count++;

            printf("\tpop bx\n");
            printf("\tpop ax\n");
            
            // CORRECTION : sless et const dx en ordre
            printf("\tconst dx,%s%d\n", label_operateur, lf);
            printf("\tsless ax,bx\n"); // CORRECTION: sless au lieu de uless
            printf("\tjmpc dx\n");

            printf("\tconst dx,%s%d\n", label_operateur, lv); 
            printf("\tjmp dx\n");

            printf(":%s%d\n", label_operateur, lv); 
            printf("\tconst ax,1\n");
            printf("\tconst dx,%s%d\n", label_operateur, lfin);
            printf("\tjmp dx\n");

            printf(":%s%d\n", label_operateur, lf); 
            printf("\tconst ax,0\n");
            printf("\tconst dx,%s%d\n", label_operateur, lfin);
            printf("\tjmp dx\n");
        
            printf(":%s%d\n", label_operateur, lfin); 
            printf("\tpush ax\n");
        }
    }
    ;

%%

void yyerror(char const *s) {
    fprintf(stderr, "Erreur de syntaxe : %s\n", s);
}

int main(int argc, char **argv) {
    if (argc < 2) {
        fprintf(stderr, "Usage: %s fichier.algo\n", argv[0]);
        return EXIT_FAILURE;
    }

    yyin = fopen(argv[1], "r");
    if (!yyin) {
        perror("Erreur d'ouverture du fichier");
        return EXIT_FAILURE;
    }

    // --- PASSE 1 : Construction de la table et des offsets ---
    path = 0;
    initDico(); 
    if (yyparse() != 0) {
        fclose(yyin);
        return EXIT_FAILURE;
    }

   // --- ON REVIENT AU DÉBUT DU FICHIER ---
    rewind(yyin); 
    yyrestart(yyin); // <--- LA LIGNE MAGIQUE POUR SAUVER LA PASSE 2 !

    // --- PASSE 2 : Génération de l'assembleur SIPRO ---
    path = 1;
    
    // Initialisation : On place la pile à 10000 et ON SAUTE AU DÉBUT
    printf("\tconst ax,pile\n");          
    printf("\tcp bp,ax\n");                 
    printf("\tcp sp,ax\n");
    printf("\tconst ax,debut_programme\n"); 
    printf("\tjmp ax\n\n");                 
   
    if (yyparse() != 0) {
        fclose(yyin);
        return EXIT_FAILURE;
    }

    printf("\tend\n");

    //Gestion des erreurs 
    printf(":erreur_div0\n");
    printf("\tconst ax,msg_div0\n");
    printf("\tcallprintfs ax\n"); // Affiche le message d'erreur 
    printf("\tend\n");

    printf(":erreur_add_mul\n");
    printf("\tconst ax,msg_add_mul\n");
    printf("\tcallprintfs ax\n"); // Affiche le message d'erreur 
    printf("\tend\n");


    //Gestion des messages d'erreurs 
    printf(":msg_div0\n");
    printf("@string \"Erreur fatale : Division par zero !\\n\"\n");

    printf(":msg_add_mul\n");
    printf("@string \"Erreur fatale : entier trop grand!\\n\"\n");


    printf(":pile\n");     
    printf("@int 0\n");
    
    fclose(yyin);
    return EXIT_SUCCESS;
}
