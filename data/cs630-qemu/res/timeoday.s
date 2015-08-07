//-----------------------------------------------------------------
//	timeoday.s
//
//	The emphasis in this example is on making very clear the
//	interrupts ('ticks') that have occurred (since midnight)
//	into the current time-of-day, expressed as 'HH:MM:SS' on
//	the famiiar twelve-hour clock, and to show how the steps
//	that require multiplications, divisions, and rounding to
//	the nearest integer, can be done using x86 instructions. 
//
//	 to assemble: $ as timeoday.s -o timeoday.o 
//	 and to link: $ ld timeoday.o -T ldscript -o timeoday.b
//
//	NOTE: This code begins executing with CS:IP = 1000:0002.
//
//	programmer: ALLAN CRUSE
//	written on: 19 OCT 2006
//-----------------------------------------------------------------


	# manifest constants

	.equ	PULSES_PER_SEC, 1193182	# timer input-frequency
	.equ	PULSES_PER_TICK, 65536	# BIOS frequency-divisor

	.equ	SECS_PER_MIN, 60	# number of seconds/minute
	.equ	MINS_PER_HOUR, 60	# number of minutes/hour
	.equ	HOURS_PER_HDAY, 12	# number of hours/half-day
	.equ	HDAYS_PER_DAY, 2	# number of half-days/day


	.code16				# for Pentium 'real-mode'

	.section	.text
#------------------------------------------------------------------
	.word	0xABCD			# loader expects signature
#------------------------------------------------------------------
main:	mov	%sp, %cs:exit_pointer+0
	mov	%ss, %cs:exit_pointer+2

	mov	%cs, %ax
	mov	%ax, %ds
	mov	%ax, %es
	mov	%ax, %ss
	lea	tos, %sp

	call	compute_total_seconds
	call	calculate_time_params	
	call	format_report_of_time
	call	print_the_time_of_day

	lss	%cs:exit_pointer, %sp
	lret
#------------------------------------------------------------------
exit_pointer:	.word	0, 0		# holds loader's SS and SP
#------------------------------------------------------------------
#------------------------------------------------------------------
report:	.ascii	"\r\n hh:mm:ss:xm \r\n"		# message-string
length:	.word	. - report			# message-length
colors:	.byte	0x2F				# white-on-green
#------------------------------------------------------------------
print_the_time_of_day:
#
# This procedure is responsible for sending the report-string to
# the video display screen (it uses ROM-BIOS INT-0x10 routines).
#
	mov	$0x0F, %ah		# current page into BH
	int	$0x10			# request BIOS service

	mov	$0x03, %ah		# cursor row,col in DX
	int	$0x10			# request BIOS service

	lea	report, %bp		# point ES:BP to string
	mov	length, %cx		# string length into CX
	mov 	colors, %bl		# text coloring into BL
	mov	$0x1301, %ax		# write_string function
	int	$0x10			# request BIOS service
	ret
#------------------------------------------------------------------
int2str:  
#
# This procedure converts an integer from 0 to 99 found in the EAX
# register into a two-character string of decimal numerals located 
# at DS:DI.  It preserves the values found in the cpu's registers.
#
	cmp	$100, %eax		# integer outside bounds?
	jae	inval			# yes, no further actions

	pushal				# else preserve registers

	mov	$2, %cx			# setup count of digits
	add	%cx, %di		# and point past field
nxdiv:	
	xor	%edx, %edx		# prepare EDX for divide
	divl	ten			# divide by number base 
	add	$'0', %dl		# turn remainder to digit
	dec	%di			# back up pointer to dest'n
	mov	%dl, (%di)		# store the digit character
	loop	nxdiv			# again  for another digit

	popal				# restore saved registers
