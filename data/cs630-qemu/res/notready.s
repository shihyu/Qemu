//-----------------------------------------------------------------
//	notready.s
//
//	This program illustrates use of the 'Segment-Not-Present'
//	processor exception, by attempting to call a procedure in
//	a code-segment whose 'Present' bit was not yet set.  Then
//	our exception-handler will load the procedure's code into
//	the code-segment, mark the segment as 'Present', and will
//	return to 'retry' execution of the faulting instruction.  
//
//	  to assemble: $ as notready.s -o notready.o
//	  and to link: $ ld notready.o -T notready -o notready.b
//
//	NOTE: This code begins executing with CS:IP = 1000:0002.
//
//	programmer: ALLAN CRUSE
//	written on: 28 SEP 2006
//-----------------------------------------------------------------

	.code16

	.section	.text
#------------------------------------------------------------------
	.word	0xABCD
#------------------------------------------------------------------
main:	mov	%sp, %cs:exit_pointer+0		# save loader's SP
	mov	%ss, %cs:exit_pointer+2		# also loader's SS

	mov	%cs, %ax		# address program's stack
	mov	%ax, %ss		#    using SS register
	lea	tos, %sp		# establish new stack-top

	call	build_entries_in_IDT 
	call	enter_protected_mode
	call	execute_fault11_demo	
	call	leave_protected_mode

	lss	%cs:exit_pointer, %sp	# recover loader's stack
	lret				# then go back to loader
#------------------------------------------------------------------
	.align	8		# CPU requires quadword alignment  
theGDT:	.word	0x0000, 0x0000, 0x0000, 0x0000	# null descriptor
	.word	0x0007, 0x8000, 0x920B, 0x0080	# vram descriptor
	.word	0xFFFF, 0x0000, 0x9A01, 0x0000	# code descriptor
	.word	0xFFFF, 0x0000, 0x9201, 0x0000	# data descriptor
	.word	0xFFFF, 0x0000, 0x1A02, 0x0000	# code descriptor
	.word	0xFFFF, 0x0000, 0x9202, 0x0000	# data descriptor
	.word	0xFFFF, 0x0000, 0x9200, 0x008F	# flat descriptor
#------------------------------------------------------------------
	.equ	sel_es, 0x0008		# vram segment-selector
	.equ	sel_cs, 0x0010		# code segment-selector
	.equ	sel_ds, 0x0018		# data segment-selector
	.equ	sel_CS, 0x0020		# code segment-selector
	.equ	sel_DS, 0x0028		# data segment-selector
	.equ	sel_fs, 0x0030		# flat segment-selector
#------------------------------------------------------------------
#------------------------------------------------------------------
	.align	8		# CPU requires quadword alignment  
theIDT:	.space	256 * 8		# enough for 256 gate-descriptors
#------------------------------------------------------------------
regGDT:	.word	0x0037, theGDT, 0x0001	# image for register GDTR
regIDT:	.word	0x07FF, theIDT, 0x0001	# image for register IDTR
regIVT:	.word	0x03FF, 0x0000, 0x0000	# image for register IDTR
exit_pointer:	.word	0, 0		# save the loader's SS:SP
#------------------------------------------------------------------
#==================================================================
#------------------------------------------------------------------
# Here is the code and data for a procedure that we will relocate
# to a higher memory-arena, where it will reside during execution
#------------------------------------------------------------------
msg:	.ascii	" Hello from demand-loaded procedure "
len:	.short	. - msg
hue:	.byte	0x20
dst:	.word	1644
#------------------------------------------------------------------
draw_message:	# shows a message (to confirm code got relocated)

	mov	$sel_ds, %si		# address program's data
	mov	%si, %ds		#    with DS register
	lea	msg, %si		# point DS:SI to message
	
	mov	$sel_es, %di		# address display-memory
	mov	%di, %es		#    with ES register
	mov	dst, %di		# point ES:DI to dest'n

	cld				# use forward processing
	mov	hue, %ah		# setup text-color in AH
	mov	len, %cx		# and message-size in CX
nxchr:	
	lodsb				# fetch the next character
	stosw				# store character w/color
	loop	nxchr			# again if more characters

	lret				# returns to other segment
#------------------------------------------------------------------
#==================================================================
#------------------------------------------------------------------
#
# Here is our code that handles a 'Segment-Not-Present' exception
#
isrNPF:  # Interrupt Service Routine for Segment-Not-Present fault

	enter	$0, $0			# setup stackframe access

	call	initialize_high_arena	# copies our code and data
	call	mark_segment_as_ready	# marks descriptor's P-bit

	leave				# discard the stackframe 
	add	$2, %sp			# discard the error-code

	iret		#<-- now 'retry' the faulting instruction
