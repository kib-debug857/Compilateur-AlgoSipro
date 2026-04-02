SHELL=/bin/sh
LEX=flex
YACC=bison
CC=gcc
CFLAGS=-g -std=c2x -pedantic -Wall -Werror -Wwrite-strings \
       #-DVERBOSE
OPT=
LDFLAGS=
# --nounput: ne génère pas la fonction yyunput() inutile
# --DYY_NO_INPUT: ne prend pas en compte la fonction input() inutile
# -D_POSIX_SOURCE: déclare la fonction fileno()
LEXOPTS=-D_POSIX_SOURCE -DYY_NO_INPUT --nounput
YACCOPTS=

PROG=compil

# --- C'EST ICI QUE CA CHANGE : Ajout de symbole.o ---
$(PROG): lex.yy.o $(PROG).tab.o symbole.o
	$(CC) $+ -o $@ $(LDFLAGS) 

# --- Règle pour la table des symboles ---
symbole.o: symbole.c symbole.h
	$(CC) $(CFLAGS) $(OPT) $< -c

lex.yy.c: $(PROG).l $(PROG).tab.h
	$(LEX) $(LEXOPTS) $<

lex.yy.h: $(PROG).l
	$(LEX) $(LEXOPTS) --header-file=$@ $<

$(PROG).tab.c $(PROG).tab.h: $(PROG).y lex.yy.h
	$(YACC) $(YACCOPTS) $< -d -v --graph

%.o: %.c
	$(CC) $(CFLAGS) $(OPT) $< -c

clean:
	touch $(PROG).output $(PROG).vcg
	rm -f $(PROG) *.o *.output *.vcg 
	rm -f lex.yy.* $(PROG).tab.*

