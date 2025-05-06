FLAGS = -W -O3

.PHONY = all clean cleanall

all: kompilator

kompilator: parser.y lexer.l
	bison -o parser_y.c -d parser.y
	flex -o lexer_l.c lexer.l
	g++ $(FLAGS) -o kompilator parser_y.c lexer_l.c
