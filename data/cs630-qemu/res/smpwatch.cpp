//-------------------------------------------------------------------
//	smpwatch.cpp
//
//	This application continuously reads the volatile kernel data 
//	that is stored in a pseudo-file (named '/proc/smpwatch') and 
//	displays it on the screen until the <ESCAPE> key is pressed.  
//	The 'data' consists of an array of 512 counters representing   
//	invocations of the Linux kernel's interrupt service routines 
//	on each of two logical processors in an SMP-enabled system.
//	 
//	   compile-and-link using: $ g++ smpwatch.cpp -o smpwatch
//
//	This program makes use of the 'select()' library-function to
//	support efficient handling of its multiplexed program-input.
//	It requires that an accompanying kernel object (smpwatch.ko)
//	has already been compiled and installed in the Linux kernel.
//
//	NOTE: Developed and tested with Linux kernel version 2.6.17.
//
//	programmer: ALLAN CRUSE
//	written on: 14 DEC 2006
//-------------------------------------------------------------------

#include <stdio.h>	// for printf(), fprintf() 
#include <fcntl.h>	// for open() 
#include <stdlib.h>	// for exit() 
#include <unistd.h>	// for read(), write(), close() 
#include <termios.h>	// for tcgetattr(), tcsetattr()

#define KEY_ESCAPE 27			// ASCII code for ESCAPE-key
#define FILENAME "/proc/smpwatch"	// name of input pseudo-file 

int main( void )
{
	// open the pseudo-file for reading 
	int	fd = open( FILENAME, O_RDONLY );
	if ( fd < 0 ) 
		{
		fprintf( stderr, "could not find \'%s\' \n", FILENAME );
		exit(1);
		}	

	// enable noncanonical terminal-mode
	struct termios	tty_orig;
	tcgetattr( STDIN_FILENO, &tty_orig );
	struct termios	tty_work = tty_orig;
	tty_work.c_lflag &= ~( ECHO | ICANON | ISIG );
	tty_work.c_cc[ VMIN ] = 1;
	tty_work.c_cc[ VTIME ] = 0;
	tcsetattr( STDIN_FILENO, TCSAFLUSH, &tty_work );

	// initialize file-descriptor bitmap for 'select()' 
	fd_set	permset;
	FD_ZERO( &permset );
	FD_SET( STDIN_FILENO, &permset );
	FD_SET( fd, &permset );

	// initialize the screen-display	
	printf( "\e[H\e[J" );		// clear the screen
	printf( "\e[?25l" );		// hide the cursor
	
	// draw the screen's title, headline and sideline
	int	i, ndev = 1+fd, row = 2, col = 25;
	printf( "\e[%d;%dHSMP INTERRUPT ACTIVITY MONITOR", row, col );
	for (i = 0; i < 16; i++)
		{
		// draw a sideline for each processor
		row = i+6;
		col = 2;
		printf( "\e[%d;%dH%02X:", row, col, i*16 );
		col += 40;
		printf( "\e[%d;%dH%02X:", row, col, i*16 );
		// draw a headline for each processor
		row = 5;
		col = i*2 + 6;
		printf( "\e[%d;%dH%X", row, col, i );
		col += 40;
		printf( "\e[%d;%dH%X", row, col, i );
		}
	// draw a footline for each processor
	for (i = 0; i < 2; i++)
		{
		char	banner[40] = {0};
		int	len = 0;
		len += sprintf( banner+len, "==========" );
		len += sprintf( banner+len, "  processor %d  ", i );
		len += sprintf( banner+len, "==========" );
		row = 22;
		col = 40*i + 2;
		printf( "\e[%d;%dH%s", row, col, banner );
		}
	fflush( stdout );
	
	// main loop: continuously responds to multiplexed input	
	for(;;)	{
		// sleep until some new data is ready to be read
		fd_set	readset = permset;
		if ( select( ndev, &readset, NULL, NULL, NULL ) < 0 ) break;

		// process new data read from the keyboard
		char	inch;
		if ( FD_ISSET( STDIN_FILENO, &readset ) )
			if ( read( STDIN_FILENO, &inch, 1 ) > 0 )
				if ( inch == KEY_ESCAPE ) break;

		// process new data read from the pseudo-file
		if ( FD_ISSET( fd, &readset ) )
			{
			unsigned char counter[ 512 ] = {0};
			lseek( fd, 0, SEEK_SET );
			if ( read( fd, counter, 512 ) < 512 ) break;
			for (i = 0; i < 512; i++)
				{
				int	cpu = i / 256;
				int	irq = i % 256;
				int 	row = ( irq / 16 ) + 6;
				int	col = ( irq % 16 ) * 2 + 40 * cpu + 6;
				unsigned long	what = counter[ i ] % 10;
				printf( "\e[%d;%dH", row, col );
				if ( !counter[i] ) printf( "-" );
				else	printf( "%01d", what );
				}
			row = 23;
			col = 0;
			}
		fflush( stdout );
		}

	// restore the standard user-interface	
	tcsetattr( STDIN_FILENO, TCSAFLUSH, &tty_orig );
	printf( "\e[23;0H\e[?25h\n" );		// show the cursor
}
