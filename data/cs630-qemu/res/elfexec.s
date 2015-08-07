//-----------------------------------------------------------------
//	elfexec.s
//
//	This will show how to 'load' an executable ELF file-image
//	at its intended load-address, in extended physical memory
//	(i.e., memory above 1MB), and then execute it from a code
//	segment whose segment-limit extends to include the entire 
//	4GB address-space.  The file-image is loaded from memory-
//	address 0x00018000 (where it initially gets placed by our 
//	'quikload' boot-loader).  The ELF executable image is put
//	onto our hard-disk partition using these commands:
//
//	   assemble with: $ as hello.s -o hello.o
//	   and link with: $ ld hello.o -o hello
//	   install using: $ dd if=hello of=/dev/sda4 seek=13
//
//	This 'second-stage loader' program is placed on out hard-
//	disk partition using these commands:
//
//	  assemble with: $ as elfexec.s -o elfexec.o
//	  and link with: $ ld elfexec.o -T ldscript -o elfexec.b
//	  install using: $ dd if=elfexec.b of=/dev/sda4 seek=1
//	
//	NOTE: This code begins executing with CS:IP = 1000:0002.
//
//	programmer: ALLAN CRUSE
//	written on: 28 OCT 2006
//-----------------------------------------------------------------


	.section	.text
#------------------------------------------------------------------
	.word	0xABCD			# application signature
#------------------------------------------------------------------
#==================================================================
	.code16				# for Pentium 'real-mode'
#==================================================================
#------------------------------------------------------------------
main:	mov	%sp, %cs:exit_pointer+0
	mov	%ss, %cs:exit_pointer+2

	mov	%cs, %ax
	mov	%ax, %ds
	mov	%ax, %ss
	lea	tos, %sp

	call	initialize_os_tables
	call	enter_protected_mode
	call	execute_program_demo
	call	leave_protected_mode

	lss	%cs:exit_pointer, %sp
	lret	
#------------------------------------------------------------------
exit_pointer:	.word	0, 0		# saves loader's SS and SP
#------------------------------------------------------------------
#------------------------------------------------------------------
	.align	8		# cpu requires quadword alignment 
theGDT:	.word	0x0000, 0x0000, 0x0000, 0x0000	# null descriptor
	.equ	sel_ts, .-theGDT + 0	# task32 segment-selector 
	.word	0x000B, theTSS, 0x8901, 0x0000	# task descriptor
	.equ	sel_cs, .-theGDT + 0	# code16 segment-selector 
	.word	0xFFFF, 0x0000, 0x9A01, 0x0000	# code descriptor
	.equ	sel_ds, .-theGDT + 0	# data16 segment-selector 
	.word	0xFFFF, 0x0000, 0x9201, 0x0000	# data descriptor
	.equ	sel_fs, .-theGDT + 0	# data16 segment-selector 
	.word	0xFFFF, 0x0000, 0x9200, 0x008F	# data descriptor
	.equ	sel_gs, .-theGDT + 0	# vram16 segment-selector 
	.word	0x0007, 0x8000, 0x920B, 0x0080	# vram descriptor
	.equ	sel_CS, .-theGDT + 0	# code32 segment-selector 
	.word	0xFFFF, 0x0000, 0x9A01, 0x0040	# code descriptor
	.equ	sel_DS, .-theGDT + 0	# data32 segment-selector 
	.word	0xFFFF, 0x0000, 0x9201, 0x0040	# data descriptor
	.equ	userCS, .-theGDT + 3	# code32 segment-selector 
	.word	0xFFFF, 0x0000, 0xFA00, 0x00CF	# code descriptor
	.equ	userDS, .-theGDT + 3	# data32 segment-selector 
	.word	0xFFFF, 0x0000, 0xF200, 0x00CF	# data descriptor
	.equ	limGDT, ( . - theGDT )-1	# segment's limit
#------------------------------------------------------------------
theIDT:	.space	256 * 8		# to support 256 gate-desgriptors
	.equ	limIDT, ( . - theIDT )-1	# segment's limit
#------------------------------------------------------------------
theTSS:	.long	0, 0x00010000, sel_DS		# Task-State info
#------------------------------------------------------------------
regGDT:	.word	limGDT, theGDT, 0x0001		# image for GDTR
regIDT:	.word	limIDT, theIDT, 0x0001		# image for IDTR
regIVT:	.word	0x03FF, 0x0000, 0x0000		# image for IDTR
#------------------------------------------------------------------
initialize_os_tables:

	# build gate-descriptor for Supervisor Calls  
	mov	$0x80, %ebx
	lea	theIDT(, %ebx, 8), %di
	movw	$isrSVC, 0(%di)
	movw	$sel_CS, 2(%di)
	movw	$0xEF00, 4(%di)
	movw	$0x0000, 6(%di)

	# build gate-descriptor for General Protection Faults 
	mov	$0x0D, %ebx
	lea	theIDT(, %ebx, 8), %di
	movw	$isrGPF, 0(%di)
	movw	$sel_CS, 2(%di)
	movw	$0x8F00, 4(%di)
	movw	$0x0000, 6(%di)

	ret
