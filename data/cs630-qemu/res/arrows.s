//-----------------------------------------------------------------
//	arrows.s
//
//	This example shows how to directly program the cursor's 
//	location and height while in standard text display-mode
//	Here the keyboard is "polled" for new input rather than
//	being "interrupt-driven" as is customary. 
//	
//	 assemble using: $ as arrows.s -o arrows.o 
//	 and link using: $ ld arrows.o -T ldscript -o arrows.b 
//
//	NOTE: This code begins executing with CS:IP = 1000:0002. 
//
//	programmer: ALLAN CRUSE
//	written on: 22 MAR 2004
//	revised on: 09 OCT 2006 -- to use GNU assembler's syntax 
//-----------------------------------------------------------------

	# EQUATES for some keyboard scancodes
	.equ	KEYPAD_MIN, 0x47	# scancode for <HOME>-key
	.equ	KEYPAD_MAX, 0x51	# scancode for <PGDN>-key
	.equ	KEY_ESCAPE, 0x01	# scancode for <ESCAPE>

	.code16				# for Pentium 'real-mode'

	.section	.text
#------------------------------------------------------------------
	.word	0xABCD			# programming signature 
#------------------------------------------------------------------
main:	mov	%sp, %cs:exit_pointer+0		# save loader's SP	
	mov	%ss, %cs:exit_pointer+2		# also loader's SS

	mov	%cs, %ax		# address this segment 
	mov	%ax, %ds		#   with DS register
	mov	%ax, %ss		#   also SS register  
	lea	tos, %sp		# establish new stack

	call	initialize_video_ram
	call	initialize_cursor_ht
	call	exec_arrow_keys_demo

	lss	%cs:exit_pointer, %sp 	# recover loader's stack 
	lret				# back to program loader 
#------------------------------------------------------------------
exit_pointer:	.word	0, 0		# holds loader's stacktop  
#------------------------------------------------------------------
# storage for display-page and cursor-location coordinates
page:	.byte	0			# video page-number
row:	.byte	0			# cursor row-number
col:	.byte	0			# cursor col-number
#------------------------------------------------------------------
jump_table:
	.word	do_home_key, do_arrow_up, do_page_up, ignore
	.word	do_arrow_left, ignore, do_arrow_right, ignore
	.word	do_end_key, do_arrow_down, do_page_down 
#------------------------------------------------------------------
#------------------------------------------------------------------
initialize_video_ram:

	# reset display_mode for standard 80-column text
	mov	$0x00, %ah		# set_display_mode
	mov	$0x03, %al		# standard 80x25 text
	int	$0x10			# request BIOS service

	# fill each vram page with that page's page-number
	mov	$0xB800, %ax		# address video memory
	mov	%ax, %es		#   with ES register
	xor	%di, %di		# initial vram offset
	cld				# do forward processing
	mov	$0x07, %ah 		# normal color-attribute
	mov	$0x30, %al		# ascii page-number '0'
	mov	$8, %dx 		# number of vram pages
.L0:
	mov	$2048, %cx		# characters-per-page
	rep	stosw			# fill w/char and color

	inc	%al			# set next page-number
	dec	%dx			# decrement loop-count
	jnz	.L0			# initialize next page

	ret
#------------------------------------------------------------------
exec_arrow_keys_demo:

	# mask the keyboard interrupt
	in	$0x21, %al		# master-8259A mask
	or	$0x02, %al 		# set mask for IRQ1
	out	%al, $0x21 		# write the new mask

await:	# wait for keyboard controller's input-buffer full
	in	$0x64, %al		# kb_controller's status	
	test	$0x01, %al 		# output buffer full?
	jz	await			# no, continue waiting

	# read the new keyboard scancode into register AL
	in	$0x60, %al		# get keyboard scancode

	# check for exit-condition
	cmp	$KEY_ESCAPE, %al	# <ESCAPE>-key?
	je	finis			# yes, exit this loop

	# otherwise process the new scancode
	call	move_cursor		# perform cursor action
	jmp	await			# then get next scancode
finis:
	# unmask keyboard interrupts
	in	$0x21, %al		# master-8259A mask
	and	$0xFD, %al		# clear mask for IRQ1
	out	%al, $0x21		# write the new mask

	ret
