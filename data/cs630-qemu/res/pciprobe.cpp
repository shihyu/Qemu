//-------------------------------------------------------------------
//	pciprobe.cpp
//
//	This program performs a PCI bus-scan and displays the vendor
//	and device identification for each device-function detected.
//
//		compile using:  $ g++ pciprobe.cpp -o pciprobe
//		execute using:  $ ./pciprobe
//
//	NOTE: This program needs to execute privileged instructions;
//	hence you will first need to run our 'iopl3' system-utility.  
//
//				------------
//
//	IN-CLASS EXERCISE: Improve the usefulness of this utility by 
//	printing the 'CLASS CODE' with each of the device-functions. 
//
//	Reference:  
//	Shanley and Anderson, "PCI System Architecture (4th Edtion)"
//	MindShare, Inc (Addison-Wesley, 1999).
//	
//	programmer: ALLAN CRUSE
//	written on: 28 NOV 2006
//-------------------------------------------------------------------

#include <stdio.h>	// for printf(), perror() 
#include <unistd.h>	// for gethostname()  
#include <sys/io.h>	// for iopl(), in(), out()

#define	CONFADD	0x0CF8
#define	CONFDAT	0x0CFC
#define PMC	0x0CFB

int main( int argc, char **argv )
{
	if ( iopl( 3 ) ) { perror( "iopl" ); return 1; }

	char	hostname[ 64 ];
	gethostname( hostname, 64 );

	// enable configuration mechanism 1
	outb( inb( PMC ) | 1, PMC );

	// perform a pci bus scan operation
	printf( "\nSCANNING FOR PCI DEVICES on station \'%s\'\n\n", hostname );
	int	ndevs = 0;
	for (int bus = 0; bus < (1 << 8); bus++)
		{
		for (int dev = 0; dev < (1 << 5); dev++)
			{
			int	busdev = (bus << 16)|(dev << 11)|(1 << 31);
			int	pcidat, header, vendor, device;

			outl( busdev, CONFADD );
			pcidat = inl( CONFDAT );
			if ( pcidat == ~0 ) continue;
	
			outl( busdev + (3 << 2), CONFADD );
			header = ( inl( CONFDAT ) >> 16 )&0xFF;		

			vendor = (pcidat >>  0)&0xFFFF;
			device = (pcidat >> 16)&0xFFFF;

			printf( "bus=%-3d dev=%-2d ", bus, dev );
			if ( header & 0x80 ) 
				{
				printf( " (multi-function device) \n" );
				for (int fun = 0; fun < (1 << 3); fun++)
					{
					outl( busdev + (fun << 8), CONFADD );
					pcidat = inl( CONFDAT );
					if ( pcidat == ~0 ) continue;
					++ndevs;

					vendor = (pcidat >>  0)&0xFFFF;
					device = (pcidat >> 16)&0xFFFF;

					printf( "\tfunction %d ", fun );
					
					printf( " VENDOR=%04X ", vendor );
					printf( " DEVICE=%04X ", device );
					printf( "\n" );
					}
				}
			else 	{
				++ndevs;
				printf( " VENDOR=%04X ", vendor );
				printf( " DEVICE=%04X ", device );
				printf( "\n" );
				}
			printf( "\n" );
			}
		}
	printf( "Identified %d PCI device-functions ", ndevs ); 
	printf( "on station \'%s\' \n\n", hostname );
}	
