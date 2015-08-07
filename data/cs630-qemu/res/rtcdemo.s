//-----------------------------------------------------------------
//	rtcdemo.s
//
//	This program directly accesses the Real-Time Clock chip
//	in order to obtain and display the current time-of-day.
//	We will setup the RTC to generate an interrupt whenever
//	its current time-of-day changes (i.e., once per second)
//	and then our RTC Interrupt Service Routine will place a 
//	record of the updated time into a queue; meanwhile, our 
//	main procedure will continous loop until it finds a new 
//	record is in this queue, whereupon it will dequeue that
//	record and output its time-information onto the screen. 
//
//	 to assemble: $ as rtcdemo.s -o rtcdemo.o 
//	 and to link: $ ld rtcdemo.o -T ldscript -o rtcdemo.b 
//
//	NOTE: This code begins executing with CS:IP = 1000:0002. 
//
//	programmer: ALLAN CRUSE
//	written on: 13 NOV 2006
//-----------------------------------------------------------------

	.code16				# for Pentium 'real-mode'
	.section	.text
#------------------------------------------------------------------
	.word	0xABCD			# programming signature 
#------------------------------------------------------------------
main:	mov	%sp, %cs:exit_pointer+0	# preserve the loader's SP
	mov	%ss, %cs:exit_pointer+2	# preserve the loader's SS

	mov	%cs, %ax 		# address program's data  
	mov	%ax, %ds		#    with DS register  
	mov	%ax, %ss		#    also SS register 
	lea	tos, %sp 		# and setup new stacktop 

	call	enter_protected_mode 
	call	execute_our_rtc_demo
	call	leave_protected_mode 

	lss	%cs:exit_pointer, %sp	# recover saved SS and SP  
	lret				# return to program loader  
#------------------------------------------------------------------
exit_pointer: 	.word	0, 0		# to store loader's SS:SP 
#------------------------------------------------------------------
	.align	8 	# quadword alignment (for fastest access)
theGDT:	.word	0x0000, 0x0000, 0x0000, 0x0000	# null descriptor 
	.equ	sel_es, (.-theGDT)+0	# vram-segment's selector
	.word	0x7FFF, 0x8000, 0x920B, 0x0000	# vram descriptor 
	.equ	sel_cs, (.-theGDT)+0	# code-segment's selector
	.word	0xFFFF, 0x0000, 0x9A01, 0x0000	# code descriptor 
	.equ	sel_ss, (.-theGDT)+0	# data-segment's selector
	.word	0xFFFF, 0x0000, 0x9201, 0x0000	# data descriptor 
	.equ	sel_fs, (.-theGDT)+0	# flat-segment's selector
	.word	0xFFFF, 0x0000, 0x9200, 0x008F	# flat descriptor 
	.equ	limGDT, (.-theGDT)-1	# the GDT-segment's limit  
#------------------------------------------------------------------
#------------------------------------------------------------------
theIDT:	.space	2048			# for 256 gate-descriptors
	.equ	limIDT, (.-theIDT)-1	# the IDT-segment's limit  
#------------------------------------------------------------------
regGDT:	.word	limGDT, theGDT, 0x0001	# register-image for GDTR
regIDT:	.word	limIDT, theIDT, 0x0001	# register-image for IDTR
regIVT:	.word	0x03FF, 0x0000, 0x0000	# register-image for IDTR
#------------------------------------------------------------------
enter_protected_mode: 

	cli				# no device interrupts 

	mov	%cr0, %eax		# get machine status 
	bts	$0, %eax		# set PE-bit to 1 
	mov	%eax, %cr0 		# enable protection 

	lgdt	regGDT			# load GDTR register-image 
	lidt	regIDT			# load IDTR register-image 

	ljmp	$sel_cs, $pm		# reload register CS 
pm:	
	mov	$sel_ss, %ax		
	mov	%ax, %ss		# reload register SS 
	mov	%ax, %ds		# reload register DS 

	xor	%ax, %ax		# use 'null' selector 
	mov	%ax, %es 		# to purge invalid ES 
	mov	%ax, %fs		# to purge invalid FS 
	mov	%ax, %gs		# to purge invalid GS 
	ret				# back to main routine 
#----------------------------------------------------------------
leave_protected_mode: 

	mov	%ss, %ax		# address 64KB r/w segment 
	mov	%ax, %ds		#   using DS register 
	mov	%ax, %es		#    and ES register 

	mov	$sel_fs, %ax		# address 4GB r/w segment 
	mov	%ax, %fs		#   using FS register 
	mov	%ax, %gs		#    and GS register 

	mov	%cr0, %eax		# get machine status 
	btr	$0, %eax		# reset PE-bit to 0 
	mov	%eax, %cr0		# disable protection 

	ljmp	$0x1000, $rm		# reload register CS 
