//-----------------------------------------------------------------
//	viewivt.s
//	
//	This boot-sector program shows the Interrupt Vector Table
//	in hexadecimal format on a 50-line character-mode screen. 
//
//	 assemble with:  $ as viewivt.s -o viewivt.o
//	 and link with:  $ ld viewivt.o -T ldscript -o viewivt.b
//
//	NOTE: This code begins executing with CS:IP = 0000:7C00.
//
//	programmer: ALLAN CRUSE
//	written on: 28 AUG 2006
//	correction: 30 AUG 2006	-- setting up 8x8 character-glyphs 
//-----------------------------------------------------------------

	# manifest constants
	.equ	seg_base, 0x0000
	.equ	seg_code, 0x07C0
	.equ	seg_vram, 0xB800

	.code16
	.section	.text
#------------------------------------------------------------------
start:	ljmp	$seg_code, $main	
#------------------------------------------------------------------
hex:	.ascii	"0123456789ABCDEF"
msg:	.ascii	"TABLE OF INTERRUPT VECTORS"
len:	.word	. - msg
buf:	.ascii	"0x0000  "
hue:	.byte	0x07
src:	.word	msg
dst:	.word	8*160 + 54		
#------------------------------------------------------------------
main:	# setup segment-registers to address three memory regions
	mov	$seg_code, %ax
	mov	%ax, %ds
	mov	$seg_vram, %ax
	mov	%ax, %es
	mov	$seg_base, %ax
	mov	%ax, %fs

	call	setup_the_video_screen
	call	draw_the_display_title
	call	draw_the_sidebar_texts
	call	draw_interrupt_vectors	
	call	reboot_when_key_is_hit
#------------------------------------------------------------------
setup_the_video_screen:
	# set standard 80x25 textmode
	mov	$0x0003, %ax
	int	$0x10
	# load 8x8 character-glyphs
	mov	$0x1112, %ax
	xor	%bx, %bx	# <--- Added 30 AUG 2006
	int	$0x10
	ret
#-------------------------------------------------------------------
#------------------------------------------------------------------
draw_message_string:
	mov	src, %si
	mov	dst, %di
	mov	hue, %ah
	mov	len, %cx
nxpel:	
	lodsb
	stosw
	loop	nxpel	
	ret
#-------------------------------------------------------------------
draw_the_display_title:
	call	draw_message_string
	ret
#------------------------------------------------------------------
draw_the_sidebar_texts:

	movw	$buf, src
	movw	$1604, dst
	movw	$4, len

	xor	%bx, %bx
nxbar:
	mov	%bx, %ax
	lea	buf+2, %di
	call	ax2hex

	mov	buf+4, %ax
	mov	%ax, buf+2
	call	draw_message_string
	addw	$160, dst

	add	$8, %bx
	cmp	$256, %bx
	jb	nxbar

	ret
#------------------------------------------------------------------
draw_interrupt_vectors:

	movw	$buf, src
	movw	$8, len
	
	xor	%bx, %bx
nxvec:
	call	convert_next_vector
	call	compute_screen_locn
	call	draw_message_string

	inc	%bx
	cmp	$256, %bx
	jb	nxvec

	ret
#------------------------------------------------------------------
#------------------------------------------------------------------
convert_next_vector:
	pusha

	imul	$4, %bx
	
	mov	%fs:2(%bx), %ax
	lea	buf+0, %di
	call	ax2hex

	mov	%fs:0(%bx), %ax
	lea	buf+4, %di
	call	ax2hex

	popa
	ret
#------------------------------------------------------------------
compute_screen_locn:

	#	row = ( index / 8 ) + 10;
	#	col = ( index % 8 )*9 + 7;
	#	dst = ( row * 80 + col )*2;

	pusha

	mov	%bx, %ax
	xor	%dx, %dx
	mov	$8, %cx
	div	%cx
	add	$10, %ax
	imul	$80, %ax, %di

	mov	$9, %ax
	mul	%dx
	add	$7, %ax
	add	%ax, %di

	add	%di, %di
	mov	%di, dst

	popa
	ret
#------------------------------------------------------------------
ax2hex:
	pusha
	mov	$4, %cx
nxnyb:	rol	$4, %ax
	mov	%al, %bl
	and	$0x0F, %bx
	mov	hex(%bx), %dl
	mov	%dl, (%di)
	inc	%di
	loop	nxnyb
	popa
	ret
#------------------------------------------------------------------
#------------------------------------------------------------------
reboot_when_key_is_hit:

	xor	%ah, %ah
	int	$0x16

	int	$0x19
#------------------------------------------------------------------
	.org	510
	.byte	0x55, 0xAA
#------------------------------------------------------------------
	.end


