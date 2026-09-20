# Syntacore SCR1 CPU Reference

This document serves as a living reference for the Syntacore SCR1 RISC-V core used in our CNN Accelerator project. We will update it as we learn more about the CPU and its integration.

## 1. External Interfaces

The SCR1 is designed as a microcontroller core for System-on-Chip (SoC) integration. It interacts with external components via the following primary interfaces:

### A. The System Bus Interface
This is the primary interface used by the CPU to execute `Load` or `Store` instructions to read/write memory or communicate with peripherals.
*   **Protocols Supported:** Configurable as either 32-bit AHB-Lite or 32-bit AXI4. **Decision:** We are using **32-bit AHB-Lite**. It is significantly simpler to implement custom DMA and Arbitration logic for AHB-Lite compared to AXI4, while still providing more than enough bandwidth for a single-cycle SRAM interface.
*   **Role:** The CPU acts as an **AHB Master** on this bus, initiating read and write transactions.
*   **Project Context:** This interface connects to the Bus Arbiter. The CPU will use this bus to write to the CNN Accelerator's memory-mapped control registers (e.g., to send the `START` command) and to access the Shared Memory.

#### Detailed Port List (AHB-Lite)
The SCR1 top-level wrapper (`scr1_top_ahb.sv`) exposes **two physically separate** AHB-Lite Master ports. This is known as a Modified Harvard Architecture physically.

**1. Data Memory Master (`dmem_`)**
Used to read/write the Shared SRAM and the Accelerator Control Registers.
*   **Outputs (CPU -> Arbiter):**
    *   `dmem_haddr [31:0]` : Address to read/write.
    *   `dmem_hwrite` : `1` for Write, `0` for Read.
    *   `dmem_hwdata [31:0]` : Data to be written.
    *   `dmem_htrans [1:0]` : Transfer type.
    *   `dmem_hsize [2:0]` : Size of transfer.
    *   `dmem_hburst [2:0]` : Burst type.
    *   `dmem_hprot [3:0]` : Protection control.
    *   `dmem_hmastlock` : Locked transfer.
*   **Inputs (Arbiter -> CPU):**
    *   `dmem_hrdata [31:0]` : Data read from memory.
    *   `dmem_hready` : Handshake signal (`1` = Arbiter ready).
    *   `dmem_hresp` : Response status.

**2. Instruction Memory Master (`imem_`)**
Dedicated entirely to fetching instructions. (Notice there are no write pins).
*   **Outputs (CPU -> Arbiter):**
    *   `imem_haddr [31:0]`, `imem_htrans [1:0]`, `imem_hsize [2:0]`, `imem_hburst [2:0]`, `imem_hprot [3:0]`, `imem_hmastlock`
*   **Inputs (Arbiter -> CPU):**
    *   `imem_hrdata [31:0]`, `imem_hready`, `imem_hresp`

### B. Tightly-Coupled Memory (TCM) Interface
*   **What it is:** An optional, dedicated memory interface that bypasses the main system bus.
*   **Protocol:** It does **not** use AXI or AHB. AHB and AXI have overhead (handshaking, burst signals) meant for complex arbitration. The TCM interface is a very simple, raw SRAM interface (Address, Data In, Data Out, Write Enable). It assumes the memory is always ready and will respond in exactly 1 clock cycle.
*   **Implementation (SystemVerilog):** In the provided `scr1_top_ahb.sv` top-level wrapper, the TCM SRAM array is actually instantiated **internally** (via `scr1_tcm.sv`) if the `SCR1_TCM_EN` macro is defined. The internal router seamlessly splits memory traffic between the internal TCM and the external AHB ports. **There are no external TCM wires coming out of the top-level block.**
*   **Hardware Mapping (FPGA):** Physically on the FPGA, both the internal TCM and our external Shared Memory will be synthesized into the exact same hardware primitives: **Block RAMs (BRAMs)**. The difference is purely in the logic surrounding them:
    *   **TCM BRAMs:** Wired directly inside the CPU wrapper with zero arbitration logic in between. Fast and private.
    *   **Shared Memory BRAMs:** Wired externally through our Bus Arbiter, which adds latency but allows both the CPU and the Accelerator to access it.
*   **Address Mapping:** The TCM is hardcoded in the core's internal router to occupy a 64 KB block spanning from **`0x00480000` to `0x0048FFFF`**. Any CPU request (instruction fetch or data load/store) falling into this range is routed to the internal TCM. All other addresses are routed out to the external AHB space.
*   **Purpose:** Provides guaranteed **single-cycle access** to connected SRAM. Because it acts as a dual-port memory spanning both the Instruction and Data memory maps, the CPU can fetch instructions from it without colliding with data accesses.
*   **Project Context:** Useful for storing the CPU's stack or critical interrupt service routines (ISRs) so the CPU execution isn't stalled when the CNN Accelerator is heavily utilizing the main System Bus.

### C. Interrupt Interface (IPIC - Integrated Programmable Interrupt Controller)
*   **What it is:** An interface accepting up to 16 external hardware interrupt (`irq_lines`) and a software interrupt (`soft_irq`).
*   **Purpose:** Allows hardware (or software) to asynchronously pause the CPU's current execution and force it to handle an event (via an ISR) instead of relying on inefficient polling. The `soft_irq` is typically used in multi-core systems or by an OS for task scheduling (often triggered by a CLINT).
*   **Project Context:** The CNN Accelerator will have a `DONE` interrupt signal connected to one of the hardware `irq_lines` to notify the CPU when a convolution is complete. Because we are building a bare-metal, single-core system without an OS or CLINT, we will simply tie the `soft_irq` input wire to ground (`1'b0`) in our top-level SystemVerilog module.

### D. Debug Interface
*   **What it is:** A standard JTAG or cJTAG interface.
*   **Purpose:** Used for flashing firmware, setting breakpoints, and stepping through code via a hardware debugger (like OpenOCD).

---
*Document will be updated as the architecture evolves.*
