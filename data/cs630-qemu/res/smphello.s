//----------------------------------------------------------------
//	smphello.s
//
//	This program employs Intel's MP Initialization Protocol
//	to awaken any auxilliary processors that may be present
//	and allows each processor to display its APIC Local-ID.
//
//	  assemble: $ as smphello.s -o smphello.o
//	  and link: $ ld smphello.o -T ldscript -o smphello.b
//
//	NOTE: This code begins executing with CS:IP = 1000:0002.
//
//	programmer: ALLAN CRUSE
//	written on: 06 MAY 2004
//	revised on: 18 APR 2006 -- for GNU assembler and linker
//	revised on: 21 NOV 2006 -- to follow cs630 coding style
//----------------------------------------------------------------

	# manifest constants
	.equ	STACKSZ, 512
	.equ	realCS, 0x1000

	
	.code16				# for Pentium 'real-mode'
	.section	.text
#-----------------------------------------------------------------
	.word	0xABCD			# our 'load' signature
#-----------------------------------------------------------------
main:	mov	%sp, %cs:exit_pointer+0	# preserve loader's SP
	mov	%ss, %cs:exit_pointer+2	# preserve loader's SS

	mov	%cs, %ax		# address this segment
	mov	%ax, %ds		#   with DS register
	mov	%ax, %es		#   also ES register
	mov	%ax, %ss		#   also SS register
	lea	tos, %esp		# and set up new stack

	call	setup_timer_channel2
	call	allow_4GB_addressing
	call	display_APIC_LocalID
	call	broadcast_AP_startup
	call	delay_until_APs_halt

	lss	%cs:exit_pointer, %sp	# restore loader's SS:SP
	lret				# and exit to the loader
#------------------------------------------------------------------
exit_pointer:	.word	0, 0		# for loader's SS and SP 
#------------------------------------------------------------------
	.align	8	# quadword alignment (for optimal access)
theGDT:	.word	0x0000, 0x0000, 0x0000, 0x0000	# null descriptor	
	.equ	sel_FS, (.-theGDT)+0	# flat-segment's selector
	.word	0xFFFF, 0x0000, 0x9200, 0x008F	# flat descriptor
	.equ	limGDT, (.-theGDT)-1	# our GDT-segment's limit
#-----------------------------------------------------------------
regGDT:	.word	limGDT, theGDT, 0x0001	# image for GDTR register
#-----------------------------------------------------------------
#-----------------------------------------------------------------
setup_timer_channel2:
#
# This procedure initializes the 8254 Programmable Timer/Counter
# so Timer Channel 2 can be used in 'one-shot' timing durations.
#
	# enable the 8254 Channel-2 counter
	in	$0x61, %al		# get PORT_B settings
	and	$0xFD, %al		# turn PC speaker off
	or	$0x01, %al		# turn on Gate2 input
	out	%al, $0x61		# output new settings

	# program channel-2 for one-shot countdown
	mov	$0xB0, %al		# chn2, r/w LSB/MSB
	out	%al, $0x43		# issue PIT command
	ret
#-----------------------------------------------------------------
delay_EAX_micro_secs:
#
# This procedure creates a programmed delay for EAX microseconds.
#
	pushal

	mov	%eax, %ecx		# number of microseconds
	mov	$100000, %eax		# microseconds-per-second
	xor	%edx, %edx		# is extended to quadword
	div	%ecx			# division by double-word
	
	mov	%eax, %ecx		# input-frequency divisor
	mov	$1193182, %eax		# timer's input-frequency
	xor	%edx, %edx		# is extended to quadword
	div	%ecx			# division by double-word

	out	%al, $0x42		# transfer to Latch LSB
	xchg	%al, %ah		# LSB swapped with MSB
	out	%al, $0x42		# transfer to Latch MSB

.T0:	in	$0x61, %al		# check PORT_B settings
	test	$0x20, %al		# has counter2 expired?
	jz	.T0			# no, continue polling
	
	popal
	ret
#-----------------------------------------------------------------
msg:	.ascii	"Hello from processor "	# message from processor
pid:	.ascii	"   "			# buffer for CPU LocalID
	.ascii	"CR0="			# legend for CR0 display
msw:	.ascii	"xxxxxxxx \n\r"		# buffer for CR0 content
len:	.int	. - msg			# length of message text
att:	.byte	0x0B			# display attribute byte
#-----------------------------------------------------------------
mutex:	.word	1			# mutual exclusion flag
n_cpu:	.word	0			# count of awakened APs
n_fin:	.word	0			# count of finished APs
newSS:	.word	0x2000			# stack segment-address
#-----------------------------------------------------------------
#-----------------------------------------------------------------
display_APIC_LocalID:
#
# This procedure is called by each processor in turn in order to
# allow it to read its processor-identification number (from its 
# private Local-APIC) and display that number using the ROM-BIOS 
# video services.  Because ROM-BIOS routines are not 'reentrant'
# it is necessary to employ a 'spinlock' to insure that only one
# processor at a time will be executing these ROM-BIOS services. 
#
	# read the Local-APIC ID-register
	push	%ds
	xor	%ax, %ax
	mov	%ax, %ds
	mov	$0xFEE00020, %ebx
	mov	(%ebx), %eax
	pop	%ds

	# acquire the spinlock -- allow only one CPU at a time
