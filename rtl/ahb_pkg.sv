package ahb_pkg;

    typedef enum logic [1:0] {
        IDLE = 2'b00, 
        NONSEQ = 2'b10,
        SEQ = 2'b11,
        BUSY = 2'b01
    } htrans_t;


    localparam logic [31:0] SRAM_BASE = 32'h0000_0000;
    localparam logic [31:0] CNN_CRTL_BASE = 32'h4000_0000;
    localparam logic [31:0] UART_BASE = 32'h4000_1000; // have to decide a upper limit to the uart address

    // cnn accelerator control registers
    localparam logic [31:0] CONTROL_REG = 32'h4000_0000; 
    localparam logic [31:0] STATUS_REG = 32'h4000_0004; // read only
    localparam logic [31:0] IMAGE_ADDR = 32'h4000_0008;
    localparam logic [31:0] WEIGHT_ADDR	= 32'h4000_000C; 
    localparam logic [31:0] RESULT_ADDR	= 32'h4000_0010; 


endpackage