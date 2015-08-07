//-----------------------------------------------------------------
//	tryvm86.s
//
//	This program, after entering protected-mode, executes  
//	a real-mode procedure in Virtual-8086 emulation mode.
//	The program exits VM86-mode when a General Protection
//	Exception is triggered, e.g., by a 'hlt' instruction.
//
//	 to assemble: $ as tryvm86.s -o tryvm86.o 
//	 and to link: $ ld tryvm86.o -T ldscript -o tryvm86.b 
//
//	NOTE: This code begins executing with CS:IP = 1000:0002. 
//
//	programmer: ALLAN CRUSE
//	written on: 23 MAR 2004
//	revised on: 04 NOV 2006 -- to use GNU assembler's syntax
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
	mov	%ax, %ss 		#   also SS register  
	lea	tos0, %sp		# establish new stacktop 

	call	initialize_os_tables
	call	enter_protected_mode
	call	execute_program_demo 
	call	leave_protected_mode 

	lss	%cs:exit_pointer, %sp	# recover saved SS and SP 
	lret				# exit to program loader 
#------------------------------------------------------------------
exit_pointer:	.word	0, 0		# to store stack-address 
#------------------------------------------------------------------
	.align	8 		# CPU requires quadword alignment 
theGDT:	.word	0x0000, 0x0000, 0x0000, 0x0000	# null descriptor 
	.equ	sel_es, (.-theGDT)+0	# vram-segment's selector 	
	.word	0x7FFF, 0x8000, 0x920B, 0x0000	# vram descriptor 
	.equ	sel_cs, (.-theGDT)+0	# code-segment's selector 	
	.word	0xFFFF, 0x0000, 0x9A01, 0x0000	# code descriptor 
	.equ	sel_ss, (.-theGDT)+0	# data-segment's selector 	
	.word	0xFFFF, 0x0000, 0x9201, 0x0000	# data descriptor 
	.equ	sel_ts, (.-theGDT)+0	# task-segment's selector 	
	.word	0x000B, theTSS, 0x8901, 0x0000	#  TSS descriptor 
	.equ	sel_fs, (.-theGDT)+0	# flat-segment's selector 	
	.word	0xFFFF, 0x0000, 0x9200, 0x008F	# flat descriptor 
	.equ	limGDT, (.-theGDT)-1	# the GDT-segment's limit 
#------------------------------------------------------------------
#------------------------------------------------------------------
theIDT:	.space	2048		# enough for 256 gate-descriptors
#------------------------------------------------------------------
theTSS:	.long	0, 0, 0			# 32bit Task-State Segment 
#------------------------------------------------------------------
regGDT:	.word	limGDT, theGDT, 0x0001	# image for GDTR register
regIDT:	.word	0x07FF, theIDT, 0x0001	# image for IDTR register
regIVT:	.word	0x03FF, 0x0000, 0x0000	# image for IDTR register
#------------------------------------------------------------------
enter_protected_mode: 

	cli				# no device interrupts 
	mov	%cr0, %eax		# get machine status 
	bts	$0, %eax		# set PE-bit to 1 
	mov	%eax, %cr0		# enable protection 

	lgdt	regGDT			# load GDTR register-image 
	lidt	regIDT			# load IDTR register-image 
	ljmp	$sel_cs, $pm		# reload register CS 
pm:	
	mov	$sel_ss, %ax		
	mov	%ax, %ss		# reload register SS 
	mov	%ax, %ds		# reload register DS 

	xor	%ax, %ax		# use 'null' selector 
	mov	%ax, %es		# to purge invalid ES 
	mov	%ax, %fs		# to purge invalid FS 
	mov	%ax, %gs		# to purge invalid GS 

	ret				# back to main routine 
#------------------------------------------------------------------
leave_protected_mode: 

	mov	$sel_fs, %ax		# address 4GB r/w segment
	mov	%ax, %fs		#   using FS register
	mov	%ax, %gs		#    and GS register

	mov	$sel_ss, %ax		# address 64KB r/w segment 
	mov	%ax, %ds		#   using DS register 
	mov	%ax, %es		#    and ES register 

	mov	%cr0, %eax		# get machine status 
	btr	$0, %eax		# reset PE-bit to 0 
	mov	%eax, %cr0		# disable protection 

	lidt	regIVT			# load IDTR register-image 

	ljmp	$0x1000, $rm		# reload register CS 
rm:	
	mov	%cs, %ax	
	mov	%ax, %ss		# reload register SS 
	mov	%ax, %ds		# reload register DS 
	sti				# interrupts allowed 

	ret				# back to main routine 
#------------------------------------------------------------------
#------------------------------------------------------------------
initialize_os_tables:

	# initialize IDT descriptor for gate 0x0D
	mov	$0x0D, %ebx		# ID-number for GP-fault
	lea	theIDT(, %ebx, 8), %di	# address gate-descriptor
	movw	$isrGPF, 0(%di)		# entry-point loword
	movw	$sel_cs, 2(%di)		# selector for code
	movw	$0x8E00, 4(%di)		# 386 interrupt-gate
	movw	$0x0000, 6(%di)		# entry-point hiword

	ret
#-----------------------------------------------------------------
execute_program_demo:

	mov	%esp, theTSS+4		# current stack-address  
	mov	%ss,  theTSS+8		# preserved in 'theTSS'

	mov	$sel_ts, %ax		# establish 'theTSS' as
	ltr	%ax			#  Task-State Segment

	pushfl				# insure NT-bit is clear  
	btrl	$14, (%esp)		# in the EFLAGS register
	popfl				# before executing iret

	pushl	$0			# register-image for GS
	pushl	$0			# register-image for FS
	pushl	$0			# register-image for DS
	pushl	$0			# register-image for ES
	pushl	$0x1000			# register-image for SS
	pushl	$tos3			# register-image for SP
	pushl	$0x00023000		# EFLAGS register-image
	pushl	$0x1000			# register-image for CS
	pushl	$turn_blue		# register-image for IP
	iretl				# enter Virtual-8086 mode 
#------------------------------------------------------------------
finish_up_main_thread:
	lss	%cs:theTSS+4, %esp	# restore saved stackptr
	ret				# return to main routine
#-----------------------------------------------------------------
turn_blue:
	mov	$0xB800, %ax		# address video memory
	mov	%ax, %ds		#   with DS register
	mov	%ax, %es		#   also ES register
	xor	%si, %si		# point DS:SI to start
	xor	%di, %di		# point ES:DI to start
	cld				# use forward processing
	mov	$2000, %cx		# number of screen cells 
.L0:	
	lodsw				# fetch next char/attrib
	mov	$0x1F, %ah		# set new attribute byte
	stosw				# store that char/attrib
	loop	.L0			# process the next cell

	hlt				# privileged instruction
#------------------------------------------------------------------
#------------------------------------------------------------------
isrGPF:	# quits when the first privileged opcode is encountered
	ljmp	$sel_cs, $finish_up_main_thread	
#------------------------------------------------------------------
	.align	16			# assure stack alignment
	.space	512			# reserved for stack use 
tos3:					# label for top-of-stack 
#------------------------------------------------------------------
	.align	16			# assure stack alignment 
	.space	512			# reserved for stack use 
tos0:					# label for top-of-stack 
#------------------------------------------------------------------
	.end				# no more to be assembled

