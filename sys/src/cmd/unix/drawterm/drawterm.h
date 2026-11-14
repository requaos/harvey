extern int havesecstore(char *addr, char *owner);
extern char *secstore;
extern char secstorebuf[65536];
extern char *secstorefetch(char *addr, char *owner, char *passwd);
extern char *authserver;
extern char *readcons(char *prompt, char *def, int secret);
extern int exportfs(int, int);
extern char *user;
extern char *getkey(char*, char*);
extern char *findkey(char**, char*);
extern int dialfactotum(void);
extern char *getuser(void);
extern void cpumain(int, char**);

/* 19-06: -G no-window stdio session + -O pinned-connection spec */
extern int Gflag;		/* set by earlyflags before any gui init */
extern char *usagestr;
extern void earlyflags(int, char**);
extern void argusage(void);	/* usage exit via the real stderr */
extern void gconsinit(void);	/* console on the invoking terminal */
extern void gconsrestore(void);	/* tty restore; atexit-registered */
extern void gconsexit(char*);	/* -G exits(): restore + real exit */
