//-----------------------------------------------------------------
//	try32bit.s
//
//	This demo illustrates some basic control-transfer steps
//	that will be needed in Project #1.  Here, it is assumed 
//	that an Elf32 linkable object-file (named 'hello.o') is
//	preinstalled on our boot media and will get loaded into 
//	memory at address 0x00011800 by our 'quikload' loader:
//
//	  install with:  $ dd if=hello.o of=/dev/sda4 seek=13  
//
//	The information we needed (to define local descriptors)
//	was extracted from 'hello.o' using our 'loadmap' tool: 	
//	text-segment: base_address=0x00011834 seg_limit=0x00022
//	data-segment: base_address=0x00011858 seg_limit=0x0000C
//	
//	to assemble:  $ as try32bit.s -o try32bit.o
//	and to link:  $ ld try32bit.o -T ldscript -o try32bit.b
//	and install:  $ dd if=try32bit.b of=/dev/fd0 seek=1 
//
//	NOTE: This code begins executing with CS:IP = 1000:0002. 
//
//	programmer: ALLAN CRUSE
//	date begun: 20 MAR 2004
//	completion: 23 MAR 2004
//	revised on: 06 APR 2004 -- to save 48-bit stack-pointer
//	bug repair: 10 MAY 2004 -- bug: subroutine modified EBX
//	revised on: 17 OCT 2006 -- to use AT&T assembler syntax
//
//	Warning: we did not have time yet to test this revision;
//	a corrected version will be posted as errors are found.
//
//	bugs fixed: 18 OCT 2006 -- ok, we corrected four errors
//
//	Error #1: 
//	In 'eax2hex': replaced 'mov %edx, %edx' with 'mov %eax, %edx'. 
//	
//	Error #2: 
//	In 'do_exit': changed operand '$sel_CS' to '$sel_cs'.
//
//	Error #3:
//	In 'isrSVC': supplied %cs segment-override in ljmp instruction.
//
//	Error #4: 
//	In 'leave_protected_mode': put 4GB segment-limits in FS and GS
//	(this required adding one more segment-descriptor to our GDT).
//	This is not strictly an error in our demo code, but rather is a
//	'workaround' for the GRUB boot-loader's expectation that it can
//	address extended memory in real-mode.   
//
//	We also made two style-changes (not strictly necessary here)
//	Added a '.section .text' directive, omitted as an oversight.
//	Changed 'lea tos0, %sp' to 'lea tos0, %esp' to insure that
//	the offset-address in ESP will be '32-bit clean', in case a
//	future program-loader different from 'quickload.s' is used.
//-----------------------------------------------------------------


	.section	.text		# <-- added section directive
#------------------------------------------------------------------
	.code16	# assemble instructions for a 16-bit code-segment
#------------------------------------------------------------------
	.word	0xABCD			# programming signature 
#------------------------------------------------------------------
main:	mov	%sp, %cs:exit_pointer+0
	mov	%ss, %cs:exit_pointer+2	

	mov	%cs, %ax		# address this segment 
	mov	%ax, %ds		#   with DS register  
	mov	%ax, %ss		#  adjust SS register 
	lea	tos0, %sp		# and set new stacktop

	call	initialize_os_tables   
	call	enter_protected_mode 
	call	execute_program_demo
	call	leave_protected_mode 

	lss	%cs:exit_pointer, %sp 	# recover loader's stacktop  
	lret				# exit to program launcher 
#------------------------------------------------------------------
exit_pointer: .word	0, 0 		# for saving stack-address 
#------------------------------------------------------------------
sys_call_table:	# the jump-table for our system-call dispatcher	
	.long	do_nothing		# for sustem-call 0
	.long	do_exit			# for system-call 1
	.long	do_nothing		# for system-call 2
	.long	do_nothing		# for system-call 3
	.long	do_write  		# for system-call 4
	.equ	NR_SYSTEM_CALLS, ( . - sys_call_table)/4   
