//-------------------------------------------------------------------
//	cpuid.cpp
//
//	This Linux application illustrates the use of the Pentium's
//	CPUID instruction, to display "feature-bits" which indicate
//	the specific capabilities that this processor implements.   
//
//	      to compile-and-link: $ g++ cpuid.cpp -o cpuid
//
//	programmer: ALLAN CRUSE
//	written on: 05 MAY 2004
//	revised on: 16 NOV 2006 -- to improve format of the output
//-------------------------------------------------------------------

#include <stdio.h>	// for printf(), perror() 

int main( int argc, char **argv )
{
	unsigned long	reg_eax, reg_ebx, reg_ecx, reg_edx;
	int	i;

	for (i = 0; i < 3; i++)
		{
		asm(" movl %0, %%eax " :: "m" (i) );
		asm(" cpuid ");
		asm(" mov %%eax, %0 " : "=m" (reg_eax) );
		asm(" mov %%ebx, %0 " : "=m" (reg_ebx) );
		asm(" mov %%ecx, %0 " : "=m" (reg_ecx) );
		asm(" mov %%edx, %0 " : "=m" (reg_edx) );
	
		printf( "\n\t" );
		printf( "%d: ", i );
		printf( "eax=%08X ", reg_eax );
		printf( "ebx=%08X ", reg_ebx );
		printf( "ecx=%08X ", reg_ecx );
		printf( "edx=%08X ", reg_edx );
		}
	printf( "\n\n" );
}