rm:
	mov	%cs, %ax	
	mov	%ax, %ss		# reload register SS 
	mov	%ax, %ds		# reload register DS 

	lidt	regIVT			# load IDTR register-image 

	sti				# ok, now allow interrupts  
	ret				# back to main routine 
#----------------------------------------------------------------
#----------------------------------------------------------------
isrRTC:
#
# This routine handles the 'update' events triggered by the RTC.
#
	pushal				# must preserve registers
	push	%ds

	# verify that this was an RTC 'update' interrupt
	
	mov 	$0x8C, %al		# RTC register C is
	out 	%al, $0x70		# selected for access
	in 	$0x71, %al		# read the RTC status
	test	$0x10, %al		# was an RTC update? 
	jz	resume			# no, then disregard

	# read the RTC's current-time registers 

	mov	$0x84, %al		# 'hours' register is
	out	%al, $0x70		# selected for access
	in	$0x71, %al		# read rtc register
	shl	$8, %eax		# and shift out of AL
	mov	$0x82, %al		# 'mins' register is
	out	%al, $0x70		# selected for access
	in	$0x71, %al		# read rtc register
	shl	$8, %eax 		# and shift out of AL
	mov	$0x80, %al		# 'secs' register is
	out	%al, $0x70		# selected for access
	in	$0x71, %al		# read rtc register

	# insert current-time as a new record in event-queue

	mov	$sel_ss, %cx		# address program data 
	mov	%cx, %ds		#   with DS register

	mov	(rttail), %ebx		# point to record entry
	mov	%eax, (%ebx)		# store the record info

	call	advEBX			# advance record pointer
	cmp	(rthead), %ebx		# check: queue was full? 
	je	resume			# yes, record discarded
	mov	%ebx, (rttail)		# else commit the insert
resume:
	# reenable NMI (Non-Maskable Interrupts) 
	mov	$0x0D, %al		# RTC register D is
	out	%al, $0x70		# selected for access

	# issue EOI-command to the master and slave PICs
	mov	$0x20, %al		# send EOI command
	out	%al, $0xA0		#  to slave PIC
	out	%al, $0x20		#  to master PIC

	pop	%ds			# restore saved registers
	popal
	iret				# resume the suspended job
#------------------------------------------------------------------
#------------------------------------------------------------------
execute_our_rtc_demo:
	call	save_pic_mask_setting 
	call	create_interrupt_gate
	call	program_new_pic_masks
	call	enable_rtc_interrupts

nxevt:	call	get_next_event_record
	call	show_the_updated_time
	decw	(enough)
	jnz	nxevt
	
	call	disable_rtc_interrupt
	call	restore_pic_mask_bits
	ret
#------------------------------------------------------------------
enough:	.short	10			# timeout for demo's loop
rtq:	.space	64			# holds sixteen longwords
rthead:	.long	rtq			# pointer to queue-head
rttail:	.long	rtq			# pointer to queue-tail
rtbase:	.long	rtq			# pointer to queue-base
rtedge:	.long	rtq+64			# pointer to queue-edge
#------------------------------------------------------------------
advEBX:	# advances pointer to next event-record in circular queue 
	push	%ax			# save working registers
	push	%ds
	mov	$sel_ss, %ax		# address this segment
	mov	%ax, %ds		#   with DS register
	add	$4, %ebx		# add record-size to EBX
	cmp	(rtedge), %ebx		# check: end-of-array?
	jl	advok			# no, new EBX value is ok
	mov	(rtbase), %ebx		# else EBX wraps to start
advok:	pop	%ds			# restore saved registers
	pop	%ax
	ret
#------------------------------------------------------------------
create_interrupt_gate:
	mov	$0x70, %ebx		# Interrupt-ID for RTC
	lea	theIDT(, %ebx, 8), %di	# point DS:DI to the gate 
	movw	$isrRTC, 0(%di)		# entry-point's loword
	movw	$sel_cs, 2(%di)		# 16-bit code-selector
	movw	$0xE600, 4(%di)		# 16-bit interrupt-gate
	movw	$0x0000, 6(%di)		# entry-point's loword
	ret
