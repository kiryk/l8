strcmp:
	; [#1, #0]: string A ptr
	; [#3, #2]: string B ptr
	; c = set if equal

	pshb

	; init local vars
	pshm #0
	pshm #1

	; routine body
.strcmp.loop:
	ld   #0   ; get a char from A
	st   bl
	ld   #1
	st   bh
	ld   #b
	st   #4

	inc
	ld   bl
	st   #0
	ld   bh
	st   #1

	ld   #2   ; get a char from B
	st   bl
	ld   #3
	st   bh
	ld   #b
	st   #5

	inc
	ld   bl
	st   #2
	ld   bh
	st   #3

	ld   #4
	teq  #5  ; equal?
	sjc  .strcmp.eq
	sj	 .strcmp.ret

.strcmp.eq:
	ld   #4  ; end of string?
	teq  0
	sjc  .strcmp.ret
	sj	 .strcmp.loop

.strcmp.ret:
	popm #1
	popm #0

	ret



strchr:
	; [#1, #0]: string ptr
	; #2: char to look for
	; #0 = index of the char in str
	; c  = set if found

	pshb

	ld   #0
	st   bl
	ld   #1
	st   bh

	ld   0
	st   #0

.strchr.loop:
	ld   #0
	ld   #b+a
	teq  #2
	sjc  .strchr.succ
	teq  0
	sjc  .strchr.fail

	ld   #0
	add  1
	st   #0

	sj   .strchr.loop

.strchr.fail:
	stc  0

.strchr.succ:
	ret
