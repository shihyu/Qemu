//-----------------------------------------------------------------
//	reporter.s
//
//	This example reprograms the 8259-A Interrupt Controllers,
//	then shows a real-time display for any device-interrupts.
//
//	 to assemble: $ as reporter.s -o reporter.o 
//	 and to link: $ ld reporter.o -T ldscript -o reporter.b 
//
//	NOTE: This code begins executing with CS:IP = 1000:0002. 
//
//	programmer: ALLAN CRUSE
//	written on: 08 MAR 2004
//	revised on: 10 OCT 2006 -- to use GNU assembler's syntax
//	correction: 14 OCT 2008 -- fix 'find_the_counter_number'
//-----------------------------------------------------------------

	# equates for reprogramming the Interrupt Controllers
	.equ	INTAORG, 0x08		# default base for INTA
	.equ	INTBORG, 0x70		# default base for INTB
	.equ	IRQBASE, 0x90		# revised base for PICs


	.macro	isr id			
	pushf				# push FLAGS register
	push	$\id 			# push interrupt-ID
	call	action			# goto common handler
	.endm


	.code16				# for Pentium 'real-mode'
	.section	.text
#------------------------------------------------------------------
	.word	0xABCD			# programming signature 
#------------------------------------------------------------------
main:	mov	%sp, %cs:exit_pointer+0
	mov	%ss, %cs:exit_pointer+2

	mov	%cs, %ax
	mov	%ax, %ds
	mov	%ax, %es
	mov	%ax, %ss
	lea	tos, %sp	

	call	create_statusline
	call	setup_new_vectors
	call	program_both_PICs
	call	do_keyboard_input
	call	program_both_PICs
	call	remove_statusline

	lss	%cs:exit_pointer, %sp 	# recover our exit-address 
	lret				# exit to program launcher 
#------------------------------------------------------------------
exit_pointer: 	.word	0, 0 		# save loader's SS and SP 
#------------------------------------------------------------------
#------------------------------------------------------------------
legend: .ascii	"TICK KYBD CASC COM2 COM1 LPT2 ---- LPT1 "
 	.ascii	"CMOS ---- ---- ---- PS/2 MATH IDE0 ---- "
	.ascii	"   0    0    0    0    0    0    0    0 "
	.ascii	"   0    0    0    0    0    0    0    0 "
#------------------------------------------------------------------
create_statusline:

	# setup the video display for 28-lines of text

	mov	$0x0003, %ax 		# reset text display-mode
	int	$0x10			# request BIOS service

	mov	$0x1111, %ax 		# load 8x14 character-set
	mov	$0x00, %bl 		# in character-table zero
	int	$0x10			# request BIOS service

	# reduce the "active" number of display-lines to 25 

	push	%ds			# preserve DS register
	mov	$0x40, %ax 		# address ROM-BIOS data
	mov	%ax, %ds		#   using DS register
	movw	$24, 0x84		# set last display-line
	pop	%ds			# restore DS register

	# draw the display-legend and the initial count-values

	mov	$0xB800, %ax 		# address video memory 
	mov	%ax, %es		#   with ES register
	mov	$26, %ax 		# output's line-number 
	imul	$160, %ax, %di 		# offset for that line

	cld				# forward processing
	lea	legend, %si 		# point to text string
	mov	$0x07, %ah 		# load color attribute 
	mov	$160, %cx 		# number of characters
.L1:	
	lodsb				# fetch next character
	stosw				# store char and color
	loop	.L1			# again for more chars

	ret
#-----------------------------------------------------------------
remove_statusline:
	mov	$0x0003, %ax		# reset text display-mode
	int	$0x10			# request BIOS service
	ret
#-----------------------------------------------------------------
	.align	2			# insure 16-bit alignment
