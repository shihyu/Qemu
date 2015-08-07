//-----------------------------------------------------------------
//	cpuslice.s
//
//	This program uses the APIC Timer's periodic interrupt to
//	implement processor timesharing among its several tasks.
//
//	 to assemble: $ as cpuslice.s -o cpuslice.o
//	 and to link: $ ld cpuslice.o -T ldscript -o cpuslice.b  
//
//	NOTE: This code begins executing with CS:IP = 1000:0002. 
//
//	programmer: ALLAN CRUSE
//	written on: 10 MAY 2004
//	revised on: 20 NOV 2006 -- to use GNU assembler's syntax
//-----------------------------------------------------------------

	.code16				# for Pentium 'real-mode'

	.section	.text
#------------------------------------------------------------------
	.word	0xABCD			# application 'signature' 
#------------------------------------------------------------------
main:	mov	%sp, %cs:exit_pointer+0	# preserve the loader's SP
	mov	%ss, %cs:exit_pointer+2	# preserve the loader's SS

	mov	%cs, %ax		# address this segment 
	mov	%ax, %ds		#   with DS register  
	mov	%ax, %ss 		#   also SS register 
	lea	tos, %sp		# and set new stacktop 

	call	initialize_os_tables 
	call	prepare_task_structs
	call	clear_display_screen
	call	xchg_interrupt_masks
	call	enter_protected_mode 
	call	init_APIC_interrupts
	call	execute_program_demo 
	call	stop_APIC_interrupts
	call	leave_protected_mode 
	call	xchg_interrupt_masks

	lss	%cs:exit_pointer, %sp	# recover loader's SS:SP 
	lret				# exit to program loader 
#------------------------------------------------------------------
exit_pointer: 	.word	0, 0		# to store loader's SS:SP 
#------------------------------------------------------------------
clear_display_screen:
	mov	$0x0003, %ax		# set standard text mode
	int	$0x10			# request BIOS service
	ret
#------------------------------------------------------------------
#------------------------------------------------------------------
	.align	8	# quadword alignment (for optimal access) 
theGDT:	.word	0x0000, 0x0000, 0x0000, 0x0000	# null descriptor 
	.equ	sel_es, (. - theGDT)+0	# vram segment-selector 
	.word	0x7FFF, 0x8000, 0x920B, 0x0000	# vram descriptor 
	.equ	sel_cs, (. - theGDT)+0	# code segment-selector 
	.word	0xFFFF, 0x0000, 0x9A01, 0x0000	# code descriptor 
	.equ	sel_ds, (. - theGDT)+0	# data segment-selector 
	.word	0xFFFF, 0x0000, 0x9201, 0x0000	# data descriptor 
	.equ	sel_ss, (. - theGDT)+0	# stak segment-selector 
	.word	0xFFFF, 0x0000, 0x9202, 0x0000	# stak descriptor 
	.equ	sel_fs, (. - theGDT)+0	# flat segment-selector 
	.word	0xFFFF, 0x0000, 0x9200, 0x008F	# flat descriptor 
	.equ	sel_as, (. - theGDT)+0	# apic segment-selector 
	.word	0x0000, 0x0000, 0x92E0, 0xFE80	# apic descriptor 
	.equ	sel_t0, (. - theGDT)+0	# task segment-selector 
	.word	0x0067, myTSS0, 0x8901, 0x0000	# task descriptor 
	.equ	sel_t1, (. - theGDT)+0	# task segment-selector 
	.word	0x0067, myTSS1, 0x8901, 0x0000	# task descriptor 
	.equ	sel_t2, (. - theGDT)+0	# task segment-selector 
	.word	0x0067, myTSS2, 0x8901, 0x0000	# task descriptor 
	.equ	sel_t3, (. - theGDT)+0	# task segment-selector 
	.word	0x0067, myTSS3, 0x8901, 0x0000	# task descriptor 
	.equ	sel_t4, (. - theGDT)+0	# task segment-selector 
	.word	0x0067, myTSS4, 0x8901, 0x0000	# task descriptor 
	.equ	sel_t5, (. - theGDT)+0	# task segment-selector 
	.word	0x0067, myTSS5, 0x8901, 0x0000	# task descriptor 
	.equ	sel_t6, (. - theGDT)+0	# task segment-selector 
	.word	0x0067, myTSS6, 0x8901, 0x0000	# task descriptor 
	.equ	sel_t7, (. - theGDT)+0	# task segment-selector 
	.word	0x0067, myTSS7, 0x8901, 0x0000	# task descriptor 
	.equ	sel_t8, (. - theGDT)+0	# task segment-selector 
	.word	0x0067, myTSS8, 0x8901, 0x0000	# task descriptor 
	.equ	limGDT, (.-theGDT)-1	# our GDT-segment's limit
