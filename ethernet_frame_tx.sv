module ethernet_frame_tx(

    input       logic             clock,
    input       logic             reset,
    input       logic   [7:0]     payload_data,
    input       logic             payload_valid,
    input       logic             payload_last,
    input       logic             tx_ready,

    output      logic   [7:0]    tx_byte,
    output      logic            tx_valid,
    output      logic            frame_done
);


logic [3:0] preamble_cnt;
logic [3:0] header_cnt;
logic [1:0] crc_cnt;
logic [4:0] ifg_cnt;

logic [31:0] crc_reg;

localparam [47:0] DEST_MAC  = 48'hFFFFFFFFFFFF;
localparam [47:0] SRC_MAC   = 48'h123456789ABC;
localparam [15:0] ETHERTYPE = 16'h0800;

logic [7:0] payload_mem [0:255];

logic [7:0] write_ptr;
logic [7:0] read_ptr;

logic [7:0] payload_size;



typedef enum logic [2:0]{
    IDLE,
    PREAMBLE,
    HEADER,
    PAYLOAD,
    CRC,
    IFG
} state_t;

state_t EA;


always_ff @(posedge clock) begin
    if(reset) begin
        
        EA            <= IDLE;

        tx_valid      <= 0;
        tx_byte       <= 0;

        preamble_cnt  <= 0;
        header_cnt    <= 0;
        crc_cnt       <= 0;
        ifg_cnt       <= 0;

        frame_done    <= 0;

        write_ptr   <= 0;
        read_ptr    <= 0;
        payload_size <= 0;

        crc_reg <= 32'hDEADBEEF;
    end 
    else begin
        case(EA)
        IDLE: begin

                tx_valid <= 0;

                if(payload_valid) begin

                    payload_mem[write_ptr] <= payload_data;

                    if(payload_last) begin

                        payload_size <= write_ptr + 1;

                        write_ptr <= 0;

                        read_ptr <= 0;

                        preamble_cnt <= 0;

                        EA <= PREAMBLE;

                    end
                    else begin

                        write_ptr <= write_ptr + 1;

                    end

                end

            end
            PREAMBLE: begin
                if(tx_ready) begin
                    tx_valid <= 1;
                    read_ptr <= 0;

                    if(preamble_cnt < 7) begin
                        tx_byte <= 8'h55;
                    end
                    else begin
                        tx_byte <= 8'hD5;
                    end

                    preamble_cnt <= preamble_cnt + 1;



                        if(preamble_cnt == 7) begin
                        header_cnt <= 0;
                        EA <= HEADER;
                    end
                end
            end
             HEADER: begin

            if(tx_ready) begin

                tx_valid <= 1;

                case(header_cnt)

                    // DEST MAC
                    0:  tx_byte <= DEST_MAC[47:40];
                    1:  tx_byte <= DEST_MAC[39:32];
                    2:  tx_byte <= DEST_MAC[31:24];
                    3:  tx_byte <= DEST_MAC[23:16];
                    4:  tx_byte <= DEST_MAC[15:8];
                    5:  tx_byte <= DEST_MAC[7:0];

                    // SRC MAC
                    6:  tx_byte <= SRC_MAC[47:40];
                    7:  tx_byte <= SRC_MAC[39:32];
                    8:  tx_byte <= SRC_MAC[31:24];
                    9:  tx_byte <= SRC_MAC[23:16];
                    10: tx_byte <= SRC_MAC[15:8];
                    11: tx_byte <= SRC_MAC[7:0];

                    // ETHERTYPE
                    12: tx_byte <= ETHERTYPE[15:8];
                    13: tx_byte <= ETHERTYPE[7:0];

                endcase

              if(header_cnt == 14) begin

                header_cnt <= 0;

                read_ptr <= 1;

                tx_byte <= payload_mem[0];

                EA <= PAYLOAD;

                end
            else begin

                 header_cnt <= header_cnt + 1;

                end
            end

        end


        PAYLOAD: begin


            if(tx_ready) begin

                tx_valid <= 1;

                tx_byte <= payload_mem[read_ptr];

                if(read_ptr == payload_size - 1) begin

                    read_ptr <= 0;

                    crc_cnt <= 0;

                    EA <= CRC;

                end
                else begin
                    read_ptr <= read_ptr + 1;
                end

            end

        end

        CRC: begin

            tx_valid <= 1;

            case(crc_cnt)

                0: tx_byte <= crc_reg[7:0];
                1: tx_byte <= crc_reg[15:8];
                2: tx_byte <= crc_reg[23:16];
                3: tx_byte <= crc_reg[31:24];

            endcase

            if(crc_cnt == 3) begin

                crc_cnt <= 0;

                EA <= IFG;

            end
            else begin

                crc_cnt <= crc_cnt + 1;

            end
        end


        IFG: begin

            tx_valid <= 0;

            ifg_cnt <= ifg_cnt + 1;

           
            if(ifg_cnt == 11) begin

                frame_done <= 1;

                EA <= IDLE;

            end

        end

        endcase
    end
end

endmodule