#------------------------------------------------------------------
#------------------------------------------------------------------
# EQUATES 
	.equ	realCS, 0x1000		# segment-address of code 
	.equ	limGDT, 0x004F		# includes 10 descriptors <--- changed
	.equ	sel_es, 0x0008		# vram-segment selector 
	.equ	sel_cs, 0x0010		# code-segment selector 
	.equ	sel_ss,	0x0018		# data-segment selector 
	.equ	sel_CS,	0x0020		# code-segment selector 
	.equ	sel_SS,	0x0028		# data-segment selector 
	.equ	sel_ts,	0x0030		#  TSS-segment selector
	.equ	sel_ls,	0x0038		#  LDT-segment selector
	.equ	sel_bs,	0x0040		# bios-segment selector
	.equ	sel_fs, 0x0048		# flat-segment selector  <--- added
	.equ	userCS,	0x0007		# code-segment selector
	.equ	userDS,	0x000F		# data-segment selector
	.equ	userSS,	0x0017		# stak-segment selector
#------------------------------------------------------------------
	.align	8 		# quadword alignment is required
#------------------------------------------------------------------
theGDT:	.word	0x0000, 0x0000, 0x0000, 0x0000	# null descriptor 
	.word	0x7FFF, 0x8000, 0x920B, 0x0000	# vram descriptor 
	.word	0xFFFF, 0x0000, 0x9A01, 0x0000	# code descriptor 
	.word	0xFFFF, 0x0000, 0x9201, 0x0000	# data descriptor 
	.word	0x17FF, 0x0000, 0x9A01, 0x0040	# code descriptor 
	.word	0x17FF, 0x0000, 0x9201, 0x0040	# data descriptor 
	.word	0x000B, theTSS, 0x8901, 0x0000	#  TSS descriptor 
	.word	0x0017, theLDT, 0x8201, 0x0000	#  LDT descriptor 
	.word	0x0100, 0x0400, 0x9200, 0x0000	# bios descriptor 
	.word	0xFFFF, 0x0000, 0x9200, 0x0080	# flat descriptor  <--- added
#------------------------------------------------------------------
theLDT:	.word	0x0022, 0x1834, 0xFA01, 0x0040	# code descriptor 
	.word	0x000C, 0x1858, 0xF201, 0x0040	# data descriptor 
	.word	0x0FFF, 0x2100, 0xF201, 0x0040	# stak descriptor 
#------------------------------------------------------------------
theIDT:	.space	2048			# for 256 gate-descriptors
#------------------------------------------------------------------
theTSS:	.long	0, 0x00001800, sel_SS	# 32bit Task-State Segment
#------------------------------------------------------------------
regGDT:	.word	limGDT, theGDT, 0x0001	# register image for GDTR
regIDT:	.word	0x07FF, theIDT, 0x0001	# register image for IDTR
regIVT:	.word	0x03FF, 0x0000, 0x0000	# register image for IDTR
#------------------------------------------------------------------
initialize_os_tables:

	# initialize IDT descriptor for gate 0x80
	mov	$0x80, %ebx		# ID-number for the gate
	lea	theIDT(, %ebx, 8), %di	# gate's offset-address
	movw	$isrSVC, 0(%di)		# entry-point's loword
	movw	$sel_CS, 2(%di)		# 32bit code-selector
	movw	$0xEF00, 4(%di)		# 32bit trap-gate type
	movw	$0x0000, 6(%di)		# entry-point's hiword

	# initialize IDT descriptor for gate 0x0D
	mov	$0x0D, %ebx		# ID-number for the gate
	lea	theIDT(, %ebx, 8), %di 	# gate's offset-address
	movw	$isrGPF, 0(%di)		# entry-point's loword
	movw	$sel_CS, 2(%di)		# 32bit code-selector
	movw	$0x8E00, 4(%di)		# 32bit interrupt-gate
	movw	$0x0000, 6(%di)		# entry-point's hiword

	ret   
#------------------------------------------------------------------
#------------------------------------------------------------------
enter_protected_mode: 

	cli				# no device interrupts 
	mov	%cr0, %eax		# get machine status 
	bts	$0, %eax		# set PE-bit to 1 
	mov	%eax, %cr0		# enable protection 

	lgdt	regGDT			# load GDTR register-image 
	lidt	regIDT			# load IDTR register-image 

	ljmp	$sel_cs, $pm 		# reload register CS 
pm:	mov	$sel_ss, %ax		
	mov	%ax, %ss		# reload register SS 
	mov	%ax, %ds		# reload register DS 

	xor	%ax, %ax		# use 'null' selector 
	mov	%ax, %es		# to purge invalid ES 
	mov	%ax, %fs 		# to purge invalid FS 
	mov	%ax, %gs 		# to purge invalid GS 

	ret				# back to main routine 
