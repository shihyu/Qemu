//-------------------------------------------------------------------
//	smpinfo.cpp
//
//	This Linux program uses our custom 8086.ko kernel object to
//	perform a search, in the system's conventional memory area,
//	for the "MP Floating Pointer Structure" (see Multiprocessor
//	Specification, version 1.4). This structure is displayed in
//	hexadecimal format (if it exists) along with its associated 
//	"MP Base Configuration Table".
//	
//	  	compile-and-link: $ g++ smpinfo.cpp -o smpinfo
//	  	and execute with: $ ./smpinfo
//	
//	NOTE: This program requires that our '8086.c' device-driver
//	must already have been compiled and installed in the kernel
//	before attempting to execute it; in addition, a device-file 
//	('/dev/8086') with read-and-write privileges must have been
//	previously created by a system administrator.  
//
//		root#  mknod /dev/8086 c 86 0
//		root#  chmod a+rw /dev/8086
//		user$  mmake 8086
//		root#  /sbin/insmod 8086.ko
//	
//	NOTE: Written and tested with Linux kernel version 2.6.17.6
//
//	programmer: ALLAN CRUSE
//	written on: 04 MAY 2004
//	revised on: 16 NOV 2006 -- added comments about requirements
//	revised on: 26 DEC 2006 -- made type-change for Linux x86_64 
//-------------------------------------------------------------------

#include <stdio.h>	// for printf(), perror() 
#include <fcntl.h>	// for open() 
#include <stdlib.h>	// for exit() 
#include <string.h>	// for strncmp()
#include <sys/mman.h>	// for mmap()

typedef struct	{ unsigned short begin, reach; } ZONE;

ZONE	zone[3] = { { 0, 64 }, { 0, 64 }, { 0xF000, 0x1000 } };
char	devname[] = "/dev/8086";

int main( int argc, char **argv )
{
	// memory-map the one-megabyte real-mode physical memory
	int	fd = open( devname, O_RDONLY );
	if ( fd < 0 ) { perror( devname ); exit(1); }
	int	base = 0x00000000;
	int	size = 0x00100000;
	int	prot = PROT_READ;
	int	flag = MAP_FIXED | MAP_PRIVATE;
	void	*vm = (void*)base;
	if ( mmap( vm, size, prot, flag, fd, base ) == MAP_FAILED )
		{ perror( "mmap" ); exit(1); }
	printf( "\nmapped ms-dos memory \n" );	
	
	// get essential parameters from the ROM-BIOS DATA-AREA
	int	ebdaseg = *(unsigned short*)0x40E;
	int	ramsize = *(unsigned short*)0x413; 
	int	topkseg = (ramsize - 4)*1024;
	zone[0].begin = ebdaseg;
	zone[1].begin = topkseg;

	// search for the MP Floating Pointer structure
	char	*mpfp = (char*)0;
	for (int i = 0; i < 3; i++)
		{
		char	*s = (char*)(16L * zone[i].begin );
		for (int p = 0; p < zone[i].reach; p++)
			{
			if ( strncmp( s, "_MP_", 4 ) )  s += 16;
			else	{ mpfp = s; break; }
			}
		if ( mpfp ) break;
		}

	// exit if no MP Floating Pointer Structure is present
	if ( !mpfp ) 
		{
		printf( "MP Floating Pointer Structure not present\n" );
		exit(1);
		}
	
	// dump the MP Floating Pointer Structure
	printf( "\nMP Floating Pointer Structure\n" );
	printf( "\nmpfp = %08X  ", mpfp );	
	for (int i= 0; i < 16; i++) 
		printf( "%02X ", (unsigned char)mpfp[i] );
	printf( "\n" );
	
	// dump the MP Configuration Table's Header
	printf( "\nMP Configuration Table Header\n" );
	char	*mpct = (char*)*(unsigned int*)&mpfp[4];
	printf( "\nmpct = %08X  ", mpct );
	for (int i= 0; i < 44; i++) 
		{
		printf( "%02X ", (unsigned char)mpct[i] );
		if ( ( i % 16 ) == 15 ) printf( "\n                 " );
		}
	printf( "\n" );

	// display the OEM STRING in the MP Configuration Table
	char	oemstring[24] = "";
	strncpy( oemstring, mpct+8, 20 );
	printf( "%s\n", oemstring );

	// get length of the Base Configuration Table	
	int	baselen = *(int*)(mpct+4);
	baselen &= 0xFFFF;
	printf( "\nbaselen = %d \n", baselen );

	// dump the Base Configuration Table
	printf( "\nMP Base Configuration Table Entries\n" );
	char	*bct = mpct + 44;
	int	i = 44;
	while ( i < baselen )
		{
		int	len = ( mpct[i] ) ? 8 : 20;
		for (int j = 0; j < len; j++) 
			printf( "%02X ", (unsigned char)mpct[i+j] );
		i += len;
		printf( "\n" );
		}
	printf( "\n" );
}


