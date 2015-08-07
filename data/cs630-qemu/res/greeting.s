//-------------------------------------------------------------------
//	greeting.s
//
//	This program simply displays a message, confirming that we
//	succeeded in loading it to memory from our storage medium. 
//
//	 assemble with: $ as greeting.s -o greeting.o
//	 and link with: $ ld greeting.o -T ldscript -o greeting.b
//
//	NOTE: This program begins executing with CS:IP = 1000:0002
//
//	programmer: ALLAN CRUSE
//	written on: 09 JUN 2006
//-------------------------------------------------------------------

	.code16				# for Pentium 'real-mode'
	.section	.text
#-------------------------------------------------------------------
	.word	0xABCD			# our application signature
#-------------------------------------------------------------------
begin:	# setup DS and ES segment-registers

	mov	%cs, %ax		# address this code-segment 	
	mov	%ax, %ds		#   with the DS register
	mov	%ax, %es		#   also the ES register

	# show the greeting message

	mov	$0x0F, %ah		# get display status
	int	$0x10			# request BIOS service

	mov	$0x03, %ah		# get cursor location
	int	$0x10			# request BIOS service

	lea	msg, %bp		# point ES:BP to string
	mov	len, %cx		# setup string's length
	mov	hue, %bl		# setup string's colors
	mov	$0x1301, %ax		# write_string function
	int	$0x10			# request BIOS service

	lret				# return control to caller
#-------------------------------------------------------------------
msg:	.ascii	"\r\n Welcome to CS 630 \n\r"	# message's content	
len:	.word	. - msg			# count of bytes in message
hue:	.byte	0x3F			# attributes: white-on-cyan
#-------------------------------------------------------------------
	.end				# nothing more to assemble