#------------------------------------------------------------------
leave_protected_mode: 

	mov	$sel_ss, %ax		# address 64KB r/w segment 
	mov	%ax, %ds		#   using DS register 
	mov	%ax, %es		#    and ES register 

	mov	$sel_fs, %ax		# address 4GB r/w segment  <--- added
	mov	%ax, %fs		#   using FS register      <--- added
	mov	%ax, %gs		#    and GS register       <--- added

	mov	%cr0, %eax		# get machine status 
	btr	$0, %eax		# reset PE-bit to 0 
	mov	%eax, %cr0		# disable protection 

	lidt	regIVT			# real-mode vector-table

	ljmp	$realCS, $rm		# reload register CS 
rm:	mov	%cs, %ax 	
	mov	%ax, %ss		# reload register SS 
	mov	%ax, %ds		# reload register DS 
	sti				# interrupts allowed 

	ret				# back to main routine 
#------------------------------------------------------------------
#------------------------------------------------------------------
tossave: .word	0, 0, 0			# for 48-bit stack-pointer
#------------------------------------------------------------------
execute_program_demo:

	# save our 16-bit stack's address (for return to 'main')
	mov	%esp, tossave+0		# preserve stack offset
	mov	%ss,  tossave+4		# preserve stack segment

	# setup register TR (for ring-transitions)
	mov	$sel_ts, %ax		# selector for Task-State
	ltr	%ax			# loaded into TR register

	# setup register LDTR (for ring3 segment-descriptrs)
	mov	$sel_ls, %ax		# selector for task's LDT
	lldt	%ax			# loaded in LDTR register

	# initialize DS and ES for accessing ring3 data
	mov	$userDS, %ax		# address application data
	mov	%ax, %ds		#   with the DS register
	mov	%ax, %es		#   also the ES register

	# setup our stack for the transition to ring3
	pushw	$userSS			# ring3 stack-selector
	pushw	$0x1000			# initial top-of-stack 
	pushw	$userCS			# ring3 code-selector
	pushw	$0x0000			# initial entry-point 
	lret				# to the ring3 program
#------------------------------------------------------------------
finish_up_main_thread:				
	# here we restore our 16-bit stack and return to 'main'
	lss	%cs:tossave, %esp	# now restore SS and ESP 
	ret				# back to 'main' routine
#------------------------------------------------------------------
#==================================================================
#========  END OF INSTRUCTIONS FOR THE 16-BIT CODE-SEGMENT  =======
#==================================================================
#------------------------------------------------------------------
	.code32	 # assemble instructions for a 32-bit code-segment
#------------------------------------------------------------------
isrSVC:	# entry-point for any SuperVisor-Call	
	cmp	$NR_SYSTEM_CALLS, %eax	# is ID-number valid?
	jb	isok			# yes, keep ID-number
	xor	%eax, %eax 		# else wipe ID-number
isok:	jmp	*%cs:sys_call_table(, %eax, 4)   # to SVC routine  <--- fixed 	
#------------------------------------------------------------------
do_nothing: # this routine is for any unimplemented system-calls	
	mov	$-1, %eax 		# setup error-code in EAX
	iret				# resume the calling task
#------------------------------------------------------------------
do_exit: # here we transfer control back to our USE16 segment
	ljmp	$sel_cs, $finish_up_main_thread   # to 16bit code  <--- fixed
#------------------------------------------------------------------
#------------------------------------------------------------------
do_write:
#
#	Expects: 	EBX = device ID-number	 
#			ECX = offset of message 
#			EDX = length of message
#
	push	%ebp			# preserve frame-pointer
	mov	%esp, %ebp		# address stack elements
	pushal				# preserve cpu registers
	push	%ds
	push	%es

	# check for valid device ID-number 
	cmp	$1, %ebx 		# is it the STDOUT device?
	je	wrok			# yes, we can do the write
	movl	$-1, -4(%ebp)		# else error-code for EAX
	jmp	wrxx			# and bypass all writing
