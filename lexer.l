%option noyywrap
%{
//Autor: Anna Świerzy
#include "parser_y.h"
#include <stdio.h>
#include <string>
#include <stdlib.h>

extern YYSTYPE yyval;
%}

%%
\n                      { yylineno++; } 
\#[^\n]*\n              { yylineno++; } 
[_a-z]+                 { yylval.id = strdup(yytext);yylloc.first_line = yylineno; return PIDENTIFIER; }
[0-9]+                  { 
                            try {
                                yylval.val = std::stoll(yytext);
                                yylloc.first_line = yylineno;
                                return NUM;
                            } catch (const std::exception) {
                                fprintf(stderr, "Stała przekracza 64 bity w linii %d: %s\n", yylineno, yytext);
                                exit(1);
                            }
                        }
"PROGRAM"              {yylloc.first_line = yylineno; return PROGRAM; }
"IS"                   {yylloc.first_line = yylineno; return IS; }
"BEGIN"                {yylloc.first_line = yylineno; return PBEGIN; }
"END"                  {yylloc.first_line = yylineno; return END; }
"PROCEDURE"            {yylloc.first_line = yylineno; return PROCEDURE; }
"IF"                   {yylloc.first_line = yylineno; return IF; }
"THEN"                 {yylloc.first_line = yylineno; return THEN; }
"ELSE"                 {yylloc.first_line = yylineno; return ELSE; }
"ENDIF"                {yylloc.first_line = yylineno; return ENDIF; }
"WHILE"                {yylloc.first_line = yylineno; return WHILE; }
"DO"                   {yylloc.first_line = yylineno; return DO; }
"ENDWHILE"             {yylloc.first_line = yylineno; return ENDWHILE; }
"FOR"                  {yylloc.first_line = yylineno; return FOR; }
"FROM"                 {yylloc.first_line = yylineno; return FROM; }
"TO"                   {yylloc.first_line = yylineno; return TO; }
"DOWNTO"               {yylloc.first_line = yylineno; return DOWNTO; }
"ENDFOR"               {yylloc.first_line = yylineno; return ENDFOR; }
"REPEAT"               {yylloc.first_line = yylineno; return REPEAT; }
"UNTIL"                {yylloc.first_line = yylineno; return UNTIL; }
"READ"                 {yylloc.first_line = yylineno; return READ; }
"WRITE"                {yylloc.first_line = yylineno; return WRITE; }
"+"                    {yylloc.first_line = yylineno; return PLUS; }
"-"                    {yylloc.first_line = yylineno; return MINUS; }
"*"                    {yylloc.first_line = yylineno; return MULT; }
"/"                    {yylloc.first_line = yylineno; return DIV; }
"%"                    {yylloc.first_line = yylineno; return MOD; }
"="                    {yylloc.first_line = yylineno; return EQUAL; }
"!"                   {yylloc.first_line = yylineno; return NOT; }
">"                    {yylloc.first_line = yylineno; return GREATER; }
"<"                    {yylloc.first_line = yylineno; return LESS; }
"("                    {yylloc.first_line = yylineno; return LPAREN; }
")"                    {yylloc.first_line = yylineno; return RPAREN; }
","                    {yylloc.first_line = yylineno; return COMMA; }
":"                    {yylloc.first_line = yylineno; return COLON; }
";"                    {yylloc.first_line = yylineno; return SEMICOLON; }
"["                    {yylloc.first_line = yylineno; return LBRACKET; }
"]"                    {yylloc.first_line = yylineno; return RBRACKET; }
"T"                    {yylloc.first_line = yylineno; return T; }
[ \t\r]+                { /* Pomijanie białych znaków */ }
.                       { fprintf(stderr, "Nieznany symbol: %s\n", yytext); exit(1); }

%%
