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

$(PROG): lex.yy.o $(PROG).tab.o
	$(CC) $+ -o $@ $(LDFLAGS) 

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
	rm $(PROG) *.o *.output *.vcg 
	rm lex.yy.* $(PROG).tab.*  