#------------------------------------------------------------------
enter_protected_mode:

	cli

	mov	%cr0, %eax
	bts	$0, %eax
	mov	%eax, %cr0

	lgdt	regGDT
	lidt	regIDT

	ljmp	$sel_cs, $pm
pm:
	mov	$sel_ds, %ax
	mov	%ax, %ds
	mov	%ax, %ss

	xor	%ax, %ax
	mov	%ax, %es
	mov	%ax, %fs
	mov	%ax, %gs

	ret
#------------------------------------------------------------------
leave_protected_mode:

	mov	$sel_ds, %ax
	mov	%ax, %ds
	mov	%ax, %es
	
	mov	$sel_fs, %ax
	mov	%ax, %fs
	mov	%ax, %gs

	cli
	mov	%cr0, %eax
	btr	$0, %eax
	mov	%eax, %cr0

	ljmp	$0x1000, $rm
rm:
	mov	%cs, %ax
	mov	%ax, %ss
	mov	%ax, %ds
	mov	%ax, %es

	lidt	regIVT
	sti

	ret
#------------------------------------------------------------------
tossave: .word	0, 0, 0			# to save 48-bit pointer
#------------------------------------------------------------------
execute_program_demo:

	# save our 16-bit stack's address (for return to 'main')
	mov	%esp, tossave+0
	mov	%ss,  tossave+4

	# switch to our 32-bit stack in ring-0
####	lss	%cs:theTSS+4, %esp

	# transfer to second-stage loader in 32-bit code-segment
	ljmp	$sel_CS, $launch_the_elf_thread	# to 32-bit code
#------------------------------------------------------------------
finish_up_main_thread:
	
	# here we restore our 16-bit stack's address
	lss	%cs:tossave, %esp		
	ret
#------------------------------------------------------------------
#==================================================================
	.code32
#==================================================================
#------------------------------------------------------------------
launch_the_elf_thread:

	# first we setup register TR (to support ring-transitions)
	mov	$sel_ts, %ax		# selector for Task-State
	ltr	%ax			# loaded into register TR

	# next we must 'load' the ELF-image at its intended address
	mov	$userDS, %ax		# address 4-GB segment
	mov	%ax, %ds		#   with DS register
	mov	%ax, %es		#   also ES register
	cld				#  do forward copying

	# here we 'load' the ELF-image's .text section
	mov	$0x00011800, %esi	# point DS:ESI to source
	mov	$0x08048000, %edi	# point ES:EDI to dest'n
	mov	$0x00000A00, %ecx	# bytes in 5 disk-sectors 
	rep	movsb			# copy the section-image

	# here we 'load' the ELF-image's .data section
	mov	$0x00011800, %esi	# point DS:ESI to source
	mov	$0x08049000, %edi	# point ES:EDI to dest'n
	mov	$0x00000A00, %ecx	# bytes in 5 disk-sectors 
	rep	movsb			# copy the section-image

	# lastly we setup our ring0 stack for a 'return' to ring3
	pushl	$userDS			# ring3 stack-selector
	pushl	$0x08048000		# initial top-of-stack
	pushl	$userCS			# ring3 code-selector
	pushl	$0x08048074		# program entry-point
	lret				# execute ELF program
#------------------------------------------------------------------
sys_call_table:	# The jump-table for our system-call dispatcher
	.long	do_nothing		# for system-call 0
	.long	do_exit			# for system-call 1
	.long	do_nothing		# for system-call 2
	.long	do_nothing		# for system-call 3
	.long	do_write		# for system-call 4
	.equ	NR_SYSTEM_CALLS, ( . - sys_call_table ) / 4
#------------------------------------------------------------------
isrSVC:	# This is the entry-point for any Supervisor-Calls
	cmp	$NR_SYSTEM_CALLS, %eax	# is ID-bumber valid?
	jb	svcok			# yes, keep ID-number
	xor	%eax, %eax		# else zero ID-number
svcok:	jmp	*%cs:sys_call_table(, %eax, 4)	# to SVC code
#------------------------------------------------------------------
do_nothing: # This routine is for any unimplemented system-calls
	mov	$-1, %eax		# setup error-code in EAX
	iret				# resume the calling task
#------------------------------------------------------------------
do_exit:  # Here we transfer control back to our .code16 segment
	ljmp	$sel_cs, $finish_up_main_thread	# to 16-bit code	
