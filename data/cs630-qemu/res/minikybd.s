//-----------------------------------------------------------------
//	minikybd.s
//
//	This program installs its own Interrupt Service Routine
//	for the keyboard interrupt (INT-0x09), then it echos to
//	the screen each keystroke that it finds in the keyboard
//	queue located in the ROM-BIOS DATA AREA.  It terminates
//	when the user presses the <ESCAPE>-key (after restoring
//	the original keyboard interrupt-vector).
//
//	  assemble: $ as minikybd.s -o minikybd.o
//	  and link: $ ld minikybd.o -T ldscript -o minikybd.b
//
//	NOTE: This code begins execution with CS:IP = 1000:0002
//
//	programmer: ALLAN CRUSE
//	written on: 12 SEP 2006
//-----------------------------------------------------------------

	.code16				# for Pentium 'real-mode'
	.section	.text
#------------------------------------------------------------------
	.word	0xABCD
#------------------------------------------------------------------
begin:	mov	%sp, %cs:exit_pointer+0		# save offset-addr
	mov	%ss, %cs:exit_pointer+2		# and segment-addr

	mov	%cs, %ax		# address our program data
	mov	%ax, %ds		#   with the DS register
	mov	%ax, %ss		#   also the SS register
	lea	tos, %sp		# establish new stack-area

	call	install_mini_handler	
	call	execute_kb_echo_demo
	call	restore_bios_handler

	mov	%cs:exit_pointer+2, %ss		# recover saved SS 
	mov	%cs:exit_pointer+0, %sp		# together with SP
	lret				# return control to loader
#------------------------------------------------------------------
exit_pointer:	.word	0, 0		#
#------------------------------------------------------------------
isr_kb:	# our Interrupt Service Routine for the keyboard interrupt
	push	%ax			# must preserve registers
	push	%bx
	push	%ds

	call	query_kb_controller
	call	process_keybd_input
	call	transmit_EOI_to_PIC
	
	pop	%ds			# restore used registers
	pop	%bx
	pop	%ax
	iret				# resume interrupted task
#------------------------------------------------------------------
#------------------------------------------------------------------
kbstat:	.byte	0			# kb-controller's status
kbdata:	.byte	0			# holds current scancode
#------------------------------------------------------------------
query_kb_controller:
	mov	%cs, %ax		# address our variables
	mov	%ax, %ds		#   using DS register

	in	$0x64, %al		# read controller status
	mov	%al, kbstat		# save controller status

	test	$0x01, %al		# output-buffer empty?
	jz	ignore			# yes, nothing to read

	in	$0x60, %al		# read the new scancode
	mov	%al, kbdata		# save the new scancode

	testb	$0xC0, kbstat		# parity/timeout errors?
	jnz	resend			# yes, a retry is needed
	jmp	queryx			# else ready to process

resend:	# TODO: our error-recovery routine will go here

ignore:	movb	$0x00, kbdata		# substitute a null byte
queryx:	ret				# return to do handling
#------------------------------------------------------------------
process_keybd_input:

	testb	$0x01, kbstat		# was new data received?
	jz	keyxx			# no, bypass handline

	call	is_special_key		# else handle shifts/locks
	jz	keyxx			# done? ready to exit

	call	is_normal_case		# else handle translations
keyxx:
	ret				# return to do EOI-command
#------------------------------------------------------------------
transmit_EOI_to_PIC:

	mov	$0x20, %al		# non-specific EOI-command
	out	%al, $0x20		#  sent to the Master PIC

	ret
#------------------------------------------------------------------
	# EQUATES for BIOS-DATA offsets and special-key scancodes
	.equ	KBFLAGS, 0x0017		# offset to KBFLAGS word
	.equ	KBHEAD,  0x001A		# offset to KBHEAD word
	.equ	KBTAIL,  0x001C		# offset to KBTAIL word
	.equ	KBBASE,  0x0080		# offset to KBBASE word
	.equ	KBEDGE,  0x0082		# offset to KBEDGE word
	.equ	LSHIFT_MK, 0x2A		# LEFT-SHIFT 'make' code	
	.equ	LSHIFT_BK, 0xAA		# LEFT-SHIFT 'break' code
	.equ	RSHIFT_MK, 0x36		# RIGHT-SHIFT 'make' code	
	.equ	RSHIFT_BK, 0xB6		# RIGHT-SHIFT 'break' code
#---------------------------------------------------------------	
#------------------------------------------------------------------
is_special_key:

	mov	$0x40, %ax		# address ROM-BIOS Data
	mov	%ax, %ds		#   using DS register

	mov	%cs:kbdata, %al		# current scancode in AL
	
	cmp	$LSHIFT_MK, %al		# was LEFT-SHIFT depressed?
	je	ls_mk			# yes, update kb-flags
	cmp	$LSHIFT_BK, %al		# was LEFT-SHIFT released?
	je	ls_bk			# yes, update kb-flags

	cmp	$RSHIFT_MK, %al		# was RIGHT-SHIFT depressed?
	je	rs_mk			# yes, update kb-flags
	cmp	$RSHIFT_BK, %al		# was RIGHT-SHIFT released?
	je	rs_bk			# yes, update kb-flags
	
	jmp	notsp			# else return w/ZF-bit clear

ls_mk:	btsw	$0, KBFLAGS		# set bit #0 in KBFLAGS
	jmp	wassp				
ls_bk:	btrw	$0, KBFLAGS		# reset bit #0 in KBFLAGS
	jmp	wassp
rs_mk:	btsw	$1, KBFLAGS		# set bit #1 in KBFLAGS
	jmp	wassp
