//-----------------------------------------------------------------
//	trypages.s
//	
//	This program builds a page-table and page-directory which	
//	define an identity-mapping for the lowest megabyte of the
//	system's memory (i.e., the 8086 real-mode memory region).
//
//
//	 to assemble: $ as trypages.s -o trypages.o
//	 and to link: $ ld trypages.o -T ldscript -o trypages.b 
//
//	NOTE: This code begins executing with CS:IP = 1000:0002. 
//
//	programmer: ALLAN CRUSE
//	date begun: 27 MAR 2004
//	completion: 19 APR 2004
//	revised on: 30 OCT 2006 -- to use the GNU assembler syntax
//-----------------------------------------------------------------


	.code16				# for Pentium 'real-mode'

	.section	.text
#------------------------------------------------------------------
	.word	0xABCD			# programming signature 
#------------------------------------------------------------------
main:	mov	%sp, %cs:exit_pointer+0	# preserve the loader's SP 
	mov	%ss, %cs:exit_pointer+2	# preserve the loader's SS

	mov	%cs, %ax		# address this segment 
	mov	%ax, %ds		#   with DS register  
	mov	%ax, %ss		#   also SS register 
	lea	tos, %sp		# and set new stacktop 

	call	create_system_tables
	call	enter_protected_mode 
	call	exec_the_paging_demo
	call	leave_protected_mode 

	lss	%cs:exit_pointer, %sp 	# recover saved stacktop  
	lret				# exit to program loader  
#------------------------------------------------------------------
exit_pointer: 	.word	0, 0		# to store exit-address 
#------------------------------------------------------------------
	.align	8		# CPU requires quadword alignment
theGDT:	.word	0x0000, 0x0000, 0x0000, 0x0000	# null descriptor 
	.equ	sel_es, (.-theGDT)+0	# vram-segment's selector 
	.word	0x7FFF, 0x8000, 0x920B, 0x0000	# vram descriptor 
	.equ	sel_cs, (.-theGDT)+0	# code-segment's selector 
	.word	0xFFFF, 0x0000, 0x9A01, 0x0000	# code descriptor 
	.equ	sel_ss, (.-theGDT)+0	# data-segment's selector 
	.word	0xFFFF, 0x0000, 0x9201, 0x0000	# data descriptor 
	.equ	sel_fs, (.-theGDT)+0	# flat-segment's selector 
	.word	0xFFFF, 0x0000, 0x9200, 0x008F	# data descriptor 
	.equ	limGDT, (.-theGDT)-1	# the GDT's segment-limit
#------------------------------------------------------------------
#------------------------------------------------------------------
pgdir:	.long	0x00018000		# page-directory address
pgtbl:	.long	0x00019000		# and page-table address
#------------------------------------------------------------------
create_system_tables:

	# clear memory-area from 1000:8000 to 2000:0000 (8 pages)
	mov	pgdir, %eax		# address for our tables
	shr	$4, %eax		#  is divided by sixteen
	mov	%ax, %es		# use quotient as segment
	xor	%di, %di		# point ES:DI to tables
	cld				# use forward processing
	xor	%eax, %eax		# use zero as fill-value
	mov	$0x2000, %cx		# fill 8192 double-words
	rep	stosl			# perform fill operation

	# now setup an "identity-mapping" for conventional memory
	mov	$0x1000, %di		# point ES:DI to page-table
	xor	%eax, %eax		# first page-frame address
	or	$0x003, %eax		# 'present' and 'writable'
	mov	$256, %cx 		# one-megabyte = 256 frames
.L0:	stosl				# write page-table entry
	add	$0x1000,%eax		# next page-frame address
	loop	.L0			# write the other entries

	# now setup the initial page-directory entry
	mov	pgtbl, %eax		# address of page-table
	or	$0x003, %eax		# 'present' and 'writable'
	xor	%di, %di 		# point ES:DI to directory
	stosl				# write a directory-entry

	ret
#------------------------------------------------------------------
regGDT:	.word	limGDT, theGDT, 0x0001	# image for register GDTR
#------------------------------------------------------------------
enter_protected_mode: 

	cli				# no device interrupts 
	mov	%cr0, %eax		# get machine status 
	bts	$0, %eax		# set PE-bit to 1 
	mov	%eax, %cr0		# enable protection 

	lgdt	regGDT 			# setup GDTR register 

	ljmp	$sel_cs, $pm		# reload register CS 
pm:	mov	$sel_ss, %ax		
	mov	%ax, %ss		# reload register SS 
	mov	%ax, %ds		# reload register DS 

	xor	%ax, %ax		# use 'null' selector 
	mov	%ax, %es		# to purge invalid ES 
	mov	%ax, %fs		# to purge invalid FS 
	mov	%ax, %gs 		# to purge invalid GS 

	ret				# back to main routine 
#------------------------------------------------------------------
#------------------------------------------------------------------
leave_protected_mode: 

	mov	%ss, %ax 		# address 64K r/w segment 
	mov	%ax, %ds 		#   using DS register 
	mov	%ax, %es 		#    and ES register 

	mov	$sel_fs, %ax		# address 4GB r/w segment
	mov	%ax, %fs		#    with FS register
	mov	%ax, %gs		#    also GS register

	mov	%cr0, %eax		# get machine status 
	btr	$0, %eax		# reset PE-bit to 0 
	mov	%eax, %cr0		# disable protection 

	ljmp	$0x1000, $rm		# reload register CS 
rm:	mov	%cs, %ax 	
	mov	%ax, %ss		# reload register SS 
	mov	%ax, %ds 		# reload register DS 
	sti				# interrupts allowed 

	ret				# back to main routine 
#------------------------------------------------------------------
msg:	.ascii	" Hello from virtual memory "
len:	.word	. - msg			# length of message text
hue:	.byte	0x1F			# intense white on green
#------------------------------------------------------------------
exec_the_paging_demo:

	# store physical address of our page-directory in CR3

	mov	pgdir, %eax		# page-directory address
	mov	%eax, %cr3		#  in control register 3

	# enable paging

	mov	%cr0, %eax 		# get machine status
	bts	$31, %eax		# turn on the PG-bit
	mov	%eax, %cr0 		# set machine status
	jmp	pg			# flush prefetch queue 
pg:

	# draw a message on the video screen

	mov	$sel_es, %ax		# address video memory
	mov	%ax, %es		#   with ES register
	mov	$1600, %di		# point ES:DI to line 10
	lea	msg, %si		# point DS:SI to message	
	cld				# do forward processing
	mov	hue, %ah		# white-on-green colors
	mov	len, %cx		# setup character-count
.L1:	
	lodsb				# fetch next character
	stosw				# store char and color
	loop	.L1			# draw entire message

	# disable paging

	mov	%cr0, %eax		# get machine status
	btr	$31, %eax		# reset PG-bit image
	mov	%eax, %cr0		# set machine status

	# invalidate the CPU's TLB (Translation Lookaside Buffer)
	
	mov	%cr3, %eax		# read contents of CR3
	mov	%eax, %cr3		# write CR3 to flush TLB

	ret
#------------------------------------------------------------------
	.align	16			# assure stack alignment  
	.space	512			# reserved for stack use 
tos:					# label fop top-of-stack 
#------------------------------------------------------------------
	.end				# nothing more to assemble
