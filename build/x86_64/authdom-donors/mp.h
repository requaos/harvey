/*
 * mp.h — host-cc shim: opaque mpint for the vendored libsec.h
 * (18-03).  The vendored DES/SHA-1 donors never touch bignum code;
 * libsec.h only needs the type name for its declarations.
 */
#ifndef _AUTHDOM_SHIM_MP_H
#define _AUTHDOM_SHIM_MP_H

typedef struct mpint mpint;

#endif
