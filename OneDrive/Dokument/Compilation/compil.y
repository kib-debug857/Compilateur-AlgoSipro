%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "symbole.h" // Ta table des symboles

int yylex();
void yyerror(char const *s);
extern FILE *yyin;
extern void yyrestart(FILE *input_file); // <--- AJOUTE CETTE LIGNE ICI !

// --- VARIABLES GLOBALES POUR LA GÉNÉRATION DE CODE ---
int label_count = 0;
int path = 0; 
/*  */
// Gestion de la mémoire de la machine SIPRO
int offset_courant = 2; 
int memoire_locales[100]; 
int index_algo_p1 = 0;    
int index_algo_p2 = 0;    

/* DÉFINITION DES LABELS POUR L'ASSEMBLEUR (Ce sont des #define du C !) */
#define label_dowhile "dowhile_label_"
#define label_dofori "dofori_label_"
#define label_if "if_label_"
#define label_else "else_label_"
#define label_operateur "operateur_label_"
%}

%union {
    int integer;
    char* str;
}
/* La suite de ton code avec les %token ... */

/* Les tokens envoyés par Flex */
%token BEGIN_ALGO END_ALGO SET IF ELSE DOWHILE DOFORI CALL RETURN OD FI
%token <integer> INT
%token <str> ID
%token TRUE FALSE

/* Types pour les règles qui remontent des valeurs */
%type <integer> liste_arguments liste_param_call 

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
            printf(":debut_programme\n"); // L'étiquette est placée avant les PUSH !
        }
    }
    appel_final
    ;

liste_algorithmes:
    algorithme
    | liste_algorithmes algorithme
    ;

/* ========================================================================== */
/* DÉFINITION D'UN ALGORITHME (Le Contrat Appelé)                             */
/* ========================================================================== */

