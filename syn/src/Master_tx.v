module onewire_master_Tx_Rx( 
    input       clk, 
    input       rst, 
    input [1:0] cmd,     // 00:RESET_PRESENCE, 01:WRITE1, 10:WRITE0, 11:READ 
    input       start,   // pulse to start command 
    output reg  busy,    // high while command in progress 
    output reg  done,    // pulse when command done 
    output reg  presence,// latched presence detect 
 
    inout  wire dq,      // 1-Wire bus line (open-drain) 
    output reg  data_out // read data 
); 
 
    //================== FSM states =================== 
    parameter IDLE            = 3'd0; 
    parameter RESET_LOW       = 3'd1; 
    parameter PRESENCE_DETECT = 3'd2; 
    parameter WRITE_SLOT      = 3'd3; 
    parameter READ_SLOT       = 3'd4; 
    parameter DONE            = 3'd5; 
     
    //=============== Timing constants ================ 
    localparam integer t_resetL  = 480;  
    localparam integer t_resetH  = 480; 
    localparam integer t_write1L = 1;      
    localparam integer t_write0L = 60;     
    localparam integer t_slot    = 70;     
    localparam integer t_rdSamp  = 15;     
 
    // Bus buffer control 
    reg dq_out_en; 
    assign dq = dq_out_en ? 1'b0 : 1'bz; 
    wire dq_in = dq; 
 
    reg [2:0] current_state, next_state; 
    reg [31:0] timer; 
 
    //============== state register =================== 
    always @(posedge clk or posedge rst) begin 
        if(rst) 
            current_state <= IDLE; 
        else 
            current_state <= next_state; 
    end 
 
    //=============== Next state logic ================  
    always @(*) begin 
        next_state = current_state; 
        case(current_state) 
            IDLE: begin 
                if(start) begin 
                    case(cmd) 
                        2'b00: next_state = RESET_LOW; 
                        2'b01: next_state = WRITE_SLOT; 
                        2'b10: next_state = WRITE_SLOT; 
                        2'b11: next_state = READ_SLOT; 
                    endcase 
                end  
            end 
 
            RESET_LOW: 
                if(timer >= t_resetL) 
                    next_state = PRESENCE_DETECT; 
 
            PRESENCE_DETECT: 
                if(timer >= t_resetH) 
                    next_state = DONE; 
 
            WRITE_SLOT: 
                if(timer >= t_slot) 
                    next_state = DONE; 
 
            READ_SLOT: 
                if(timer >= t_slot) 
                    next_state = DONE; 
 
            DONE: 
                next_state = IDLE; 
        endcase 
    end 
 
    //================= Sequential outputs ================== 
    always @(posedge clk or posedge rst) begin 
        if(rst) begin 
            presence <= 0; 
            data_out <= 0; 
        end else begin 
            case(current_state) 
                RESET_LOW: 
                    presence <= 0;  // clear before detect 
                PRESENCE_DETECT: 
                    if(!dq_in) presence <= 1; // latch presence if low seen 
                READ_SLOT: 
                    if(timer == t_rdSamp) data_out <= dq_in; // sample bus 
            endcase 
        end 
    end 
 
    //================= Combinational outputs ==================  
    always @(*) begin 
        dq_out_en = 0; 
        busy      = 0; 
        done      = 0; 
 
        case(current_state) 
            RESET_LOW: begin 
                dq_out_en = 1; // pull low 
                busy      = 1; 
            end 
 
            PRESENCE_DETECT: 
                busy = 1; 
 
            WRITE_SLOT: begin 
                busy = 1; 
                if(cmd==2'b01) dq_out_en = (timer < t_write1L); // write 1 
                else if(cmd==2'b10) dq_out_en = (timer < t_write0L); // write 0 
            end 
 
            READ_SLOT: begin 
                busy      = 1; 
                dq_out_en = (timer < t_write1L); // short init low pulse 
            end 
 
            DONE: 
                done = 1; 
        endcase 
    end 
 
    //================= timer logic ================== 
    always @(posedge clk or posedge rst) begin 
        if (rst)  
            timer <= 0; 
        else if(current_state != next_state) 
            timer <= 0; 
        else if(current_state != IDLE) 
            timer <= timer + 1; 
    end 
 
endmodule
