`timescale 1ns/1ps

/* register numbers */
`define REG_A  8'b00
`define REG_BL 8'b01
`define REG_BH 8'b10
`define REG_SL 8'b11

/* address bases */
`define BAS_NO 2'b00
`define BAS_B  2'b01
`define BAS_PC 2'b10
`define BAS_SP 2'b11

/* instruction types */
`define TYP_DIR 1'b0
`define TYP_REF 1'b1
`define TYP_IMM 1'b0
`define TYP_REG 1'b1

/* instruction groups */
`define GRP_ERR 6'b00????
`define GRP_BAS 6'b01????
`define GRP_MEM 6'b010???
`define GRP_FLW 6'b011???
`define GRP_SPC 6'b100???
`define GRP_BLK 6'b101???
`define GRP_ALU 6'b11????

/* instruction opcodes */
`define OPC_LD  6'b010000
`define OPC_ST  6'b010100

`define OPC_JMP 6'b011000
`define OPC_JMC 6'b011100

`define OPC_JAL 6'b100001
`define OPC_RTI 6'b100010
`define OPC_PSH 6'b100011
`define OPC_POP 6'b100100
`define OPC_HLT 6'b100101

`define OPC_INC 6'b101000
`define OPC_DEC 6'b101001
`define OPC_OBT 6'b101011

`define OPC_ADD 6'b110000
`define OPC_ADC 6'b110001
`define OPC_SUB 6'b110010
`define OPC_SUC 6'b110011
`define OPC_SHL 6'b110100
`define OPC_SHR 6'b110101
`define OPC_AND 6'b110110
`define OPC_OR  6'b110111
`define OPC_XOR 6'b111000

`define OPC_STC 6'b111001
`define OPC_TNE 6'b111010
`define OPC_TLT 6'b111011
`define OPC_TGT 6'b111100
`define OPC_TLE 6'b111101
`define OPC_TGE 6'b111110
`define OPC_TEQ 6'b111111

typedef struct packed {
	logic [3:0] group;
	logic [1:0] base;
	logic isref;
	logic isreg;
	logic [7:0] arg;
} inst_t;

interface bus_t ();
	logic        ready;
	logic        ack;
	logic        irq;

	logic [15:0] addr;

	logic        wreq;
	logic [7:0]  wdata;

	logic        rreq;
	logic [7:0]  rdata;

	modport main (
		input  ack,

		output addr,

		output wreq,
		output wdata,

		output rreq,
		input  rdata
	);

	modport sub (
		output ack,

		input  addr,

		input  wreq,
		input  wdata,

		input  rreq,
		output rdata
	);
endinterface

