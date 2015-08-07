//----------------------------------------------------------------
//	int86.h
//
//	This header supplies function-prototypes and structure-
//	declarations that are needed by the Linux SVGA graphics
//	application programs which we shall create and compile.   
//
//	programmer: ALLAN CRUSE
//	written on: 15 JUN 2005
//----------------------------------------------------------------

#ifndef _INT86
#define _INT86
#include <sys/vm86.h>	// for struct vm86plus_struct
extern int int86( int id, struct vm86plus_struct & );
extern int init8086( void );
#endif

