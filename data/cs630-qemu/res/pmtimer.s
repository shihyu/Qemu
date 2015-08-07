//-----------------------------------------------------------------
//	pmtimer.s
//
//	This program handles timer interrupts in protected-mode.
//	It continuously displays the tick-count for ten seconds.
// 
//	 to assemble:  $ as pmtimer.s -o pmtimer.o
//	 and to link:  $ ld pmtimer.o -T ldscript -o pmtimer.b
//
//	NOTE: This code begins executing with CS:IP = 1000:0002. 
//
//	programmer: ALLAN CRUSE
//	written on: 23 FEB 2004
//	revised on: 15 SEP 2006 -- to use AT&T assembler syntax
//-----------------------------------------------------------------

	.section	.text
	.code16				# for Pentium 'real-mode'	
#-----------------------------------------------------------------
	.word	0xABCD			# programming signature 
#-----------------------------------------------------------------
begin:	mov	%sp, %cs:exit_pointer+0	# preserve the pointer to 
	mov	%ss, %cs:exit_pointer+2	# our launcher's stacktop

	mov	%cs, %ax		# address this segment
	mov	%ax, %ss		#   with SS register
	lea	tos0, %sp		# and set new stacktop

	call	prepare_for_our_demo
	call	enter_protected_mode 
	call	exec_timer_tick_demo
	call	leave_protected_mode 

	lss	%cs:exit_pointer, %sp	# recover our exit-address 
	lret				# exit to program launcher 
#-----------------------------------------------------------------
exit_pointer:	.word	0, 0		# to store exit-address 
#-----------------------------------------------------------------
# EQUATES 
	.equ	realCS, 0x1000		# segment-address of code 
	.equ	mswGDT, 0x0001		# base-address upper-word 
	.equ	limGDT, 0x0027		# allocates 5 descriptors 
	.equ	sel_es, 0x0008		# vram-segment selector 
	.equ	sel_cs, 0x0010		# code-segment selector 
	.equ	sel_ss, 0x0018		# data-segment selector 
	.equ	sel_bs, 0x0020		# bios-segment selector
#-----------------------------------------------------------------
	.align	8 		# quadword alignment is required
theGDT:	.word	0x0000, 0x0000, 0x0000, 0x0000	# null descriptor 
	.word	0x7FFF, 0x8000, 0x920B, 0x0000	# vram descriptor 
	.word	0xFFFF, 0x0000, 0x9A01, 0x0000	# code descriptor 
	.word	0xFFFF, 0x0000, 0x9201, 0x0000	# data descriptor 
	.word	0x0100, 0x0400, 0x9200, 0x0000	# bios descriptor 
#-----------------------------------------------------------------
theIDT:	.space	2048		# enough for 256 gate-descriptors
#-----------------------------------------------------------------
#-----------------------------------------------------------------
regGDT:	.word	0x0027, theGDT, 0x0001	# image for register GDTR
regIDT:	.word	0x07FF, theIDT, 0x0001	# image for register IDTR
regIVT:	.word	0x03FF, 0x0000, 0x0000	# image for register IDTR
#-----------------------------------------------------------------
prepare_for_our_demo:

	# initialize an interrupt-gate descriptor for INT-0x08

	mov	$0x08, %edi			# gate ID-number
	lea	theIDT(,%edi,8), %di		# offset-address
	movw	$isrPIT, %cs:0(%di)		# entry-loword
	movw	$sel_cs, %cs:2(%di) 		# code-selector
	movw	$0x8600, %cs:4(%di) 		# gate-type = 6
	movw	$0x0000, %cs:6(%di) 		# entry-hiword
	ret
#-----------------------------------------------------------------
enter_protected_mode: 

	cli				# no device interrupts 
	mov	%cr0, %eax 		# get machine status 
	bts	$0, %eax		# set PE-bit to 1 
	mov	%eax, %cr0 		# enable protection 

	lgdt	%cs:regGDT		# establish the GDT
	ljmp	$sel_cs, $pm		# reload register CS 
pm:	
	mov	$sel_ss, %ax 		# address this segment
	mov	%ax, %ss		#   with SS register		
	mov	%ax, %ds 		#   also DS register 

	ret				# back to main routine 
#-----------------------------------------------------------------
pic_mask_bits:	.word	0xFFFE		# mask-register settings
#-----------------------------------------------------------------
reprogram_interrupts:

	push	%ds			# preserve DS contents

	mov	$sel_ss, %ax 		# address this segment
	mov	%ax, %ds		#   with DS register

	in	$0x21, %al 		# read Master-PIC mask
	xchg	%al, %ah			
	in	$0xA1, %al 		# read Slave-PIC mask
	xchg	%al, %ah

	xchg	%ax, pic_mask_bits	# swap old w/new masks

	out	%al, $0x21 		# write Master-PIC mask
	xchg	%al, %ah
	out	%al, $0xA1 		# write Slave-PIC mask

	pop	%ds			# restore saved DS
	ret
