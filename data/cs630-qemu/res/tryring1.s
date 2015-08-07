//-----------------------------------------------------------------
//	tryring1.s
//
//	This example demonstrates how a privilege-level transition
//	(and its accompanying stack-switch) would be accomplished.
//
//	  to assemble: $ as tryring1.s -o tryring1.o
//	  and to link: $ ld tryring1.o -T ldscript -o tryring1.b
//	  and install: $ dd if=tryring1.b of=/dev/sda4 seek=1
//
//	NOTE: This code begins executing with CS:IP = 1000:0002.
//
//	programmer: ALLAN CRUSE
//	written on: 12 SEP 2008
//-----------------------------------------------------------------


	# manifest constants
	.equ	seg_prog, 0x1000	# program segment-address 


	.section	.text
#------------------------------------------------------------------
	.word	0xABCD			# our program 'signature'
#------------------------------------------------------------------
main:	.code16				# we start in 'real-mode'

	# preserve original SS and SP (for return to loader later)
	mov	%sp, %cs:origtos+0	# save stack's offset-addr
	mov	%ss, %cs:origtos+2	# and stack's segment-addr

	# switch to our own stack, so we know its size is adequate
	mov	%cs, %ax		# address program's data
	mov	%ax, %ss		#    with SS register
	lea	tos0, %sp		# establish ring0 stacktop

	call	enter_protected_mode
	call	exec_ring1_procedure
	call	leave_protected_mode

	# switch back to the original stack, for return to loader
	lss	%cs:origtos, %sp	# restore loader's SS:SP
	lret				# and exit to the loader
#------------------------------------------------------------------
origtos: .word	0, 0			# storage-space for SS:SP
#------------------------------------------------------------------
msg1:	.ascii	" Now executing in ring1 "	# text of message
len1:	.word	. - msg1			# size of message
att1:	.byte	0x2E				# yellow on green
dst1:	.word	(80*4 + 0)*2			# screen location 
#------------------------------------------------------------------
theTSS:	.word	0x0000			# back-link (not used)
	.word	0x0000			# reserve for SP0 value
	.word	0x0000			# reserve for SS0 value
	.equ	limTSS, (.-theTSS)-1	# the TSS's segment-limit
#------------------------------------------------------------------
#------------------------------------------------------------------
theGDT:	.word	0x0000, 0x0000, 0x0000, 0x0000	# null descriptor
	
	.equ	sel_tss, (.-theGDT)+0	# selector for task-state
	.word	limTSS, theTSS, 0x8101, 0x0000	# task-descriptor

	.equ	sel_cs0, (.-theGDT)+0	# selector for ring0-code
	.word	0xFFFF, 0x0000, 0x9A01, 0x0000	# code-descriptor

	.equ	sel_ds0, (.-theGDT)+0	# selector for ring0-data
	.word	0xFFFF, 0x0000, 0x9201, 0x0000	# data-descriptor

	.equ	sel_cs1, (.-theGDT)+1	# selector for ring1-code
	.word	0xFFFF, 0x0000, 0xBA01, 0x0000	# code-descriptor

	.equ	sel_ds1, (.-theGDT)+1	# selector for ring1-data
	.word	0xFFFF, 0x0000, 0xB201, 0x0000	# data-descriptor

	.equ	sel_es1, (.-theGDT)+1	# selector for ring1-vram
	.word	0x7FFF, 0x8000, 0xB20B, 0x0000	# vram-descriptor

	.equ	sel_ret, (.-theGDT)+0	# selector for call-gate
	.word	finis, sel_cs0, 0xA400, 0x0000	# gate-descriptor  

	.equ	limGDT, (.-theGDT)-1	# the GDT's segment-limit
#------------------------------------------------------------------
regGDT:	.word	limGDT, theGDT, 0x0001	# register-image for GDTR
#------------------------------------------------------------------
enter_protected_mode:

	# NOTE: we're unprepared for interrupts in protected-mode

	cli				# no device interrupts

	# turn on the PE-bit in system register CR0

	mov	%cr0, %eax		# get machine status
	bts	$0, %eax		# set PE-bit's image 
	mov	%eax, %cr0		# turn on protection

	# reinitialize the SS and CS segment-registers' caches

	lgdt	%cs:regGDT		# initialize GDTR
	mov	$sel_ds0, %ax			
	mov	%ax, %ss		# reload SS register
	ljmp	$sel_cs0, $pm		# reload CS register
pm:
	# nullify 'stale' values in other segment-registers

	xor	%ax, %ax		# purge invalid values
	mov	%ax, %ds		#   from DS register
	mov	%ax, %es		#   from ES register
	mov	%ax, %fs		#   from FS register
	mov	%ax, %gs		#   from GS register
	ret
#------------------------------------------------------------------
#------------------------------------------------------------------
exec_ring1_procedure:

	# store the current SS and SP in our Task-State Segment

	mov	%sp, %ss:theTSS+2	# save SP in SP0-field
	mov	%ss, %ss:theTSS+4	# save SS in SS0-field

	# initialize the TR system-register

	mov	$sel_tss, %ax		# address task's state
	ltr	%ax			#   with TR register

	# setup ring0 stack for a 'return' to our ring1 procedure

	pushw	$sel_ds1		# push image for SS
	pushw	$tos1			# push image for SP
	pushw	$sel_cs1		# push image for CS
	pushw	$showmsg		# push image for IP
	lret				# load the four registers

	# OK, this is where the processor will resume execution in
	# ring0 (by transferring control here through a call-gate)
finis:
	add	$8, %sp			# discard callgate words 

	ret				# return control to main
#------------------------------------------------------------------
leave_protected_mode:

	# insure segment-registers have real-mode attributes

	mov	%ss, %ax		# load limit and rights
	mov	%ax, %ds		#   into the DS cache
	mov	%ax, %es		#   into the ES cache
	mov	%ax, %fs		#   into the FS cache
	mov	%ax, %gs		#   into the GS cache

	# turn off protection (by resetting the PE-bit to 0)

	mov	%cr0, %eax		# get machine status
	btr	$0, %eax		# reset PE-bit's image 
	mov	%eax, %cr0		# turn off protection

	# reinitialize SS and CS for real-mode addressing

	ljmp	$seg_prog, $rm		# reload the CS register
rm:	mov	%cs, %ax		# address program memory
	mov	%ax, %ss		#    with SS register

	# now we can handle device-interrupts again

	sti				# turn interrupts on

	ret
#------------------------------------------------------------------
#------------------------------------------------------------------
# The following code will be executed with privilege-restrictions
#------------------------------------------------------------------
showmsg: # this procedure displays our ring1 confirmation-message

	mov	$sel_ds1, %ax		# address message text
	mov	%ax, %ds		#   with DS register
	lea	msg1, %si		# point DS:SI to string

	mov	$sel_es1, %ax		# address video memory
	mov	%ax, %es		#   with ES register
	mov	dst1, %di		# point ES:DI to screen

	mov	att1, %ah		# text-attribute in AH
	mov	len1, %cx		# message-length in CX
	cld				# do forward processing
nxpel:	lodsb				# fetch next character
	stosw				# store char and color
	loop	nxpel			# draw rest of message

	# transfer control back to ring0 (through a call-gate)

	lcall	$sel_ret, $0		# invoke far direct call
#------------------------------------------------------------------
	.align	16			# insure word alignment
#------------------------------------------------------------------
	.space	256			# space for ring1 stack
tos1:					# label for ring1 stack
#------------------------------------------------------------------
	.space	256			# space for ring0 stack
tos0:					# label for ring0 stack
#------------------------------------------------------------------
	.end				# no more to assemble

