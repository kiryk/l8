NPROC = $(shell nproc)
SRC   = os
TLS   = \
	wordle \
	hello

all: obj_dir/Vtb

test: obj_dir/Vtb l8.img
	obj_dir/Vtb

clean:
	rm -r l8.asm *.bin *.img obj_dir las mkfs $(TLS)

las: las.c
	cc -g -Wall -ansi -o las las.c

mkfs: mkfs.c
	cc -g -Wall -ansi -o mkfs mkfs.c

l8.img: mkfs $(TLS)
	./mkfs l8.img -d os -d tools $(TLS)

l8.asm: $(SRC).asm
	cp $< $@

obj_dir/Vtb: tb.sv l8.sv l8.bin
	verilator --build-jobs $(NPROC) --binary $<

%.bin: %.asm las
	./las -o $@ $<

%: %.asm las
	./las -o $@ $<
