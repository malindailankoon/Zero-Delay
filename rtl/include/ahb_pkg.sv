package ahb_pkg;

    typedef enum logic [1:0] {
        IDLE = 2'b00, 
        NONSEQ = 2'b10,
        SEQ = 2'b11,
        BUSY = 2'b01
    } htrans_t;


endpackage