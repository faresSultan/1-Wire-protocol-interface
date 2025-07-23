module Master_tb();
    reg clk,rst,bit_to_send,ready;
    
    wire bus_out;

    integer error_count,correct_count;

    Master_tx DUT (.*);
    
    initial begin
        clk = 0;
        forever begin
            #1 clk = ~clk;
        end
    end

    initial begin
        error_count = 0 ;
        correct_count = 0;
        
        rst = 1;
        @(negedge clk);
        @(negedge clk);
        rst = 0;

    // if not ready -> should remain idle
        @(negedge clk);
        ready = 0;
        bit_to_send = 1;
        @(negedge clk);
        if(bus_out != 1) begin
            $display ("Ready Flag error");
            error_count = error_count + 1;    
            $stop;
        end
        else begin
            correct_count = correct_count + 1;
        end
    //========================================

    // if ready and bit to send = 1 -> bus is low for six clk cycles
        @(negedge clk);
        ready = 1;
        repeat(6) begin
            @(negedge clk);
            if(bus_out == 1) begin
                error_count = error_count + 1;    
                $fatal("send1 error");

            end

            else begin
                correct_count = correct_count + 1;
            end
        end
    //========================================

    // if ready and bit to send = 0 -> bus is low for 60 clk cycles
        @(negedge clk);
        ready = 1;
        bit_to_send = 0;
        repeat(60) begin
            @(negedge clk);
            if(bus_out == 1) begin
                error_count = error_count + 1;    
                $fatal ("send0 error");
            end
            else begin
                correct_count = correct_count + 1;
            end
        end
        @(negedge clk);
        @(negedge clk);
    //========================================
        $display("Correct count = %0d",correct_count);
        $stop;
    end

endmodule