#------------------------------------------------------------------
do_write:  # Here we implement the 'write( fd, buf, len )' service
#
#	Expects:	EBX = device ID-number
#			ECX = offset of message
#			EDX = length of message
#			 DS = user data-selector
#
#	Returns:	EAX = count of bytes written
#			      (or -1 for any errors) 
#
	enter	$0, $0			# setup parameter access

	pushal				# preserve cpu registers
	push	%ds
	push	%es

	# check for a valid devicID-number
	cmp	$1, %ebx		# is the STDOUT device?
	je	isval			# yes, we can do writing

	# else substitute -1 for the saved value from register EAX 
	movl	$-1, -4(%ebp)		# setup error-code for EAX
	jmp	wrxxx			# and skip all the writing	
isval:
	# fetch and process the the user's ascii-codes
	mov	$sel_gs, %ax		# address vram segment
	mov	%ax, %es		#   with ES register

	cld
	mov	-8(%ebp), %esi		# point DS:ESI to 'buf'
	mov	-12(%ebp), %ecx		# setup 'len' in ECX
	movl	$0, -4(%ebp)		# initialize return-value	
nxchr:
	lodsb				# fetch next ascii-code
	call	write_tty		# output that character
	incl	-4(%ebp)		# increment return-value 
	loop	nxchr	

	# move CRT cursor to screen-location following message
	call	sync_crt_cursor		# update hardware cursor	
wrxxx:
	pop	%es			# restore cpu registers
	pop	%ds
	popal

	leave				# restore former frameptr
	iret				# resume the calling task
#------------------------------------------------------------------
	# Equates for control-codes that require special handling
	.equ	ASCII_BACKSPACE, 0x08
	.equ	ASCII_CARR_RETN, 0x0D
	.equ	ASCII_LINE_FEED, 0x0A
#------------------------------------------------------------------
write_tty: # Writes byte found in AL to current cursor location 
	
	call	get_cursor_locn		# DH=row, DL=col, EBX=page

	# certain ascii control-codes require special handling

	cmp	$ASCII_CARR_RETN, %al	# is it Carriage-Return?
	je	do_cr			# yes, move the cursor

	cmp	$ASCII_LINE_FEED, %al	# is it Line Feed?
	je	do_lf			# yes, move the cursor

	cmp	$ASCII_BACKSPACE, %al	# is it Backspace?
	je	do_bs			# yes move the cursor

	# otherwise, write character and attribute to the screen

	call	compute_vram_offset	# where to put character
	mov	$0x07, %ah		# normal color attribute
	stosw				# store char/color pair
	
	# then adjust the cursor-coordinates (row,col) in (DH,DL)
	
	inc	%dl			# increment column-number
	cmp	$80, %dl		# end-of-row was reached
	jb	ttyxx			# no, keep column-number
	xor	%dl, %dl		# else do carriage-return
	jmp	do_lf			# followed by line-feed

do_bs:	# implement the 'backspace' action
	
	or	%dl, %dl		# column-number is zero?
	jz	ttyxx			# yes, can't go backward

	dec	%dl			# else go back a column
	call	compute_vram_offset	# update (row,col,page)
	mov	$0x0720, %ax		# setup blank character
	stosw				# write blank character
	jmp	ttyxx			# keep that column-number

do_cr:	# implement the 'carriage return' action

	xor	%dl, %dl		# move cursor to column 0
	jmp	ttyxx			# and update ROM-BIOS DATA 

do_lf:	# implement the 'line feed' action

	inc	%dh			# move cursor to next row
	xor	%dl, %dl		# move cursor to column 0
	cmp	$25, %dh		# beyond bottom-of-screen?	
	jb	ttyxx			# no, keep the row-number
	dec	%ah			# else reduce row-number
	call	scroll_vpage_up		# and scroll screen upward
ttyxx:
	call	set_cursor_locn		# update ROM-BIOS variables

	ret
#------------------------------------------------------------------
get_cursor_locn:  # returns cursor's (row,col) in (DH,DL)
	mov	0x462, %bl		# current video page
	movzx	%bl, %ebx		# extended to 32-bits
	mov	0x450(,%ebx, 2), %dx	# lookup page's cursor
	ret
#------------------------------------------------------------------
set_cursor_locn:  # stores cursor's (row,col) from (DH,DL)
	mov	0x462, %bl		# current video page
	movzx	%bl, %ebx		# extended to 32-bits
	mov	%dx, 0x450(,%ebx, 2)	# store page's cursor
	ret
