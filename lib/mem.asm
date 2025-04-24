memcpy:
	; [#1, #0]: dst ptr
	; [#3, #2]: src ptr
	; [#5, #4]:	length

	pshb
	pshm #0
	pshm #1

	pshm #16

.memcpy.loop:
	ld   #4
	or   #5
	teq  0
	sjc   .memcpy.ret

	ld   #2   ; load from [#3, #2]
	st   bl
	ld   #3
	st   bh
	ld   #b
	st   #16

	inc       ; increment [#3, #2]
	ld   bl
	st   #2
	ld   bh
	st   #3

	ld   #0   ; store under [#1, #0]
	st   bl
	ld   #1
	st   bh
	ld   #16
	st   #b

	inc	      ; increment [#1, #0]
	ld   bl
	st   #0
	ld   bh
	st   #1

	ld   #4   ; decrement iterator
	sub  1
	st   #4
	ld   #5
	suc  0
	st   #5

	sj	 .memcpy.loop

.memcpy.ret:
	popm #16

	popm #1
	popm #0

	ret
