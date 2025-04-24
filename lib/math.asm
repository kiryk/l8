; The RNG is LFSR-based, with the generating polynomial:
;   x^16+x^10+x^8+x^6+x^5+x^3+1

math_rng_poly_lo = 069h
math_rng_poly_hi = 005h

math_rng_state_lo: 072h
math_rng_state_hi: 04fh

math_rand:
	; [#1, #0]: pseudorandom number

	pshb

	pshm #2

	; shift lower byte
	sld  #math_rng_state_lo
	shl  1
	st   #0

	; save carry
	ld   0
	adc  0
	st   #2

	; shift upper byte
	sld  #math_rng_state_hi
	shl  1
	or   #2
	st   #1

	sjc  .math_rand16.norm
	sj   .math_rand16.done

.math_rand16.norm:
	xor  math_rng_poly_hi
	st   #1

	ld   #0
	xor  math_rng_poly_lo
	st   #0

.math_rand16.done:
	ld   #0
	sst  #math_rng_state_lo

	ld   #1
	sst  #math_rng_state_hi

	popm #2

	ret


math_seed:
	; [#1, #0]: seed

	pshb

	ld  #0
	sst #math_rng_state_lo

	ld  #1
	sst #math_rng_state_hi

	ret