#------------------------------------------------------------------
theIDT:	.space	2048		# enough for 256 gate-descriptors 
	.equ	limIDT, (.-theIDT)-1	# our IDT-segment's limit
#------------------------------------------------------------------
regGDT:	.word	limGDT, theGDT, 0x0001	# register-image for GDTR
regIDT:	.word	limIDT, theIDT, 0x0001	# register-image for IDTR
regIVT:	.word	0x07FF, 0x0000, 0x0000	# register-image for IDTR
#------------------------------------------------------------------
mask1:	.BYTE	0xFD			# mask for the master PIC
mask2:	.BYTE	0xFF			# mask for the slave PIC
#------------------------------------------------------------------
xchg_interrupt_masks:

	in	$0xA1, %al		# slave PIC mask bits
	xchg	mask2, %al		# swapped with storage
	out	%al, $0xA1		# setup revised masks

	in	$0x21, %al		# master PIC mask bits
	xchg	mask1, %al		# swapped with storage
	out	%al, $0x21		# setup revised masks
	
	ret
#------------------------------------------------------------------
#------------------------------------------------------------------
enter_protected_mode: 

	cli				# no device interrupts 

	mov	%cr0, %eax		# get machine status 
	bts	$0, %eax		# set PE-bit to 1 
	mov	%eax, %cr0		# enable protection 

	lgdt	regGDT			# load GDTR register-image 
	lidt	regIDT 			# load IDTR register-image 

	ljmp	$sel_cs, $pm		# reload register CS 
pm:	
	mov	$sel_ds, %ax		
	mov	%ax, %ss		# reload register SS 
	mov	%ax, %ds		# reload register DS 

	xor	%ax, %ax		# use "null" selector 
	mov	%ax, %es		# to purge invalid ES 
	mov	%ax, %fs		# to purge invalid FS 
	mov	%ax, %gs		# to purge invalid GS 

	ret				# back to main routine 
#------------------------------------------------------------------
leave_protected_mode: 

	mov	$sel_fs, %ax 		# address 4GB r/w segment 
	mov	%ax, %fs		#   using FS register 
	mov	%ax, %gs		#    and GS register 

	mov	$sel_ds, %ax 		# address 64K r/w segment 
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

	lidt	regIVT			# restore vector table
	sti				# interrupts allowed 

	ret				# back to main routine 
#------------------------------------------------------------------
#------------------------------------------------------------------
initialize_os_tables: 

	# initialize IDT descriptor for gate 0x40 
	mov	$0x40, %ebx		# ID-number for the gate 
	lea	theIDT(, %ebx, 8), %di	# gate's offset-address 
	movw	$isrTMR, 0(%di)		# entry-point's loword 
	movw	$sel_cs, 2(%di)		# code-segment selector 
	movw	$0x8E00, 4(%di)		# 386 interrupt-gate 
	movw	$0x0000, 6(%di)		# entry-point's hiword 

	# initialize IDT descriptor for gate 0x0D 
	mov	$0x0D, %ebx		# ID-number for the gate 
	lea	theIDT(, %ebx, 8), %di	# gate's offset-address 
	movw	$isrGPF, 0(%di)		# entry-point's loword 
	movw	$sel_cs, 2(%di)		# code-segment selector 
	movw	$0x8E00, 4(%di)		# 386 interrupt-gate 
	movw	$0x0000, 6(%di)		# entry-point's hiword 

	# initialize IDT descriptor for gate 0x09 
	mov	$0x09, %ebx		# ID-number for the gate 
	lea	theIDT(, %ebx, 8), %di	# gate's offset-address 
	movw	$isrKBD, 0(%di)		# entry-point's loword 
	movw	$sel_cs, 2(%di)		# code-segment selector 
	movw	$0x8E00, 4(%di)		# 386 interrupt-gate 
	movw	$0x0000, 6(%di)		# entry-point's hiword 

	ret				# back to main routine 