algorithme:
    BEGIN_ALGO '{' ID '}' '{' 
    {
            entreeFonction();   // Nouveau contexte
            offset_courant = 2; // On réinitialise l'offset pour les variables locales
        
    }
    liste_arguments '}' 
    {
      
        fixerOffsetsArguments($7); // $7 est le nombre d'arguments
        if(path == 1){
            // PROLOGUE
            printf(":%s\n", $3);             // Label de la fonction
            printf("\tpush bp\n");           // Sauvegarde l'ancien BP
            printf("\tcp bp,sp\n");         // Nouveau BP
            
            int espace = memoire_locales[index_algo_p2];
            if (espace > 0) {
                printf("\tconst cx,%d\n", espace);
                printf("\tadd sp,cx\n");    // Alloue l'espace pour les variables locales
            }
            index_algo_p2++;
        }
    }
    liste_instructions 
    END_ALGO
    { 
        if (path == 0) {
            // Fin de passe 1 : On sauvegarde la taille totale des variables locales
            memoire_locales[index_algo_p1] = offset_courant - 2;
            index_algo_p1++;
            
        } else {
            // ÉPILOGUE de sécurité (si pas de RETURN explicite)
            printf("\tcp sp,bp\n");
            printf("\tpop bp\n");
            printf("\tret\n");
        }
        sortieFonction(); // Ferme le contexte
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
    | appel_proc // Pour un CALL utilisé sans récupérer la valeur
    ;

affectation:
    SET '{' ID '}' '{' EXPR '}' 
    {
        // Dans les 2 passes, on ajoute la variable si elle n'existe pas encore !
        Symbole *symb = rechercheExecutable($3);
        if (symb == NULL) {
            symb = ajouteIdentificateur($3, C_VARIABLE, INT_T, offset_courant);
            offset_courant += 2; 
        }
        
        // Uniquement en Passe 2 pour l'assembleur
        if (path == 1) {
            printf("\tpop ax\n");                      
            printf("\tcp bx,bp\n"); 
            if (symb->adresse < 0) {
                printf("\tconst cx,%d\n", -symb->adresse); // On prend la valeur positive
                printf("\tsub bx,cx\n");                   // On soustrait !
            } else {
                printf("\tconst cx,%d\n", symb->adresse);
                printf("\tadd bx,cx\n");                   // On additionne
            }
            printf("\tstorew ax,bx\n");               
        }
     }
    ;

struct_return:
    RETURN '{' EXPR '}' 
    {
        if (path == 1) {
            printf("\tpop ax\n");      // Résultat dans AX
            printf("\tcp sp,bp\n");   // Désallocation des locales
            printf("\tpop bp\n");      // Restauration du contexte
            printf("\tret\n");         // Retour à l'appelant
        }
    }
    ;

/* --- IF / ELSE --- */
struct_if:
    IF '{' EXPR '}' 
    {   
        if (path == 1) {
            int l_sinon = ++label_count;
            int l_fin = ++label_count;
            $<integer>$ = (l_sinon << 16) | (l_fin & 0xFFFF);
            
            printf("\tpop ax\n");          
            printf("\tconst bx,0\n");     
            printf("\tconst dx,%s%d\n", label_else, l_sinon);
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
        if (path == 1) {
            printf(";Je suis la \n");
            int l_fin = $<integer>2 & 0xFFFF;
            printf("\tpop ax\n");
            printf("\tconst bx,0\n");
            printf("\tconst dx,%s%d\n", label_dowhile, l_fin);
            printf("\tcmp ax,bx\n");
            printf("\tjmpc dx\n"); // Sort de la boucle si faux
        }
    }
    liste_instructions OD
    {
        if (path == 1) {
            printf(";Je suis la  dans les instructions\n");

            int l_debut = ($<integer>2 >> 16) & 0xFFFF;
            int l_fin = $<integer>2 & 0xFFFF;
            
            printf("\tconst dx,%s%d\n", label_dowhile, l_debut);
            printf("\tjmp dx\n"); // Retour au début
            printf(":%s%d\n", label_dowhile, l_fin); // Label de sortie
        }
    }
    ;
/* --- DOFORI --- */
struct_dofori:
    DOFORI '{' ID '}' '{' EXPR '}' 
    {   
        
        Symbole *symb = rechercheExecutable($3);
        if (symb == NULL) {
            ajouteIdentificateur($3, C_VARIABLE, INT_T, offset_courant);
            offset_courant += 2;
        }
        if(path == 1) {
            int l_debut = ++label_count; 
            int l_fin = ++label_count;
            $<integer>$ = (l_debut << 16) | (l_fin & 0xFFFF); 

            Symbole *symb = rechercheExecutable($3);
            if(symb != NULL) {
                printf("\tpop ax\n");                      
                printf("\tcp bx,bp\n"); 
                printf("\tconst cx,%d\n", symb->adresse); 
                printf("\tadd bx,cx\n");                  
                printf("\tstorew ax,bx\n");               
                printf(":%s%d\n", label_dofori, l_debut);
            }
        }
    }
    '{' EXPR '}' 
    {
        if (path == 1) {
            int l_fin = $<integer>8 & 0xFFFF; 
            Symbole *symb = rechercheExecutable($3);
            
            printf("\tpop bx\n"); // Borne de fin
            printf("\tcp cx,bp\n"); 
            printf("\tconst dx,%d\n", symb->adresse); 
            printf("\tadd cx,dx\n");      
            printf("\tloadw ax,cx\n");    // Valeur de l'itérateur

            printf("\tconst dx,%s%d\n", label_dofori, l_fin);
            printf("\tsless bx,ax\n");    // Borne < Itérateur ?
            printf("\tjmpc dx\n");         // On sort
        }
    }
    liste_instructions OD
    {
        if (path == 1) {
            int l_debut = ($<integer>8 >> 16) & 0xFFFF;
            int l_fin = $<integer>8 & 0xFFFF;
            Symbole *symb = rechercheExecutable($3);
            
            // Incrémentation
            printf("\tcp cx,bp\n"); 
            printf("\tconst dx,%d\n", symb->adresse); 
            printf("\tadd cx,dx\n");      
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
        if (path == 1) {

            printf("\tconst dx,%s\n", $3);
            printf("\tcall dx\n");
            
            int nb_args = $6; 
            for(int i = 0; i < nb_args; i++) {
                printf("\tpop cx\n"); 
            }
            
            // Affichage du résultat final
            // Affichage du résultat final
            printf("\tpush ax\n");         
            printf("\tcp bx,sp\n");       
            // ON A SUPPRIMÉ LE const cx,2 ET LE sub bx,cx !
            printf("\tcallprintfd bx\n");  
            printf("\tpop ax\n");       
        }
    }
    ;

appel_proc:
    CALL '{' ID '}' '{' liste_param_call '}'
    {
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
    }
    | TRUE
    {
        if(path == 1) {
            printf("\tconst ax,1\n");
            printf("\tpush ax\n");
        }
    }
    | FALSE
    {
        if(path == 1) {
            printf("\tconst ax,0\n");
            printf("\tpush ax\n");
        }
    }
    | ID 
    { 
        if (path == 1) {
            Symbole *symb = rechercheExecutable($1);
            if (symb != NULL) {
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
    }
    | CALL '{' ID '}' '{' liste_param_call '}'
    {
        if (path == 1) {
            printf("\tconst dx,%s\n", $3);
            printf("\tcall dx\n");
            
            int nb_args = $6; 
            for(int i = 0; i < nb_args; i++) {
                printf("\tpop cx\n");
            }
            printf("\tpush ax\n"); // Range le retour du CALL pour le reste du calcul
        }
    }
    | EXPR '+' EXPR 
    {
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
        if(path == 1) {
            printf("\tpop bx\n");
            printf("\tpop ax\n");
            printf("\tsub ax,bx\n");
            printf("\tpush ax\n");
        }
    }
    | EXPR '*' EXPR 
    {
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
        if(path ==1){
            int lv = label_count++;
            int lf = label_count++;
            
            printf("\tpop bx\n");
            printf("\tpop ax\n");
            printf("\tconst dx,%s%d\n", label_operateur, lv); /*Ce code est toujours le même*/
            printf("\tuless ax,bx\n");
            
            /*Cas de figure numéro 1 c'est vrais alors on saute dans lv*/
            printf("\tjmpc dx\n"); 

            /*Cas de figure numéro 2 c'est faux alors on saute dans lf*/
            printf("\tconst ax,0\n");
            printf("\tconst dx,%s%d\n", label_operateur, lf); /*Ce code est toujours le même*/ 
            printf("\tjmp dx\n");


            /*On créer les endroits de sauts*/

            printf(":%s%d\n", label_operateur, lv); /*Label pour le cas ou c'est vrais*/
            printf("\tconst ax,1\n");

            printf(":%s%d\n", label_operateur, lf); /*Label pour le cas ou c'est faux*/
            printf("\tpush ax\n");
        }
    }
    |EXPR '>' EXPR{
        if(path == 1){
            int lv = label_count++;
            int lf = label_count++;
            
            printf("\tpop bx\n");
            printf("\tpop ax\n");
            printf("\tconst dx,%s%d\n", label_operateur, lv);
            printf("\tsless bx,ax\n");
            
            /*Cas de figure numéro 1 c'est vrais alors on saute dans lv*/
            printf("\tjmpc dx\n"); 

            /*Cas de figure numéro 2 c'est faux alors on saute dans lf*/
            printf("\tconst ax,0\n");
            printf("\tconst dx,%s%d\n", label_operateur, lf); /*Ce code est toujours le même*/ 
            printf("\tjmp dx\n");


            /*On créer les endroits de sauts*/

            printf(":%s%d\n", label_operateur, lv); /*Label pour le cas ou c'est vrais*/
            printf("\tconst ax,1\n");

            printf(":%s%d\n", label_operateur, lf); /*Label pour le cas ou c'est faux*/
            printf("\tpush ax\n");
        }
    }

    |EXPR '=' EXPR{
        if(path ==1){
            int lv = label_count++;
            int lf = label_count++;
            
            printf("\tpop bx\n");
            printf("\tpop ax\n");
            printf("\tconst dx,%s%d\n", label_operateur, lv);
            printf("\tcmp ax,bx\n");
        
            /*Cas de figure numéro 1 c'est vrais alors on saute dans lv*/
            printf("\tjmpc dx\n"); 
            /*Cas de figure numéro 2 c'est faux alors on saute dans lf*/
            printf("\tconst ax,0\n");
            printf("\tconst dx,%s%d\n", label_operateur, lf); /*Ce code est toujours le même*/ 
            printf("\tjmp dx\n");


            /*On créer les endroits de sauts*/

            printf(":%s%d\n", label_operateur, lv); /*Label pour le cas ou c'est vrais*/
            printf("\tconst ax,1\n");

            printf(":%s%d\n", label_operateur, lf); /*Label pour le cas ou c'est faux*/
            printf("\tpush ax\n");
        }
    }
    
    | EXPR SOE EXPR { 
        if(path == 1){
            int lv = label_count++;
            int lf = label_count++;
            printf("\tpop bx\n");
            printf("\tpop ax\n");
            printf("\tsless bx,ax\n"); // On vérifie si ax > bx
            
            // CORRECTION: Si bx < ax (donc ax > bx), la condition <= est FAUSSE
            printf("\tconst dx,%s%d\n", label_operateur, lf); 
            printf("\tjmpc dx\n"); // On saute direct au FAUX
            
            // Sinon (ax <= bx), c'est VRAI
            printf("\tconst ax,1\n");
            printf("\tconst dx,%s%d\n", label_operateur, lv);
            printf("\tjmp dx\n");
            
            printf(":%s%d\n", label_operateur, lf); // Cas FAUX
            printf("\tconst ax,0\n");
            
            printf(":%s%d\n", label_operateur, lv); // FIN
            printf("\tpush ax\n");
        }
    }


    | EXPR IOE EXPR{
        if(path == 1){
            int lv = label_count++;
            int lf = label_count++;
            int lfin = label_count++;

            printf("\tpop bx\n");
            printf("\tpop ax\n");
            printf("\tconst dx,%s%d\n", label_operateur, lf); /*Ce code est toujours le même*/
            printf("\tuless ax,bx\n");

            /*Cas de figure numéro 1 c'est vrais alors on saute dans lf car c'est faux */
            printf("\tjmpc dx\n");


            /*Cas de figure numéro 2 c'est faux alors on saute dans lv*/
            printf("\tconst dx,%s%d\n", label_operateur, lv); /*Ce code est toujours le même*/
            printf("\tjmp dx\n");


            printf(":%s%d\n", label_operateur, lv); /*Label pour le cas ou c'est vrais*/
            printf("\tconst ax,1\n");
            printf("\tconst dx,%s%d\n", label_operateur, lfin);
            printf("\tjmp dx\n");

            printf(":%s%d\n", label_operateur, lf); /*Label pour le cas ou c'est faux*/
            printf("\tconst ax,0\n");
            printf("\tconst dx,%s%d\n", label_operateur, lfin);
            printf("\tjmp dx\n");
        

            printf(":%s%d\n", label_operateur, lfin); /*Label de fin pour les deux cas*/
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
    printf("\tconst ax,debut_programme\n"); // On charge l'adresse
    printf("\tjmp ax\n\n");                 // On saute par-dessus les fonctions !
   
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
