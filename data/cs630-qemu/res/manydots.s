//----------------------------------------------------------------
//	manydots.s
//
//	This is an assembly language program that runs under the
//	Linux operating system, but without calling functions in 
//	the standard C runtime library.  Instead, it makes calls
//	directly to the Linux kernel, to perform console i/o and 
//	then to exit back to the command-shell when finished.
//
//	     assemble with:  $ as manydots.s -o manydots.o
//	     and link with:  $ ld manydots.o -o manydots
//	     execute using:  $ ./manydots
//
//	We created this program in order to provide ourselves an
//	example to work with in designing our own mini operating 
//	system, which should be capable of loading and executing
//	this program on its own (i.e., independently of Linux).
//
//	programmer: ALLAN CRUSE
//	written on: 09 MAR 2004
//	updated on: 17 OCT 2006
//----------------------------------------------------------------

	# symbolic names for device and system-call ID-numbers
	.equ	dev_STDIN, 0		# device-ID for keyboard
	.equ	dev_STDOUT, 1		# device-ID for display
	.equ	sys_EXIT, 1		# service-ID for 'exit'  
	.equ	sys_READ, 3		# service-ID for 'read' 
	.equ	sys_WRITE, 4		# service-ID for 'write'

	.code32				# default for Linux code


	.section	.data
prompt:	.ascii	"How many dots do you want to see? "	
length:	.int	. - prompt		# length of this message
count:	.int	0			# will hold the dot-count
dot:	.ascii	"."			# ascii code for the dot 
newln:	.ascii	"\n"			# ascii code for newline
answer:	.space	16			# will hold keybd input


	.section	.text
_start:	
	# prompt the user for input 	

	movl	$sys_WRITE, %eax	# system-call ID-number
	movl	$dev_STDOUT, %ebx	# device's ID-number
	leal	prompt, %ecx		# buffer-address
	mov	length, %edx		# buffer-length
	int	$0x80			# enter the kernel

	# obtain the user's response

	movl	$sys_READ, %eax		# system-call ID-number
	movl	$dev_STDIN, %ebx	# device's ID-number
	leal	answer, %ecx		# buffer-address
	mov	$16, %edx		# buffer-length
	int	$0x80			# enter the kernel

	# convert the input-string to an integer

	xor	%edi, %edi		# initial array-index
.L0:	# test: is next character a valid ascii numeral?	
	cmpb	$'0', answer(%edi)	# character preceeds '0'?
	jb	.L1			# yes, end-of-number
	cmpb	$'9', answer(%edi)	# character follows '9'?
	ja	.L1			# yes, end-of-number
	# multiply count by ten and add next numeral's value
	imul	$10, count, %eax	# 10 * count into EAX
	movb	answer(%edi), %dl	# get numeral into DL
	andl	$0x0000000F, %edx	# convert ascii to int
	addl	%edx, %eax		# and add int to count  
	mov	%eax, count		# store the new total
	incl	%edi			# advance array-index
	jmp	.L0			# check next character
.L1:
	# loop to show the requested number of dots

	movl	count, %ecx		# setup the loop-count
	jecxz	.L3			# zero? skip past loop
.L2:	pushl	%ecx			# preserve loop-count
	movl	$sys_WRITE, %eax	# system-call ID-number
	movl	$dev_STDOUT, %ebx	# device's ID-number
	leal	dot, %ecx		# buffer-address
	movl	$1, %edx		# buffer-length
	int	$0x80			# enter the kernel
	popl	%ecx			# restore loop-count
	loop	.L2
.L3:
	# advance the cursor to the beginning of the next line

	movl	$sys_WRITE, %eax	# system-call ID-number
	movl	$dev_STDOUT, %ebx	# device's ID-number
	leal	newln, %ecx		# buffer-address
	movl	$1, %edx		# buffer-length
	int	$0x80			# enter the kernel

	# yield control back to the operating system

	movl	$sys_EXIT, %eax		# system-call ID-number
	movl	$0, %ebx		# zero is return-code
	int	$0x80			# enter the kernel

	.global	_start			# entry-point is visible
	.end				# no more to be assembled
