module Master_tx(rst,clk,bit_to_send,ready,bus_out);

    parameter IDLE = 2'b00;
    parameter SEND_1 = 2'b01;
    parameter SEND_0 = 2'b11;

    input clk,rst,bit_to_send,ready;
    output reg bus_out;
    
    wire load_en;
    wire [5:0] counter_out;
    wire [5:0] load_value;

    reg[1:0] current_state,next_state;

    internal_counter counter (rst,clk,load_value,load_en,counter_out);
    Bus bus (.bus(bus_out));

//============Current state logic==============
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            current_state <= IDLE;
        end
        else begin
            current_state <= next_state;
        end
    end

//============Next state logic==============
    always @(*) begin
        case (current_state)
            IDLE: begin
                if (bit_to_send == 1'b1 && ready) begin
                    next_state = SEND_1;
                end
                else if (bit_to_send == 1'b0 && ready) begin
                    next_state = SEND_0;
                end
                else begin
                    next_state = IDLE;
                end
            end 

            SEND_1: begin
                if(counter_out !== 'b0) begin
                    next_state = SEND_1;
                end
                else begin
                    next_state = IDLE;
                end
            end

            SEND_0: begin
                if(counter_out !== 'b0) begin
                    next_state = SEND_0;
                end
                else begin
                    next_state = IDLE;
                end
            end
            default: next_state = IDLE;
    
        endcase
    end

//============output logic==============
    always @(*) begin
        case (current_state)
           IDLE: begin
                bus_out = 1;
           end

           SEND_1: begin
                bus_out = 0;
           end

           SEND_0: begin
                bus_out = 0;
           end 

            default: bus_out = 1;
        endcase
    end

    assign load_en = ((current_state != next_state)||next_state == IDLE);
    assign load_value = ((next_state==SEND_1)?5 : 59);

endmodule


module internal_counter(rst,clk,load_value,load_en,counter_out);
    input rst, clk,load_en;
    input [5:0] load_value;
    output reg [5:0] counter_out;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            counter_out <= 'b0;
        end
        else begin
            if (load_en) begin
                counter_out <= load_value;
            end
            else begin
                counter_out <= counter_out - 1;
            end
        end
    end

endmodule