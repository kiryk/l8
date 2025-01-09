`include "l8.sv"

task automatic readmem(string filename, integer base, ref logic [7:0] mem []);
	integer fd = $fopen(filename, "rb");
	bit [7:0] word;

	for (integer i = 0; !$feof(fd); i++) begin
		$fread(word, fd);
		mem[base+i] = word;
	end
endtask

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