#-----------------------------------------------------------------
#-----------------------------------------------------------------
# EQUATES for ROM-BIOS constants and address-offsets
	.equ	HOURS24, 0x180000	# number of ticks-per-day
	.equ	N_TICKS, 0x006C		# offset for tick-counter
	.equ	TM_OVFL, 0x0070		# offset of rollover-flag
	.equ	MOTOR_COUNT, 0x0040	# offset of motor-counter
	.equ	MOTOR_STAT,  0x003F	# offset for motor-status
#-----------------------------------------------------------------
exec_timer_tick_demo:
	
	mov	$sel_bs, %ax		# address rom-bios data
	mov	%ax, %ds 		#   using DS register
	mov	$sel_es, %ax		# address video memory
	mov	%ax, %es 		#   using ES register

	call	reprogram_interrupts	# mask all but timer-tick
	lidt	%cs:regIDT		#  and establish the IDT
	sti				# allow device interrupts

	mov	N_TICKS, %ebp 		# get current tick-count
	add	$182, %ebp 		#  increment by 10-secs
again:
	mov	N_TICKS, %eax		# get current tick-count 
	cmp	%ebp, %eax 		# test: timeout yet?
	jge	finis			# yes, exit this loop	

	mov	$10, %ebx 		# base of decimal system
	xor	%cx, %cx		# initialize digit-count 
nxdiv:	
	xor	%edx, %edx		# extend EAX to quadword
	div	%ebx			# divide by number-base
	push	%dx			# push remainder on stack
	inc	%cx			# and count the remainder
	or	%eax, %eax		# was the quotient zero?
	jnz	nxdiv			# no, do another divide

	mov	$156, %di 		# final screen-position
	sub	%cx, %di 		# back up for digits
	sub	%cx, %di 		# back up for colors
	mov	$0x3020, %ax 		# initial blank space
	stosw				#  written to screen
nxdgt:	
	pop	%ax			# recover saved remainder
	or	$0x3030, %ax 		# convert to numeral/color
	stosw				#  and write it to screen
	loop	nxdgt			# process all the digits
	mov	$0x3020, %ax		# final blank space
	stosw				# written to screen
	jmp	again			# reenter this loop

finis:
	cli				# discontinue interrupts
	call	reprogram_interrupts	# restore device-masks
	lidt	%cs:regIVT		# real-mode vector-table
	ret				# back to main routine
#-----------------------------------------------------------------
#-----------------------------------------------------------------
leave_protected_mode: 

	mov	%ss, %ax 		# address 64KB r/w segment 
	mov	%ax, %ds 		#   using DS register 
	mov	%ax, %es 		#    and ES register 

	mov	%cr0, %eax		# get machine status 
	btr	$0, %eax 		# reset PE-bit to 0 
	mov	%eax, %cr0 		# disable protection 

	ljmp 	$realCS, $rm 		# reload register CS 
rm:	mov	%cs, %ax 	
	mov	%ax, %ss 		# reload register SS 
	mov	%ax, %ds 		# reload register DS 
	sti				# interrupts allowed 
	ret				# back to main routine 
#-----------------------------------------------------------------
#=================================================================
isrPIT:	# Interrupt-Service Routine for the timer-tick interrupt

	push	%ax			# save working registers
	push	%dx
	push	%ds

	mov	$sel_bs, %ax 		# address rom-bios data
	mov	%ax, %ds 		#   using DS register

	incl	N_TICKS			# increment tick-count
	cmpl	$HOURS24, N_TICKS 	# past midnight?
	jl	isok1			# no, don't rollover yet
	movl	$0, N_TICKS 		# else reset count to 0
	movb	$1, TM_OVFL 		# and set rollover flag
isok1:
	decb	MOTOR_COUNT		# decrement motor-count
	jnz	isok2			# nonzero? motor stays on
	mov	$0x03F2, %dx 		# else turn off motors
	mov	$0x0C, %al		# command: turn off motors
	out	%al, %dx 		#  sent to disk-controller
	andb	$0xF0, MOTOR_STAT 	# mark the motors as 'off'
isok2:
	mov	$0x20, %al 		# non-specific EOI command
	out	%al, $0x20 		#  sent to the Master-PIC

	pop	%ds			# restore saved registers
	pop	%dx
	pop	%ax
	iret				# resume interrupted task
#=================================================================
#-----------------------------------------------------------------
	.align	16			# assure stack alignment  
	.space	512			# space for stack to use 
tos0:					# label for top-of-stack 
#-----------------------------------------------------------------
	.end				# no more to be assembled
