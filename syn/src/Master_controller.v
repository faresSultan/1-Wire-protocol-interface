module onewire_controller (
    input        clk,
    input        rst,
    input        start,        // pulse to begin full transaction
    input        led_on,       // 1=send 0xFF, 0=send 0x00
    output reg   busy,
    output reg   done,
    output reg   error,        // 1 if no presence detected

    inout  wire  dq
);

    // ========= Instantiate low-level driver =========
    reg [1:0] cmd;
    reg       cmd_start;
    wire      cmd_busy, cmd_done;
    wire      presence;
    wire      data_out;

    onewire_master_Tx_Rx bit_fsm (
        .clk(clk),
        .rst(rst),
        .cmd(cmd),
        .start(cmd_start),
        .busy(cmd_busy),
        .done(cmd_done),
        .presence(presence),
        .dq(dq),
        .data_out(data_out)
    );

    // ========= controller FSM states =========
       parameter IDLE          = 4'd0;
       parameter RESET_PULSE   = 4'd1;
       parameter CHECK_PRES    = 4'd2;
       parameter SEND_MATCHROM = 4'd3;
       parameter SEND_ROM      = 4'd4;
       parameter SEND_CRC      = 4'd5;
       parameter WAIT_SLAVE    = 4'd6;
       parameter SEND_COMMAND  = 4'd7;
       parameter FINISH        = 4'd8;
       parameter ERROR_STATE   = 4'd9;
    

    reg [3:0] current_state, next_state;

    // ROM code (example: family+serial)
    localparam [55:0] ROM_CODE = 56'hFFFFFFFFFFFFFF; // all 1s for demo
    localparam [7:0]  MATCH_ROM = 8'h55;

    reg [7:0] byte_to_send;
    reg [5:0] bit_cnt;
    reg [55:0] rom_shift;
    reg [7:0] crc_dummy = 8'hAA; // placeholder CRC

    // ========= current state logic =========
    always @(posedge clk or posedge rst) begin
        if (rst) current_state <= IDLE;
        else     current_state <= next_state;
    end

    // ========= Next-state logic =========
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: if (start) next_state = RESET_PULSE;

            RESET_PULSE: if (cmd_done) next_state = CHECK_PRES;

            CHECK_PRES: begin
                if (!presence) next_state = ERROR_STATE;
                else           next_state = SEND_MATCHROM;
            end

            SEND_MATCHROM: if (bit_cnt==8 && cmd_done) next_state = SEND_ROM;

            SEND_ROM: if (bit_cnt==56 && cmd_done) next_state = SEND_CRC;

            SEND_CRC: if (bit_cnt==8 && cmd_done) next_state = WAIT_SLAVE;

            WAIT_SLAVE: next_state = SEND_COMMAND; // could insert timer here

            SEND_COMMAND: if (bit_cnt==8 && cmd_done) next_state = FINISH;

            FINISH: next_state = IDLE;

            ERROR_STATE: next_state = IDLE;
        endcase
    end

    // ========= Output / datapath =========
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            busy   <= 0;
            done   <= 0;
            error  <= 0;
            cmd    <= 0;
            cmd_start <= 0;
            bit_cnt   <= 0;
            rom_shift <= ROM_CODE;
        end else begin
            cmd_start <= 0;
            done <= 0;

            case (current_state)
                IDLE: begin
                    busy <= 0;
                    error <= 0;
                end

                RESET_PULSE: begin
                    busy <= 1;
                    cmd  <= 2'b00;  // RESET
                    if (!cmd_busy && !cmd_start) cmd_start <= 1;
                end

                CHECK_PRES: begin
                    if (!presence) error <= 1;
                end

                SEND_MATCHROM: begin
                    if (!cmd_busy && bit_cnt < 8) begin
                        cmd <= (MATCH_ROM[bit_cnt]) ? 2'b01 : 2'b10;
                        cmd_start <= 1;
                        bit_cnt <= bit_cnt + 1;
                    end
                end

                SEND_ROM: begin
                    if (!cmd_busy && bit_cnt < 56) begin
                        cmd <= (rom_shift[0]) ? 2'b01 : 2'b10;
                        cmd_start <= 1;
                        rom_shift <= rom_shift >> 1;
                        bit_cnt <= bit_cnt + 1;
                    end
                end

                SEND_CRC: begin
                    if (!cmd_busy && bit_cnt < 8) begin
                        cmd <= (crc_dummy[bit_cnt]) ? 2'b01 : 2'b10;
                        cmd_start <= 1;
                        bit_cnt <= bit_cnt + 1;
                    end
                end

                WAIT_SLAVE: begin
                    // wait N cycles for slave CRC check (TODO: insert counter)
                    bit_cnt <= 0;
                end

                SEND_COMMAND: begin
                    if (!cmd_busy && bit_cnt < 8) begin
                        cmd <= (led_on)? 2'b01 : 2'b10;
                        cmd_start <= 1;
                        bit_cnt <= bit_cnt + 1;
                    end
                end

                FINISH: begin
                    busy <= 0;
                    done <= 1;
                end

                ERROR_STATE: begin
                    busy <= 0;
                    error <= 1;
                end
            endcase
        end
    end

endmodule