module lmem (clk, addr, wreq, wdata, rdata);
	/*
		low memory: fast memory on 0000--00ff address range
	*/

	input  logic clk;

	input  logic wreq;
	input  logic [7:0] addr, wdata;

	output logic [7:0] rdata;

	logic [7:0] mem [8'hff:0];

	assign rdata = mem[addr];

	always @(posedge clk)
		if (wreq)
			mem[addr] <= wdata;
endmodule

module alu (opc, lop, rop, res, ic, oc);
	input  logic [5:0] opc;
	input  logic [7:0] lop, rop;

	output logic [7:0] res;

	input  logic ic;
	output logic oc;

	always @(*) case (opc)
		default: {oc, res} = 9'b0;
		`OPC_ADD: {oc, res} = {1'b0, lop} + {1'b0, rop};
		`OPC_ADC: {oc, res} = {1'b0, lop} + {1'b0, rop} + {7'b0, ic};
		`OPC_SUB: {oc, res} = {1'b0, lop} - {1'b0, rop};
		`OPC_SUC: {oc, res} = {1'b0, lop} - {1'b0, rop} - {7'b0, ic};
		`OPC_SHL: {oc, res} = {1'b0, lop} << rop;
		`OPC_SHR: {oc, res} = {ic,   lop  >> rop};
		`OPC_AND: {oc, res} = {ic,   lop  & rop};
		`OPC_OR:  {oc, res} = {ic,   lop  | rop};
		`OPC_XOR: {oc, res} = {ic,   lop  ^ rop};

		`OPC_STC: {oc, res} = {|rop,       lop};
		`OPC_TNE: {oc, res} = {lop != rop, lop};
		`OPC_TLT: {oc, res} = {lop <  rop, lop};
		`OPC_TGT: {oc, res} = {lop >  rop, lop};
		`OPC_TLE: {oc, res} = {lop <= rop, lop};
		`OPC_TGE: {oc, res} = {lop >= rop, lop};
		`OPC_TEQ: {oc, res} = {lop == rop, lop};
	endcase
endmodule

module core (clk, rst, hlt, iaddr, idata, bus);
	input  logic clk;
	input  logic rst;

	output logic hlt;

	output logic  [15:0] iaddr;
	input  inst_t        idata;

	bus_t bus;

	/* registers */
	logic c;
	logic [15:1] pc;
	logic [15:0] ic;
	logic [7:0]  a, bl, bh, sl;

	/* dummy registers (combination of the previous) */
	logic [15:0] b, sp;

	/* current instruction */
	logic [5:0] opc;
	inst_t      inst;

  /* predicates (tell what has to be done) */
	logic ready, irq, igirq, rmem, wmem, wreg, hmem;

	/* memory and ALU outputs */
	logic [7:0] lmemres, hmemres, alures;
	logic       aluc;

	/* partial results in instruction processing */
	logic [15:0] base, saddr;
	logic [7:0]  sreg, sarg, sdata, sres;
	logic [7:0]  smem;

	/* next instruction address */
	logic [15:1] npc;

	initial begin
		pc = 15'h01fe >> 1;
		sl = 8'h00;
		a = 0;
		{bh, bl} = 16'h0200;
		c = 0;
		bus.ack = 0;
	end

	/* assign predicates */
	/* access high memory or IO */
	assign hmem = |saddr[15:8];

	/* ignore IRQs */
	assign igirq = |ic;

	/* hadle IRQ */
	assign irq = !igirq && bus.irq;

	/* halt CPU */
	assign hlt = !|idata || opc == `OPC_HLT;

	/* read memory */
	assign rmem = (opc == `OPC_LD &&  inst.isref)               || opc == `OPC_POP;

	/* write memory */
	assign wmem = (opc == `OPC_ST &&  inst.isref)               || opc == `OPC_PSH;

	/* write register */
	assign wreg = (opc == `OPC_ST && !inst.isref && inst.isreg) || opc == `OPC_POP;

	/* fetch next instruction */
	assign ready = !(hmem && (wmem || rmem)) || bus.ack;

	/* assign dummy registers */
	assign sp = {8'b1, sl};
	assign b  = {bh, bl};

	/* get opcode */
	assign opc = {inst.group, inst.group[3] ? inst.base : 2'b00};

	/* get adressing base */
	always @(*) casez (inst.base)
		`BAS_NO: base = 0;
		`BAS_B:  base = b;
		`BAS_PC: base = {pc, 1'b0} - 16'h80;
		`BAS_SP: base = sp;
	endcase

	/* get value of the source register */
	always @(*) casez (inst.arg)
		default: sreg = 0;
		`REG_A:  sreg = a;
		`REG_BL: sreg = bl;
		`REG_BH: sreg = bh;
		`REG_SL: sreg = sl;
	endcase

	/* get instruction argument (reg value or immediate) */
	always @(*) casez (inst.isreg)
		`TYP_IMM: sarg = inst.arg;
		`TYP_REG: sarg = sreg;
	endcase

	/* calculate address used */
	always @(*) casez (opc)
		default:  saddr = {8'b0, sarg};
		`GRP_BAS,
		`OPC_JAL: saddr = {8'b0, sarg} + base;
		`OPC_PSH: saddr = {8'b1, sl - 8'b1};
		`OPC_POP: saddr = sp;
	endcase

	/* get memory value referred by the instruction */
	assign smem = hmem ? hmemres : lmemres;
	lmem lmem (
		.clk(clk),
		.addr(saddr[7:0]),
		.wreq(!hmem && wmem),
		.wdata(sres),
		.rdata(lmemres)
	);

	/* get data used by the instruction */
	always @(*) casez (inst.isref)
		`TYP_REF: sdata = smem;
		`TYP_DIR: sdata = sarg;
	endcase

	/* calculate instruction result (ALU or source data) */
	always @(*) casez (opc)
		default:  sres = a;
		`GRP_ALU: sres = alures;
		`GRP_FLW,
		`OPC_JAL,
		`OPC_LD,
		`OPC_PSH,
		`OPC_POP: sres = sdata;
	endcase
	alu alu (
		.opc(opc),
		.lop(a),
		.rop(sdata),
		.res(alures),
		.ic(c),
		.oc(aluc)
	);

	/* calculate next pc */
	always @(*) if (irq)
		npc = 15'h0200 >> 1;
	else casez (opc)
		default:  npc = pc + 1;
		`OPC_JMP: npc = saddr[15:1];
		`OPC_JMC: npc = c ? saddr[15:1] : pc + 1;
		`OPC_JAL: npc = saddr[15:1];
		`OPC_RTI: npc = ic[15:1] + 1;
	endcase

	/* interract with the data bus */
	assign hmemres   = bus.rdata;
	assign bus.addr  = saddr;
	assign bus.rreq  = hmem && rmem;
	assign bus.wreq  = hmem && wmem;
	assign bus.wdata = sres;

	/* interract with the instruction bus */
	assign inst = idata;
	assign iaddr = {ready ? npc : pc, 1'b0};

	/* switch to the next CPU state */
	always @(posedge clk) begin
		if (ready) begin
			if (irq)
				ic <= {pc, c};
			bus.irq <= 0;
			bus.ack <= 0;
			pc <= npc;
			casez ({wreg, inst.arg})
				default:         ;
				{1'b1, `REG_A}:  a  <= sres;
				{1'b1, `REG_BL}: bl <= sres;
				{1'b1, `REG_BH}: bh <= sres;
				{1'b1, `REG_SL}: sl <= sres;
			endcase
			casez (opc)
				default:  ;
				`OPC_LD:  a <= sres;
				`OPC_JAL: {bh, bl} <= {pc, 1'b0} + 2;
				`OPC_RTI: {c, ic} <= {ic[0], 16'b0};
				`OPC_PSH: sl <= sl - 1;
				`OPC_POP: sl <= sl + 1;
				`OPC_INC: {bh, bl} <= b + 1;
				`OPC_DEC: {bh, bl} <= b - 1;
				`OPC_OBT: {bh, bl, ic} <= {ic, 16'b0};
				`GRP_ALU: {c, a} <= {aluc, sres};
			endcase
		end
	end
endmodule
