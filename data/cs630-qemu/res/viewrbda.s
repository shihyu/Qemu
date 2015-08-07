//-----------------------------------------------------------------
//	viewrbda.s
//
//	This boot-sector program will generate a dynamic real-time 
//	display of values residing in the PC's ROM-BIOS DATA-AREA. 
//	(Users can hit the <ESCAPE>-key to terminate the display.)
//
//	 assemble using: $ as viewrbda.s -o viewrbda.o
//	 then link with: $ ld viewrbda.o -T ldscript -o viewrbda.b
//
//	NOTE: This program begins executing with CS:IP = 0000:7C00
//
//	programmer: ALLAN CRUSE
//	written on: 28 AUG 2006
//-----------------------------------------------------------------

	.code16				# for Pentium 'real mode'

	# manifest constants
	.equ	seg_bios, 0x0040	# segment-address for RBDA
	.equ	seg_code, 0x07C0	# segment-address for code
	.equ	seg_vram, 0xB800	# segment-address for vram
	
	.section	.text
#-----------------------------------------------------------------
start:	ljmp	$seg_code, $main	# renormalize CS and IP
#-----------------------------------------------------------------
msg:	.ascii	"ROM-BIOS DATA-AREA"	# string explaining info
len:	.word	. - msg			# count of message bytes
hex:	.ascii	"0123456789ABCDEF"	# hexadecimal digit list
buf:	.ascii	"0x00400:"		# buffer for hex strings
dst:	.word	542			# offset for screen cell
src:	.word	msg			# offset for text string
hue:	.byte	0x07			# selects drawing colors 
#-----------------------------------------------------------------
main:	# setup segment-registers to address three memory areas
	mov	$seg_code, %ax		# address our variables
	mov	%ax, %ds		#   using DS register
	mov	$seg_vram, %ax		# address video memory
	mov	%ax, %es		#   using ES register
	mov	$seg_bios, %ax		# address ROM-BIOS data
	mov	%ax, %fs		#   using FS register

	# setup the static portions of the display-screen
	call	erase_video_screen
	call	draw_display_title
	call	draw_sidebar_lines

	# continuously redraw dynamic parts of the display
again:	call	draw_rom_bios_data	
	call	check_for_exit_key
	jnz	again	

	# reboot the machine in case <ESCAPE>-key was pressed
	int	$0x19
#------------------------------------------------------------------
#------------------------------------------------------------------
erase_video_screen:
#
# This procedure uses the Pentium's 'store-string' instruction to 
# fill up the active display memory with blank-space ascii-codes. 
#
	xor	%di, %di		# point ES:DI at screen
	mov	$' ', %al		# blank ascii-character
	mov	hue, %ah		# white-on-black colors 
	mov	$2000, %cx		# count of screen cells
	cld				# do forward processing
	rep	stosw			# fill the whole screen 
	ret				# then return to 'main' 
#------------------------------------------------------------------
draw_display_title:
#
# This procedure calls a 'helper' function to draw a title-string;
# it relies upon already initialized values of 'global' variables.
#
	call	draw_text_string
	ret	
#------------------------------------------------------------------
draw_sidebar_lines:
#
# This procedure reuses our 'helper' function to draw sidebar-text
# on successive screen-rows, by modifying our 'global' parameters.
#
	# adjust the global parameter-values 
	movw	$buf, src		# offset of source-text
	movw	$8, len			# length of source-text
	movw	$832, dst		# offset to topmost row

	# loop to draw the sidebar texts
	xor	%bx, %bx		# initialize row-count
nxbar:	
	mov	hex(%bx), %dl		# lookup ascii-numeral
	mov	%dl, buf+5		# to use in row's text
	call	draw_text_string	# draw the text string	
	addw	$160, dst		# advance to row below
	inc	%bx			# increment row-count
	cmp	$16, %bx		# has count reached 16?
	jb	nxbar			# no, then draw another 
	ret				# else return to 'main'
#------------------------------------------------------------------
draw_text_string:  # Helper-function parameters stored as globals
	pusha				# preserve registers
	mov	src, %si		# point DS:SI to source
	mov	dst, %di		# point ES:DI to dest'n
	mov	hue, %ah		# AH = color-attributes 
	mov	len, %cx		# CX = length of string
nxpel:	lodsb				# fetch next character
	stosw				# store char and color
	loop	nxpel			# again if other chars
	popa				# restore registers
	ret				# return to caller