#------------------------------------------------------------------
prepare_task_structs:

	# create non-overlapping stack-areas for all the tasks
	mov	$0x0000, %ebx		# offset for stack areas

	# initialize the TSS for each of the auxiliary tasks
	lea	myTSS0, %di		# point to the TSS array
	mov	$8, %cx			# number of other tasks
nxtss:
	add	$0x68, %di		# point to the next TSS	
	add	$0x1000, %ebx		# next stacktop address
	movl	$thread, 0x20(%di) 	# image for register EIP 
	movl	$0x0200, 0x24(%di)	# image for register EFLAGS 
	movl	%ebx, 0x38(%di)		# image for register ESP 
	movl	$sel_es, 0x48(%di)	# image for register ES
	movl	$sel_cs, 0x4C(%di) 	# image for register CS
	movl	$sel_ss, 0x50(%di)	# image for register SS
	movl	$sel_ds, 0x54(%di) 	# image for register DS
	movl	$0, 0x58(%di)		# image for register FS
	movl	$0, 0x5F(%di) 		# image for register GS
	movl	$0, 0x60(%di)	 	# image for register LDTR
	loop	nxtss

	ret
#------------------------------------------------------------------
tossave: .word	0, 0, 0 		# stores 48-bit pointer 
#------------------------------------------------------------------
#------------------------------------------------------------------
execute_program_demo: 

	# save stack-address (so our fault-handler can exit)
	mov	%esp, tossave+0		# preserve 32-bit offset   
	mov	%ss,  tossave+4		#  plus 16-bit selector   

	# establish this task's save-area 
	mov	$sel_t0, %ax		# address task segment
	ltr	%ax			#   with TR register

	# begin the "round-robin" multitasking
	ljmp	*(taskptr)		# transfer to first task

	# here is where execution resumes on reentering this task
	ret				# return to main routine
#------------------------------------------------------------------
finish_up_main_thread: 
	mov	$sel_ds, %ax 		# address this segment 
	mov	%ax, %ds		#   with DS register
	lss	tossave, %esp 		# to reload SS and ESP 
	ret				# back to main routine 
#------------------------------------------------------------------
init_APIC_interrupts:
	# program the Local-APIC Timer for periodic interrupts
	push	%ds
	mov	$sel_as, %ax		# address APIC segment
	mov	%ax, %ds		#   with DS register
	mov	$0x00020040, %eax	# periodic int-0x40
	mov	%eax, (0x0320)		# in APIC Timer LVT
	mov	$0x00000000, %eax	# program zero value
	mov	%eax, (0x03E0)		# into Divisor Config
	mov	$0x01000000, %eax	# 2**24 (16 million)
	mov	%eax, (0x0380)		# APIC Initial Count
	pop	%ds
	ret
#------------------------------------------------------------------
stop_APIC_interrupts:
	# mask the Local-APIC Timer's periodic interrupts
	push	%ds
	mov	$sel_as, %ax		# address APIC segment
	mov	%ax, %ds		#   with DS register
	mov	$0x00010040, %eax	# mask interrupt 0x40
	mov	%eax, (0x0320)		# APIC Timer LVT
	mov	$0x00000000, %eax	# program zero value
	mov	%eax, (0x0380)		# APIC Initial Count
	pop	%ds
	ret
#------------------------------------------------------------------
hex:	.ascii	"0123456789ABCDEF"
elt:	.ascii	"  TR  SS  GS  FS  ES  DS"	# field labels 
	.ascii	" EDI ESI EBP ESP EBX EDX ECX EAX" 
	.ascii	" err EIP  CS EFL" 
#------------------------------------------------------------------
buf:	.ascii	" nnn=xxxxxxxx " 
len:	.word	. - buf			# length of output buffer 
att:	.byte	0x70			# reverse-video attribute 
#------------------------------------------------------------------
#------------------------------------------------------------------
draw_stack: 
	push	%ds 			# preserve registers
	push	%es 

	mov	$sel_ds, %ax 		# address this segment 
	mov	%ax, %ds		#   with DS register    
	mov	$sel_es, %ax 		# address vram segment 
	mov	%ax, %es		#   with ES register    

	cld 				# do forward processing
	xor	%ebx, %ebx 		# start element counter
