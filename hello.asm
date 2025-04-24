offset 02000h

start:
	ld  .message
	st  #0
	ldh .message
	st  #1
	call puts

	ret

.message: "hello, world\n" 0

include "lib/io.asm"
