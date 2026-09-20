# Software Integration Guide

This document outlines the critical steps required to bridge the gap between our SystemVerilog hardware design and the C code that will actually run on the SCR1 CPU.

## 1. The Boot Process & Reset Vector
When the FPGA is powered on and the CPU reset line (`rst_n`) is released, the CPU must fetch its very first instruction. 
*   **The Reset Vector:** The SCR1 is configured to look at a specific memory address immediately upon boot (usually `0x0000_0000`, though this is configurable via SystemVerilog parameters).
*   **Hardware Implication:** Our AHB Bus Arbiter must map the Shared SRAM to this exact address space (`0x0000_0000`). If the CPU boots looking for code at zero, but our memory isn't mapped there, the CPU will instantly crash.

## 2. Startup Assembly (`crt0.S`)
Before the CPU can execute a standard C `main()` function, it must initialize its core environment using a small snippet of RISC-V assembly code, typically called `crt0.S` (C Run-Time 0).
This code is responsible for:
1.  **Setting the Stack Pointer (`sp`):** C code requires a stack for local variables and function calls. The startup code must initialize the `sp` register, ideally pointing it to the top of our high-speed **TCM (Tightly Coupled Memory)** at `0x0048_FFFF`.
2.  **Setting up Interrupts:** It must configure the `mtvec` (Machine Trap-Vector Base-Address) register to point to our Interrupt Service Routine (ISR) so the CPU knows where to jump when the CNN Accelerator asserts its `DONE` signal.
3.  **Jumping to Main:** Once the environment is safe, it executes a `call main` instruction.

## 3. The Compilation Toolchain
To write software for the SCR1, we cannot use a standard PC compiler. We must cross-compile it for the RISC-V architecture.
*   **The Compiler:** We will use a bare-metal RISC-V GCC toolchain (e.g., `riscv64-unknown-elf-gcc`).
*   **The Output:** The compiler generates an `.elf` (Executable and Linkable Format) file.

## 4. FPGA Memory Pre-loading
The FPGA does not have a hard drive to load the `.elf` file from. The code must be permanently burned into the Shared SRAM (BRAMs) when the FPGA turns on.
*   **File Conversion:** We use a tool like `riscv64-unknown-elf-objcopy` to extract the raw machine code from the `.elf` file and convert it into a simple `.hex` or `.mif` (Memory Initialization File) text format.
*   **Synthesis Integration:** In our FPGA design software (like Vivado or Quartus), we configure our BRAM IP block to read this `.hex` file. When the FPGA is programmed, the BRAM is automatically pre-loaded with our compiled C code, allowing the CPU to boot instantly.