#------------------------------------------------------------------
#------------------------------------------------------------------
set_crt_cursor:

	# compute the cursor's page-offset in BX

	mov	page, %bl		# get vram page-number
	and	$0x0007, %bx		# extended to 16-bits
	shl	$11, %bx 		# multiply by 2048

	# reprogram the CRTC start_address

	mov	$0x3D4, %dx		# CRTC port-address
	mov	$0x0D, %al		# index for start_addr_lo
	mov	%bl, %ah		# value for start_addr_lo
	out	%ax, %dx 		# write new start_addr_lo
	mov	$0x0C, %al		# index for start_addr_hi
	mov	%bh, %ah 		# value for start_addr_hi
	out	%ax, %dx 		# write new start_addr_hi

	# compute the cursor's cell-offset in BX

	mov	$80, %al 		# setup cells-per-line
	mulb	row			# times cursor row-number
	add	%ax, %bx 		# add offset to BX

	add	col, %bl		# plus column's lobyte
	adc	$0, %bh 		# also column's hibyte

	# reprogram the cursor-position and start_address

	mov	$0x3D4, %dx		# CRTC port-address

	mov	$0x0F, %al		# index for cursor_lo
	mov	%bl, %ah		# value for cursor_lo
	out	%ax, %dx		# write new cursor_lo

	mov	$0x0E, %al		# index for cursor_hi
	mov	%bh, %ah		# value for cursor_hi
	out	%ax, %dx		# write new cursor_hi

	ret	
#------------------------------------------------------------------
move_cursor:

	cmp	$KEYPAD_MIN, %al	# scancode below minimum?
	jb	movxx			# yes, take no action
	cmp	$KEYPAD_MAX, %al	# scancode above maximum?
	ja	movxx			# yes, take no action

	sub	$KEYPAD_MIN, %al	# subtract table minimum
	movzx	%al, %eax 		# then extend to 32-bits

	call	*jump_table(,%eax,2)	# perform cursor movement
	call	set_crt_cursor		# and adjust the cursor  
movxx:	ret				# return to the caller
#-----------------------------------------------------------------
#-----------------------------------------------------------------
#=============  Below are the jump-table routines  ===============
#-----------------------------------------------------------------
ignore:	ret				# no cursor movement
#-----------------------------------------------------------------
do_home_key:
	movb	$0, row 
	movb	$0, col 
	movb	$0, page 
	ret
#-----------------------------------------------------------------
do_end_key:
	movb	$24, row 
	movb	$79, col 
	ret
#-----------------------------------------------------------------
do_arrow_up:
	subb	$1, row 
	jge	upok
	movb	$24, row 
	subb	$1, page 
	andb	$0x07, page 
upok:	ret
#------------------------------------------------------------------
do_arrow_down:
	addb	$1, row 
	cmpb	$24, row 
	jle	dnok
	movb	$0, row 
	addb	$1, page 
	andb	$0x07, page 
dnok:	ret	
#------------------------------------------------------------------
do_arrow_left:	
	subb	$1, col 
	jge	lfok
	movb	$79, col 
	subb	$1, row 
	jge	lfok
	movb	$24, row 
	subb	$1, page 
	andb	$0x07, page 
lfok:	ret
#------------------------------------------------------------------
do_arrow_right:
	addb	$1, col 
	cmpb	$79, col 
	jle	rtok
	movb	$0, col 
	addb	$1, row 
	cmpb	$24, row 
	jle	rtok
	addb	$1, page 
	andb	$0x07, page 
rtok:	ret
#------------------------------------------------------------------
#------------------------------------------------------------------
do_page_up:
	subb	$1, page 
	andb	$0x07, page 
	ret
#------------------------------------------------------------------
do_page_down:
	addb	$1, page 
	andb	$0x07, page 
	ret
#------------------------------------------------------------------
initialize_cursor_ht:
	mov	$0x03D4, %dx		# CRTC port-address
	mov	$0x020A, %ax		# cursor_start: line 2
	out	%ax, %dx 		# write to CRTC register
	mov	$0x0C0B, %ax		# cursor_end: line 12
	out	%ax, %dx		# write to CRTC register
	ret
#------------------------------------------------------------------
	.align	16			# assure stack alignment  
	.space	512			# reserved for stack use 
tos:					# label for top-of-stack 
#------------------------------------------------------------------
	.end				# nothing more to assemble
