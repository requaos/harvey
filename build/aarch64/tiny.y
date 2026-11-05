%{
/*
 * tiny.y — yacc execution-evidence input (06-06, RESEARCH OQ-2).
 * Minimal one-rule grammar: the donor guest's hyacc compiles this to
 * y.tab.c in the writable /tmp scratch, and the sweep asserts the
 * generated parser fragment (yyparse).  A failure here is a genuine
 * toolchain defect (T1-FAIL), never exempt.
 */
%}
%%
line:	'x'
	;
%%
