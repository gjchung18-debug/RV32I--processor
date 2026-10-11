# RV32I Processor

Two implementations of the RV32I base integer ISA in SystemVerilog, verified with self-checking testbenches and simulated with Icarus Verilog:

1. **Single-cycle processor:** each instruction completes in one clock cycle.
2. **5-stage pipelined processor:** IF, ID, EX, MEM, WB, with forwarding, load-use stalls and branch/jump flushing.

The pipelined design reuses the single-cycle building blocks (`alu`, `imm_gen`, `control_unit`, `register_file`, `data_mem`, `instr_mem`, `pc_reg`) and adds the pipeline registers, forwarding, hazard detection and flush logic.

## Repository Structure

```
.
├── single_cycle/
│   ├── rtl/
│   │   ├── alu_pkg.sv
│   │   ├── alu.sv
│   │   ├── control_unit.sv
│   │   ├── data_mem.sv
│   │   ├── datapath.sv          # single-cycle top level
│   │   ├── imm_gen.sv
│   │   ├── instr_mem.sv
│   │   ├── pc_reg.sv
│   │   └── register_file.sv
│   └── tb/
│       ├── tb_self.sv           # self-checking smoke test
│       └── instructions.hex
├── pipelined/
│   ├── rtl/
│   │   └── pipelined.sv         # pipelined top level, reuses modules from single_cycle/rtl
│   └── tb/
│       ├── tb_pipelined.sv      # self-checking testbench
│       └── pipelined.hex        # 84-instruction test program
├── .gitignore
└── README.md
```

## Requirements

