//-----------------------------------------------------------------
//	apictick.s
//
//	This program activates the Local APIC's timer-interrupt.
//
//	 to assemble: $ as apictick.s -o apictick.o 
//	 and to link: $ ld apictick.o -T ldscript -o apictick.b 
//
//	NOTE: This code begins executing with CS:IP = 1000:0002. 
//
//	programmer: ALLAN CRUSE
//	written on: 16 NOV 2006
//-----------------------------------------------------------------

	.code16				# for Pentium 'real-mode'
	.section	.text
#------------------------------------------------------------------
	.word	0xABCD			# programming signature 
#------------------------------------------------------------------
main:	mov	%sp, %cs:exit_pointer+0	# preserve loader's SP
	mov	%ss, %cs:exit_pointer+2	# preserve loader's SS

	mov	%cs, %ax		# address this segment 
	mov	%ax, %ds		#   with DS register  
	mov	%ax, %ss		#   also SS register 
	lea	tos, %sp		# and set new stacktop 

	call	clear_display_screen
	call	initialize_os_tables
	call	enter_protected_mode 
	call	execute_program_demo
	call	leave_protected_mode 

	lss	%cs:exit_pointer, %sp 	# recover loader's stack 
	lret				# and exit to the loader 
#------------------------------------------------------------------
exit_pointer:	.word	0, 0		# to store loader's SS:SP  
#------------------------------------------------------------------
	.align	8	# quadword alignment (to optimize access) 
theGDT:	.word	0x0000, 0x0000, 0x0000, 0x0000	# null descriptor 
	.equ	sel_es, (.-theGDT)+0
	.word	0x0007, 0x8000, 0x920B, 0x0080	# vram descriptor 
	.equ	sel_cs, (.-theGDT)+0
	.word	0xFFFF, 0x0000, 0x9A01, 0x0000	# code descriptor 
	.equ	sel_ss, (.-theGDT)+0
	.word	0xFFFF, 0x0000, 0x9201, 0x0000	# data descriptor 
	.equ	sel_fs, (.-theGDT)+0
	.word	0xFFFF, 0x0000, 0x9200, 0x008F	# flat descriptor 
	.equ	sel_CS, (.-theGDT)+0
	.word	0xFFFF, 0x0000, 0x9A01, 0x0040	# code descriptor 
	.equ	sel_SS, (.-theGDT)+0
	.word	0xFFFF, 0x0000, 0x9201, 0x0040	# data descriptor 
	.equ	gate32, (.-theGDT)+0
	.word	dodemo, sel_CS, 0x8C00, 0x0000	# 80386 call-gate
	.equ	limGDT, (.-theGDT)-1	# our GDT-segment's limit
#------------------------------------------------------------------
#------------------------------------------------------------------
theIDT:	.space	2048		# enough for 256 gate-descriptors
	.equ	limIDT, (.-theIDT)-1	# out IDT-segment's limit
#------------------------------------------------------------------
regGDT:	.word	limGDT, theGDT, 0x0001	# register-image for GDTR
regIDT:	.word	limIDT, theIDT, 0x0001	# register-image for IDTR
regIVT:	.word	0x03FF, 0x0000, 0x0000	# register-image for IDTR
#------------------------------------------------------------------
enter_protected_mode: 

	cli				# no device interrupts
	lgdt	regGDT			# load GDTR register-image 
	lidt	regIDT			# load IDTR register-image 
 
	mov	%cr0, %eax		# get machine status 
	bts	$0, %eax		# set PE-bit to 1 
	mov	%eax, %cr0		# enable protection 

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

	ljmp	$0x1000, $rm		# reload register CS 
rm:	
	mov	%cs, %ax	
	mov	%ax, %ss		# reload register SS 
	mov	%ax, %ds		# reload register DS 

	lidt	regIVT			# load IDTR register-image 
	sti				# interrupts allowed 

	ret				# back to main routine 
#------------------------------------------------------------------
#------------------------------------------------------------------
clear_display_screen:
	mov	$0x0003, %ax 		# set_mode: standard-text
	int	$0x10			# request VIDEO service
	ret