#------------------------------------------------------------------
compute_vram_offset:
#
# Uses the (row,col, page) parameters in (DH, DL, BL) to compute
# the current cell's vram-offset, and returns it in register EDI 
#
	push	%eax
	push	%ebx
	push	%ecx
	push	%edx

	mov	0x462, %bl		# current video page
	movzx	%bl, %ebx		# extended to 32-bits
	mov	0x450(, %ebx, 2), %dx	# lookup page's cursor	
	
	imul	$0x1000, %ebx, %edi	# EDI = offset to page
	movzx	%dh, %ecx		# row-number into EAX
	imul	$160, %ecx		# page-offset to line
	add	%ecx, %edi		# vram-offset to line
	movzx	%dl, %ecx		# col-number into EAX
	imul	$2, %ecx		# line-offset to cell
	add	%ecx, %edi		# vram-offset to cell
	
	pop	%edx
	pop	%ecx
	pop	%ebx
	pop	%eax
	ret
#------------------------------------------------------------------
sync_crt_cursor:
	push	%eax
	push	%ebx
	push	%ecx	
	push	%edx

	mov	0x462, %bl
	movzx	%bx, %ebx		# page-number
	mov	0x450(, %ebx, 2), %dx
	movzx	%dh, %ecx		# row-number
	movzx	%dl, %edx		# col-offset

	imul	$0x1000, %ebx		# vram-offset of page
	imul	$160, %ecx		# page-offset of line
	imul	$2, %edx		# line-offset of cell
	add	%edx, %ecx		# page-offset of cell
	add	%ecx, %ebx		# vram-offset of cell
	shr	$1, %ebx		# crtc-offset of cell

	# port-address for CRTC registers	
	mov	$0x03D4, %dx	

	# write CURSOR_HI
	mov	$0x0E, %al
	mov	%bh, %ah
	out	%ax, %dx

	# write CURSOR_LO
	mov	$0x0F, %al
	mov	%bl, %ah
	out	%ax, %dx

	pop	%edx
	pop	%ecx
	pop	%ebx
	pop	%eax
	ret
#------------------------------------------------------------------
scroll_vpage_up:
	pushal
	push	%ds

	mov	%es, %ax
	mov	%ax, %ds
	cld

	# copy rows 1 through 24 to rows 0 through 23, respectively

	xor	%edi, %edi		# point ES:EDI to row 0
	lea	160(%edi), %esi		# point ES:ESI to row 1
	mov	$24, %edx		# number of rows to move
rowup:	mov	$80, %ecx		# number of cells-per-row
	rep	movsw			# copy the entire row
	dec	%edx			# reduce the row-counter
	jnz	rowup			# and copy another row

	# now fill row 24 with blanks

	mov	$0x0720, %ax		# blank w/normal colors
	mov	$80, %ecx		# number of cells to fill
	rep	stosw			# fill the row with blanks 

	pop	%ds
	popal
	ret
#------------------------------------------------------------------
#------------------------------------------------------------------
hex:	.ascii	"0123456789ABCDEF"
name:	.ascii	" GS= FS= ES= DS="
	.ascii	"EDI=ESI=EBP=ESP=EBX=EDX=ECX=EAX="
	.ascii	"err=EIP= CS=EFL="
	.equ	N_ELTS, (. - name)/4
msg:	.ascii	" nnn=xxxxxxxx "
len:	.int	. - msg 
#------------------------------------------------------------------
isrGPF:
	pushal
	pushl	$0
	mov	%ds, (%esp)
	pushl	$0
	mov	%es, (%esp)
	pushl	$0
	mov	%fs, (%esp)
	pushl	$0
	mov	%gs, (%esp)

	mov	$sel_gs, %ax
	mov	%ax, %es

	mov	$sel_DS, %ax
	mov	%ax, %ds

	cld
	mov	%esp, %ebp		# base-address of items
	xor	%ebx, %ebx		# initial item-number
nxitm:
	# setup the item-name
	mov	name(, %ebx, 4), %eax
	mov	%eax, msg+1

	# setup the item-value
	mov	(%ebp, %ebx, 4), %eax
	lea	msg+5, %edi
	call	eax2hex

	# compute the screen-location
	mov	$22, %edi
	sub	%ebx, %edi
	imul	$160, %edi
	mov	len, %eax
	imul	$2, %eax
	sub	%eax, %edi
	
	# draw the message onscreen
	lea	msg, %esi
	mov	$0x30, %ah
	mov	len, %ecx
nxout:
	lodsb
	stosw
	loop	nxout

	inc	%ebx
	cmp	$N_ELTS, %ebx
	jb	nxitm
	
	ljmp	$sel_cs, $finish_up_main_thread	# to 16-bit code	
#------------------------------------------------------------------
eax2hex:
	pushal

	mov	$8, %ecx
nxnyb:
	rol	$4, %eax
	mov	%al, %bl
	and	$0xF, %ebx
	mov	hex(%ebx), %dl
	mov	%dl, (%edi)
	inc	%edi
	loop	nxnyb

	popal
	ret
#------------------------------------------------------------------
	.align	16
	.space	512
tos:	
#------------------------------------------------------------------
	.end

