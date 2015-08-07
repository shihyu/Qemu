//-------------------------------------------------------------------
//	try64bit.s
//
//	This program demonstrates the steps that are needed in order
//	to activate the Extended Memory 64-bit Technology (EM64T) in
//	Intel's Pentium-D and Core-2 processors, and then to display 
//	some text characters while executing in 64-bit mode and also 
//	"compatibility" mode, before finally returning to real-mode.
//
//	 assemble using: $ as try64bit.s -o try64bit.o
//	 and link using: $ ld try64bit.o -T ldscript -o try64bit.b 
//
//	NOTE: This code begins executing with cs:ip = 1000:0002.
//
//	programmer: ALLAN CRUSE
//	written on: 22 MAY 2006
//	revised on: 05 DEC 2006
//-------------------------------------------------------------------



	.section	.text
#-------------------------------------------------------------------
	.word	0xABCD			# our application signature
#-------------------------------------------------------------------
	.code16				# for Pentium 'real-mode'
#-------------------------------------------------------------------
main:	mov	%sp, %cs:exit_pointer+0
	mov	%ss, %cs:exit_pointer+2

	mov	%cs, %ax	
	mov	%ax, %ds	
	mov	%ax, %es	
	mov	%ax, %ss	
	lea	tos, %sp	

	call	initialize_os_tables 
	call	enter_protected_mode
	call	execute_program_demo
	call	leave_protected_mode
	call	display_confirmation

	lss	%cs:exit_pointer, %sp
	lret	
#-------------------------------------------------------------------
exit_pointer:	.word	0, 0 		# holds the loader's SS:SP
#-------------------------------------------------------------------
msg1:	.ascii	" OK, processor is now executing in 64-bit mode "
len1:	.quad	. - msg1
#------------------------------------------------------------------
msg2:	.ascii	" Executing 16-bit code in 'compatibility' mode "
len2:	.word	. - msg2
#------------------------------------------------------------------
msg3:	.ascii	"\r\n Successfully returned to real-mode \r\n\n"
len3:	.word	. - msg3
#------------------------------------------------------------------
#-------------------------------------------------------------------
	.align	16			# optimal memory-alignment 
theGDT:	# This is our Global Descriptor Table (octaword entries)
	.octa	0x00000000000000000000000000000000	# null desc

	# the selector and descriptor for our 64-bit code-segment
	.equ	sel_CS, (.-theGDT)+0 
	.octa	0x000000000000000000209A0000000000	# code 64bit

	# the selector and descriptor for out 16-bit code-segment
	.equ	sel_cs, (.-theGDT)+0
	.octa	0x000000000000000000009A010000FFFF	# code 16bit

	# the selector and descriptor for our 16-bit data-segment
	.equ	sel_ss, (.-theGDT)+0
	.octa	0x0000000000000000000092010000FFFF	# data 16bit

	# the selector and descriptor for our 1-MB data-segment
	.equ	sel_ds, (.-theGDT)+0
	.octa	0x0000000000000000000F92000000FFFF	# data 16bit

	# the selector and descriptor for our 4-GB data-segment
	.equ	sel_fs, (.-theGDT)+0
	.octa	0x0000000000000000008F92000000FFFF	# flat 4GB

	# the selector and descriptor for our 16to64-bit call-gate  
	.equ	gate64, (.-theGDT)+0
	.word	mode64, sel_CS, 0x8C00, 0x0001	# call-gate lo-quad
	.word	0x0000, 0x0000, 0x0000, 0x0000	# call-gate hi-quad

	.equ	limGDT, (.-theGDT)-1			# GDT-limit
#-------------------------------------------------------------------
regGDT:	.word	limGDT, theGDT, 0x0001		# image for GDTR
#-------------------------------------------------------------------
level1_phys_address:	.quad	0x00021000	# for pagetbl	
level2_phys_address:	.quad	0x00022000	# for pagedir
level3_phys_address:	.quad	0x00023000	# for pageptr
level4_phys_address:	.quad	0x00024000	# for level-4
#-------------------------------------------------------------------
initialize_os_tables:

	# we will use register ES to address our paging-table arena
	mov	$0x2000, %ax		# address arena at 0x20000
	mov	%ax, %es		# with ES segment-register

	# our table-building procedures use string-instructions
	cld				# do forward processing

	# long-mode address-translations use a 4-level hierarchy
	call	build_level1_table	# page-table at 0x21000
	call	build_level2_table	# page-directory at 0x22000
	call	build_level3_table	# pgdir-ptr-tbl at 0x23000
	call	build_level4_table	# long-mode lvl4 0x24000

	ret