#-----------------------------------------------------------------
#-----------------------------------------------------------------
draw_rom_bios_data:
#
# This procedure loops through the array of 128 memory-words that
# reside in the ROM-BIOS DATA-AREA: it converts each one into its
# representation as a string of hexadecimal digits, it calculates
# the screen-location where that string should be drawn, and then 
# it calls our 'helper' function to place the digit-string there.  
#
	movw	$4, len			# setup buffer's length
	xor	%bx, %bx		# initialize array-index 
nxdat:
	call	format_next_word	# convert binary to hex
	call	calc_screen_locn	# compute screen offset
	call	draw_text_string	# draw string on screen
	inc	%bx			# increment array-index
	cmp	$128, %bx		# has index reached 128?
	jb	nxdat			# no, draw another value

	ret				# else return to 'main'
#------------------------------------------------------------------
format_next_word:
#
# This procedure fetches the next word-value from the ROM-BIOS
# DATA-AREA, and converts it into a 4-digit hexadecimal string
# in our 'buf' storage-area.  The array-index of the data-word
# is found in register BX; all of the registers are preserved. 
#
	pusha				# preserve registers

	# compute the word-offset by doubling the array-index
	add	%bx, %bx		# BX is doubled

	# fetch the array word using a segment-override prefix
	mov	%fs:(%bx), %ax		# and word is fetched

	# loop uses four nybble-rotations to lookup hex digits
	xor	%di, %di		# initialize buf index
	mov	$4, %cx			# generate four digits  
nxnyb:
	rol	$4, %ax			# high-nybble into AL
	mov	%ax, %bx		# copy result into BX
	and	$0x0F, %bx		# isolate nybble bits
	mov	hex(%bx), %dl		# convert to numeral
	mov	%dl, buf(%di)		# store numeral in buf
	inc	%di			# and advance buf index
	loop	nxnyb			# again for next digit

	popa				# restore registers
	ret				# return to caller
#-----------------------------------------------------------------
calc_screen_locn:
#
# This procedure computes the screen-position where the next word
# from the ROM-BIOS DATA-AREA should be drawn, based on the value
# found in register BX, and assigns it to our 'dst' variable.  To
# perform this computation, the following algorithm is employed:
#
#		   CELL-POSITION ALGORITHM
#		index = word-number (from BX)
#		  row = ( index / 8 ) + 5;
#		  col = ( index % 8 )*5 + 25;
# 		  dst = ( row * 80 + col )*2;
#
	pusha

	mov	%bx, %ax		# copy dividend to AX
	xor	%dx, %dx		# and extend dividend
	mov	$8, %cx			# setup divisor in CX
	div	%cx			# perform a division
	add	$5, %ax			# add 5 to row-num
	imul	$5, %dx			# remainder times 5
	add	$25, %dx		# add 40 to col-num

	imul	$80, %ax, %di		# DI = row * 80
	add	%dx, %di		#    + col
	add	%di, %di		# then DI is doubled
	mov	%di, dst		# result saved as 'pos'

	popa				# restore registers
	ret				# return to caller
#-----------------------------------------------------------------
check_for_exit_key:
#
# This procedure invokes a ROM-BIOS keyboard-service which 'peeks'
# into the keyboard input-queue to see whether or not it is empty,
# as indicated by the ZF-bit in the EFLAGS register.  In case ZF=1
# it returns immediately; otherwise, it calls a ROM-BIOS keyboard-
# service which removes an entry from the keyboard input-queue and
# checks to see if that entry indicates that <ESCAPE> was pressed.
#
#	RETURNS:	ZF=1 	if <ESCAPE>-key was pressed
#			ZF=0	otherwise
#
	# see if data is waiting in the keyboard input-queue
	mov	$1, %ah			# peek at keyboard queue
	int	$0x16			# call keyboard service

	# if so, pull it out and into AX; otherwise leave AX clear
	mov	$0, %ax			# put zero in accumulator
	jz	check			# queue empty? do compare 
	int	$0x16			# else remove queue-item

check:	# now compare value in AL with ascii-code for <ESC>-key
	cmp	$0x1B, %al		# was <ESC>-key pressed?
	ret				# return ZF-bit setting
#-----------------------------------------------------------------
	.org	510			# offset to the signature
	.byte	0x55, 0xAA		# boot-sector's signature
#-----------------------------------------------------------------
	.end				# no more to be assembled
