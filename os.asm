os:
; ===============================================
; Init filesystem and say hello
; ===============================================
.os.start:
	call disc_load_fat

	call os_load_root

	ld   os_hello
	st   #0
	ldh  os_hello
	st   #1
	call puts


; ===============================================
; Get command
; ===============================================
.os.getcmd:
	ld   os_prompt
	st   #0
	ldh  os_prompt
	st   #1
	call puts

	ld   os_input
	st   #0
	ldh  os_input
	st   #1
	call gets

	; cut off the first token
	ld   ' '
	st   #2
	call strchr
	sjc  .os.cut
	sj   .os.skipcut

.os.cut:
	ldb  os_input
	ld   bl
	add  #0
	st   bl
	add  1
	st   #16
	ld   bh
	adc  0
	st   bh
	st   #17
	ld   0
	st   #b

.os.skipcut:
	ld   os_input
	st   #0
	ldh  os_input
	st   #1

	ld   os_cmd_list
	st   #2
	ldh  os_cmd_list
	st   #3
	call strcmp
	jc .os.cmd_list

	ld   os_cmd_cd
	st   #2
	ldh  os_cmd_cd
	st   #3
	call strcmp
	jc   .os.cmd_cd

	ld   os_cmd_type
	st   #2
	ldh  os_cmd_type
	st   #3
	call strcmp
	jc   .os.cmd_type

	ld   os_cmd_clear
	st   #2
	ldh  os_cmd_clear
	st   #3
	call strcmp
	jc   .os.cmd_clear

	ld   os_cmd_none
	st   #2
	ldh  os_cmd_none
	st   #3
	call strcmp
	jc   .os.getcmd

	ld   os_cmd_halt
	st   #2
	ldh  os_cmd_halt
	st   #3
	call strcmp
	jc   .os.cmd_halt

	ld   os_cmd_help
	st   #2
	ldh  os_cmd_help
	st   #3
	call strcmp
	jc   .os.cmd_help

	j    .os.tryrun

; ===============================================
; Code of commands
; ===============================================
.os.cmd_list:
	call os_list_files
	j    .os.getcmd

.os.cmd_cd:
	ld   #16
	st   #0
	ld   #17
	st   #1
	call os_find_file

	sjc  .os.cmd_cd.found
	j    .os.getcmd

.os.cmd_cd.found:
	ldb  os_folder_buff
	ld   bl
	st   #2
	ld   bh
	st   #3
	call disc_load_file

	j    .os.getcmd

.os.cmd_type:
	ld   #16
	st   #0
	ld   #17
	st   #1
	call os_find_file

	sjc  .os.cmd_type.found
	j    .os.getcmd

.os.cmd_type.found:
	ldb  os_file_buff
	ld   bl
	st   #2
	ld   bh
	st   #3
	call disc_load_file

	ldb  os_file_buff
	ld   bl
	st   #0
	ld   bh
	st   #1
	call puts

	j    .os.getcmd

.os.cmd_clear:
	ldb  os_clear
	ld   bl
	st   #0
	ld   bh
	st   #1
	call puts

	j    .os.getcmd

.os.cmd_help:
	ld   os_help
	st   #0
	ldh  os_help
	st   #1
	call puts

	j    .os.getcmd

.os.cmd_halt:
	hlt

.os.tryrun:
	ldb  os_input
	ld   bl
	st   #0
	ld   bh
	st   #1
	call os_find_file
	sjc  .os.tryrun.run

	ldb  os_unknown
	ld   bl
	st   #0
	ld   bh
	st   #1
	call puts
	j    .os.getcmd

.os.tryrun.run:
	ldb  os_file_buff
	ld   bl
	st   #2
	ld   bh
	st   #3
	call disc_load_file

	ldb  .os.getcmd
	psh  bl
	psh  bh
	call os_file_buff

	j    .os.getcmd


; ===============================================
; Filesystem routines
; ===============================================
os_load_root:
	pshb

	ld   disc_root_sector
	st   #0

	ldb  os_folder_buff
	ld   bl
	st   #2
	ld   bh
	st   #3

	call disc_load_file

	ret


os_list_files:
	pshb

	ldb  os_folder_buff
	ld   bl
	st   #0
	ld   bh
	st   #1

	ld   #b+30
	teq  000h
	jc   .os_list_files.ret

.os_list_files.loop:
	call puts

	ld   #0
	st   #2

	ld   #0
	st   bl
	ld   #1
	st   bh
	ld   #b+31
	and  00000001b
	stc  a
	jc   .os_list_files.dir
	j    .os_list_files.eol

.os_list_files.dir:
	ld   '/'
	st   #0
	call putc

.os_list_files.eol:
	ld   '\t'
	st   #0
	call putc

	ld   #2
	st   #0
	call disc_next_entry

	jc   .os_list_files.loop

.os_list_files.ret:
	ld   '\n'
	st   #0
	call putc

	ret


os_find_file:
	; [#1, #0]: filename
	; #0 = first sector number
	; c  = set if found

	pshb

	pshm #16
	pshm #17

	ld   #0
	st   #16
	ld   #1
	st   #17

	ldb  os_folder_buff
	ld   bl
	st   #0
	ld   bh
	st   #1

	ld   #b+30    ; +30 = sector number offset
	teq  000h
	jc   .os_find_file.ret

.os_find_file.loop:
	ld   #16
	st   #2
	ld   #17
	st   #3
	call strcmp
	jc   .os_find_file.found

	call disc_next_entry
	jc   .os_find_file.loop
	j    .os_find_file.ret

.os_find_file.found:
	ld   #0
	st   bl
	ld   #1
	st   bh

	ld   #b+30    ; +30 = sector number offset
	st   #0

.os_find_file.ret:
	popm #17
	popm #16

	ret


; ===============================================
; Library includes
; ===============================================
include "lib/io.asm"
include "lib/mem.asm"
include "lib/disc.asm"
include "lib/string.asm"


; ===============================================
; Data section
; ===============================================
os_prompt:  "] " 0
os_unknown: "unknown command\n" 0
os_hello:   "\n"
            "  Toucan OS\n"
            "     0.1\n"
            "\n"
						"Run 'help' for help\n" 0
os_clear:   "\e[2J\e[H" 0
os_input:   "                "
            "                "
            "                "
            "                " 0
os_help:    "To run a binary type its filename\n\n"
            "cd [filename]: change directory\n"
						"clear: clear screen\n"
						"halt: halt cpu execution\n"
						"help: display this message\n"
            "ls: list contents of the current directory\n"
						"tp: [filename]: type file contents\n" 0

os_cmd_none:  "" 0
os_cmd_cd:    "cd" 0
os_cmd_list:  "ls" 0
os_cmd_type:  "tp" 0
os_cmd_clear: "clear" 0
os_cmd_halt:  "halt" 0
os_cmd_help:  "help" 0

os_folder_buff = 01b00h
os_file_buff   = 02000h