counter: .space  32, 0			# 16 counters (word-size)	
#-------------------------------------------------------------------
base1:	.byte	IRQBASE+0		# holds baseID of PIC #1	
base2:	.byte	IRQBASE+8		# holds baseID of PIC #2
mask1:	.byte	-1			# holds mask from PIC #1
mask2:	.byte	-1			# holds mask from PIC #2
#-----------------------------------------------------------------
#-----------------------------------------------------------------
program_both_PICs:

	# assure register DS can address our program variables

	mov	%cs, %ax 		# address this segment
	mov	%ax, %ds 		#   with DS register
	
	# mask all interrupt sources during PIC reprogramming 

	cli				# no device interrupts

	in	$0x21, %al 		# get mask for PIC #1
	xchg	%al, mask1		#  swap with memory
	out	%al, $0x21 		# set mask for PIC #1

	in	$0xA1, %al		# get mask for PIC #2
	xchg	%al, mask2		#  swap with memory 
	out	%al, $0xA1 		# set mask for PIC #2

	# reprogram the Master Interrupt Controller

	mov	$0x11, %al		# write ICW1
	out	%al, $0x20 		#  to PIC #1
	mov	base1, %al		# write ICW2
	out	%al, $0x21		#  to PIC #1
	mov	$0x04, %al		# write ICW3
	out	%al, $0x21		#  to PIC #1
	mov	$0x01, %al		# write ICW4
	out	%al, $0x21		#  to PIC #1

	# reprogram the Slave Interrupt Controller

	mov	$0x11, %al		# write ICW1
	out	%al, $0xA0 		#  to PIC #2
	mov	base2, %al		# write ICW2
	out	%al, $0xA1		#  to PIC #2
	mov	$0x02, %al		# write ICW3
	out	%al, $0xA1		#  to PIC #2
	mov	$0x01, %al		# write ICW4
	out	%al, $0xA1		#  to PIC #3

	# unmask the previously allowed interrupt sources

	in	$0x21, %al		# get mask for PIC #1
	xchg	%al, mask1		#  swap with memory 
	out	%al, $0x21 		# set mask for PIC #1
	
	in	$0xA1, %al		# get mask for PIC #2
	xchg	%al, mask2		#  swap with memory 
	out	%al, $0xA1		# set mask for PIC #2
	
	sti				# allow interrupts again

	ret
#-----------------------------------------------------------------
#-----------------------------------------------------------------
setup_new_vectors:
	push	%ds			# preserve registers
	push	%es

	xor	%ax, %ax		# address vector table
	mov	%ax, %es 		#   with ES register
	mov	$IRQBASE, %ax		# initial vector-number
	imul	$4, %ax, %di 		#  times vector-width
	cld				# do forward processing
	mov	%cs, %ax 		# code segment-address
	shl	$16, %eax 		#   is vector hiword
	lea	myisrs, %ax		# point to first isr 
	mov	$16, %cx 		# number of vectors 
.L3:	stosl				# store next vector
	add	$ISRLEN, %ax		# point to next isr
	loop	.L3			# store next vector

	pop	%es			# restore registers
	pop	%ds
	ret
#-----------------------------------------------------------------
do_keyboard_input:

	mov	$0, %bh 		# output display-page 
again:	mov	$1, %ah 		# peek_keyboard_input
	int	$0x16			# request BIOS service
	jz	again			# none? keep trying

	mov	$0, %ah 		# read_keyboard_input
	int	$0x16			# request BIOS service
	cmp	$0x011B, %ax 		# was it <ESCAPE>-key?
	je	finis			# yes, exit this loop

	cmp	$0x0D, %al 		# was it <RETURN>-key?
	jne	ahead			# no, output ascii

	push	%ax
	mov	$0x0E0A, %ax		# else output linefeed
	int	$0x10			# request BIOS service 
	pop	%ax
ahead:	mov	$0x0E, %ah 		# write_TTY function
	int	$0x10			# request BIOS service
	jmp	again
finis:
	mov	$0x0E0A, %ax		# output linefeed
	int	$0x10			# request BIOS service
	mov	$0x0E0D, %ax		# output carriage-return
	int	$0x10			# request BIOS service

	mov	$INTAORG, %al		# original ID for PIC #1
	mov	%al, base1		# use when reprogramming
	mov	$INTBORG, %al		# original ID for PIC #2
	mov	%al, base2 		# use when reprogramming
	ret
