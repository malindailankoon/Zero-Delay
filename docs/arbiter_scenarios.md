# AHB-Lite Multi-Master Arbitration Scenarios

This document provides a detailed, cycle-by-cycle breakdown of how our custom AHB-Lite Arbiter handles various multi-master contention scenarios on the bus.

## Master Hierarchy Reference
1. **Master A (CPU Data)** - Highest Priority
2. **Master B (CPU Instr)** - Medium Priority
3. **Master C (DMA Engine)** - Lowest Priority

---

## Scenario 1: Simultaneous Wake-up (Contention on Idle Bus)
**Situation:** The bus is idle. Master A (CPU) and Master C (DMA) both decide to initiate a single read on the exact same clock edge.

*   **Cycle 0 (Combinational Request)**
    *   **Master A:** Asserts `htrans = NONSEQ`, `haddr = 0xA`.
    *   **Master C:** Asserts `htrans = NONSEQ`, `haddr = 0xC`.
    *   **Arbiter:** The priority encoder instantly grants Master A (`grant_A = 1`, `grant_C = 0`).
    *   **Routing:** Address A is routed to the Slave.
    *   **Stall Logic:** Because `grant_A = 1` and `reg_grant_A = 0`, Master A's `hready` receives the Slave's `hready` (which is `1` because the Slave is idle). Because `grant_C = 0` and `reg_grant_C = 0`, Master C is fed `hready = 0`.
*   **Cycle 1 (Rising Edge)**
    *   **Master A:** Sees `hready = 1`. Knows its address was accepted. Transitions to the Data Phase (`htrans = IDLE`).
    *   **Master C:** Sees `hready = 0`. Knows its address was NOT accepted. Freezes its state machine and continues holding `htrans = NONSEQ` and `haddr = 0xC`.
    *   **Arbiter Registers:** Update to `reg_grant_A = 1`, `reg_grant_C = 0`.
*   **Cycle 1 (Combinational Data Phase)**
    *   **Slave:** Begins fetching Data A.
    *   **Arbiter:** Because Master A dropped its request (`htrans = IDLE`), the priority encoder sees only Master C requesting. It switches grants: `grant_A = 0`, `grant_C = 1`.
    *   **Routing:** Address C is routed to the Slave.
*   **Cycle 2 (Rising Edge)**
    *   **Slave:** Completes Data A fetch. Outputs `hrdata = Data A` and asserts `hready = 1`.
    *   **Master A:** Because `reg_grant_A = 1`, it receives `hready = 1`. It successfully latches Data A. It is done.
    *   **Master C:** Because `grant_C = 1` (from Cycle 1), it ALSO receives `hready = 1`. It knows its address was accepted by the Slave. It transitions to the Data Phase (`htrans = IDLE`).
    *   **Arbiter Registers:** Update to `reg_grant_A = 0`, `reg_grant_C = 1`.
*   **Cycle 3 (Rising Edge)**
    *   **Slave:** Completes Data C fetch. Outputs `hrdata = Data C` and asserts `hready = 1`.
    *   **Master C:** Because `reg_grant_C = 1`, it receives `hready = 1`. It latches Data C. It is done.

---

## Scenario 2: High Priority Master Interrupts Low Priority Burst
**Situation:** Master C (DMA) is actively executing a long multi-beat Burst Read (SEQ). Suddenly, Master A (CPU) requests the bus.

*   **Cycle 0 (DMA is bursting)**
    *   **Master C (DMA):** Is in the Data Phase for Pixel 1 (`reg_grant_C = 1`), and is broadcasting the Address Phase for Pixel 2 (`htrans = SEQ`, `haddr = Pixel 2`).
    *   **Arbiter:** `grant_C = 1`. Address Pixel 2 is routed to the Slave.
*   **Cycle 1 (Rising Edge - CPU Wakes Up)**
    *   **Slave:** Finishes Data Phase for Pixel 1 (`hready = 1`).
    *   **Master C (DMA):** Latches Pixel 1. Address Phase for Pixel 2 is accepted. Broadcasts Address Phase for Pixel 3 (`haddr = Pixel 3`).
    *   **Master A (CPU):** Suddenly wakes up and requests! (`htrans = NONSEQ`, `haddr = CPU Addr`).
*   **Cycle 1 (Combinational Arbitration)**
    *   **Arbiter:** Priority Encoder sees both Master A and Master C requesting. Master A wins!
    *   **Grants:** `grant_A = 1`, `grant_C = 0`. 
    *   **Routing:** The CPU Addr is routed to the Slave (overwriting Pixel 3).
    *   **Stall Logic:** Master C is in its Data Phase for Pixel 2 (`reg_grant_C = 1`), so it still receives the Slave's `hready`. Master A is in its Address Phase (`grant_A = 1`), so it ALSO receives the Slave's `hready`.
*   **Cycle 2 (Rising Edge)**
    *   **Slave:** Finishes Data Phase for Pixel 2 (`hready = 1`).
    *   **Master C (DMA):** Latches Pixel 2. However, because `grant_C` was 0, it realizes its Address Phase for Pixel 3 was **rejected**. It freezes its Address Phase (`haddr = Pixel 3`).
    *   **Master A (CPU):** Sees `hready = 1`. Its Address Phase is accepted! It moves to its Data Phase (`htrans = IDLE`).
    *   **Arbiter Registers:** Update to `reg_grant_A = 1`, `reg_grant_C = 0`.
*   **Cycle 2 (Combinational Data Phase)**
    *   **Slave:** Begins fetching CPU Data.
    *   **Arbiter:** Because Master A dropped to `IDLE`, Master C wins priority again. `grant_C = 1`. 
    *   **Routing:** Pixel 3 Address is finally routed to the Slave.
    *   **Stall Logic:** Because Master C is no longer in its Data Phase (`reg_grant_C = 0`), but IS in its Address Phase (`grant_C = 1`), it receives the Slave's `hready` (which is `0` while fetching CPU data, then `1` when done).
*   **Cycle 3 (Rising Edge)**
    *   **Slave:** Completes CPU Data fetch. Outputs `hready = 1`.
    *   **Master A (CPU):** Latches its data. Done.
    *   **Master C (DMA):** Sees `hready = 1`. Its Pixel 3 address is finally accepted! The DMA burst resumes flawlessly.

---

## Scenario 3: Low Priority Master Requests while High Priority is Active
**Situation:** Master A (CPU) is actively executing a burst transfer. Master C (DMA) requests the bus.

*   **Cycle 0 (CPU is bursting)**
    *   **Master A (CPU):** Is actively bursting (`htrans = SEQ`, `reg_grant_A = 1`).
    *   **Master C (DMA):** Wakes up and requests (`htrans = NONSEQ`, `haddr = DMA Addr`).
    *   **Arbiter:** The priority encoder sees both requests. Master A is higher priority. `grant_A = 1`, `grant_C = 0`.
*   **Cycle 1 (Rising Edge)**
    *   **Master C (DMA):** Because `grant_C = 0` and `reg_grant_C = 0`, its `hready` is hardwired to `0`. It instantly freezes on its very first cycle.
    *   **Master A (CPU):** Continues its burst without ever knowing the DMA requested the bus.
*   **Subsequent Cycles**
    *   The DMA remains frozen with `hready = 0` indefinitely until Master A completes its final Data Phase and sets `htrans = IDLE`. 
    *   Once Master A goes IDLE, the priority encoder updates, `grant_C` becomes `1`, and the DMA is finally allowed to begin its Address Phase.