spin:	bt	$0, mutex
	jnc	spin
	lock	
	btr	$0, mutex
	jnc	spin

	# write CPU Local-APIC ID-number into shared buffer
	rol	$8, %eax		# get ID-number in AL
	and	$0xF, %al		# isolate lowest nybble
	or	$'0', %al		# convert to numeral	
	movb	%al, pid		# write to shared buffer	

	# format the contents of register CR0 for display
	lea	msw, %di
	mov	%cr0, %eax
	call	eax2hex
	
	# display the information using ROM-BIOS routines
	mov	$0x0F, %ah		# get display-page
	int	$0x10			# call video bios

	mov	$0x03, %ah		# get cursor position
	int	$0x10			# call video bios

	mov	$0x1301, %ax		# write_string
	lea	msg, %bp		# point ES:BP to string
	mov	len, %cx		# number of characters
	mov	att, %bl		# display attributes
	mov	$0x1301, %ax		# write_string
	int	$0x10			# call video bios 

	# release spinlock -- finished with 'non-reentrant' code
	lock 	
	bts 	$0, mutex

	ret
#-----------------------------------------------------------------
#-----------------------------------------------------------------
eax2hex:  # converts value in EAX to hexadecimal string at DS:DI
	pusha	

	mov	$8, %cx
nxnyb:
	rol	$4, %eax
	mov	%al, %bl
	and	$0xF, %bx
	mov	hex(%bx), %dl
	mov	%dl, (%di)
	inc	%di
	loop	nxnyb	

	popa
	ret
#-----------------------------------------------------------------
hex:	.ascii	"0123456789ABCDEF"	# array of hex numerals
#-----------------------------------------------------------------
allow_4GB_addressing:
#
# This procedure will be called by each processor in order to 
# raise the 'hidden' segment-limit in its DS segment-register
# which permits Local-APIC registers to be addressed with DS.   
#
	pushf				# preserve FLAGS settings
	push	%ds			# preserve DS contents

	cli				# no device interrupts

	mov	%cr0, %eax		# get machine status
	bts	$0, %eax		# set PE-bit to 1
	mov	%eax, %cr0		# enter protected mode
	
	lgdt	regGDT			# load GDTR register-image
	mov	$sel_FS, %ax		# address 4GB data-segment
	mov	%ax, %ds		#   with the DS register

	mov	%cr0, %eax		# get machine status
	btr	$0, %eax		# reset PE-bit to 0
	mov	%eax, %cr0		# leave protected mode
		
	pop	%ds			# restore register DS
	popf				# restore FLAGS value
	ret				
#-----------------------------------------------------------------
delay_until_APs_halt:
#
# This procedure is called by the main CPU so that it will not
# terminate our program until the other CPUs have been halted.
#
.W0:	mov	n_cpu, %ax		# number of APs awoken
	sub	n_fin, %ax		# less number finished
	jnz	.W0			# spin unless all done
	ret
#-----------------------------------------------------------------
#-----------------------------------------------------------------
broadcast_AP_startup:
#
# This procedure is called by the main CPU to awaken other CPUs.
#
	push	%ebx
	push	%ds

	# address the Local-APIC registers' page
	xor	%ax, %ax
	mov	%ax, %ds
	mov	$0xFEE00000, %ebx

	# issue an 'INIT' Inter-Processor Interrupt command
	mov	$0x000C4500, %eax	# broadcase INIT-IPI
	mov	%eax, 0x300(%ebx)	# to all-except-self
.B0:	bt	$12, 0x300(%ebx)	# command in progress?
	jc	.B0			# yes, spin till done

	# do ten-millisecond delay, allow time for APs to awaken
	mov	$10000, %eax		# number of microseconds
	call	delay_EAX_micro_secs	# for a programmed delay
	
	# finish the Intel 'MP Initialization Protocol'
	mov	$2, %ecx		# issue 'Startup' twice
nxIPI:	mov	$0x000C4611, %eax	# broadcast Startup-IPI
	mov	%eax, 0x300(%ebx)	# to all-except-self
.B1:	bt	$12, 0x300(%ebx)	# command in progress?
	jc	.B1			# yes, spin till done

	# delay for 200 microseconds	
	mov	$200, %eax		# number of microseconds
	call	delay_EAX_micro_secs	# for a programmed delay
	loop	nxIPI	
		
	pop	%ds
	pop	%ebx
	ret
#-----------------------------------------------------------------
#=================================================================
#==  HERE IS THE CODE THAT EACH APPLICATION PROCESSOR EXECUTES  ==
#=================================================================
#-----------------------------------------------------------------
initAP:	cli
	mov	%cs, %ax		# address program's data
	mov	%ax, %ds		#    with DS register
	mov	%ax, %es		#    also ES register
	
	lock				# insure 'atomic' update
	incw	n_cpu			# increment count of APs

	# setup an exclusive stack-area for this processor
	mov	$0x1000, %ax		# paragraphs in segment
	xadd	%ax, newSS		# 'atomic' xchg-and-add
	mov	%ax, %ss		# segment-address in SS
	xor	%esp, %esp		# top-of-stack into ESP

	call	allow_4GB_addressing	# adjust DS's seg-limit
	call	display_APIC_LocalID	# display this CPU's ID

	# put this processor to sleep
	lock				# insure 'atomic' update
	incw	n_fin			# increment count of APs

freeze:	cli				# do not awaken this CPU
	hlt				# 'fetch-execute' ceases	
	jmp	freeze			# just-in-case of an NMI
#-----------------------------------------------------------------
#=================================================================
#==  APPLICATION PROCESSORS BEGIN EXECUTING AT A PAGE-BOUNDARY  ==
#=================================================================
#-----------------------------------------------------------------
	.org	4096			# alignment at next page
tos:	ljmp	$realCS, $initAP	# initialize awakened AP
#-----------------------------------------------------------------
	.end

