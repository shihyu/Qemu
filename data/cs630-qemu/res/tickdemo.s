//-----------------------------------------------------------------
//	tickdemo.s
//
//	This boot-sector program illustrates basic issues involved
//	in writing the interrupt-handling procedure for a hardware
//	device (in this instance the PC's interval timer-counter). 
//	Here we temporarily replace the interrupt-handler provided 
//	by the ROM-BIOS with one of our own design, by overwriting 
//	the appropriate entry in the Interrupt Vector Table.  What
//	is essential, besides incrementing our 'ticks'variable, is
//	that (1) an interrupt-handler must issue an EOI command to 
//	the Interrupt Controller, and (2) an interrupt-handler has
//	to preserve the contents of all the processor's registers.  
//
//	CAUTION: Something our interrupt-handler neglects to do is
//	turn off the diskette-drive's motor in case we boot from a
//	floppy disk, so beware of letting this demo keep running!  
//
//	 assemble with: $ as tickdemo.s -o tickdemo.o
//	 and link with: $ ld tickdemo.o -T ldscript -o tickdemo.b
//
//	programmer: ALLAN CRUSE
//	written on: 31 AUG 2006
//-----------------------------------------------------------------

	.code16				# for Pentium 'real-mode'

	# manifest constants
	.equ	seg_base, 0x0000	# segment-address for IVT
	.equ	seg_boot, 0x07C0	# segment-address of code 
	.equ	seg_vram, 0xB800	# segment-address of VRAM


	.section	.text
#------------------------------------------------------------------
start:	ljmp	$seg_boot, $main	# re-normalize CS and IP
#------------------------------------------------------------------
ticks:	.word	0			# keeps count of 'ticks'
#------------------------------------------------------------------
isr_tick:  # Interrupt Service Routine for timer-tick interrupts
	push	%ax			# preverve AX contents
	incw	%cs:ticks		# increment tick-count
	mov	$0x20, %al		# send 'EOI' command to
	out	%al, $0x20		#  Interrupt Controller
	pop	%ax			# restore saved register
	iret				# return-from-interrupt
#------------------------------------------------------------------
msg:	.ascii	"Timer-ticks: "		# title for screen-display
buf:	.ascii	"    0"			# buffer for 5-digit value
len:	.word	. - msg			# length of output-message
hue:	.byte	0x0E			# colors: yellow-on-black
src:	.word	msg			# offset of message source
dst:	.word	(12*80 + 31)*2		# offset of message dest'n
ten:	.word	10			# radix for decimal-system 
sav:	.word	0, 0			# space for storing vector 
#------------------------------------------------------------------
#------------------------------------------------------------------
main:	# setup segment-registers DS, ES, FS so that we can access 
	# three memory-regions: our data, the IVT, and the display

	mov	$seg_boot, %ax		# address the BOOT_LOCN
	mov	%ax, %ds		#   using register DS

	mov	$seg_vram, %ax		# address screen-memory
	mov	%ax, %es		#   using register ES

	mov	$seg_base, %ax		# address vector-table
	mov	%ax, %fs		#   using register FS

	# save the default interrupt-vector for the timer (INT 8)

	mov	%fs:0x0020, %ax		# copy vector's lo-word
	mov	%ax, sav+0		#  to our save-location
	mov	%fs:0x0022, %ax		# copy vector's hi-word 
	mov	%ax, sav+2		#  to our save-location

	# Write the address of our handler into the IVT (INT 8)

	cli			# <---- ENTER 'CRITICAL SECTION'
	movw	$isr_tick, %fs:0x0020	# write vector's lo-word
	movw	$seg_boot, %fs:0x0022	# write vector's hi-word
	sti 			# <---- LEAVE 'CRITICAL SECTION'

	# loop converts 'ticks' to a decimal string and displays it
	# this loop uses repeated division-by-ten to convert 'ticks'
	# into its representation as a string of decimal numerals,
	# then writes our message-string into video screen memory
again:	mov	$5, %di			# point past 5-place buffer
	mov	ticks, %ax		# setup the dividend in AX 
nxdiv:	
	# perform a division of AX by ten 
	xor	%dx, %dx		# zero-extend the dividend 
	divw	ten			# divide (DX,AX) by radix

	# store numeral representing remainder into message-buffer
	add	$'0', %dl		# convert remainder to ascii
	dec	%di			# move buffer-index leftward
	mov	%dl, buf(%di)		# and store the ascii numeral

	# check for possible additional digits
	or	%ax, %ax		# did quotient equal zero?
	jnz	nxdiv			# no, generate another digit

	# draw message-text (w/color-attributes) onto the screen 
	mov	src, %si		# point DS:SI to the string
	mov	dst, %di		# point ES:DI to the screen
	mov	len, %cx		# setup count of characters
	mov	hue, %ah		# and text color-attributes
	cld				# forward string-processing
nxpel:	lodsb				# fetch next character-byte
	stosw				# store char and color-code
	loop	nxpel			# draw the entire message
		
	# check whether any key has been pressed

	mov	$1, %ah			# peek into keyboard queue
	int	$0x16			# request BIOS service
	jz	again			# jump if queue is empty

	# remove the entry from the keyboard's input-queue 

	xor	%ah, %ah		# return keyboard entry
	int	$0x16			# request BIOS service

	# restore original interrupt-vector to the IVT (INT 8)

	mov	sav+0, %eax		# fetch the saved vector
	mov	%eax, %fs:0x0020	# store it into the IVT

	# re-boot the machine

	int	$0x19			# request BIOS service
#------------------------------------------------------------------
	.org	510			# offset to boot-signature 
	.byte	0x55, 0xAA		# value for boot-signature
#------------------------------------------------------------------
	.end				# nothing more to assemble
