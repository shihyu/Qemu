//----------------------------------------------------------------
//	alphabet.s
//
//	This Linux application fills the screen with copies of
//	each successive uppercase letter from the alphabet; it
//	pauses briefly as each new screen is displayed, before
//	continuing to cycle endlessly through the alphabet.  A
//	user may terminate this program by typing <CONTROL>-C.
//
//	    assemble using:  $ as alphabet.s -o alphabet.o
//	    and link using:  $ ld alphabet.o -o alphabet
//
//	programmer: ALLAN CRUSE
//	written on: 20 APR 2004
//----------------------------------------------------------------

	.equ	sys_write, 4		# service ID-number
	.equ	dev_stdout, 1		# device ID-number


	.data
outln:	.space	2000			# no. of screen cells
total:	.long	26			# no. of alphabet letters
count:	.long	0			# current loop iteration 


	.text
_start:
	call	do_fill			# fill the output buffer 
	call	do_draw			# write buffer to screen
	call	do_wait			# perform a brief delay
	call	do_incr			# increment cycle count
	jmp	_start			# repeat loop forever

do_fill:
	# fill buffer with copies of ascii character-code
	pushal
	movl	count, %eax		# get iteration counter
	addl	$'A', %eax		# add ascii-code for 'A'
	lea	outln, %edi		# point ES:EDI to buffer
	cld				# do forward processing
	movl	$2000, %ecx		# setup character count
	rep	stosb			# fill the entire buffer
	popal
	ret
	
do_draw:
	# write contents of buffer to standard output device
	pushal
	movl	$sys_write, %eax	# service ID-number
	movl	$dev_stdout, %ebx	# device ID-number
	lea	outln, %ecx		# buffer offset
	movl	$2000, %edx		# buffer length
	int	$0x80			# enter the kernel
	popal
	ret

do_wait:
	# do a timed delay of approximately 500-million cpu-cycles 
	pushal	
	rdtsc				# read timestamp counter
	addl	$500000000, %eax	# increment the quadword 
	adcl	$0x0000000, %edx	# counter by 500-million
	movl	%eax, %ebx		# copy bits 31..0 to EBX
	movl	%edx, %ecx		# and bits 63..32 to ECX
.L2:	rdtsc				# read timestamp again
	subl	%ebx, %eax		# subtract saved quadword
	sbbl	%ecx, %edx		#  from latest timestamp
	js	.L2			# negative? read it again
	popal
	ret

do_incr:
	# advance the cycle-count by 1 (with wrapping at 26)
	pushal
	incl	count			# add 1 to the count
	movl	count, %eax		# get new count value
	xorl	%edx, %edx		# extend to quadword
	divl	total			# divide by letter-count
	movl	%edx, count		# remainder is new count
	popal
	ret

	.global	_start
	.end

