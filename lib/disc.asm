disc_sel = 0ffc0h
disc_cmd = 0ffc1h
disc_buf = 0fc00h

disc_fat = 0ee00h

disc_fat_sector  = 0
disc_root_sector = 1

disc_load_sector:
	; #0: sector number

	pshb

	ldb  disc_sel
	ld   #0
	st   #b

	ld   #sp

	inc
	ld   1
	st   #b

	ret



disc_next_sector:
	; #0: sector number
	; #0 = next sector number
	; c  = set next exists

	pshb

	ldb  disc_fat
	ld   #0
	ld   #b+a
	tne  0ffh

	st   #0

	ret



disc_next_entry:
	; [#1, #0]: entry ptr
	; [#1, #0]: next _nonepty_ entry ptr
	; c = set if found

	pshb

	pshm #2

.disc_next_entry.loop:
	ld   #0
	add  32    ; 32 = folder entry size
	st   bl
	st   #0

	ld   #1
	adc  0
	st   bh
	st   #1

	ld   #b+30 ; +30 = sector number offset
	st   #2

	teq  0ffh
	jc   .disc_next_entry.loop

	ld   #2
	tne  000h  ; check if we're dandy

	popm #2
	ret



disc_load_fat:
	pshb

	ld   disc_fat_sector
	st   #0
	call disc_load_sector

	ldb  disc_fat
	ld   bl
	st   #0
	ld   bh
	st   #1

	ldb  disc_buf
	ld   bl
	st   #2
	ld   bh
	st   #3

	ld   0
	st   #4
	ld   2
	st   #5
	call memcpy

	ret



disc_load_file:
	; #0:       first sector
	; [#3, #2]: dst ptr

	pshb

; init local vars
	ld   #0
	st   #6

	ld   #2
	st   #7

	ld   #3
	st   #8

; routine body
.disc_load_file.loop:
	ld   #6
	st   #0
	call disc_load_sector

	ldb  disc_buf
	ld   bl
	st   #2
	ld   bh
	st   #3

	ld   #7
	st   #0
	ld   #8
	st   #1

	ld   0
	st   #4
	ld   2
	st   #5
	call memcpy

	ld   #8
	add  2
	st   #8

	ld   #6
	st   #0
	call disc_next_sector

	st   #6

	jc   .disc_load_file.loop

	ret