inval:	ret				# return control to caller
#------------------------------------------------------------------
a_or_p:		.ascii	"ap"	# character for 'am' or 'pm' field
ten:		.int	10	# the decimal number-system's base
total_ticks:	.int	0	# number of 'ticks' since midnight
total_seconds:	.int	0	# number of seconds since midnight
hh:		.int	0	# for the number of the hour today
mm:		.int	0	# for the number of the minute now
ss:		.int	0	# for the number of the second now
xm:		.int	0	# for 'morning-or-afternoon' flag  
#------------------------------------------------------------------
#------------------------------------------------------------------
#	ticks-per-second = 1193182 / 65536 (approximately 18.2) 
#------------------------------------------------------------------
compute_total_seconds: 
#
# This procedure computes the total number of seconds that have
# elapsed today (i.e., since midnight), based on the tick_count
# which is stored (at offset 0x006C) in the ROM-RIOS DATA AREA.
#
	# fetch the number of timer-ticks from ROM-BIOS DATA-AREA 
	xor	%ax, %ax		# address bottom memory
	mov	%ax, %fs		#   using FS register
	mov	%fs:0x046C, %eax	# get current tick-count 
	mov	%eax, total_ticks	# store as 'total_ticks'

	# calculate total seconds (= total_ticks * 65536 / 1193182)
	mov	total_ticks, %eax	# setup the multiplicand
	mov	$PULSES_PER_TICK, %ecx	# setup the multiplier
	mul	%ecx			# product is in (EDX,EAX)
	mov	$PULSES_PER_SEC, %ecx	# setup the divisor
	div	%ecx			# quotient is left in EAX

	#--------------------------------------------------------
	# ok, now we 'round' the quotient to the nearest integer
	#--------------------------------------------------------

	# rounding-rule: 
	#	if  ( remainder >= (1/2)*divisor )
	#	   then increment the quotient
	
	add	%edx, %edx	# EDX = twice the remainder
	sub	%ecx, %edx	# CF=1 if 2*rem < divisor 
	cmc			# CF=1 if 2*rem >= divisor
	adc	$0, %eax	# ++EAX if 2+rem >= divisor

	# save this rounded quotient as 'total_seconds'
	mov	%eax, total_seconds	# seconds-since-midnight

	ret
#------------------------------------------------------------------
calculate_time_params:
#
# Here we compute the time-display parameters from 'total_seconds'
# 
#	ss = total_seconds % 60;
#	mm = (total_seconds / 60) % 60;
#	hh = ((total_seconds / 60) / 60 ) % 12; 
#	xm = (((total_seconds / 60) / 60 ) / 12) % 2;
#
	mov	total_seconds, %eax	# setup initial dividend

	# calculate  ss = total_seconds % 60
	mov	$SECS_PER_MIN, %ecx	# setup the divisor
	xor	%edx, %edx		# extend the dividend 
	div	%ecx			# perform the division
	mov	%edx, ss		# save remainder as ss
	
	# calculate  mm = (total_seconds / 60) % 60
	mov	$MINS_PER_HOUR, %ecx	# setup the divisor
	xor	%edx, %edx		# extend the dividend
	div	%ecx			# perform the division
	mov	%edx, mm		# save remainder as mm

	# calculate  hh = ((total_seconds / 60) / 60) % 12
	mov	$HOURS_PER_HDAY, %ecx	# setup the divisor
	xor	%edx, %edx		# extend the dividend
	div	%ecx			# perform the division
	mov	%edx, hh		# save remainder as hh

	# calculate  xm = (((total_seconds / 60) / 60) / 12) % 2
	mov	$HDAYS_PER_DAY, %ecx	# setup the divisor
	xor	%edx, %edx		# extend the dividend
	div	%ecx			# perform the division
	mov	%edx, xm		# save remainder as xm
	
	ret
#------------------------------------------------------------------
format_report_of_time:
#
# This procedure converts time-parameters into character-strings.
#
	# format 'hh'
	mov	hh, %eax		# get the current hour 
	lea	report+3, %di		# point to 'hh' fields
	call	int2str			# convert int to string

	# format 'mm'
	mov	mm, %eax		# get the current minute
	lea	report+6, %di		# point to 'mm' field
	call	int2str			# convert int to string

	# format 'ss'
	mov	ss, %eax		# get the current second
	lea	report+9, %di		# point to 'ss' field
	call	int2str			# convert int to string

	# format 'xm'
	mov	xm, %eax		# get the current halfday
	lea	report+12, %di		# point to 'xm' field
	mov	a_or_p(%eax), %dl	# lookup 'a' or 'm'
	mov	%dl, (%di)		# store in message-string

	ret				# return to the caller
#------------------------------------------------------------------
	.align	16			# insure stack alignment
	.space	512			# reserved for stack use
tos:					# label for top-of-stack
#------------------------------------------------------------------
	.end				# no more to be assembled

