# MIPS example: Manipulating arrays
# Author:  Ney Calazans
# Function: This code adds the contents of two vectors
#		and stores the result in a third vector
#

.text				# Add what follows to the text segment of the program
	.globl	main		# Declare the label main to be a global one
main:
	la	$t0,V1		# generate pointer to V1 source vector
	la	$t1,V2		# generate pointer to V2 source vector
	la	$t2,V3		# generate pointer to V3 destination vector

	la	$t3,size	# get address of size
	lw	$t3,0($t3)	# register $t1 contains the size of the array

loop:
	blez	$t3,end		# if size is/becomes 0, end of processing
	lw	$t4,0($t0)
	lw	$t5,0($t1)
	addu	$t4,$t4,$t5 
	sw	$t4,0($t2)	# update V3 vector element in memory
	addiu	$t0,$t0,4	# advance pointers
	addiu	$t1,$t1,4	
	addiu	$t2,$t2,4	
	addiu	$t3,$t3,-1	# decrement elements to process counter
	j	loop		# execute the loop another time
	
	# now, stop
end:	j	end

.data

V3:	.word	0x0       0x0  0x0 0x0  0x0   0x0   0x0  0x0  0x0 0x0  0x0 
V1:	.word	0x1000011 0xff 0x3 0x14 0x878 0x31  0x62 0x10 0x5 0x16 0xAB000002
V2:	.word	0x2000002 0xf4 0x3 0x14 0x878 0x31  0x62 0x10 0x5 0x16 0x21000020

size:	.word	11