wrok:	# fetch and process the ascii-codes 
	mov	$sel_es, %ax		# address video memory
	mov	%ax, %es		#   with ES register
	cld				# do forward processing	
	mov	-8(%ebp), %esi 		# buffer-offset in ESI
	mov	-12(%ebp), %ecx 	# buffer-length in ECX
.L2:	lodsb				# fetch next character
	call	write_ascii_tty		# write that character	
	loop	.L2

	# return-value in EAX is number of characters written
	mov	-12(%ebp), %eax 	# use character-count
	mov	-4(%ebp), %eax		# as the return-value

	# move CRT cursor to screen-location following message
	call	sync_crt_cursor		# update hardware cursor
wrxx:
	pop	%es			# restore saved registers
	pop	%ds
	popal
	mov	%ebp, %esp		# restore frame-pointer
	pop	%ebp
	iret				# return from system-call
#------------------------------------------------------------------
get_cursor_locn:	# returns cursor's (row,col) in (DH,DL)
	push	%ax
	push	%ds

	mov	$sel_bs, %ax		# address ROM-BIOS DATA
	mov	%ax, %ds		#   using DS register
	mov	(0x62), %bl 		# current video page
	movzx	%bl, %ebx 		# extended to dword
	mov	0x50(, %ebx, 2), %dx	# get page's cursor

	pop	%ds
	pop	%ax
	ret
#------------------------------------------------------------------
#------------------------------------------------------------------
set_cursor_locn:	# sets cursor's (row,col) from (DH,DL)
	push	%ax
	push	%ds
	mov	$sel_bs, %ax		# address ROM-BIOS DATA
	mov	%ax, %ds		#   using DS register
	mov	(0x62), %bl 		# current video page
	movzx	%bl, %ebx		# extended to dword
	mov	%dx, 0x50(, %ebx, 2) 	# set page's cursor
	pop	%ds
	pop	%ax	
	ret
#------------------------------------------------------------------
scroll_vpage_up:	# expects video page-number in EBX
	pushal
	push	%ds
	push	%es

	# copy rows 1 thru 24 onto rows 0 thru 23, respectively
	mov	$sel_es, %ax		# address video memory
	mov	%ax, %ds		#   with DS register
	mov	%ax, %es 		#   also ES register
	cld
	imul	$4096, %ebx, %edi 	# offset to page-origin
	lea	160(%edi), %esi		# offset to row beneath
	mov	$1920, %ecx 		# 24 rows, 80 cells each
	rep	movsw			# slide rows 1-24 upward

	# then erase row 24 (by filling it with blank characters)
	mov	$0x0720, %ax 		# blank w/normal colors
	mov	$80, %ecx 		# one row, 80 cells
	rep	stosw			# overwrite bottom row 

	pop	%es
	pop	%ds
	popal
	ret
#------------------------------------------------------------------
compute_vram_offset:
	push	%ebx			#<-- added 5/10/2004

	imul	$4096, %ebx, %edi	# EDI = offset to page 

	movzx	%dh, %ebx 		# extended row-number
	imul	$160, %ebx 		#  times row-length
	add	%ebx, %edi 		# added to page-origin

	movzx	%dl, %ebx 		# extended col-number
	imul	$2, %ebx 		#  times col-width
	add	%ebx, %edi 		# added to row-origin

	pop	%ebx			#<-- added 5/10/2004
	ret
#------------------------------------------------------------------
#------------------------------------------------------------------
	.equ	ASCII_BACKSPACE, 8	# backspace (0x08) 
	.equ	ASCII_CARR_RETN, 13	# carriage-return (0x0D)
	.equ	ASCII_LINE_FEED, 10	# line-feed (0x0A)
#------------------------------------------------------------------
write_ascii_tty:	# writes char from AL to cursor location

	call	get_cursor_locn		# DH=row DL=col EBX=page

	# certain ASCII control-codes receive special handling
	
	cmp	$ASCII_CARR_RETN, %al	# is carriage-return?
	je	do_cr			# yes, move the cursor

	cmp	$ASCII_LINE_FEED, %al	# is line-feed?
	je	do_lf			# yes, move the cursor

	cmp	$ASCII_BACKSPACE, %al	# is backspace?
	je	do_bs			# yes, move the cursor

	# otherwise write character and attribute to the screen

	call	compute_vram_offset	# where to put character
	mov	$0x07, %ah 		# use normal attribute
	stosw				# write char/attribute
	
	# then adjust the cursor-coordinates (row,col) in (DH,DL)

	inc	%dl			# increment column-number
	cmp	$80, %dl 		# end-of-row was reached?
	jb	ttyxx			# no, keep column-number
	xor	%dl, %dl		# else do carriage-return
	jmp	do_lf			#  followed by line-feed 