- [Icarus Verilog](https://steveicarus.github.io/iverilog/) (used with `-g2012`)
- [GTKWave](https://gtkwave.sourceforge.net/) (optional, for waveforms)

Run all simulations from the **repository root**. Instruction memory is loaded with `$readmemh` using a relative path, and `instr_mem` takes the hex file as a parameter (`HEX_FILE`), so each design loads its own program:

```systemverilog
// default (single-cycle)
parameter string HEX_FILE = "single_cycle/tb/instructions.hex"

// pipelined.sv overrides it
instr_mem #(.HEX_FILE("pipelined/tb/pipelined.hex")) instr_mem_inst ( ... );
```

---

# Part 1: Single-Cycle Processor

## Overview

All five steps (fetch, decode, execute, memory access, write-back) happen in one clock cycle, so CPI = 1 and the clock period is set by the slowest instruction (a load).

## Modules (`single_cycle/rtl/`)

| Module | Purpose |
|---|---|
| `alu_pkg` | Shared ALU control encodings |
| `alu` | Arithmetic, logic, shifts, signed/unsigned compare |
| `control_unit` | Decodes opcode/funct fields into control signals |
| `imm_gen` | Builds I/S/B/U/J immediates |
| `register_file` | 32 x 32-bit registers, `x0` hardwired to 0 |
| `instr_mem` | Instruction memory loaded from a hex file |
| `data_mem` | Data memory with byte/half/word access |
| `pc_reg` | Program counter |
| `datapath` | Top level that connects the modules together |

## Running

`alu_pkg.sv` must be compiled before the files that use it, so list it first:

```bash
iverilog -g2012 -o sim_single.out \
  single_cycle/rtl/alu_pkg.sv single_cycle/rtl/alu.sv single_cycle/rtl/control_unit.sv \
  single_cycle/rtl/data_mem.sv single_cycle/rtl/imm_gen.sv single_cycle/rtl/instr_mem.sv \
  single_cycle/rtl/pc_reg.sv single_cycle/rtl/register_file.sv single_cycle/rtl/datapath.sv \
  single_cycle/tb/tb_self.sv
vvp sim_single.out
gtkwave dump.vcd        # optional
```

## Testbench (`tb_self.sv`)

A self-checking smoke test that runs a short program on the `datapath` and checks results directly in the register file (`dut.register_file_inst.regfile`):

```systemverilog
check_answer(register_number, expected_value, "test name");
```

`check_answer` reads the register and compares it with the expected value. On a mismatch it raises an `$error` that prints the register, actual value, expected value and test name, and increments `error_count`. At the end the testbench prints `Error count = N`, so `N = 0` means everything passed.

Because the design is single-cycle, each instruction's result is visible one clock after it executes. The testbench releases reset after the first clock, then steps the clock and checks each result 1 ns after the edge (`#1`). A few checks wait extra cycles to line up with when the register is written.

| Check | Instruction | Expected | What it verifies |
|---|---|---|---|
| 1 | `auipc` | `x2 = 0x00800000` | PC-relative address |
| 2 | `lui` | `x1 = 0x12345000` | Upper 20-bit immediate |
| 3 | `sw` then `lw` | `x6 = 0x00800000` | Store to and load from data memory |
| 4 | `add` then `beq` (taken) | `x3 = 0x00800000` | Branch taken |
| 5 | `bne` (not taken) | none (cycles skipped) | Branch not taken falls through |
| 6 | `jal` | `x4 = 0x00000028` | Link address (PC + 4) |
| 7 | `jalr` | `x5 = 0x00000030` | Link address (PC + 4) |

The waveform is written to `dump.vcd`.

**Coverage note:** this test checks `auipc`, `lui`, word `sw`/`lw`, `add`, `beq`, `bne`, `jal` and `jalr`. It does not check the other ALU operations, byte/half loads and stores, the remaining branches, or shifts. The pipelined testbench below covers those.

---

# Part 2: 5-Stage Pipelined Processor

## Overview

The whole pipelined top level is in `pipelined/rtl/pipelined.sv`. It instantiates the shared modules from `single_cycle/rtl/` for the ALU, immediate generator, control unit, register file, instruction memory and data memory.

| Stage | Work done |
|---|---|
| IF | Fetch instruction, compute PC+4 |
| ID | Decode, read registers, generate immediate, detect load-use hazard |
| EX | ALU, branch compare, branch/jump target |
| MEM | Data memory access |
| WB | Write result back to the register file |

## Features

- **Instructions:** `add sub and or xor slt sltu sll srl sra` and their immediate forms, `lui`, `auipc`, `lb lbu lh lhu lw`, `sb sh sw`, `beq bne blt bge bltu bgeu`, `jal`, `jalr`
- **Forwarding:** EX/MEM and MEM/WB into EX, including branch compares and store data (the forwarded `rs2` is latched into EX/MEM)
- **Load-use stall:** one bubble when an instruction depends on a load directly ahead of it
- **Flush:** taken branches, `jal` and `jalr` flush wrong-path instructions; flush has priority over stall
- **Register file:** write-through (WB-to-ID bypass), `x0` always 0
- **`auipc`:** the EX result comes from the branch/jump target adder (`PC + imm`)

## Hazard Priority

```systemverilog
// PC and IF/ID: flush always wins over stall
if (flush)       // redirect PC, clear IF/ID
else if (stall)  // hold PC and IF/ID
else             // PC + 4

// ID/EX: stall and flush both insert a bubble
```

A stall comes from the instruction in ID and a flush comes from an older instruction in EX. The stalled instruction is on the wrong path and is being discarded anyway, so the flush must win.

## Running

The pipelined top level reuses the single-cycle modules, so compile those too, but not `datapath.sv`, which is the single-cycle top level:

```bash
iverilog -g2012 -o sim_pipelined.out \
  single_cycle/rtl/alu_pkg.sv single_cycle/rtl/alu.sv single_cycle/rtl/control_unit.sv \
  single_cycle/rtl/data_mem.sv single_cycle/rtl/imm_gen.sv single_cycle/rtl/instr_mem.sv \
  single_cycle/rtl/pc_reg.sv single_cycle/rtl/register_file.sv \
  pipelined/rtl/pipelined.sv pipelined/tb/tb_pipelined.sv
vvp sim_pipelined.out
gtkwave dump.vcd        # optional
```

A passing run prints no `ERROR:` lines and ends with a `$finish` message. The warning `Not enough words in the file for the requested range [0:1023]` is harmless: the program is 84 words and the memory has 1024.

---

# Pipelined Testbench (`tb_pipelined.sv`)

## How it works

The testbench loads `pipelined.hex`, releases reset, then calls:

```systemverilog
check_ans(reg_number, expected_value, "message");
```

`check_ans` compares a register against its expected value and prints `ERROR: ... Failed! Register number: N, True value: ..., Register value: ...` on a mismatch.

### Phase 1: cycle-exact checks (instructions 0-32)

Instruction `k` is visible in the register file at cycle `k+5`. The testbench steps the clock and checks each result as it writes back. The first check (`x1 = 0` at "Cycle 4") is an alignment probe: `x1` is still 0 until the first write lands, so it only passes with exactly the right startup timing.

```systemverilog
@(posedge clk); #1;
check_ans(1, 32'h0000_0000, "Cycle 4: Check x1 (x1 = 0)");
@(posedge clk); #1; check_ans(1, 32'h0000_0005, "Cycle 5: addi x1 = 5");
```

### Phase 2: final-state checks

After instruction 32, stalls and flushes make the cycle count design-dependent. The program ends in `jal x0, 0` (an infinite self-loop that writes nothing), so once it parks, all registers are stable. The testbench waits for it to finish and checks every register back to back.

Instead of counting cycles, you can wait for the halt address (`0x14C`):

```systemverilog
wait (dut.pc == 32'h0000_014C);
repeat (6) @(posedge clk); #1;   // let the last writebacks drain
```

## Test program (`pipelined.hex`)

84 instructions, starting at `0x00` and halting at `0x14C`.

| Instructions | Section | What it exercises |
|---|---|---|
| 0-1 | Setup | `x1 = 5`, `x2 = -3` |
| 2-19 | ALU | All R-type and I-type ALU ops, with back-to-back dependencies (forwarding) |
| 20-21 | Upper immediates | `lui`, `auipc` |
| 22-24 | Constants | `x23 = 0x40` (base address), `x24 = 0x8081F2F3` |
| 25-32 | Load/store | `sw`, then `lw lb lbu lh lhu` (sign and zero extension) |
| 33-37 | Load-use | `lw` then dependent `add`; `lw` then `sw`; store-then-load |
| 38-46 | Setup | Clear flag registers, set `x5 = x6 = 7` |
| 47-60 | Branches | `beq` `bne` `blt` `bltu` `bgeu` `bge`, taken and not taken, signed vs unsigned |
| 61-65 | Jumps | `jal` and `auipc` + `jalr` (link address and flush) |
| 66-70 | Loop | Backward `bne` taken twice, 3 iterations |
| 71-73 | Load into branch | `lw` then `beq` using the loaded value |
| 74-80 | Sub-word stores | `sw`, `sb`, `sh`, read back with `lw lb lhu` |
| 81-83 | Finish | `addi x0,x0,5` (`x0` must stay 0), `add`, halt |

Wrong-path instructions after taken branches write marker values (`0x111`, `0x222`, ... `0x777`) into registers that must end as 0, so a missing flush shows up as a nonzero value.

## Expected final register values

| Reg | Value | Why |
|---|---|---|
| x0 | `0x00000000` | Hardwired zero |
| x1 | `0x8081F2F3` | `lw` of the stored word |
| x2 | `0x0103E5E6` | `add x1,x1` after a load-use stall |
| x3, x4 | `0x8081F2F3` | `lw` / store-then-load round trip |
| x5, x6 | `0x00000007` | Branch operands |
| x7, x11, x13, x14, x16, x20, x27 | `0x00000000` | Flushed wrong-path writes |
| x8 | `0x00000001` | `bne` not taken, next instruction runs |
| x9 | `0xFFFFFFFF` | -1 |
| x10, x12 | `0x00000001` | Set to 1 |
| x15 | `0x000000F8` | `jal` link address |
| x17 | `0xFFFFFFFF` | Unchanged since `srai` |
| x18 | `0x000000FC` | `auipc` at PC `0xFC` |
| x19 | `0x00000104` | `jalr` link address |
| x21 | `0x00000000` | `add x0,x0` |
| x22 | `0x00000000` | Loop counter reached 0 |
| x23 | `0x00000040` | Data base address |
| x24 | `0x8081F2F3` | Constant |
| x25 | `0x00000006` | Loop ran 3 times (+2 each) |
| x26 | `0x8081F2F3` | `lw` |
| x28 | `0x0000FFFF` | `sh` then `lhu` |
| x29 | `0xFFFFFFFF` | -1 |
| x30 | `0xFFFFFF00` | `sw 0`, `sb @+1`, `sh @+2`, then `lw` |
| x31 | `0xFFFFFFFF` | `lb` of the `0xFF` byte (sign-extended) |

## Debugging guide

| Failing register | Likely cause |
|---|---|
| x7, x11, x13, x14, x16, x20, x27 nonzero | Flush bug (wrong-path instruction executed) |
| x2, x4, x26 | Load-use stall or forwarding bug |
| x22, x25 wrong, or later registers garbage | Backward branch bug; check that flush wins over stall |
| x30, x31 | Store data forwarding or byte-enable bug |
| x18, x19, x22 (cycle 26) | `auipc` not adding the PC |
| x10, x12, x14 | Branch condition polarity (`bge` / `bltu`) |

If every check is off by one cycle, shift the startup `repeat (N) @(posedge clk)` before the first check.

## Bugs found during development

- `auipc` returned only the immediate; fixed by using the branch/jump target adder (`PC + imm`) as the EX result.
- `bge` and `bltu` had inverted branch conditions.
- A stall in the same cycle as a taken branch blocked the PC redirect; fixed by giving flush priority over stall.
- `sb` stored a stale register value because EX/MEM took the unforwarded `rs2`; fixed by latching the forwarded operand.

## Limitations

- The test is one directed program, not a proof of correctness. Corner cases such as shifts by 0 or 31, `INT_MIN`, `slt` with equal operands and `jalr` with a negative offset are not covered.
- `fence`, `ecall` and `ebreak` are not tested.
- The load-use stall is conservative: it can also stall a `lw` followed by a `sw` that only needs the data in MEM.
- A random-instruction comparison against a reference model (for example Spike) would give more confidence.