#-------------------------------------------------------------------
#-------------------------------------------------------------------
build_level1_table:	# page-table at 0x21000

	# NOTE: this procedure executes in 'real-mode' with DF=0
	# and register ES already addresses the arena at 0x20000

	# point ES:DI to the beginning of the Level-1 table area
	movw	level1_phys_address, %di	

	# these will be quadword entries describing 4KB-frames
	xor	%edx, %edx		# initial upper longword
	mov	$0x007, %eax		# initial lower longword
	mov	$512, %ecx		# count of table entries
next1:
	stosl				# store quadword's lo-half
	xchg	%eax, %edx
	stosl				# store quadword's hi-half
	xchg	%edx, %eax

	add	$0x1000, %eax		# advance frame-address
	loop	next1			# back for another entry

	ret
#-------------------------------------------------------------------
build_level2_table:	# page-directory at 0x22000

	# NOTE: this procedure executes in 'real-mode' with DF=0
	# and register ES already addresses the arena at 0x20000

	# point ES:DI to the beginning of the Level-2 table area
	movw	level2_phys_address, %di

	# these will be quadword entries describing 4KB-frames
	xor	%edx, %edx
	mov	level1_phys_address, %eax
	or	$0x007, %eax
	mov	$512, %ecx
next2:
	stosl
	xchg	%eax, %edx
	stosl
	xchg	%edx, %eax

	xor	%eax, %eax
	loop	next2

	ret
#-------------------------------------------------------------------
build_level3_table:	# pgdir-ptr-tbl at 0x23000

	# this procedure executes in real-mode with DF=0
	# register ES already addresses arena at 0x20000
	movw	level3_phys_address, %di

	# these are quadword entries describing 4KB-pages
	xor	%edx, %edx
	mov	level2_phys_address, %eax
	or	$0x007, %eax
	mov	$512, %ecx
next3:
	stosl
	xchg	%eax, %edx
	stosl
	xchg	%edx, %eax

	xor	%eax, %eax
	loop	next3
	ret
#-------------------------------------------------------------------
build_level4_table:	# long-mode lvl4 0x24000

	# this procedure executes in real-mode with DF=0
	# register ES already addresses arena at 0x20000
	movw	level4_phys_address, %di

	# these are quadword entries describing 4KB-pages
	xor	%edx, %edx
	mov	level3_phys_address, %eax
	or	$0x007, %eax
	mov	$512, %ecx
next4:
	stosl
	xchg	%eax, %edx
	stosl
	xchg	%edx, %eax

	xor	%eax, %eax
	loop	next4
	ret
#-------------------------------------------------------------------
enter_protected_mode:
	
	cli
	lgdt	regGDT

	mov	%cr0, %eax
	bts	$0, %eax
	mov	%eax, %cr0

	ljmp	$sel_cs, $pm
pm:
	mov	$sel_ss, %ax
	mov	%ax, %ss
	mov	%ax, %ds

	mov	$sel_fs, %ax
	mov	%ax, %es

	xor	%ax, %ax
	mov	%ax, %fs
	mov	%ax, %gs

	ret
#-------------------------------------------------------------------
leave_protected_mode:

	mov	$sel_fs, %ax
	mov	%ax, %fs
	mov	%ax, %gs

	mov	$sel_ss, %ax
	mov	%ax, %ds
	mov	%ax, %es

	mov	%cr0, %eax
	btr	$0, %eax
	mov	%eax, %cr0

	ljmp	$0x1000, $rm
rm:
	mov	%cs, %ax
	mov	%ax, %ss
	mov	%ax, %ds
	mov	%ax, %es
	mov	%ax, %fs
	mov	%ax, %gs

	sti
	ret
