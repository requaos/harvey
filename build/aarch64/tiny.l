%{
/*
 * tiny.l — lex execution-evidence input (06-06, RESEARCH OQ-2).
 * Minimal one-rule scanner: the donor guest's hlex compiles this to
 * lex.yy.c in the writable /tmp scratch, and the sweep asserts the
 * generated scanner fragment (yylex).  lex carries the same
 * execution-evidence class as yacc — no artifact-only carve-out.
 */
%}
%%
x	;
%%