#------------------------------------------------------------------
mask1:	.byte	0			# holds mask for 8259A #1
mask2:	.byte	0			# holds mask for 8259A #2
#------------------------------------------------------------------
att:	.byte	0x30			# display color-attribute
win:	.word	1978, sel_es		# pointer to video window
msg:	.ascii	" Time now is "		# legend for clock report
hour:	.ascii	"xx:"			# stores a 2-digit string
mins:	.ascii	"xx:"			# stores a 2-digit string
secs:	.ascii	"xx "			# stores a 2-digit string
len:	.short	. - msg			# total length of message
#------------------------------------------------------------------
#------------------------------------------------------------------
show_the_updated_time:	# event-record is found in register EAX

	# format our message-string with the updated information 
	lea	secs, %di		# address seconds field
	call	al2num			# convert AL to ascii
	lea	mins, %di		# address minutes field
	shr	$8, %eax		# shift minutes into AL 
	call	al2num			# convert AL to ascii
	lea	hour, %di		# address hours field
	shr	$8, %eax		# shift hours into AL
	call	al2num			# convert AL to ascii

	# write our message-string directly to video memory
	lea	msg, %si		# point DS:SI to string
	les	win, %di		# point ES:DI to window
	cld				# do forward processing
	mov	att, %ah		# setup color attribute
	mov	len, %cx 		# setup character count
nxchr:	lodsb				# fetch next character
	stosw				# store char and color
	loop	nxchr			# process entire message
	ret
#------------------------------------------------------------------
al2num:	# convert packed-BCD value in AL to ascii string at DS:DI
	push	%ax
	xor	%ah, %ah		# clear accumulator MSB
	ror	$4, %ax			# hi-nybble into AL
	ror	$4, %ah			# lo-nybble into AH
	or	$0x3030, %ax		# convert into numerals
	mov	%ax, (%di)		# store the digit-pair
	pop	%ax
	ret
#------------------------------------------------------------------
save_pic_mask_setting: 
	in	$0x21, %al		# get master-PIC's mask
	mov	%al, mask1		# save it for use later
	in	$0xA1, %al		# get slave-PIC's mask
	mov	%al, mask2		# save it for use later
	ret
#------------------------------------------------------------------
program_new_pic_masks:	# mask all IRQs except RTC and slave-PIC
	mov	$0xFE, %al		# mask all but IRQ8  
	out	%al, $0xA1		#  in slave-PIC
	mov	$0xFB, %al		# mask all but IRQ2
	out	%al, $0x21		#  in master-PIC
	ret
#------------------------------------------------------------------
restore_pic_mask_bits:
	# restore original masks to the master and slave PICs
	mov	mask2, %al		# recover slave's mask
	out	%al, $0xA1		# and restore to PIC
	mov	mask1, %al		# recover master's mask
	out	%al, $0x21 		# and restore to PIC
	ret
#------------------------------------------------------------------
#------------------------------------------------------------------
enable_rtc_interrupts:
	# program the RTC to generate 'update' interrupts
	mov	$0x8B, %al		# rtc's register B is
	out	%al, $0x70		# selected for access
	in	$0x71, %al		# read rtc register B
	and	$0x03, %al		# retain data-format bits
	or	$0x10, %al		# enable update interrupt
	out	%al, $0x71		# write to register B
	mov	$0x0D, %al		# rtc's register D is
	out	%al, $0x70		# selected for access
	sti				# allow interrupts now
	ret
#------------------------------------------------------------------
disable_rtc_interrupt:
	# reprogram the RTC to disable its 'update' interrupt
	mov	$0x8B, %al		# rtc's register B is
	out	%al, $0x70		# selected for access
	in	$0x71, %al		# read rtc register B
	and	$0x03, %al		# keep data-format bits
	out	%al, $0x71		# write to register B
	mov	$0x0D, %al		# rtc's register D is
	out	%al, $0x70		# selected for access
	cli				# no device interrupts
	ret
#------------------------------------------------------------------
get_next_event_record:

	# spin here until our event-queue has a new record
spin:	mov	(rthead), %ebx		# get queue's tail-ptr
	cmp	(rttail), %ebx		# is same as head-ptr?
	je	spin			# yes, continue testing

	# remove the new 'update' record from our event-queue
	mov	(%ebx), %eax		# else fetch new record
	call	advEBX			# advance queue tail-ptr
	mov	%ebx, (rthead)		# to effect its removal
	ret
#------------------------------------------------------------------
	.align	16			# assure stack alignment
	.space	512			# reserved for stack use 
tos:					# label fop top-of-stack 
#------------------------------------------------------------------
	.end				# no more to be assembled
