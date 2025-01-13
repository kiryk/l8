`include "l8.sv"

task automatic readmem(string filename, integer base, ref logic [7:0] mem []);
	integer fd = $fopen(filename, "rb");
	bit [7:0] word;

	for (integer i = 0; !$feof(fd); i++) begin
		$fread(word, fd);
		mem[base+i] = word;
	end
endtask

module hmem (clk, mem, iaddr, idata, bus);
	/*
		high memory: addresses 00ff--f000
	*/

	input  logic clk;

	ref logic [7:0] mem [];

	input  logic [15:0] iaddr;
	output logic [15:0] idata;

	bus_t  bus;

	logic range = bus.addr >= 16'h0100 && bus.addr < 16'hf000;
	logic [15:0] addr = bus.addr;

	always @(posedge clk) begin
		idata <= {mem[iaddr], mem[iaddr+1]};

		if (range && !bus.ack) begin
			if (bus.wreq || bus.rreq)
				bus.ack <= 1;
			if (bus.wreq)
				mem[addr] <= bus.wdata;
			if (bus.rreq)
				bus.rdata <= mem[addr];
		end
	end
endmodule

module term(clk, bus);
	/*
		fff0: read/write keyboard character
	*/

	input logic clk;
	bus_t bus;

	logic range;
	logic [7:0] ch;

	integer fd;

	initial fd = $fopen("/dev/stdin");

	assign range = bus.addr == 16'hfff0;

	always @(posedge clk) begin
		if (!bus.ack && range) begin
			if (bus.wreq || bus.rreq)
				bus.ack <= 1;
			if (bus.wreq)
				$write("%c", bus.wdata);
			if (bus.rreq) begin
				$c(ch, " = getchar();");
				bus.rdata <= ch;
			end
		end
	end
endmodule

module disc(clk, mem, bus);
	/*
		ffc0:      sector selection
		ffc1:      read (=01)/write(=02) command
		fc00-fdff: disc buffer
	*/

	input logic clk;
	ref logic [7:0] mem [];
	bus_t bus;

	logic setsel, setcmd, setbuf;
	logic [7:0] sel;
	logic [7:0] buff [511:0];

	assign setsel = bus.addr == 16'hffc0;
	assign setcmd = bus.addr == 16'hffc1;
	assign setbuf = bus.addr >= 16'hfc00 && bus.addr < 16'hfe00;

	always @(posedge clk) begin
		if (!bus.ack && (setsel || setcmd || setbuf) && (bus.wreq || bus.rreq))
			bus.ack <= 1'b1;
		if (setsel) begin
			if (bus.rreq)
				bus.rdata <= sel;
			if (bus.wreq)
				sel <= bus.wdata;
		end else if (setbuf) begin
			if (bus.rreq)
				bus.rdata <= buff[bus.addr[8:0]];
			if (bus.wreq)
				buff[bus.addr[8:0]] <= bus.wdata;
		end else if (setcmd) begin
			if (bus.wreq) begin
				if (bus.wdata == 1)
					for (bit [9:0] i = 0; i < 512; i++)
						buff[i[8:0]] <= mem[{sel, i[8:0]}];
				if (bus.wdata == 3)
					for (bit [9:0] i = 0; i < 512; i++)
						mem[{sel, i[8:0]}] <= buff[i[8:0]];
			end
		end
	end
endmodule

module timer(clk, bus);
	/*
		fb00: write read timer value * 256
		fb01: read current simulation $time
	*/

	input logic clk;

	bus_t bus;

	logic        range;
	logic [15:0] cnt;

	assign range = bus.addr ==? 16'hfb0?;

	always @(posedge clk) begin
		if (range)
			bus.ack <= 1;
		if (!bus.ack) begin
			if (bus.addr == 16'hfb00) begin
				if (bus.wreq)
					cnt <= {bus.wdata, 8'b0};
				if (bus.rreq)
					bus.rdata <= cnt[15:8];
			end
			if (bus.addr == 16'hfb01)
				if (bus.rreq)
					bus.rdata <= 8'($time);
		end
		if (cnt == 1)
			bus.irq <= 1;
		if (cnt > 0)
			cnt <= cnt - 1;
	end
endmodule

module top();
	bus_t bus();

	logic clk, hlt;
	logic [15:0] iaddr, idata;
	string memfile;

	logic [7:0] imem [] = new[32'hffff];
	logic [7:0] dmem [] = new[255*512];

	initial begin
		if (!$value$plusargs("mem=%s", memfile))
		   memfile = "l8.bin";
		readmem(memfile, 'h200, imem);
		readmem("l8.img", 'h0, dmem);
		$dumpfile("l8.vcd");
		$dumpvars(0, core);
		clk = 0;
		idata = 16'b1110010000000000;
	end

	core core (
		.clk(clk),
		.rst(1'b0),
		.hlt(hlt),
		.iaddr(iaddr),
		.idata(idata),
		.bus(bus.main)
	);

	hmem hmem (
		.clk(clk),
		.mem(imem),
		.iaddr(iaddr),
		.idata(idata),
		.bus(bus.sub)
	);

	term term (
		.clk(clk),
		.bus(bus.sub)
	);

	disc disc (
		.clk(clk),
		.mem(dmem),
		.bus(bus.sub)
	);

	timer timer (
		.clk(clk),
		.bus(bus.sub)
	);

	always #1 clk = ~clk;

	always @(posedge clk)
		if (hlt) begin
			$strobe("time: %d", $time);
			$finish;
		end
endmodule