#------------------------------------------------------------------
#------------------------------------------------------------------
isready: .word	0	# flag indicates that arena is initialized  
#------------------------------------------------------------------
initialize_high_arena:

	# check: we need to 'relocate' our program-code only once

	btw	$0, %cs:isready		# is code in place yet?
	jc	initok			# yes, copying not needed
	
	# copy contents of memory-segment from 0x10000 to 0x20000

	pusha				# must preserve registers
	push	%ds			
	push	%es

	mov	$sel_ds, %ax		# address arena at 0x10000
	mov	%ax, %ds		#     with DS register
	xor	%si, %si		# point DS:SI to beginning

	mov	$sel_DS, %ax		# address arena at 0x20000
	mov	%ax, %es		#    with ES register
	xor	%di, %di		# point ES:DI to beginning

	mov	$0x8000, %cx		# copy the whole 64K arena
	cld				# using forward processing
	rep	movsw			# perform the 'relocation'

	btsw	$0, isready 		# mark the copying as done	

	pop	%es			# restore saved registers
	pop	%ds
	popa
initok:	
	ret 				# return to the caller
#------------------------------------------------------------------
mark_segment_as_ready:

	# sanity-check: bits[2..0] of 'error-code' should be zero

	testw	$0x0007, 2(%bp)		# unexpected error-code?
	jnz	back_to_main		# yes, abandon this demo

	# ok, mark the designated segment-descriptor as 'Present'

	push	%bx			# must preserve registers
	push	%ds			# that get clobbered here
	mov	$sel_ds, %bx		# address program's data
	mov	%bx, %ds		#    with DS register
	mov	2(%bp), %bx		# get CPU's 'error-code' 
	lea	theGDT(%bx), %bx	# point DS:BX to descriptor
	btsw	$15, 4(%bx)		# and set its 'Present' bit
	pop	%ds			# restore saved registers
	pop	%bx			# we only used BX and DS
	ret				# return to the caller
#------------------------------------------------------------------	
#==================================================================
#------------------------------------------------------------------	
build_entries_in_IDT:

	mov	%cs, %ax		# address program's data
	mov	%ax, %ds		#    with DS register

	mov	$0x0B, %ebx		# setup gate's ID-number  
	lea	theIDT(,%ebx,8), %di	# point to gate in IDT 
	movw	$isrNPF, 0(%di)		# loword of entry-point
	movw	$sel_cs, 2(%di)		# code-segment selector
	movw	$0x8600, 4(%di)		# 16-bit Interrupt-Gate
	movw	$0x0000, 6(%di)		# hiword of entry-point

	ret 
#------------------------------------------------------------------
enter_protected_mode:

	cli				# no 'external' interrupts

	mov	%cr0, %eax		# current machine status
	bts	$0, %eax		# set image of PE-bit
	mov	%eax, %cr0		# enable protected-mode

	lgdt	%cs:regGDT		# establisg the GDT
	lidt	%cs:regIDT		# establish the IDT

	mov	$sel_ds, %ax		# address program's stack
	mov	%ax, %ss		#    using SS register
	ljmp	$sel_cs, $pm		# also reload CS register
pm:
	# purge 'real-mode' segment-addresses -- to avoid 'bugs'
	xor	%ax, %ax		# 'null' value is OK
	mov	%ax, %ds		#   in DS register
	mov	%ax, %es		#   in ES register
	mov	%ax, %fs		#   in FS register
	mov	%ax, %gs		#   in GS register
	
	ret				# back to main procedure
#------------------------------------------------------------------
execute_fault11_demo:	

	mov	$sel_ds, %ax		# address program's data
	mov	%ax, %ds		#    with DS register
	mov	%sp, back_pointer+0	# save the current SP 
	mov	%ss, back_pointer+2	# and save current SS

	lcall	$sel_CS, $draw_message	# call other code-segment
	jmp	back_to_main 		# return to main routine
#------------------------------------------------------------------
back_pointer: 	.word	0, 0		# stores stacktop address
#------------------------------------------------------------------
back_to_main:	
	lss	%cs:back_pointer, %sp	# recover stacktop address
	ret				# for exit back 
#------------------------------------------------------------------
#------------------------------------------------------------------
leave_protected_mode:

	mov	$sel_ds, %ax		# setup 64KB atributes
	mov	%ax, %ds		#    in DS register
	mov	%ax, %es		#  and in ES register

	mov	$sel_fs, %ax		# setup 4GB attributes
	mov	%ax, %fs		#    in FS register
	mov	%ax, %gs		#  and in GS register

	mov	%cr0, %eax		# read machine's status
	btr	$0, %eax		# reset PE-bit's image
	mov	%eax, %cr0		# and reenter real-mode

	ljmp	$0x1000, $rm		# reload CS for real-mode
rm:	mov	%cs, %ax
	mov	%ax, %ss		# reload SS for real-mode

	lidt	%cs:regIVT		# use 'real-mode' vectors
	sti				# allow device interrupts

	ret				# back to main procedure
#------------------------------------------------------------------
	.align	16			# assures stack-alignment
	.space	512			# allocate area for stack
tos:					# provides stacktop label
#------------------------------------------------------------------
	.end				# no more to be assembled