nxelt: 
	mov	(%ebp,%ebx,4), %eax	# get next stack-element 
	lea	buf+5, %edi 		# point to output-field 
	call	eax2hex 		# convert to hexadecimal

	mov	elt(, %ebx, 4), %eax 	# get next element-label 
	mov	%eax, buf		# put next element-label 

	mov	$3970, %edi		# bottom line destination 
	imul	$160, %ebx, %eax	# line-count times length
	sub	%eax, %edi 		# subtracted from bottom
	lea	buf, %esi 		# point to message buffer
	mov	att, %ah 		# setup character colors
	mov	len, %ecx 		# setup buffer length
.L1:	lodsb 				# fetch next character
	stosw 				# store char and color
	loop	.L1 			# again for other chars

	inc	%ebx 			# increment element count
	cmp	$18, %ebx 		# all elements displayed?
	jb	nxelt 			# no, show another element

	pop	%es 			# restore registers
	pop	%ds 
	ret 
#------------------------------------------------------------------
eax2hex: 
	# converts EAX to hexadecimal digit-string at DS:EDI
	pushal
	mov	$8, %ecx		# setup digit counter
 .L0:
	rol	$4, %eax		# next nybble into AL
	mov	%al, %bl		# copy nybble into BL
	and	$0xF, %ebx		# isolate nybble bits
	mov	hex(%ebx), %dl		# look up hex numeral
	mov	%dl, (%edi)		# put digit in buffer
	inc	%edi			# advance buffer index
	loop	.L0			# again for next nybble
	popal 

	ret 
#------------------------------------------------------------------
#------------------------------------------------------------------
isrGPF:	# our fault-handler for General Protection Exceptions 

	pushal				# preserve registers 
	pushl	$0 
	mov	%ds, (%esp) 		# store DS
	pushl	$0 
	mov	%es, (%esp) 		# store ES
	pushl	$0 
	mov	%fs, (%esp) 		# store FS
	pushl	$0 
	mov	%gs, (%esp) 		# store GS
	pushl	$0 
	mov	%ss, (%esp) 		# store SS
	pushl	$0
	strw	(%esp)			# store TR

	mov	%esp, %ebp 		# setup frame base 
	call	draw_stack 		# draw register values

	ljmp	$sel_cs, $finish_up_main_thread  # to exit routine 
#------------------------------------------------------------------
taskidx: .long	0	
taskptr: .word	0, sel_t1
tasklst: .word	sel_t1, sel_t2, sel_t3, sel_t4
	 .word	sel_t5, sel_t6, sel_t7, sel_t8
#------------------------------------------------------------------
isrTMR:	# interrupt-handler for APIC Timer's periodic interrupt
	pushal				# must preserve registers
	push	%ds
	
	# issue 'End-Of-Interrupt' command to Local-APIC
	mov	$sel_as, %ax		# address Local-APIC
	mov	%ax, %ds		#  with DS register
	mov	%eax, (0x00B0)		# issue EOI to APIC

	# increment revolving counter and 'schedule' next task  
	mov	$sel_ds, %ax		# address this segment
	mov	%ax, %ds		#   with DS register
	incl	(taskidx)		# increment taskidx
	andl	$0x7, (taskidx)		# get remainder mod 8
	mov	taskidx, %esi		# load new array-index
	mov	tasklst(,%esi,2), %ax	# copy next tss-selector
	mov	%ax, taskptr+2		#  into address pointer
	ljmp	*(taskptr)		# transfer to next task

	# upon return, check for termination-request
	cmpw	$0, (quit)		# user wants to quit?
	je	.OK			# no, resume the thread
	ljmp	$sel_t0, $0		# else back to task #0
.OK:
	pop	%ds			# restore registers
	popal
	iretl				# resume suspended task
#------------------------------------------------------------------
#------------------------------------------------------------------
quit:	.word	0			# flag, set for <ESC>-key
#------------------------------------------------------------------
isrKBD:	# interrupt-handler for keyboard-controller interrupts
	pushal
	push	%ds

	in	$0x64, %al		# get controller status
	test	$0x01, %al		# output buffer full?
	jz	ignore			# no, disregard data

	in	$0x60, %al		# else get new scancode
	cmp	$0x81, %al		# <ESC>-key released?
	jne	ignore			# no, then disregard

	mov	$sel_ds, %ax		# address this segment
	mov	%ax, %ds 		#   with DS register
	movw	$1, (quit)		# set the 'quit' flag