#------------------------------------------------------------------
initialize_os_tables:

	# initialize IDT descriptor for gate 0x28
	mov	$0x28, %ebx		# ID-number for the gate
	lea	theIDT(, %ebx, 8), %di	# address gate-descriptor
	movw	$isrTMR, 0(%di)		# entry-point loword
	movw	$sel_CS, 2(%di)		# selector for code
	movw	$0x8E00, 4(%di)		# 386 interrupt-gate
	movw	$0x0000, 6(%di)		# entry-point hiword

	# initialize IDT descriptor for gate 0x0D
	mov	$0x0D, %ebx		# ID-number for the gate
	lea	theIDT(, %ebx, 8), %di	# address gate-descriptor
	movw	$isrGPF, 0(%di)		# entry-point loword
	movw	$sel_CS, 2(%di)		# selector for code
	movw	$0x8E00, 4(%di)		# 386 interrupt-gate
	movw	$0x0000, 6(%di)		# entry-point hiword
	ret				# back to main routine
#------------------------------------------------------------------
execute_program_demo:

	# save the caller's stack-address (so we can return later)
	mov	%esp, tossave+0
	mov	%ss,  tossave+4

	# switch to 32-bit stack (must be 32-bit aligned) 
	mov	$sel_SS, %ax
	mov	%ax, %ss
	and	$0xFFFC, %esp

	# transfer through call-gate to 32-bit code-segment 
	lcall	$gate32, $0

	# load the previous stack-address and return to caller
	lss	%cs:tossave, %esp
	ret
#------------------------------------------------------------------
tossave: 	.long	0, 0		# for saving SS and ESP
#------------------------------------------------------------------
#== Executing 32-bit code simplifies addressing the APIC registers
#------------------------------------------------------------------
	.code32				# for addressing the APIC
#------------------------------------------------------------------
dodemo:	call	modify_the_pic_masks	
	call	start_the_apic_timer
	call	initiate_timed_delay
	call	stop_apic_timer_tick
	call	modify_the_pic_masks	
	lret
#------------------------------------------------------------------
#------------------------------------------------------------------
mask1:	.byte	0xFF
mask2:	.byte	0xFF
#------------------------------------------------------------------
modify_the_pic_masks:

	in	$0xA1, %al		# read slave PIC masks
	xchg	%al, mask2		# exchange with storage
	out	%al, $0xA1		# install revised masks

	in	$0x21, %al		# read master PIC masks
	xchg	%al, mask1		# exchange with storage
	out	%al, $0x21		# install revised masks
	ret
#------------------------------------------------------------------
start_the_apic_timer:
	
	mov	$sel_fs, %ax		# address 4GB memory
	mov	%ax, %fs		#  with FS register

	xor	%eax, %eax
	mov	%eax, %fs:(0xFEE003E0)	# Timer: Divisor Config

	mov	$10000, %eax		# countdown from 10000
	mov	%eax, %fs:(0xFEE00380)	# Timer: Initial Count

	mov	$0x28, %eax		# Timer: interrupt-ID
	bts	$17, %eax		# do periodic interrupt 
	mov	%eax, %fs:(0xFEE00320)	# set APIC Timer's LVT 
	ret	
#------------------------------------------------------------------
clkhz:	.long	1193182			# channel2 input-frequency 
outhz:	.long	100			# channel2 output-frequency
#------------------------------------------------------------------
initiate_timed_delay:

	in	$0x61, %al		# get PORT_B settings
	or	$0x01, %al		# enable PIT Channel2
	out	%al, $0x61		# output new settings

	mov	$0xB0, %al		# setup Channel2 Latch
	out	%al, $0x43		# for oneshot countdown
	mov	clkhz+0, %ax		# get frequency divisor
	mov	clkhz+2, %dx		#  for timed delay of
	divw	(outhz)			#   ten milliseconds
	out	%al, $0x42		# write divisor's LSB
	xchg	%ah, %al		# exchange LSB w/MSB
	out	%al, $0x42		# write divisor's MSB

	sti				# interrupts permitted
