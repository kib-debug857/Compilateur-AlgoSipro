%{
  #include <stdlib.h>
  #include <stdio.h>
  #include <errno.h>
  //#include "type.h"
  #include <limits.h>
  #include "compil.tab.h"
  void string_to_int(int *r, const char *s);
  void yytext_copy(char **copy, const char *s);
%}

%option noyywrap

%%
 /* STRUCTURE DE L'ALGO */
"\\begin{algo}" {return BEGIN_ALGO;}
"\\end{algo}" {return END_ALGO;}

 /* COMMANDES À CONSIDERER*/
"\\SET" {return SET;}
"\\IF"  {return IF;}
"\\ELSE" {return ELSE;}
"\\ELSEIF" {return ELSEIF;}
"\\DOWHILE" {return DOWHILE;}
"\\DOFORI" {return DOFORI;}
"\\CALL" {return CALL;}
"\\RETURN" {return  RETURN;}

"\\OD" {return OD;}
"\\FI" {return FI;}


 /*TOKENS VU EN TP*/
0|[1-9][0-9]*   { string_to_int(&yylval.integer, yytext); return INT; }
[a-zA-Z][a-zA-Z0-9]* { yytext_copy(&yylval.str, yytext); return ID; }
"+"|"-"|"*"|"/"|"{"|"}"|","|"("|")"|"="|"<"|">" { return yytext[0]; }
"<=" { return SOE; }
">=" { return IOE; }
"true" { return TRUE; }
"false" { return FALSE; }
[[:blank:]]     {}
.               {fprintf(stderr, "Bad character: %c\n", yytext[0]);
                 yyterminate();}
\n              {}

%%

void string_to_int(int *r, const char *s) {
  char *p;
  long v;
  errno = 0;
  v = strtol(s, &p, 10);
  if ( ( *p != '\0' || ( errno == ERANGE 
                     && ( v == LONG_MIN || v == LONG_MAX ) ) ) 
       || ( v < INT_MIN || v > INT_MAX ) ) {
    fprintf(stderr, "Error converting string to int\n");
    exit(EXIT_FAILURE);
  } 
  *r = v;
}

void yytext_copy(char **id, const char *s) {
  char *copy = malloc(strlen(s) + 1);
  if (copy == NULL) {
    fprintf(stderr, "Memory allocation problem.\n");
    exit(EXIT_FAILURE);
  }
  strcpy(copy,s);
  *id = copy;
}

