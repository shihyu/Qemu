//----------------------------------------------------------------
//	newasapp.cpp	
//
//	This utility will create 'boilerplate' assembly language 
//	code for a new CS630 protected-mode application program,
//	with a fault-handler for General Protection Exceptions.
//
//		to compile:  $ g++ newasm.cpp -o newapp
//		to execute:  $ ./newasapp <appname>
//
//	programmer: ALLAN CRUSE
//	written on: 24 NOV 2006 
//----------------------------------------------------------------

#include <stdio.h>	// for fprintf(), fopen(), etc
#include <string.h>	// for strncpy(), strncat()
#include <time.h>	// for time(), localtime()

char authorname[] = "ALLAN CRUSE";
char monthlist[] = "JANFEBMARAPRMAYJUNJULAUGSEPOCTNOVDEC";

int main( int argc, char *argv[] )
{
	// check for program-name as command-line argument
	if ( argc == 1 ) 
		{
		fprintf( stderr, "Must specify program-name\n" );
		return	-1;
		}

	// prepare program name 
	char	appname[33] = "";
	strncpy( appname, argv[1], 28 );

	// prepare code-file name
	char	srcname[33] = "";
	char	objname[33] = "";
	char	binname[33] = "";
	strncpy( srcname, argv[1], 28 );
	strncpy( objname, argv[1], 28 );
	strncpy( binname, argv[1], 28 );
	strncat( srcname, ".s", 4 );
	strncat( objname, ".o", 4 );
	strncat( binname, ".b", 4 );

	// announce this program's purpose 
	printf( "\nCreating skeleton for program " );
	printf( "named \'%s\' \n", srcname );

	// insure source-file doesn't already exist
	FILE	*fp = fopen( srcname, "rb" );
	if ( fp != NULL )
		{
		fclose( fp );
		fprintf( stderr, "File \'%s\' already exists\n", srcname );
		return	-1;
		}

	// create the new source-file
	fp = fopen( srcname, "wb" );
	if ( fp == NULL )
		{
		fprintf( stderr, "Cannot create source-file\n" );
		return	-1;
		}

	// obtain today's date (in DD MMM YYYY format)
	time_t		now = time( (time_t *)NULL );
	struct tm	*t = localtime( &now );
	char	month[4] = "";
	strncpy( month, monthlist+3*t->tm_mon, 3 );
	month[3] = '\0';

	char	when[16] = "";
	sprintf( when, "%02d %3s %04d", t->tm_mday, month, 1900+t->tm_year );	

	char	border[68] = "";
	memset( border, '-', 67 );

	fprintf( fp, "//%s\n", border );
	fprintf( fp, "//\t%s\n", srcname );
	fprintf( fp, "//\n" );
	fprintf( fp, "//\n" );
	fprintf( fp, "//\t to assemble: $ as %s ", srcname );
	fprintf( fp, "-o %s \n", objname );
	fprintf( fp, "//\t and to link: $ ld %s ", objname );
	fprintf( fp, "-T ldscript " );
	fprintf( fp, "-o %s \n", binname );
	fprintf( fp, "//\n" );
	fprintf( fp, "//\tNOTE: This program begins executing " );
	fprintf( fp, "with CS:IP = 1000:0002. \n" );
	fprintf( fp, "//\n" );
	fprintf( fp, "//\tprogrammer: %s\n", authorname );
	fprintf( fp, "//\tdate begun: %s\n", when );
	fprintf( fp, "//%s\n", border );

	fprintf( fp, "\n" );
	fprintf( fp, "\t.section\t.text\n" );
	fprintf( fp, "#%s\n", border );
	fprintf( fp, "\t.word\t0xABCD\t\t\t# our application signature\n" );
	fprintf( fp, "#%s\n", border );
	fprintf( fp, "main:" );
	fprintf( fp, "\t.code16\t\t\t\t# for Pentium 'real-mode' \n" );
	fprintf( fp, "\tmov\t%%sp, %%cs:exit_pointer+0\t" );
	fprintf( fp, "# preserve the loader's SP" );
	fprintf( fp, "\n" );
	fprintf( fp, "\tmov\t%%ss, %%cs:exit_pointer+2\t" );
	fprintf( fp, "# preserve the loader's SS" );
	fprintf( fp, "\n" );
	fprintf( fp, "\n" );
	fprintf( fp, "\tmov\t%%cs, %%ax\t\t" );
	fprintf( fp, "# address program's data " );
	fprintf( fp, "\n" );
	fprintf( fp, "\tmov\t%%ax, %%ds\t\t" );
	fprintf( fp, "#   with DS register     " );
	fprintf( fp, "\n" );
	fprintf( fp, "\tmov\t%%ax, %%es\t\t" );
	fprintf( fp, "#   also ES register     " );
	fprintf( fp, "\n" );
	fprintf( fp, "\tmov\t%%ax, %%ss\t\t" );
	fprintf( fp, "#   also SS register     " );
	fprintf( fp, "\n" );
	fprintf( fp, "\tlea\ttos, %%sp\t\t" );
	fprintf( fp, "# and setup new stacktop " );
	fprintf( fp, "\n" );
	fprintf( fp, "\n" );
	fprintf( fp, "\tcall\tinitialize_os_tables\t" );
	fprintf( fp, "\n" );
	fprintf( fp, "\tcall\tenter_protected_mode\t" );
	fprintf( fp, "\n" );
	fprintf( fp, "\tcall\texecute_program_demo\t" );
	fprintf( fp, "\n" );
	fprintf( fp, "\tcall\tleave_protected_mode\t" );
	fprintf( fp, "\n" );
	fprintf( fp, "\n" );
	fprintf( fp, "\tlss\t%%cs:exit_pointer, %%sp\t" );
	fprintf( fp, "# recover saved SS and SP" );
	fprintf( fp, "\n" );
	fprintf( fp, "\tlret\t\t\t\t" );
	fprintf( fp, "# exit back to the loader" );
	fprintf( fp, "\n" );
	fprintf( fp, "#%s\n", border );
	fprintf( fp, "exit_pointer:\t.word\t0, 0 \t\t" );
	fprintf( fp, "# for loader's SS and SP " );
	fprintf( fp, "\n" );
	fprintf( fp, "#%s\n", border );

	fprintf( fp, "\t.align\t8\t" );
	fprintf( fp, " # quadword alignment (for optimal access) " );
	fprintf( fp, "\n" );
	fprintf( fp, "theGDT:\t" );
	fprintf( fp, ".word\t0x0000, 0x0000, 0x0000, 0x0000\t" );
	fprintf( fp, "# null descriptor \n" );
	
	fprintf( fp, "\t.equ\tsel_es, (.-theGDT)+0\t" );
	fprintf( fp, "# vram-segment's selector \n" );
	fprintf( fp, "\t.word\t0x0007, 0x8000, 0x920B, 0x0080\t" );
	fprintf( fp, "# vram descriptor \n" );

	fprintf( fp, "\t.equ\tsel_cs, (.-theGDT)+0\t" );
	fprintf( fp, "# code-segment's selector \n" );
	fprintf( fp, "\t.word\t0xFFFF, 0x0000, 0x9A01, 0x0000\t" );
	fprintf( fp, "# code descriptor \n" );

	fprintf( fp, "\t.equ\tsel_ds, (.-theGDT)+0\t" );
	fprintf( fp, "# data-segment's selector \n" );
	fprintf( fp, "\t.word\t0xFFFF, 0x0000, 0x9201, 0x0000\t" );
	fprintf( fp, "# data descriptor \n" );

	fprintf( fp, "\t.equ\tsel_fs, (.-theGDT)+0\t" );
	fprintf( fp, "# flat-segment's selector \n" );
	fprintf( fp, "\t.word\t0xFFFF, 0x0000, 0x9200, 0x008F\t" );
	fprintf( fp, "# flat descriptor \n" );

	fprintf( fp, "\t.equ\tlimGDT, (.-theGDT)-1\t" );
	fprintf( fp, "# our GDT-segment's limit \n" );
	fprintf( fp, "#%s\n", border );
	fprintf( fp, "theIDT:\t.space\t256 * 8\t\t" );
	fprintf( fp, "# enough for 256 gate-descriptors \n" );
	fprintf( fp, "\t.equ\tlimIDT, (.-theIDT)-1\t" );
	fprintf( fp, "# our IDT-segment's limit \n" );
	fprintf( fp, "#%s\n", border );

	fprintf( fp, "regGDT:\t.word\tlimGDT, theGDT, 0x0001\t" );
	fprintf( fp, "# register-image for GDTR \n" );
	fprintf( fp, "regIDT:\t.word\tlimIDT, theIDT, 0x0001\t" );
	fprintf( fp, "# register-image for IDTR \n" );
	fprintf( fp, "regIVT:\t.word\t0x03FF, 0x0000, 0x0000\t" );
	fprintf( fp, "# register-image for IDTR \n" );

	fprintf( fp, "#%s\n", border );
	fprintf( fp, "initialize_os_tables:\t" );
	fprintf( fp, "\n" );

	fprintf( fp, "\n\t# initialize IDT descriptor for gate 0x0D \n" );
	fprintf( fp, "\tmov\t$0x0D, %%ebx \t\t" );
	fprintf( fp, "# ID-number for the gate \n" );
	fprintf( fp, "\tlea\ttheIDT(, %%ebx, 8), %%di \t" );
	fprintf( fp, "# gate's offset-address \n" );
	fprintf( fp, "\tmovw\t$isrGPF, 0(%%di)\t\t" );
	fprintf( fp, "# entry-point's loword \n" );
	fprintf( fp, "\tmovw\t$sel_cs, 2(%%di)\t\t" );
	fprintf( fp, "# code-segment selector\n" );
	fprintf( fp, "\tmovw\t$0x8E00, 4(%%di)\t\t" );
	fprintf( fp, "# 386 interrupt-gate   \n" );
	fprintf( fp, "\tmovw\t$0x0000, 6(%%di)\t\t" );
	fprintf( fp, "# entry-point's hiword \n" );
	 
	fprintf( fp, "\n" );
	fprintf( fp, "\tret\t" );
	fprintf( fp, "\n" );

	fprintf( fp, "#%s\n", border );
	fprintf( fp, "enter_protected_mode:\t" );
	fprintf( fp, "\n" );

	fprintf( fp, "\n\tcli\t\t\t\t" );
	fprintf( fp, "# no device interrupts" );
	fprintf( fp, "\n" );
	fprintf( fp, "\tlgdt\tregGDT\t\t\t" );
	fprintf( fp, "# setup GDTR register" );
	fprintf( fp, "\n" );
	fprintf( fp, "\tlidt\tregIDT\t\t\t" );
	fprintf( fp, "# setup IDTR register" );
	fprintf( fp, "\n" );

	fprintf( fp, "\n" );
	fprintf( fp, "\tmov\t%%cr0, %%eax\t\t" );
	fprintf( fp, "# get machine status" );
	fprintf( fp, "\n" );
	fprintf( fp, "\tbts\t$0, %%eax\t\t" );
	fprintf( fp, "# set PE-bit to 1" );
	fprintf( fp, "\n" );
	fprintf( fp, "\tmov\t%%eax, %%cr0\t\t" );
	fprintf( fp, "# enable protection" );
	fprintf( fp, "\n" );

	fprintf( fp, "\n" );
	fprintf( fp, "\tljmp\t$sel_cs, $pm\t\t" );
	fprintf( fp, "# reload register CS" );
	fprintf( fp, "\npm:" );
	fprintf( fp, "\n" );

	fprintf( fp, "\tmov\t$sel_ds, %%ax\t\t" );
	fprintf( fp, "\n" );

	fprintf( fp, "\tmov\t%%ax, %%ss\t\t" );
	fprintf( fp, "# reload register SS" );
	fprintf( fp, "\n" );
	fprintf( fp, "\tmov\t%%ax, %%ds\t\t" );
	fprintf( fp, "# reload register DS" );
	fprintf( fp, "\n" );

	fprintf( fp, "\n" );
	fprintf( fp, "\txor\t%%ax, %%ax\t\t" );
	fprintf( fp, "# use \"null\" selector" );
	fprintf( fp, "\n" );
	fprintf( fp, "\tmov\t%%ax, %%es\t\t" );
	fprintf( fp, "# to purge invalid ES" );
	fprintf( fp, "\n" );
	fprintf( fp, "\tmov\t%%ax, %%fs\t\t" );
	fprintf( fp, "# to purge invalid FS" );
	fprintf( fp, "\n" );
	fprintf( fp, "\tmov\t%%ax, %%gs\t\t" );
	fprintf( fp, "# to purge invalid GS" );
	fprintf( fp, "\n" );

	fprintf( fp, "\n" );
	fprintf( fp, "\tret\t" );
	fprintf( fp, "\n" );

	fprintf( fp, "#%s\n", border );
	fprintf( fp, "leave_protected_mode:\t" );
	fprintf( fp, "\n" );

	fprintf( fp, "\n" );
	fprintf( fp, "\tmov\t$sel_ds, %%ax\t\t" );
	fprintf( fp, "# address 64K r/w segment" );
	fprintf( fp, "\n" );
	fprintf( fp, "\tmov\t%%ax, %%ds\t\t" );
	fprintf( fp, "#   using DS register" );
	fprintf( fp, "\n" );
	fprintf( fp, "\tmov\t%%ax, %%es\t\t" );
	fprintf( fp, "#    and ES register" );
	fprintf( fp, "\n" );

	fprintf( fp, "\n" );
	fprintf( fp, "\tmov\t$sel_fs, %%ax\t\t" );
	fprintf( fp, "# address 4GB r/w segment" );
	fprintf( fp, "\n" );
	fprintf( fp, "\tmov\t%%ax, %%fs\t\t" );
	fprintf( fp, "#   using FS register" );
	fprintf( fp, "\n" );
	fprintf( fp, "\tmov\t%%ax, %%gs\t\t" );
	fprintf( fp, "#    and GS register " );
	fprintf( fp, "\n" );

	fprintf( fp, "\n" );
	fprintf( fp, "\tmov\t%%cr0, %%eax\t\t" );
	fprintf( fp, "# get machine status" );
	fprintf( fp, "\n" );
	fprintf( fp, "\tbtr\t$0, %%eax\t\t" );
	fprintf( fp, "# reset PE-bit to 0 " );
	fprintf( fp, "\n" );
	fprintf( fp, "\tmov\t%%eax, %%cr0\t\t" );
	fprintf( fp, "# disable protection" );
	fprintf( fp, "\n" );

	fprintf( fp, "\n" );
	fprintf( fp, "\tljmp\t$0x1000, $rm\t\t" );
	fprintf( fp, "# reload register CS" );
	fprintf( fp, "\nrm:" );
	fprintf( fp, "\n" );

	fprintf( fp, "\tmov\t%%cs, %%ax\t\t" );
	fprintf( fp, "\n" );
	fprintf( fp, "\tmov\t%%ax, %%ss\t\t" );
	fprintf( fp, "# reload register SS" );
	fprintf( fp, "\n" );
	fprintf( fp, "\tmov\t%%ax, %%ds\t\t" );
	fprintf( fp, "# reload register DS" );
	fprintf( fp, "\n" );
	fprintf( fp, "\tmov\t%%ax, %%es\t\t" );
	fprintf( fp, "# reload register ES" );
	fprintf( fp, "\n" );

	fprintf( fp, "\n" );
	fprintf( fp, "\tlidt\tregIVT\t\t\t" );
	fprintf( fp, "# restore vector table" );
	fprintf( fp, "\n" );
	fprintf( fp, "\tsti\t\t\t\t" );
	fprintf( fp, "# and allow interrupts" );
	fprintf( fp, "\n" );

	fprintf( fp, "\n" );
	fprintf( fp, "\tret\t" );
	fprintf( fp, "\n" );

	fprintf( fp, "#%s\n", border );
	fprintf( fp, "execute_program_demo: \n" );
	fprintf( fp, "\n" );
	fprintf( fp, "\tmov\t%%esp, tossave+0\t\t" );
	fprintf( fp, "# preserve 32-bit offset \n" );
	fprintf( fp, "\tmov\t%%ss,  tossave+4\t\t" );
	fprintf( fp, "#  plus 16-bit selector \n" );

	fprintf( fp, "\n\t# your application-specific demo-routines " );
	fprintf( fp, "would go here \n" );
	fprintf( fp, "\tint\t$0xFF\t" );
	fprintf( fp, "#<-- this instruction is only for testing \n" );

	fprintf( fp, "\nfin:\tlss\t%%cs:tossave, %%esp \t" );
	fprintf( fp, "# reload our saved SS:ESP \n" );
	fprintf( fp, "\tret\t\t\t\t" );
	fprintf( fp, "# return to main function " );
	fprintf( fp, "\n" );

	fprintf( fp, "#%s\n", border );
	fprintf( fp, "tossave:  .long\t0, 0 \t\t\t" );
	fprintf( fp, "# stores a 48-bit pointer \n" );

	fprintf( fp, "#%s\n", border );
	fprintf( fp, "isrGPF:\t# our fault-handler for " );
	fprintf( fp, "General Protection Exceptions \n" );

	fprintf( fp, "\n" );
	fprintf( fp, "\tpushal\t\t\t\t# preserve registers \n" );
	fprintf( fp, "\tpushl\t$0\t\t\t\t\n" );
	fprintf( fp, "\tmov\t%%ds, (%%esp)\t\t# store DS \n" ); 
	fprintf( fp, "\tpushl\t$0\t\t\t\t\n" );
	fprintf( fp, "\tmov\t%%es, (%%esp)\t\t# store ES \n" ); 
	fprintf( fp, "\tpushl\t$0\t\t\t\t\n" );
	fprintf( fp, "\tmov\t%%fs, (%%esp)\t\t# store FS \n" ); 
	fprintf( fp, "\tpushl\t$0\t\t\t\t\n" );
	fprintf( fp, "\tmov\t%%gs, (%%esp)\t\t# store GS \n" ); 
	fprintf( fp, "\tpushl\t$0\t\t\t\t\n" );
	fprintf( fp, "\tmov\t%%ss, (%%esp)\t\t# store SS \n" ); 
	fprintf( fp, "\tpushl\t$0\t\t\t\t\n" );
	fprintf( fp, "\tstrw\t(%%esp)\t\t\t# store TR \n" ); 

	fprintf( fp, "\n" );
	fprintf( fp, "\tmov\t%%esp, %%ebp\t\t# setup frame base \n" );
	fprintf( fp, "\tcall\tdraw_stack\t\t# display registers \n" );

	fprintf( fp, "\n" );
	fprintf( fp, "\tljmp\t$sel_cs, $fin\t\t" );
	fprintf( fp, " # now transfer to demo finish \n" );

	fprintf( fp, "#%s\n", border );
	fprintf( fp, "hex:\t.ascii\t\"0123456789ABCDEF\"\t" );
	fprintf( fp, "# array of hex digits\n" );
	fprintf( fp, "names:" );
	fprintf( fp, "\t.ascii\t\"  TR  SS  GS  FS  ES  DS\" \n" );
	fprintf( fp, "\t.ascii\t\" EDI ESI EBP ESP EBX EDX ECX EAX\" \n" );
	fprintf( fp, "\t.ascii\t\" err EIP  CS EFL\" \n" );
	fprintf( fp, "\t.equ\tNELTS, (. - names)/4 \t" );
	fprintf( fp, "# number of elements \n" );
	fprintf( fp, "buf:\t.ascii\t\" nnn=xxxxxxxx \"\t" );
	fprintf( fp, "# buffer for output \n" );
	fprintf( fp, "len:\t.int\t. - buf \t\t" );
	fprintf( fp, "# length of output \n" );
	fprintf( fp, "att:\t.byte\t0x70\t\t\t" );
	fprintf( fp, "# color attributes \n" );

	fprintf( fp, "#%s\n", border );
	fprintf( fp, "eax2hex:  # converts value in EAX " );
	fprintf( fp, "to hexadecimal string at DS:EDI \n" );
	fprintf( fp, "\tpushal \n" );
	fprintf( fp, "\tmov\t$8, %%ecx \t\t" );
	fprintf( fp, "# setup digit counter \n" );
	fprintf( fp, "nxnyb:\t\n" );
	fprintf( fp, "\trol\t$4, %%eax \t\t" );
	fprintf( fp, "# next nybble into AL \n" );
	fprintf( fp, "\tmov\t%%al, %%bl \t\t" );
	fprintf( fp, "# copy nybble into BL \n" );
	fprintf( fp, "\tand\t$0xF, %%ebx\t\t" );
	fprintf( fp, "# isolate nybble's bits \n" );
	fprintf( fp, "\tmov\thex(%%ebx), %%dl\t\t" );
	fprintf( fp, "# lookup ascii-numeral \n" );
	fprintf( fp, "\tmov\t%%dl, (%%edi) \t\t" );
	fprintf( fp, "# put numeral into buf \n" );
	fprintf( fp, "\tinc\t%%edi\t\t\t" );
	fprintf( fp, "# advance buffer index \n" );
	fprintf( fp, "\tloop\tnxnyb\t\t\t" );
	fprintf( fp, "# back for next nybble\n" );
	fprintf( fp, "\tpopal \n" );
	fprintf( fp, "\tret \n" );

	fprintf( fp, "#%s\n", border );
	fprintf( fp, "draw_stack: \n" );
	fprintf( fp, "\n" );
	fprintf( fp, "\tpushal \t\t\t\t" );
	fprintf( fp, "# preserve registers \n\n" );

	fprintf( fp, "\tmov\t$sel_es, %%ax \t\t" );
	fprintf( fp, "# address video memory \n" );
	fprintf( fp, "\tmov\t%%ax, %%es \t\t" );
	fprintf( fp, "#   with ES register \n" );

	fprintf( fp, "\tmov\t$sel_ds, %%ax \t\t" );
	fprintf( fp, "# address program data \n" );
	fprintf( fp, "\tmov\t%%ax, %%ds \t\t" );
	fprintf( fp, "#   with DS register \n" );

	fprintf( fp, "\n\tcld\t\t\t\t" );
	fprintf( fp, "# do forward processing \n" );
	fprintf( fp, "\txor\t%%ebx, %%ebx \t\t" );
	fprintf( fp, "# initial element index \n" );
	fprintf( fp, "nxelt: \n" );
	fprintf( fp, "\t# put element's label into buf \n" );
	fprintf( fp, "\tmov\tnames(, %%ebx, 4), %%eax \t" );
	fprintf( fp, "# fetch element's label \n" );
	fprintf( fp, "\tmov\t%%eax, buf\t\t" );
	fprintf( fp, "# store label into buf \n" );
	fprintf( fp, "\n\t# put element's value into buf \n" );
	fprintf( fp, "\tmov\t(%%ebp, %%ebx, 4), %%eax \t" );
	fprintf( fp, "# fetch element's value \n" );
	fprintf( fp, "\tlea\tbuf+5, %%edi \t\t" );
	fprintf( fp, "# point to value field \n" );
	fprintf( fp, "\tcall\teax2hex\t\t\t" );
	fprintf( fp, "# convert value to hex \n" );
	fprintf( fp, "\n\t# compute element's screen-offset \n" );
	fprintf( fp, "\timul\t$160, %%ebx, %%eax \t" );
	fprintf( fp, "# offset to screen line \n" );
	fprintf( fp, "\tmov\t$3810, %%edi \t\t" );
	fprintf( fp, "# from starting location \n" );
	fprintf( fp, "\tsub\t%%eax, %%edi \t\t" );
	fprintf( fp, "# destination goes in EDI \n" );
	fprintf( fp, "\n\t# write buf to screen memory \n" );
	fprintf( fp, "\tlea\tbuf, %%esi \t\t" );
	fprintf( fp, "# point DS:ESI to buffer \n" );
	fprintf( fp, "\tmov\tlen, %%ecx \t\t" );
	fprintf( fp, "# setup buffer's length \n" );
	fprintf( fp, "\tmov\tatt, %%ah \t\t" );
	fprintf( fp, "# setup color attribute \n" );
	fprintf( fp, "nxpel:" );
	fprintf( fp, "\tlodsb \t\t\t\t" );
	fprintf( fp, "# fetch next character \n" );
	fprintf( fp, "\tstosw \t\t\t\t" );
	fprintf( fp, "# store char and color \n" );
	fprintf( fp, "\tloop\tnxpel \t\t\t" );
	fprintf( fp, "# again if more chars \n" );
	fprintf( fp, "\n" );
	fprintf( fp, "\tinc\t%%ebx \t\t\t" );
	fprintf( fp, "# increment element number \n" );
	fprintf( fp, "\tcmp\t$NELTS, %%ebx \t\t" );
	fprintf( fp, "# more elements to show? \n" );
	fprintf( fp, "\tjb\tnxelt \t\t\t" );
	fprintf( fp, "# yes, back for next one \n" );

	fprintf( fp, "\n\tpopal \t\t\t\t" );
	fprintf( fp, "# restore registers \n" );
	fprintf( fp, "\tret \t\t\t\t" );
	fprintf( fp, "# and return to caller \n" );
	
	fprintf( fp, "#%s\n", border );
	fprintf( fp, "\t.align\t16\t\t\t" );
	fprintf( fp, "# assure stack alignment \n" );
	fprintf( fp, "\t.space\t512\t\t\t" );
	fprintf( fp, "# reserved for stack use \n" );
	fprintf( fp, "tos:\t\t\t\t\t" );
	fprintf( fp, "# label for top-of-stack \n" );
	fprintf( fp, "#%s\n", border );
	fprintf( fp, "\t.end\t\t\t\t" );
	fprintf( fp, "# nothing more to assemble " );
	fprintf( fp, "\n" );

	printf( "\n" );
}
