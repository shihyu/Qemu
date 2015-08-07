//-----------------------------------------------------------------
//	twotasks.s
//
//	This program demonstrates task-switching by the processor
//	between two tasks that both execute at privilege-level 0.
//
//	 to assemble: $ as twotasks.s -o twotasks.o
//	 and to link: $ ld twotasks.o -T ldscript -o twotasks.b
//
//	NOTE: This code begins executing with CS:IP = 1000:0002.
//
//	programmer: ALLAN CRUSE
//	written on: 17 SEP 2006
//-----------------------------------------------------------------

	.code16				# for Pentium 'real-mode'

	.section	.text
#------------------------------------------------------------------
	.word	0xABCD			# loader expects signature 
#------------------------------------------------------------------
begin:	
	mov	%sp, %cs:exit_pointer+0		# save loader's SP
	mov	%ss, %cs:exit_pointer+2		# save loader's SS

	mov	%cs, %ax		# address this segment 
	mov	%ax, %ss		#   with SS register
	lea	tos1, %sp		# establish a new stack

	call	prepare_for_the_demo
	call	enter_protected_mode
	call	exec_taskswitch_demo
	call	leave_protected_mode

	lss	%cs:exit_pointer, %sp		# restore SS:SP and
	lret					# go back to loader
#------------------------------------------------------------------
exit_pointer:	.word	0, 0
#------------------------------------------------------------------
# EQUATES for our various segment-descriptor selectors
	.equ	sel_es, 0x0008		# vram-segment's selector
	.equ	sel_cs, 0x0010		# code-segment's selector
	.equ	sel_ds, 0x0018		# data-segment's selector
	.equ	sel_t1, 0x0020		# task#1 state's selector
	.equ	sel_t2, 0x0028		# task#2 state's selector
	.equ	sel_fs, 0x0030		# flat-segment's selector
#------------------------------------------------------------------
	.align	8		# quadword alignment is required
theGDT:	.word	0x0000, 0x0000, 0x0000, 0x0000	# null descriptor
	.word	0x0007, 0x8000, 0x920B, 0x0080	# vram descriptor
	.word	0xFFFF, 0x0000, 0x9A01, 0x0000	# code descriptor
	.word	0xFFFF, 0x0000, 0x9201, 0x0000	# data descriptor
	.word	0x0067, myTSS1, 0x8901, 0x0000	# task descriptor
	.word	0x0067, myTSS2, 0x8901, 0x0000	# task descriptor
	.word	0xFFFF, 0x0000, 0x9200, 0x008F	# flat descriptor
#------------------------------------------------------------------
#------------------------------------------------------------------
myTSS1:	.zero	0x68			# task-state segment #1
myTSS2:	.zero	0x68			# task-state segment #2
#------------------------------------------------------------------
regGDT:	.word	0x0037, theGDT, 0x0001	# image for register GDTR 
#------------------------------------------------------------------
myloop:	lodsb				# fetch the next character
	stosw				# store character and color
	loop	myloop			# draw the entire message
	iret				# back to the calling task
	jmp	myloop			# (in case we enter again) 
#------------------------------------------------------------------
hello1:	.ascii	" Goodbye from our primary task "   # from task #1
hello2:	.ascii	" Hello from our secondary task "   # from task #2
	.equ	MSGLEN, . - hello2	# size for message-strings
#------------------------------------------------------------------
prepare_for_the_demo:

	# initialize the Task-State Segment for task #2

	mov	%cs, %bx		# address our program data
	mov	%bx, %ds		#   with the DS register
	lea	myTSS2, %bx		# point DS:BX to structure

	movw	$myloop, 32(%bx)	# image for register EIP
	movw	$0x0000, 36(%bx)	# image for register EFLAGS
	movw	$0x6E00, 40(%bx)	# image for register EAX
	movw	$MSGLEN, 44(%bx)	# image for register ECX
	movw	$tos2,   56(%bx)	# image for register ESP
	movw	$hello2, 64(%bx)	# image for register ESI
	movw	$1648,	 68(%bx)	# image for register EDI
	movw	$sel_es, 72(%bx) 	# image for register ES
	movw	$sel_cs, 76(%bx) 	# image for register CS
	movw	$sel_ds, 80(%bx) 	# image for register SS
	movw	$sel_ds, 84(%bx) 	# image for register DS
	movw	$0x0000, 96(%bx)  	# image for register LDTR

	ret
#------------------------------------------------------------------
enter_protected_mode:

	cli				# interrupts not allowed

	mov	%cr0, %eax		# get machine's status
	bts	$0, %eax		# set PE-bit's image
	mov	%eax, %cr0		# enable protection 

	lgdt	%cs:regGDT		# establish the GDT

	ljmp	$sel_cs, $pm		# reload register CS 
pm:	
	mov	$sel_ds, %ax		
	mov	%ax, %ss		# reload register SS

	ret				# back to 'main' function
#------------------------------------------------------------------
#------------------------------------------------------------------
exec_taskswitch_demo:

	# establish a Task-State Segment for this initial task
	mov	$sel_t1, %ax		# address task's TSS
	ltr	%ax			#  with TR register

	# discard "stale" values from FS and GS (or risk crashing) 
	xor	%ax, %ax		# null value is allowed
	mov	%ax, %fs		#  for the FS register
	mov	%ax, %gs		#  and the GS register

	# setup other registers for calling 'myloop' upon return
	cld				# use forward processing
	mov	$sel_ds, %si		# address program data
	mov	%si, %ds		#   with DS register
	lea	hello1, %si		# point DS:SI to message
	mov	$sel_es, %di		# address video screen
	mov	%di, %es		#   with ES register
	mov	$1968, %di		# point ES:DI to screen
	mov	$0x3F, %ah		# color-atributes in AH
	mov	$MSGLEN, %cx		# message-length in CX

	# but now switch to second task -- it switches back here
	lcall	$sel_t2, $0		# performs a task-switch

	# now setup the stack so 'iret' in 'myloop' returns here
	pushw	$0			# return-image for FLAGS
	lcall	$sel_cs, $myloop	# far call pushes CS, IP 

	ret				# back to 'main' function
#------------------------------------------------------------------
leave_protected_mode:

	# restore real-mode attributes and segment-limits in DS, ES
	mov	$sel_ds, %ax		# reload hidden fields
	mov	%ax, %ds		#   for DS register
	mov	%ax, %es		#   and ES register
	
	# NOTE: 'grub' expects 4-GB segment-limits in FS and/or GS 
	mov	$sel_fs, %ax		# reload hidden fields
	mov	%ax, %fs		#   for FS register
	mov	%ax, %gs		#   and GS register

	# now we are ready to leave protected-mode
	mov	%cr0, %eax		# get machine's status
	btr	$0, %eax		# clear PE-bit's image
	mov	%eax, %cr0		# disable protection

	# must restore 'real-mode' segment-addresses to CS and SS
	ljmp	$0x1000, $rm		# reloads CS 
rm:	mov	%cs, %ax		
	mov	%ax, %ss		# reloads SS
	sti				# interrupts now allowed
	ret				# back to 'main' function
#------------------------------------------------------------------
#------------------------------------------------------------------
	.align	16			# insures stack-alignment
	.space	512			# reserved for task #1
tos1:					# label for top-of-stack
#------------------------------------------------------------------
	.align	16			# insures stack-alignment
	.space	512			# reserved for task #2
tos2:					# label for top-of-stack
#------------------------------------------------------------------
	.end				# nothing else to assemble