delay:	in	$0x61, %al		# read PORT_B settings
	test	$0x20, %al		# check: OUT2 active?
	jz	delay			# no, continue polling
	cli				# interrupts suspended
	ret
#------------------------------------------------------------------
#------------------------------------------------------------------
stop_apic_timer_tick:	
	
	mov	$sel_fs, %ax		# address 4GB memory
	mov	%ax, %fs		#  with FS register

	# disable the APIC timer's periodic-interrupt
	mov	$0x00010000, %eax	# set the mask bit
	mov	%eax, %fs:(0xFEE00320)	# in APIC timer's LVT

	ret
#------------------------------------------------------------------
window:	.long	640			# for next screen offset 
#------------------------------------------------------------------
isrTMR:	 # Our Interrupt Service Routine for the Local-APIC timer
	pushal				# must preserve registers
	push	%ds
	push	%es
	push	%fs

	mov	$sel_ss, %ax		# address this segment
	mov	%ax, %ds		#   with DS register
	mov	$sel_es, %ax		# address video memory
	mov	%ax, %es		#   with ES register
	mov	$sel_fs, %ax		# address 4GB memory
	mov	%ax, %fs		#  with FS register

	cld				# do forward processing
	mov	$0x4F54, %ax		# setup char and colors
	mov	window, %edi		# point ES:DI to window
	stosw				# draw char into window
	mov	%edi, window		# save window location
		
	mov	%eax, %fs:(0xFEE000B0)	# write to EOI register

	pop	%fs			# recover saved registers
	pop	%es
	pop	%ds
	popal
	iret				# resume suspended task
#------------------------------------------------------------------
#=== WE KEEP OUR GENERAL-PROTECTION FAULT-HANDLER FOR DEBUGGING ===
#------------------------------------------------------------------
eax2hex:  # converts value in EAX to hexadecimal string at DS:EDI
	pushal
	mov	$8, %ecx
.L2:	rol	$4, %eax
	mov	%al, %bl
	and	$0xF, %ebx
	mov	hex(%ebx), %dl
	mov	%dl, (%edi)
	inc	%edi
	loop	.L2
	popal
	ret
#------------------------------------------------------------------
#------------------------------------------------------------------
names:	.ascii	"  SS  GS  FS  ES  DS"
	.ascii	" EDI ESI EBP ESP EBX EDX ECX EAX"
	.ascii	" err EIP  CS EFL"
	.equ	NELTS, (.-names)/4
hex:	.ascii	"0123456789ABCDEF"
buf:	.ascii	" nnn=xxxxxxxx "
len:	.long	. - buf
att:	.byte	0x70
#------------------------------------------------------------------
isrGPF:  # This fault-handler shows register-values for debugging
	pushal
	pushl	$0
	mov	%ds, (%esp)
	pushl	$0
	mov	%es, (%esp)
	pushl	$0
	mov	%fs, (%esp)
	pushl	$0
	mov	%gs, (%esp)
	pushl	$0
	mov	%ss, (%esp)
	enter	$0, $0

	mov	$sel_es, %ax
	mov	%ax, %es
	mov	$sel_SS, %ax
	mov	%ax, %ds

	xor	%ebx, %ebx
.L0:	# store item-name in output-buffer
	mov	names(, %ebx, 4), %eax
	mov	%eax, buf
	# format item-value in output-buffer
	mov	4(%ebp, %ebx, 4), %eax
	lea	buf+5, %edi
	call	eax2hex
	# compute item's screen-offset in EDI	
	mov	$3800, %edi
	imul	$160, %ebx, %eax
	sub	%eax, %edi
	# draw the label item on the screen
	lea	buf, %esi
	mov	len, %ecx
	mov	att, %ah
	cld
.L1:	lodsb
	stosw
	loop	.L1

	inc	%ebx
	cmp	$NELTS, %ebx
	jb	.L0

freeze: jmp	freeze
#------------------------------------------------------------------
#------------------------------------------------------------------
	.align	16			# assure stack alignment  
	.space	512			# reserved for stack use 
tos:					# label fop top-of-stack 
#------------------------------------------------------------------
	.end