do_bs:	or	%dl, %dl		# column-number is zero?
	jz	ttyxx			# yes, perform no action
	dec	%dl			# else preceeding column
	call	compute_vram_offset	#  is located on screen
	mov	$0x0720, %ax 		#  and blank character
	stosw				#  overwrites the cell
	jmp	ttyxx			# keep that column-number

do_cr:	xor	%dl, %dl		# move cursor to column 0
	jmp	ttyxx			# skip to rom-bios update

do_lf:	inc	%dh			# move cursor to next row
	cmp	$25, %dh 		# beyond bottom-of-screen? 
	jb	ttyxx			# no, keep the row-number
	dec	%dh			# else reduce row-number	
	call	scroll_vpage_up		# and scroll screen upward
ttyxx:	
	call	set_cursor_locn		# update ROM-BIOS info

	ret
#------------------------------------------------------------------
#------------------------------------------------------------------
sync_crt_cursor:

	push	%ax
	push	%ds

	mov	$sel_bs, %ax		# address ROM-BIOS DATA
	mov	%ax, %ds		#   using DS register

	mov	(0x62), %bl		# current video page
	movzx	%bl, %ebx 		# extended to dword
	mov	0x50(, %ebx, 2), %dx	# get page's cursor
	
	# update hardware cursor

	imul	$2048, %bx
	mov	$80, %al 
	mul	%dh
	add	%dl, %al 
	adc	$0, %ah 
	add	%ax, %bx 
	
	mov	$0x3D4, %dx 
	mov	$0x0E, %al 
	mov	%bh, %ah 
	out	%ax, %dx 
	mov	$0x0F, %al 
	mov	%bl, %ah 
	out	%ax, %dx 

	pop	%ds
	pop	%ax
	ret
#==================================================================
#========  Fault-Handler for General Protection Exceptions  =======
#==================================================================
isrGPF:	# we kept this handler as it helped us during debugging 
	pushal
	pushl	$0
	mov	%ds, (%esp)
	pushl	$0 
	mov	%es, (%esp)

	mov	$sel_es, %ax		# address video memory
	mov	%ax, %es 		#   with ES register
	mov	$80, %edi 		# offset for stackdump

	mov	%esp, %ebp 		# point to top element
	mov	$14, %ecx 		# setup element count
.L1:	
	mov	(%ebp), %eax 		# get the next element
	call	eax2hex			# display it on screen
	add	$160, %edi 		# advance to next line
	add	$4, %ebp 		# point to next element
	loop	.L1			# print another element

	jmp	do_exit			# bail out of this demo
#-----------------------------------------------------------------
#-----------------------------------------------------------------
eax2hex: # draws register EAX in hex-format onto screen at ES:EDI

	pushal

	mov	%eax, %edx 		# transfer data to EDX  <--- fixed
	cld				# do forward processing
	mov	$0x3020, %ax 		# prepend a blank space 
	stosw				# before register value
	mov	$8, %ecx 		# setup count of nybbles
.L0:	
	rol	$4, %edx 		# next nybble into DL
	mov	%dl, %al		# copy nybble to AL
	and	$0x0F, %al 		# isolate nybble's bits
	cmp	$10, %al 		# -- Lopez algorithm -- 
	sbb	$0x69, %al 		# -- converts binary --
	das				# -- to hex numeral  --
	stosw				# store char and colors
	loop	.L0			# process other nybbles

	mov	$0x3020, %ax		# append a blank space
	stosw				# after register value

	popal
	ret
#-----------------------------------------------------------------
	.align	16			# alignment at paragraph 
	.space	512			# reserved for stack use 
tos0:					# label fop top-of-stack 
#-----------------------------------------------------------------
	.end				# no more to be assembled

	Thanks to Alex Fedosov for pointing out the need to
	preserve EBX in our 'compute_vram_offset' function.
						10 MAY 2004