#-------------------------------------------------------------------
tossave:	.long	0, 0		# stores 32-bit pointer
#-------------------------------------------------------------------
execute_program_demo:

	# save the 16-bit code's stack-address for return-to-main
	mov	%esp, tossave+0
	mov	%ss,  tossave+4
 
	# enable Page-Address Extensions (bit #5) in register CR4 
	mov	%cr4, %eax
	bts	$5, %eax
	mov	%eax, %cr4

	# establish page-tables-base-address in register CR3	
	mov	level4_phys_address, %eax
	mov	%eax, %cr3

	# enable long-mode (bit #8) in the EFER register) 
	mov	$0xC0000080, %ecx
	rdmsr
	bts	$8, %eax
	wrmsr	

	# activate long-mode by setting PG-bit (bit #31) in CR0
	mov	%cr0, %eax
	bts	$31, %eax
	mov	%eax, %cr0	

	# use a call-gate to transfer from 16-bit to 64-bit code
	ljmp	$gate64, $0		# jump to 64-bit code 
#------------------------------------------------------------------
display_confirmation:

	mov	%cs, %ax
	mov	%ax, %ds
	mov	%ax, %es

	# this draws the message using ROM-BIOS write_tty service
	mov	$0x0F, %ah
	int	$0x10

	mov	$0x03, %ah
	int	$0x10

	lea	msg3, %bp
	mov	len3, %cx
	mov	$0x07, %bl
	mov	$0x1301, %ax
	int	$0x10

	ret
#------------------------------------------------------------------
#-------------------------------------------------------------------
	.align	16
	.space	512
tos:	
#-------------------------------------------------------------------
	.code64
#-------------------------------------------------------------------
mode64:	
	mov	$sel_ss, %ax		# data-segment selector
	mov	%ax, %es		#  into register ES
	mov 	%ax, %ds		#  also register DS
	mov	%ax, %ss		#  also register SS

	# here we draw a confirming message directly to video memory 
	mov	$sel_ss, %ax		# address our program data
	mov	%ax, %gs		#   with the GS register
	lea	msg1, %rsi		# point GS:RSI to message

	mov	$0x000B8000, %rbx	# address of video memory 
	lea	480(%rbx), %rdi		# point ES:RDI to row 3
	mov	%gs:len1, %rcx		# setup message's length
	mov	$0x1F, %ah		#  and color attributes
	cld				# do forward processing
.L1:	lodsb	%gs:(%rsi)		# fetch next character
	stosw				# store char and color
	loop	.L1			# again if chars remain	

	#--------------------------------------------------
	# now we want to transfer to 'compatibility mode'
	# in preparation for our exit from protected-mode
	#--------------------------------------------------
	ljmp	*%gs:destination	# indirect far jump
#------------------------------------------------------------------
destination:	.long	cmode, sel_cs	# pointer to jump-target
#------------------------------------------------------------------
	.code16		# for 16-bit code in 'compatibility' mode
#------------------------------------------------------------------
	.align	16
cmode:	# here we execute 16-bit code in 'compatibility' mode

	# draw second confirmation message
	mov	$sel_fs, %ax
	mov	%ax, %es
	mov	$0x000B8000, %ebx
	lea	640(%ebx), %edi
	
	mov	$sel_ss, %ax
	mov	%ax, %ds
	lea	msg2, %si
	mov	len2, %cx
	mov	$0x3F, %ah
	cld
.L2:	lodsb
	stosw	%es:(%edi)
	loop	.L2

	# disable long mode (by turning off the PG-bit in CR0)
	mov	%cr0, %eax
	btr	$31, %eax
	mov	%eax, %cr0
	jmp	.L3
.L3:	
	# we are executing 16-bit code in 'legacy' protected-mode

	# disable Page-Address Extensions
	mov	%cr4, %eax
	btr	$5, %eax
	mov	%eax, %cr4

	# disable long-mode (bit #8 in EFER register) 
	mov	$0xC0000080, %ecx
	rdmsr
	btr	$8, %eax
	wrmsr	

	mov	$sel_ss, %ax	#<--
	mov	%ax, %ss	#<--
	mov	%ax, %ds	#<--
	mov	%ax, %es	#<--

	# let's return to main so we can exit protected-mode
	lss	%cs:tossave, %esp
	ret
#------------------------------------------------------------------
	.end				# nothing more to assemble

