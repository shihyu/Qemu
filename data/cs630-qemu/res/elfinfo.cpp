//-------------------------------------------------------------------
//	elfinfo.cpp	(modification of the 'loadmap.cpp' utility)
//
//	This utility displays a map showing the arrangement and the
//	sizes of the various regions in a relocatable or executable 
//	ELF file, whose filename was supplied on the command-line.
//
//	programmer: ALLAN CRUSE
//	written on: 29 MAR 2004
//-------------------------------------------------------------------

#include <stdio.h>	// for printf(), perror() 
#include <fcntl.h>	// for open() 
#include <stdlib.h>	// for exit() 
#include <unistd.h>	// for read(), write(), close() 
#include <string.h>	// for strncmp()
#include <malloc.h>	// for malloc()
#include <elf.h>	// for Elf32_Ehdr, Elf32_Shdr, Elf32_Phdr

#define ELFMAGIC "\177ELF"

typedef struct node {
		char		nodename[30];
		unsigned long	base, size, flags;
		struct node	*next;
		} NODE;

NODE	HDR = { "<<    ELF FILE-HEADER   >>" };
NODE	SHT = { "<< SECTION-HEADER TABLE >>" };
NODE	PHT = { "<< PROGRAM-HEADER TABLE >>" };

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
	if ( argc == 1 ) 
		{ printf( "No input-file\n" );	exit(1); }

	// open the specified program-file
	int	fd = open( argv[1], O_RDONLY );
	if ( fd < 0 ) { perror( argv[1] ); exit(1); }
	
	int	size = lseek( fd, 0, SEEK_END );
	void	*input = malloc( size );
	
	lseek( fd, 0, SEEK_SET );
	if ( read( fd, input, size ) < size )
		{ perror( "read" ); exit(1); }

	printf( "\nFilename: \'%s\' \t", argv[1] );

	Elf32_Ehdr	*ehdr = (Elf32_Ehdr*)input;
	if ( strncmp( (char*)ehdr->e_ident, ELFMAGIC, 4 ) )
		{ printf( "Not an ELF-format file\n" ); exit(1); }

	switch( ehdr->e_type )
		{
		case ET_REL:
			printf( "ELF type is \'relocatable\'\n" );
			break;
		case ET_EXEC:	
			printf( "ELF type is \'executable\'\n" );
			break;
		default:
			printf( "File is neither linkable nor executable\n" );
			exit(1);
		}	
			
	if ( ehdr->e_machine != EM_386 )
		{ printf( "Not an IA32 executable\n" ); exit(1); }

	printf( "Filesize: %d bytes (=0x%08X) \n", size, size );
	
	// initialize HDR
	HDR.size = ehdr->e_ehsize;
	HDR.next = &PHT;

	// initialize PHT
	PHT.base = ehdr->e_phoff;
	PHT.size = ehdr->e_phnum * sizeof( Elf32_Phdr ); 
	PHT.next = &SHT;
	
	// initialize SHT
	SHT.base = ehdr->e_shoff;
	SHT.size = ehdr->e_shnum * sizeof( Elf32_Shdr ); 
	
	// allocate storage for the linked-list's nodes
	pool = (NODE*)malloc( ehdr->e_shnum * sizeof( NODE ) );
	fill = (NODE*)malloc( ehdr->e_shnum * sizeof( NODE ) );
	
	printf( "\nsection-header table at offset 0x%08X ", ehdr->e_shoff );
	printf( "(%d entries) \n", ehdr->e_shnum );

	int	shnum = ehdr->e_shnum;
	Elf32_Shdr	*shdr = (Elf32_Shdr*)( (int)ehdr + ehdr->e_shoff );

	char	*strtbl = (char*)((int)ehdr+shdr[ehdr->e_shstrndx].sh_offset );
	
	for (int i = 0; i < shnum; i++)
		{
		pool[i].base = shdr[i].sh_offset;
		pool[i].size = shdr[i].sh_size;
		pool[i].flags = shdr[i].sh_flags;
		sprintf( pool[i].nodename, " SECTION #%d: ", i );
		strncat( pool[i].nodename, strtbl + shdr[i].sh_name, 15 );
		}

	for (int i = 1; i < shnum; i++) insert( &pool[i], list );	

	for (int i = 0; i < shnum; i++)
		{
		fill[i].base = pool[i].base + pool[i].size;
		if ( pool[i].next )
			fill[i].size = pool[i].next->base - fill[i].base;
		sprintf( fill[i].nodename, "    << filler >>      " );
		fill[i].flags = 0;
		}
	
	for (int i = 0; i < shnum; i++) 
		if ( fill[i].size ) insert( &fill[i], list );

	NODE	*p = list;
	while ( p ) 
		{
		printf( "\n" );
		if ( p->flags & SHF_ALLOC ) printf( " LOAD " );
		else	printf( "      " );
		printf( "%08X-%08X ", p->base, p->base + p->size );
		printf( " %08X ", p->size );
		printf( "%-30s ", p->nodename );
		p = p->next;	
		}
	printf( "\n" );
	
	printf( "\nprogram-header table at offset 0x%08X ", ehdr->e_phoff );
	printf( "(%d entries) \n", ehdr->e_phnum );

	int	phnum = ehdr->e_phnum;
	Elf32_Phdr	*phdr = (Elf32_Phdr*)( (int)ehdr + ehdr->e_phoff ); 	
	
	for (int i = 0; i < phnum; i++)
		{
		printf( "\nprogram-header #%d: \n", i );
		printf( "p_type=%d ", phdr[i].p_type );	
		printf( "p_offset=%08X ", phdr[i].p_offset );
		printf( "p_vaddr=%08X ", phdr[i].p_vaddr );
		printf( "p_paddr=%08X ", phdr[i].p_paddr );
		printf( "\np_filesz=%d ", phdr[i].p_filesz );
		printf( "p_memsz=%d ", phdr[i].p_memsz );
		printf( "p_flags=%04X ", phdr[i].p_flags );
		printf( "p_align=%04X ", phdr[i].p_align );
		printf( "\n" );
		}
		
	printf( "\nprogram entry-point: 0x%08X \n", ehdr->e_entry );
	printf( "\n" );
}
