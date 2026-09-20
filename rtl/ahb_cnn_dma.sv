module ahb_cnn_dma import ahb_pkg::*; (
    input logic clk, rstn,
    ahb_if.master dma,
    output logic [31:0] data,
    output logic data_valid, // signify the cnn that the data line has valid data
    input logic [31:0] im_addr, wei_addr, rs_addr,
    input logic [31:0] rslt_data,
    input logic rd_image, rd_weight, wrt_result,
    output logic ready,
    input logic reset_r
);

    logic [31:0] img_offset, weigh_offset, next_img_offset, next_weigh_offset;
    logic [31:0] next_haddr, next_hwdata;
    logic next_hwrite;
    htrans_t next_htrans;

    assign dma.hburst = '0;
    assign dma.hprot = '0;
    assign dma.hmastlock = '0;
    assign dma.hsel = '0;
    assign dma.hsize = 3'b010;
    assign data = dma.hrdata;

    

    typedef enum logic [2:0] {
        SIDLE,
        IMG_ADDR,
        IMG_DATA,
        WEI_ADDR,
        WEI_DATA,
        RSLT_ADDR,
        RSLT_DATA
    } state_t;

    state_t current_state, next_state;

    always_ff @(posedge clk) begin
        if (~rstn) begin
            current_state <= SIDLE;
            dma.haddr <= '0;
            dma.hwrite <= 0;
            dma.htrans <= IDLE;
            dma.hwdata <= '0;
            img_offset <= '0;
            weigh_offset <= '0;
        end else begin
            current_state <= next_state;
            dma.haddr <= next_haddr;
            dma.hwrite <= next_hwrite;
            dma.htrans <= next_htrans;
            dma.hwdata <= next_hwdata;
            img_offset <= next_img_offset;
            weigh_offset <= next_weigh_offset;
        end
    end

    assign data_valid = (current_state inside {IMG_DATA, WEI_DATA, RSLT_DATA}) && dma.hready;


    always_comb begin
        next_state = current_state;
        next_haddr = '0;
        next_hwrite = 0;
        next_htrans = IDLE;
        next_hwdata = '0;
        next_img_offset = img_offset;
        next_weigh_offset = weigh_offset;

        case (current_state) 
            SIDLE: begin
                if (reset_r) begin
                    next_state = SIDLE;
                    next_img_offset = '0;
                    next_weigh_offset = '0;
                end else begin
                    case ({rd_image, rd_weight, wrt_result})
                        3'b100: begin
                            next_state = IMG_ADDR;
                            next_haddr = im_addr + img_offset;
                            next_htrans = NONSEQ;
                        end
                        3'b010: begin
                            next_state = WEI_ADDR;
                            next_haddr = wei_addr + weigh_offset;
                            next_htrans = NONSEQ;
                        end
                        3'b001: begin
                            next_state = RSLT_ADDR;
                            next_haddr = rs_addr;
                            next_htrans = NONSEQ;
                            next_hwrite = 1;
                        end
                        default: begin
                            next_state = current_state;
                            next_htrans = IDLE;
                            next_haddr = dma.haddr;
                        end
                    endcase
                end
            end

            IMG_ADDR: begin 
                            
                if (dma.hready == 1) begin
                    next_state = IMG_DATA;
                    next_img_offset = img_offset + 4;
                end else begin
                    next_haddr = dma.haddr; // keep the same address placed on the idle state
                    next_htrans = NONSEQ;
                end
        
            end

            RSLT_ADDR: begin
                
                if (dma.hready == 1) begin
                    next_state = RSLT_DATA;
                    next_hwdata = rslt_data;
                end else begin
                    next_haddr = dma.haddr; // keep the same address placed on the idle state
                    next_htrans = NONSEQ;
                    next_hwrite = 1;
                end
                
            end

            WEI_ADDR: begin
                
                if (dma.hready == 1) begin
                    next_state = WEI_DATA;
                    next_weigh_offset = weigh_offset + 4;
                end else begin
                    next_haddr = dma.haddr; // keep the same address placed on the idle state
                    next_htrans = NONSEQ;
                end
                
            end

            IMG_DATA: begin
                // if hready is 0 stay in current state
                // if any of the {rd_image, rd_weight, wrt_result} signals are 1, move to the corresponding address state.
                
                if (dma.hready == 1) begin
                    case ({rd_image, rd_weight, wrt_result})
                        3'b100: begin
                            next_state = IMG_ADDR;
                            next_haddr = im_addr + img_offset;
                            next_htrans = NONSEQ;
                        end
                        3'b010: begin
                            next_state = WEI_ADDR;
                            next_haddr = wei_addr + weigh_offset;
                            next_htrans = NONSEQ;
                        end
                        3'b001: begin
                            next_state = RSLT_ADDR;
                            next_haddr = rs_addr;
                            next_htrans = NONSEQ;
                            next_hwrite = 1;
                        end
                        default: begin
                            next_state = SIDLE;
                            next_htrans = IDLE;
                            next_haddr = dma.haddr;
                        end
                    endcase
                end 
                
            end


            WEI_DATA: begin
                
                if (dma.hready == 1) begin
                    case ({rd_image, rd_weight, wrt_result})
                        3'b100: begin
                            next_state = IMG_ADDR;
                            next_haddr = im_addr + img_offset;
                            next_htrans = NONSEQ;
                        end
                        3'b010: begin
                            next_state = WEI_ADDR;
                            next_haddr = wei_addr + weigh_offset;
                            next_htrans = NONSEQ;
                        end
                        3'b001: begin
                            next_state = RSLT_ADDR;
                            next_haddr = rs_addr;
                            next_htrans = NONSEQ;
                            next_hwrite = 1;
                        end
                        default: begin
                            next_state = SIDLE;
                            next_htrans = IDLE;
                            next_haddr = dma.haddr;
                        end
                    endcase
                end
                
            end


            RSLT_DATA: begin
                
                if (dma.hready == 1) begin
                    case ({rd_image, rd_weight, wrt_result})
                        3'b100: begin
                            next_state = IMG_ADDR;
                            next_haddr = im_addr + img_offset;
                            next_htrans = NONSEQ;
                        end
                        3'b010: begin
                            next_state = WEI_ADDR;
                            next_haddr = wei_addr + weigh_offset;
                            next_htrans = NONSEQ;
                        end
                        3'b001: begin
                            next_state = RSLT_ADDR;
                            next_haddr = rs_addr;
                            next_htrans = NONSEQ;
                            next_hwrite = 1;
                        end
                        default: begin
                            next_state = SIDLE;
                            next_htrans = IDLE;
                            next_haddr = dma.haddr;
                        end
                    endcase
                end else begin
                    next_hwdata = rslt_data;
                end
                
            end
        endcase
    end


endmodule