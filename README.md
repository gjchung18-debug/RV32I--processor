# RV32I Single-Cycle CPU Core (SystemVerilog)

A single-cycle implementation of the RV32I base integer instruction set, built to
understand datapath design, control logic, and hardware verification fundamentals —
with a focus on getting signed/unsigned ALU behavior provably correct via a
self-checking testbench rather than manual waveform inspection.

## Status (as of Sep 2026)

| Area                                             | Status |
|---------------------------------------------------|--------|
| Core datapath (ALU, register file, control unit, immediate generator, PC, instr/data memory) | ✅ Implemented |
| ADD / ADDI / SW / BEQ                              | ✅ Verified via manual waveform inspection (GTKWave) |
| Self-checking testbench (`tb_self.sv`) | ✅ Implemented — automated pass/fail |
| SLT vs. SLTU on signed/unsigned operands           | ✅ Covered |
| SRL vs. SRA (logical vs. arithmetic shift, sign-fill) | ✅ Covered |
| Immediate sign-extension (ADDI with negative imm)  | ✅ Covered |
| LW (verifying against prior SW)                   | 🔄 In progress |
| Branch taken/not-taken, JAL/JALR return address     | 🔄 In progress |
| Byte/halfword load-store alignment, LUI/AUIPC       | ⬜ Not started |
| Multicycle / pipelined refactor with hazard detection | ⬜ Stretch goal |

## Repository structure
.
├── rtl/
│ ├── alu_pkg.sv # Shared parameters/typedefs for ALU
│ ├── alu.sv # ALU: arithmetic, logic, shift, SLT/SLTU
│ ├── control_unit.sv # Instruction decode -> control signals
│ ├── data_mem.sv # Data memory
│ ├── datapath.sv # Top-level datapath wiring
│ ├── imm_gen.sv # Immediate generation (I/S/B/U/J-type)
│ ├── instr_mem.sv # Instruction memory
│ ├── pc_reg.sv # Program counter register
│ └── register_file.sv # 32x32-bit register file
├── tb/
│ ├── instructions.hex # Hand-assembled test program (loaded via $readmemh)
│ └── tb_self.sv # Top-level self-checking testbench
├── .gitignore
└── README.md

## Test program (`tb/instructions.hex`)

The current instruction sequence in `instructions.hex` deliberately targets
signed/unsigned edge cases:

| Addr | Instruction         | Purpose                                              |
|------|----------------------|-------------------------------------------------------|
| 0x00 | `addi x1, x0, -1`   | Load `0xFFFFFFFF` into x1 — sign-extension check      |
| 0x04 | `addi x2, x0, 2`    | Load `0x00000002` into x2 — shift/compare operand     |
| 0x08 | `slt  x3, x1, x2`   | Signed compare: -1 < 2 → true (x3 = 1)                |
| 0x0C | `sltu x4, x1, x2`   | Unsigned compare: 4,294,967,295 < 2 → false (x4 = 0)  |
| 0x10 | `srl  x5, x1, x2`   | Logical shift right: zero-fill from MSB               |
| 0x14 | `sra  x6, x1, x2`   | Arithmetic shift right: sign-fill from MSB            |

This program is the core evidence for the resume claim that SLT/SLTU and
SRA/SRL are explicitly tested against each other using the same operand pair,
so the sign/unsigned distinction is what's actually being checked, not just
two unrelated calculations.

## How to run

```bash
# Compile
iverilog -g2012 -o sim.out rtl/alu_pkg.sv rtl/alu.sv rtl/control_unit.sv \
    rtl/data_mem.sv rtl/datapath.sv rtl/imm_gen.sv rtl/instr_mem.sv \
    rtl/pc_reg.sv rtl/register_file.sv tb/tb_self.sv

# Run simulation
vvp sim.out

```

## Why single-cycle first

Single-cycle was chosen deliberately to build a correct, fully understood
baseline before adding pipelining complexity. Priority has been on datapath
correctness and verification methodology — writing tests that actually catch
bugs — over adding architectural features. A pipelined refactor with hazard
detection is a planned stretch goal once the single-cycle core and its test
coverage are solid.

## Author

Chung Guo Jing — [LinkedIn](https://linkedin.com/in/guojingchung)