IO_SERIAL = 0fff0h

getc:
	; #0 = char code

	pshb

	lld  #IO_SERIAL
	st   #0

	ret



putc:
	; #0: char code

	pshb

	ldb  IO_SERIAL
	ld   #0
	st   #b

	ret



gets:
	; [#1, #0]: dst buf

	pshb

	pshm #0
	pshm #1

	; init local vars
	ld   #0
	st   #2

	ld   #1
	st   #3

	; routine body
.gets.loop:
	call getc
	ld   #0
	st   #4

	teq  '\n'
	sjc  .gets.term

	ld   #2
	st   bl
	ld   #3
	st   bh
	ld   #4
	st   #b

	inc
	ld   bl
	st   #2
	ld   bh
	st   #3

	sj   .gets.loop

.gets.term:
	ld   #2
	st   bl

	ld   #3
	st   bh

	ld   0
	st   #b

.gets.ret:

	popm #1
	popm #0

	ret



puts:
	; [#1, #0]: src buf

	pshb

	pshm #0

	ld   #0
	st   bl
	ld   #1
	st   bh

	; routine body
.puts.loop:
	ld   #b

	teq  '\0'
	sjc  .puts.ret

	st   #0

	pshb
	call putc
	popb

	inc

	sj   .puts.loop

.puts.ret:
	popm #0

	ret