rs_bk:	btrw	$1, KBFLAGS		# reset bit #1 in KBFLAGS
	jmp	wassp	

wassp:	xor	%al, %al		# set ZF-bit for return
notsp:	ret				# keep ZF-bit as it was
#------------------------------------------------------------------
# SCANCODE TRANSLATION TABLES
uppercase:
	.byte	0, 27
	.ascii	"!@#$%^&*()_+"
	.byte	8, 9
	.ascii	"QWERTYUIOP{}"
	.byte	13, 0
	.ascii	"ASDFGHJKL:\"~"
	.byte	0
	.ascii	"|ZXCVBNM<>?"
	.byte	0, 0, 0, 32
	.zero	70
lowercase:
	.byte	0, 27
	.ascii	"1234567890-="
	.byte	8, 9
	.ascii	"qwertyuiop[]"
	.byte	13, 0
	.ascii	"asdfghjkl;'`"
	.byte	0
	.ascii	"\\zxcvbnm,./"
	.byte	0, 0, 0, 32
	.zero	70
#------------------------------------------------------------------
#------------------------------------------------------------------
is_normal_case:

	mov	$0x40, %bx		# address ROM-BIOS Data
	mov	%bx, %ds		#   using DS register

	mov	%cs:kbdata, %al		# copy scancode into AL
	mov	%al, %ah		# and also copy into AH

	test	$0x80, %al		# was keyboard 'break'?
	jnz	discard			# yes, we disregard it

	lea	lowercase, %bx		# provisional xlat-table
	testw	$0x03, KBFLAGS		# is a shift-key down?
	jz	xok			# no, retain xlat-table
	lea	uppercase, %bx		# else change xlat-table
xok:	xlat	%cs:(%bx)		# translate the scancode

	mov	KBTAIL, %bx		# next storage location
	mov	%ax, (%bx)		# save ascii/scan codes
	
	call	advbx			# advance tail-location
	cmp	%bx, KBHEAD 		# kb-queue was full?
	je	discard			# yes, discard new data

	mov	%bx, KBTAIL		# else commit new input
	jmp	normx			# and return to do EOI
discard:
	# TODO: Some form of user-alert ought to be added here	
normx:
	ret
#------------------------------------------------------------------
advbx:	
	# Increments the array-index for circular keyboard-queue 

	push	%ax			# preserve registers
	push	%ds

	mov	$0x40, %ax		# address ROM-BIOS data
	mov	%ax, %ds		#   using DS register

	add	$2, %bx			# advance the queue-index

	cmpw	KBEDGE, %bx		# is index beyond bounds?
	jne	advok			# no, the new index is ok
	mov	KBBASE, %bx		# else reset to beginning
advok:
	pop	%ds			# restore registers
	pop	%ax
	ret	
#------------------------------------------------------------------
#==================================================================
#------------------------------------------------------------------
old_vector:	.word	0x0000, 0x0000	# interrupt-vector space
new_vector:	.word	isr_kb, 0x1000	# interrupt-vector value
#------------------------------------------------------------------
#------------------------------------------------------------------
install_mini_handler:

	xor	%ax, %ax		# address vector table
	mov	%ax, %es		#   with ES register

	mov	$0x09, %edi		# keyboard interrupt-ID

	mov	%es:(,%edi,4), %eax	# get the current vector
	mov	%eax, %cs:old_vector	# save for restore later

	mov	%cs:new_vector, %eax	# get replacement vector
	mov	%eax, %es:(,%edi,4)	# to put in vector table

	ret
#------------------------------------------------------------------
execute_kb_echo_demo:
#
# Echos keyboard-input to the screen until <ESCAPE>-key is pressed 
#	
	mov	$0x40, %ax		# address ROM-BIOS data
	mov	%ax, %ds		#   using DS register

	sti				# must allow interrupts 
await:
	mov	KBHEAD, %bx		# index to front-of-queue
	cmp	KBTAIL, %bx		# same as index to tail?
	je	await			# yes, nothing there yet

	mov	(%bx), %ax		# else dequeue front datum
	call	advbx			# and queue-index advances
	mov	%bx, KBHEAD		# then new index is stored

	cmp	$0x1B, %al		# datum is <ESCAPE>-key? 
	je	isesc			# yes, break out of loop

	mov	$0x0E, %ah		# else do 'write_tty' 
	mov	$0x0007, %bx		# BH=page, BL=colors
	int	$0x10			# invoke BIOS service

	cmp	$0x0D, %al		# datum was <ENTER>-key?
	jne	await			# no, await another key

	mov	$0x0A, %al		# else issue a LineFeed
	int	$0x10			# invoke BIOS service
	jmp	await			# and await another key

isesc:
	mov	$0x0007, %bx		# BH=page, BL=colors
	mov	$0x0E0D, %ax		# issue CarriageReturn
	int	$0x10			# invoke BIOS service
	mov	$0x0E0A, %ax		# also issue LineFeed
	int	$0x10			# invoke BIOS service

	ret
#------------------------------------------------------------------
#------------------------------------------------------------------
restore_bios_handler:

	xor	%ax, %ax		# address vector table 
	mov	%ax, %es		#   with ES register

	mov	$0x09, %edi		# keyboard interrupt-ID 

	mov	%cs:old_vector, %eax	# retrieve former vector
	mov	%eax, %es:(,%edi,4)	# to put in vector table

	ret
#------------------------------------------------------------------
	.align	16			# insure stack alignment
	.space	1024			# reserve 1-KB for stack
tos:					# label for top-of-stack
#------------------------------------------------------------------
	.end				# no more to be assembled




