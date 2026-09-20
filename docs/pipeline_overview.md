# CNN Accelerator: Final Pipeline Overview

This document summarizes the complete, hardware-optimized 1-Layer, 8-Filter CNN pipeline. The architecture is designed to maximize throughput using a **Zero-Write Fused Pipeline**, eliminating the need to write intermediate feature maps back to main memory.

## 1. Physical Hardware Allocations

To achieve stall-free operation (with one minor exception), the accelerator allocates the following intermediate storage on-chip:

*   **Convolution Line Buffers (4x 28-Byte FIFOs):** 
    *   Named `LB0`, `LB1`, `LB2`, and `LB3`.
    *   *Purpose:* Holds rows of the image. While the Convolution MAC reads from 3 buffers to form the 3x3 window, the DMA quietly fills the 4th buffer in the background. This "ping-pong" rotation ensures the MAC array never stalls between rows.
*   **Max-Pool Line Buffer (1x 26-Byte FIFO):** 
    *   *Purpose:* Holds the output of the Convolution MAC for exactly one row. Because Max Pooling requires a 2x2 window, the comparator needs the current MAC output pixel AND the pixel directly above it from the previous row.
*   **Dense Weight Prefetch Buffer (7x 10-Byte FIFOs):** 
    *   Named `DW0` through `DW6`.
    *   *Purpose:* A deep reservoir for the Fully Connected weights. The DMA aggressively fills this buffer during its idle time so the Dense MAC has weights ready the instant a pooled pixel is generated.

## 2. The Dataflow (Step-by-Step)

The pipeline is completely fused. Once the image goes in, it flows through all 4 stages continuously without touching main SRAM until the final probabilities are computed.

### Stage 1: Fetch & Convolution
*   **The DMA** fetches a 32-bit word (4 image pixels) per clock cycle and shifts them into the active Convolution Line Buffer (`LBx`).
*   **The Conv MAC** pulls a 3x3 grid of pixels from the three active line buffers and multiplies them by the 9 Convolution Weights (fetched only once at the start of the filter pass).
*   *Output:* 1 intermediate pixel (representing the convolution result) per clock cycle.

### Stage 2: Activation (ReLU)
*   **The Hardware:** A simple combinational sign-bit check immediately follows the Conv MAC.
*   *Output:* If the Stage 1 pixel is negative, it becomes `0`. Otherwise, it passes through untouched.

### Stage 3: Max Pooling
*   **The Router:** The ReLU pixel is routed simultaneously to the Max Pool Circuit AND pushed into the Max-Pool Line Buffer (to be saved for the next row).
*   **The Circuit:** When on an even row and even column, the circuit compares 4 pixels (current pixel, previous pixel, and the two pixels above them from the Max-Pool Line Buffer). 
*   *Output:* 1 "winning" pixel. This only happens once every 2 columns and once every 2 rows.

### Stage 4: Dense (Fully Connected) Layer
*   **The Trigger:** As soon as Stage 3 outputs a winning pooled pixel, the Dense MAC activates.
*   **The Execution:** It pulls 10 weights from the Dense Weight Prefetch Buffer (`DWx`). It multiplies the pooled pixel by all 10 weights and adds the results to the 10 permanent output registers (`Reg0` through `Reg9`).
*   **The 32-bit Stall:** Because fetching 10 weights over a 32-bit bus takes 3 clock cycles, the DMA cannot keep up when pooling is active. If the `DWx` buffer runs empty, a 1-cycle `global_stall` is asserted, cleanly freezing Stages 1, 2, and 3 until the DMA catches up.

### Stage 5: ArgMax & Output
*   After the entire 28x28 image has been processed across all 8 filters, the pipeline halts.
*   The 10 output registers contain the final confidence scores for digits 0-9.
*   A simple comparator finds the register with the highest value and writes that single digit (e.g., `7`) to the `RESULT_ADDR` in the Shared SRAM.
*   The accelerator fires the CPU Interrupt, and the classification is complete!
