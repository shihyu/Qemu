//-------------------------------------------------------------------
//	int86.cpp
//
//	This file defines the support-functions which are needed by
//	our SVGA application-programs in order for Linux to execute
//	essential graphics firmware functions in virtual-8086 mode.
//
//	 init8086() sets up a simulated 8086 execution environment 
//	 int86() executes a 'real-mode' software interrupt routine
//
//	programmer: ALLAN CRUSE
//	written on: 14 JUN 2005
//	revised on: 15 AUG 2006 -- renamed device-file '/dev/8086'
//	revised on: 04 OCT 2006 -- revise two logprint statements
//-------------------------------------------------------------------

#include <stdio.h>	// for perror() 
#include <fcntl.h>	// for open() 
#include <stdlib.h>	// for exit() 
#include <sys/io.h>	// for outb(), inb(), etc.
#include <sys/mman.h>	// for mmap()
#include <sys/vm86.h>	// for vm86()

int int86( int id, struct vm86plus_struct & vm )
{
	int my_emulate( struct vm86plus_struct & );

	unsigned short	*wp = (unsigned short *)0x1FFFE;
	wp[0] = 0x90F4;		// 'hlt' (plus 'nop')
	wp[-1] = (1<<9);	// IF-bit (in EFLAGS)
	wp[-2] = 0x1000;	// real-mode CS-value 
	wp[-3] = 0xFFFE;	// real-mode IP-value

	vm.cpu_type = CPU_586;
	vm.regs.ss = 0x1000;	// real-mode SS-value
	vm.regs.esp = 0xFFF8;	// real-mode SP-value
	vm.regs.eflags = 0x23200; // VM=1,IOPL=3,IF=1
	vm.regs.cs = *(unsigned short*)( id*4 + 2 );
	vm.regs.eip = *(unsigned short*)( id*4 + 0 );
	while ( vm86( VM86_ENTER, &vm ) ) if ( my_emulate( vm ) ) break;

	if (( vm.regs.eip == 0xFFFE )&&( vm.regs.cs == 0x1000 )) return 0;
	return	-1;
}

int init8086( void )
{
	int	fd = open( "/dev/8086", O_RDWR );
	if ( fd < 0 ) { perror( "open /dev/8086" ); exit(1); }

	int	size = (1 << 20 );	// one megabyte
	int	prot = PROT_READ | PROT_WRITE | PROT_EXEC;
	int	flag = MAP_FIXED | MAP_SHARED;
	void	*vm = 0;
	if ( mmap( vm, size, prot, flag, fd, 0 ) == MAP_FAILED )
		{ perror( "mmap" ); exit(1); }
	return	1;
}

/*
** This helper-function handles any input/output attempts that could
** not be executed by the virtual machine in 'virtual-8086' mode; it 
** also detects any attempt to execute the privileged 'hlt' opcode.
**
** By uncommenting the following '#define' statement and redirecting
** standard-output to a file, you can discover which i/o-ports are
** being accessed by real-mode firmware routines.
*/

//#define IO_TRAPPING

#ifdef IO_TRAPPING 
#define logprintf printf
#else
#define logprintf
#endif
	
int my_emulate( struct vm86plus_struct &vm )
{
	static int	count = 0;
	unsigned char	*cp;
	unsigned int	dx, ax, al, eax;

	logprintf( "#%d: ", ++count );
	logprintf( "CS:EIP = %04X:%08X ", vm.regs.cs, vm.regs.eip );
	cp = (unsigned char*)(( vm.regs.cs << 4 ) + vm.regs.eip ); 	
	dx = (unsigned short)vm.regs.edx;

	if ( cp[0] == 0xF4 )	// hlt
		{
		logprintf( "hlt\n" );
		return	1;
		}
	else if ( cp[0] == 0xEF )	// outw
		{
		ax = (unsigned short)vm.regs.eax;
		logprintf( "outw( %04X, %04X ) \n", ax, dx );
		outw( ax, dx );
		vm.regs.eip += 1;
		return	0;
		}
	else if ( cp[0] == 0xEE )	// outb
		{
		al = (unsigned char)vm.regs.eax;
		logprintf( "outb( %02X, %04X ) \n", al, dx );
		outb( al, dx );
		vm.regs.eip += 1;
		return	0;
		}
	else if ( cp[0] == 0xED )	// inw
		{
		ax = inw( dx );
		vm.regs.eax &= ~0xFFFF;
		vm.regs.eax |= ax;
		logprintf( "%04X = inw( %04X ) \n", ax, dx );
		vm.regs.eip += 1;
		return	0;
		}
	else if ( cp[0] == 0xEC )	// inb
		{
		al = inb( dx );
		vm.regs.eax &= ~0xFF;
		vm.regs.eax |= al;
		logprintf( "%02X = inb( %04X ) \n", al, dx );
		vm.regs.eip += 1;
		return	0;
		}
	else if (( cp[0] == 0x66 )&&( cp[1] == 0xEF ))	// outl
		{
		eax = (unsigned int)vm.regs.eax;
		logprintf( "outl( %08X, %04X ) \n", eax, dx );
		outl( eax, dx );
		vm.regs.eip += 2;
		return	0;
		}
	else if (( cp[0] == 0x66 )&&( cp[1] == 0xED ))	// inl
		{
		eax = inl( dx );
		vm.regs.eax = eax;
		logprintf( "%08X = inl( %04X ) \n", eax, dx );
		vm.regs.eip += 2;
		return	0;
		}
	else if ( cp[0] == 0xE6 )	// outb al, nn
		{
		dx = cp[1];
		al = (unsigned char)vm.regs.eax;
		logprintf( "outb( %02X, %04X ) \n", al, dx );
		outb( al, dx );
		vm.regs.eip += 2;
		return	0;
		}
	else if ( cp[0] == 0xE4 )	// inb nn, al
		{
		dx = cp[1];
		al = inb( dx );
		vm.regs.eax &= ~0xFF;
		vm.regs.eax |= al;
		logprintf( "%02X = inb( %04X ) \n", al, dx );
		vm.regs.eip += 2;
		return	0;
		}
	else if ( cp[0] == 0xE7 )	// outl eax, nn
		{
		dx = cp[1];
		eax = (unsigned char)vm.regs.eax;
		logprintf( "outl( %08X, %04X ) \n", eax, dx );
		outl( eax, dx );
		vm.regs.eip += 2;
		return	0;
		}
	else if ( cp[0] == 0xE5 )	// inl nn, eax
		{
		dx = cp[1];
		eax = inl( dx );
		vm.regs.eax = eax;
		logprintf( "%08X = inl( %04X ) \n", eax, dx );
		vm.regs.eip += 2;
		return	0;
		}
	else if (( cp[0] == 0x66 )&&( cp[1] == 0xE7 ))	// outw ax, nn
		{
		dx = cp[2];
		ax = (unsigned short)vm.regs.eax;
		logprintf( "outw( %04X, %04X ) \n", ax, dx );
		outw( ax, dx );
		vm.regs.eip += 3;
		return	0;
		}
	else if (( cp[0] == 0x66 )&&( cp[1] == 0xE5 ))	// inw nn, ax
		{
		dx = cp[2];
		ax = (unsigned short)inw( dx );
		vm.regs.eax &= ~0xFFFF;
		vm.regs.eax |= ax;
		logprintf( "%04X = inw( %04X ) \n", ax, dx );
		vm.regs.eip += 3;
		return	0;
		}

	for (int i = 0; i < 15; i++) logprintf( "%02X ", cp[i] );
	logprintf( "\n" );
	return	-1;
}