#-----------------------------------------------------------------
#-----------------------------------------------------------------
myisrs:	isr	0x08	
	isr	0x09
	isr	0x0A
	isr	0x0B
	isr	0x0C
	isr	0x0D
	isr	0x0E
	isr	0x0F
	isr	0x70
	isr	0x71
	isr	0x72
	isr	0x73
	isr	0x74
	isr	0x75
	isr	0x76
	isr	0x77
	.equ	ISRLEN, ( . - myisrs )/16
#-----------------------------------------------------------------
#-----------------------------------------------------------------
#=================================================================
#===  Common Interrupt Service Routine (and Helper-Functions)  ===
#=================================================================
#-----------------------------------------------------------------
#-----------------------------------------------------------------
action:	
	enter	$2, $0			# setup local stackframe 

	pusha				# must preserve registers				
	push	%ds
	push	%es

	call	find_the_counter_number
	call	increment_counter_value
	call	write_counter_to_screen
	call	setup_stack_to_transfer	

	pop	%es			# restore saved registers
	pop	%ds
	popa

	leave				# discard our stackframe
	iret				# resume interrupted task
#-----------------------------------------------------------------
find_the_counter_number:

	# convert interrupt-ID in ranges 0x08-0x0F or 0x70-0x77
	# to a counter-number in ranges 0x00-0x07 or 0x08-0x0F,
	# respectively.  Source from 4(%bp), result to -2(%bp).

	mov	4(%bp), %ax 		# get interrupt-number
	add	$0x08, %ax		# add 8 to bottom nybble
	and	$0x0F, %ax		# isolate nybble's bits
	mov	%ax, -2(%bp)		# save counter-number
	ret
#-----------------------------------------------------------------
#-----------------------------------------------------------------
increment_counter_value:

	mov	%cs, %ax 		# address this segment
	mov	%ax, %ds 		#   with DS register
	imul	$2, -2(%bp), %bx	# offset to the counter
	incw	counter(%bx)		# update counter value
	ret
#-----------------------------------------------------------------
write_counter_to_screen:

	# setup ES:DI to point to this device's counter-field

	mov	$0xB800, %ax 		# address video memory
	mov	%ax, %es 		#   with ES register
	mov	$27, %ax 		# output's line-number 
	imul	$160, %ax, %di 		# offset to the line
	imul	$10, -2(%bp), %ax 	# indent for counter 
	add	%ax, %di 		# offset on screen
	add	$6, %di 		# last digit position

	# draw this device's count-value as a decimal string

	mov	counter(%bx), %ax	# get the counter-value
	mov	$10, %bx 		# setup decimal radix
	mov	$3, %cx 		# maximum digit-count
.L2:	xor	%dx, %dx		# extend AX for divide
	div	%bx			# divide by the radix
	or	$0x0730, %dx		# remainder into ascii
	mov	%dx, %es:(%di) 		# write char and color
	sub	$2, %di 		# update screen pointer
	or	%ax, %ax		# quotient was zero?
	loopnz	.L2			# no, show next digit

	ret
#-----------------------------------------------------------------
setup_stack_to_transfer:

	# prepare stack for a transfer to the device's ISR 

	xor	%ax, %ax		# address vector table
	mov	%ax, %ds 		#   with DS register
	mov	4(%bp), %ax 		# get vector ID-number	
	imul	$4, %ax, %si 		# get vector's offset
	mov	0(%si), %ax 		# fetch vector loword
	mov	%ax, 2(%bp)		# store vector loword
	mov	2(%si), %ax		# fetch vector hiword
	mov	%ax, 4(%bp)		# store vector hiword
	ret
#-----------------------------------------------------------------
	.align	16			# assure stack alignment 
	.space	512			# reserved for stack use 
tos:					# label fop top-of-stack 
#-----------------------------------------------------------------
	.end				# no more to be assembled