ignore:
	mov	$0x20, %al		# non-specific EOI 
	out	%al, $0x20		# sent to Master PIC

	pop	%ds
	popal
	iretl
#------------------------------------------------------------------
qw2hex:	# draws quadword in (EDX,EAX) as a hex-string at DS:EDI
	pushal

	push	%eax			# push lo doubleword
	push	%edx			# push hi doubleword

	mov	$2, %ebp		# number of doublewords
.Q0:	pop	%eax			# pop saved doubleword
	mov	$8, %ecx		# number of nybbles
.N0:	rol	$4, %eax		# next nybble to AL
	mov	%al, %bl		# copy nybble to NL
	and	$0x0F, %ebx 		# isolate nybble bits
	mov	%cs:hex(%ebx), %dl	# loop up hex numeral
	mov	%dl, (%edi)		# put digit in buffer
	inc	%edi			# advance buffer index
	loop	.N0			# again for more nybbles
	dec	%ebp			# decrement loop-count
	jnz	.Q0			# nonzero? do loop again

	popal
	ret
#------------------------------------------------------------------
thmsg:	.ascii	" Task #"
thbuf:	.ascii	" : xxxxxxxxxxxxxxxx "
thlen:	.long	. - thmsg
thatt:	.byte	0x70
#------------------------------------------------------------------
#------------------------------------------------------------------
thread:
	# allocate 80-byte data-buffer on task's private stack
	sub	$80, %esp 		# allocate buffer space
	mov	%esp, %ebp 		# setup base pointer

	# copy the message-template to this task's data-buffer
	xor	%edi, %edi 		# initialize the index	
	mov	thlen, %ecx		# length of message
.C0:	mov	thmsg(%edi), %al	# fetch next character
	mov	%al, (%ebp, %edi, 1)	# store this character
	inc	%edi			# increment the index
	loop	.C0			# again for other chars
	
	# compute this task's ID-number from its task-selector
	str	%ax			# get task's TSS-selector
	sub	$sel_t0, %ax		# minus Task #0 selector
	shr	$3, %ax 		# divide difference by 8
	movzx	%ax, %eax		# extend result to dword
	mov	%eax, 76(%ebp)		# and save for use below
	or	$'0', %al 		# convert to a numeral
	mov	$thbuf, %edi		# offset to the buffer
	sub	$thmsg, %edi		# less offset to message
	mov	%al, (%ebp, %edi, 1)	# put numeral in message
nxmsg:
	push	%ds			# preserve DS
	mov	%ss, %ax		# address stack segment
	mov	%ax, %ds		#   using DS register
	mov	$thbuf+3, %edi		# offset to output-field
	sub	$thmsg, %edi		# minus message's offset
	lea	(%ebp, %edi, 1), %edi	# point EDI to the field
	rdtsc				# read TimeStamp Counter
	call	qw2hex			# convert quadword to hex
	pop	%ds			# restore DS

	cld				# do forward processing
	imul	$160, 76(%ebp), %edi	# ID# times line-length 
	add	$1334, %edi		# plus indent (to center)
	xor	%esi, %esi		# initialize index
	mov	thatt, %ah		# setup attribute
	mov	thlen, %cx		# setup counter
.O1:	mov	(%ebp, %esi, 1), %al	# get message character
	inc	%esi			# and increment index
	stosw				# write char and color
	loop	.O1			# again for full message
	
	jmp	nxmsg			# draw TimeStamp again
#------------------------------------------------------------------
	.align	16			# assure stack alignment
	.space	512			# reserved for stack use 
tos:					# label fop top-of-stack 
#------------------------------------------------------------------
#------------------------------------------------------------------
myTSS0:	.zero	0x68			# Task-State Segment #0
myTSS1:	.zero	0x68			# Task-State Segment #1
myTSS2:	.zero	0x68			# Task-State Segment #2
myTSS3:	.zero	0x68			# Task-State Segment #3
myTSS4:	.zero	0x68			# Task-State Segment #4
myTSS5:	.zero	0x68			# Task-State Segment #5
myTSS6:	.zero	0x68			# Task-State Segment #6
myTSS7:	.zero	0x68			# Task-State Segment #7
myTSS8:	.zero	0x68			# Task-State Segment #8
#------------------------------------------------------------------
	.byte	0xFF			# to insure zero memory
#------------------------------------------------------------------
	.end				# no more to be assembled
