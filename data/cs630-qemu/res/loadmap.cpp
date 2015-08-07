//-------------------------------------------------------------------
//	loadmap.cpp
//
//	This utility displays a map showing the arrangement and the
//	sizes of the various sections within a relocatable ELF file 
//	whose filename is supplied as a command-line argument.
//
//			usage:  $ loadmap <filename>	
//
//	The program creates a linked-list for the various sections, 
//	sorted in order of their placements within the file, noting
//	sections which need to be loaded into memory for execution. 
//
//	programmer: ALLAN CRUSE
//	date begun: 16 JAN 2004
//	completion: 19 MAR 2004
//-------------------------------------------------------------------

#include <stdio.h>	// for printf(), perror() 
#include <fcntl.h>	// for open() 
#include <stdlib.h>	// for exit() 
#include <unistd.h>	// for read(), close() 
#include <string.h>	// for strncmp()
#include <malloc.h>	// for malloc()
#include <elf.h>	// for Elf32_Ehdr, Elf32_Shdr

#define ELFMAGIC "\177ELF"

typedef struct node {
		char		nodename[30];
		unsigned long	base, size, flags;
		struct node	*next;
		} NODE;

NODE	HDR = { "<<    ELF FILE-HEADER   >>" };
NODE	SHT = { "<< SECTION-HEADER TABLE >>" };

NODE	*list = &HDR;
NODE	*pool, *fill;

void insert( NODE *n, NODE *list )
{	
	NODE	*p = list;

	while ( p->next )
		{
		NODE	*q = p->next;	
		if ( q->base > n->base ) break;
		if (( q->base == n->base )&&( q->size )) break;
		p = q;
		}
	n->next = p->next;
	p->next = n;
}
	

int main( int argc, char **argv )
{
	// verify that a command-line argument was supplied
	if ( argc == 1 ) 
		{ printf( "No input-file\n" ); exit(1); }

	// open the specified file
	int	fd = open( argv[1], O_RDONLY );
	if ( fd < 0 ) { perror( argv[1] ); exit(1); }

	// allocate memory for the file	
	int	size = lseek( fd, 0, SEEK_END );
	void	*input = malloc( size );
	
	// read the file contents into memory
	lseek( fd, 0, SEEK_SET );
	if ( read( fd, input, size ) < size )
		{ perror( "read" ); exit(1); }
	
	// verify the file-format
	Elf32_Ehdr	*ehdr = (Elf32_Ehdr*)input;
	if ( strncmp( (char*)ehdr->e_ident, ELFMAGIC, 4 ) )
		{ printf( "Not an ELF-format file\n" ); exit(1); }
	if ( ehdr->e_type != ET_REL )
		{ printf( "Not a relocatable file\n" ); exit(1); }
	if ( ehdr->e_machine != EM_386 )
		{ printf( "Not an IA32 executable\n" ); exit(1); }

	// allocate storage for the linked-list's nodes
	int	shnum = ehdr->e_shnum;
	pool = (NODE*)malloc( shnum * sizeof( NODE ) );
	fill = (NODE*)malloc( shnum * sizeof( NODE ) );
	
	// initialize HDR node
	HDR.size = ehdr->e_ehsize;
	HDR.next = &SHT;

	// initialize SHT node
	SHT.base = ehdr->e_shoff;
	SHT.size = ehdr->e_shnum * sizeof( Elf32_Shdr ); 

	// initialize pointer to the Section-Header Table	
	Elf32_Shdr	*shdr = (Elf32_Shdr*)( (int)ehdr + ehdr->e_shoff );

	// initialize pointer to the Section-Header String-Table
	char	*strtbl = (char*)((int)ehdr+shdr[ehdr->e_shstrndx].sh_offset );
	
	// initialize the array of pool nodes
	for (int i = 0; i < shnum; i++)
		{
		pool[i].base = shdr[i].sh_offset;
		pool[i].size = shdr[i].sh_size;
		pool[i].flags = shdr[i].sh_flags;
		sprintf( pool[i].nodename, " SECTION #%d: ", i );
		strncat( pool[i].nodename, strtbl + shdr[i].sh_name, 15 );
		}

	// insert the (non-null) pool nodes into our linked-list
	for (int i = 1; i < shnum; i++) insert( &pool[i], list );	

	// initialize the array of fill nodes
	for (int i = 0; i < shnum; i++)
		{
		fill[i].base = pool[i].base + pool[i].size;
		if ( pool[i].next )
			fill[i].size = pool[i].next->base - fill[i].base;
		sprintf( fill[i].nodename, "    << filler >>      " );
		fill[i].flags = 0;
		}
	
	// insert the non-trivial fill-nodes into our linked-list
	for (int i = 0; i < shnum; i++) 
		if ( fill[i].size ) insert( &fill[i], list );
		
	// display map showing the layout of the file's sections	
	printf( "\n        MAP OF RELOCATABLE ELF FILE CONTENTS: " );	
	printf( "%s (%d bytes) \n", argv[1], size );
	NODE	*p = list;
	while ( p ) 
		{
		printf( "\n" );
		if ( p->flags & SHF_ALLOC ) printf( "LOAD--> " );
		else	printf( "        " );
		printf( "%08X-%08X ", p->base, p->base + p->size );
		printf( " %08X ", p->size );
		printf( "%-30s ", p->nodename );
		p = p->next;	
		}
	printf( "\n\n" );

	// release allocated resources
	free( fill );
	free( pool );
	free( input );
	close( fd );
}
