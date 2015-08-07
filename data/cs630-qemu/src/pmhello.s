//-------------------------------------------------------------------
//	pmhello.s
//
//	This program provides an example of segment-register usage
//	when entering protected-mode and for exiting to real-mode.
//
//	 assemble using:  $ as pmhello.s -o pmhellp.o
//	 and link using:  $ ld pmhello.o -T ldscript -o pmhello.b
//
//	NOTE: This program begins execution with CS:IP = 1000:0002.
//
//	programmer: ALLAN CRUSE
//	date begun: 10 SEP 2006
//-------------------------------------------------------------------

	# manifest constants
	.equ	seg_prog, 0x1000	# segment for program code
	.equ	seg_vram, 0xB800	# segment for video memory

	.code16
	.text
#-------------------------------------------------------------------
	.word	0xABCD			# our application signature
#-------------------------------------------------------------------
begin:	# preserve the pointer to our exit-address 
	mov	%sp, %cs:return_handle+0	# save offset-addr
	mov	%ss, %cs:return_handle+2	# and segment-addr
	
	# setup DS segment-registers and establish new stack 
	mov	%cs, %ax		# address program data	
	mov	%ax, %ds		#   with DS register
	mov	%ax, %ss		#   also SS register
	lea	tos, %sp		# SS:SP = top-of-stack

	call	main			# perform program's work

	# restore the pointer to our exit-address, and return
	mov	%cs:return_handle+2, %ss	# restore saved SS
	mov	%cs:return_handle+0, %sp	# together with SP
	lret				# return control to loader
#-------------------------------------------------------------------
return_handle:	.word	0, 0		# storage for stack-pointer 
#-------------------------------------------------------------------
# EQUATES for our segment-descriptor selectors
	.equ	sel_cs0, 0x08		# selector for ring0 code
	.equ	sel_ds0, 0x10		# selector for ring0 data
	.equ	sel_es0, 0x18		# selector for ring0 vram
#-------------------------------------------------------------------
	.align	8			# quad alignment required
theGDT:	.word	0x0000, 0x0000, 0x0000, 0x0000	# null descriptor
	.word	0xFFFF, 0x0000, 0x9A01, 0x0000	# code descriptor
	.word	0xFFFF, 0x0000, 0x9201, 0x0000	# data descriptor
	.word	0x7FFF, 0x8000, 0x920B, 0x0000	# vram descriptor
#-------------------------------------------------------------------
regGDT:	.word	0x001F, theGDT, 0x0001	# image for register GDTR
#-------------------------------------------------------------------
#-------------------------------------------------------------------
msg1:	.ascii	" Hello from protected mode "	# message's text
len1:	.short	. - msg1		# size of message-string
hue1:	.byte	0x2E			# colors: yellow-on-green
msg2:	.ascii	" OK, returned to real mode "	# message's text
len2:	.short	. - msg2		# size of message-string
hue2:	.byte	0x1F			# collows: white-on-blue
#-------------------------------------------------------------------
main:	# enter protected mode (with interrupts disabled)
	cli				# disable interrupts
	mov	%cr0, %eax		# get machine status	
	bts	$0, %eax		# turn on the PE-bit 
	mov	%eax, %cr0		# protection enabled
	lgdtl	%cs:regGDT		# load GDTR register
	ljmp	$sel_cs0, $pm		# reload CS and IP
pm:	
	# setup segment-selectors in SS and DS
	mov	$sel_ds0, %ax		# address our variables
	mov	%ax, %ss		#   with SS register
	mov	%ax, %ds		#   also DS register

	# write message #1 to the video display
	mov	$sel_es0, %ax		# address video memory
	mov	%ax, %es		#   with ES register
	mov	$320, %di		# point ES:DI to screen
	lea	msg1, %si		# point DS:SI to string
	mov	len1, %cx		# string length into CX
	mov	hue1, %ah		# string colors into AH
	call	dodraw			# call drawing function 

	# adjust the hidden portion of register ES    
	mov	$sel_ds0, %ax		# need 64K segment-limit 
	mov	%ax, %es		# as 'real-mode' expects
 
	# leave protected mode 
	mov	%cr0, %eax		# get machine status
	btr	$0, %eax		# turn off the PE-bit
	mov	%eax, %cr0		# protection disabled
	ljmp	$seg_prog, $rm		# reload CS and IP
rm:	
	mov	%cs, %ax		# address program data 
	mov	%ax, %ss		#   with SS register
	mov	%ax, %ds		#   also DS register
	sti				# allow interrupts again

	# write message #2 to the video display
	mov	$seg_vram, %ax		# address video memory
	mov	%ax, %es		#   with ES register
	mov	$640, %di		# point ES:DI to screen
	lea	msg2, %si		# point DS:SI to string
	mov	len2, %cx		# string length into CX 
	mov	hue2, %ah		# string colors into AH
	call	dodraw			# call drawing function

	ret		
#-------------------------------------------------------------------
#-------------------------------------------------------------------
dodraw:	cld				# do forward processing
nxchar:	lodsb				# fetch next character
	stosw				# store char and color
	loop	nxchar			# again if chars remain	
	ret				# return to the caller
#-------------------------------------------------------------------
	.align	16			# insure stack alignment
	.space	1024			# reserve 1-KB for stack
tos:					# label for top-of-stack
#-------------------------------------------------------------------
	.end				# no more to be assembled

