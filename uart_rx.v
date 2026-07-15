module uart_rx #(
    parameter RX_CLK_LIMIT = 27 // 50,000,000 / 115,200 x 16
)(input clk, input rst_n, input rx_serial, output reg [7:0] rx_data, output reg rx_ready);//a 1-cycle pulse when a byte is fully collected

        wire sample_tick;
        reg [5:0] clk_count;

        localparam STATE_IDLE  = 2'b00;
        localparam STATE_START = 2'b01;
        localparam STATE_DATA  = 2'b10;
        localparam STATE_STOP  = 2'b11;

        always @(posedge clk) begin
        if (!rst_n) begin
        clk_count <= 0;
        end else begin
            if (clk_count == RX_CLK_LIMIT - 1) begin
                clk_count <= 0;
            end else begin
                clk_count <= clk_count + 1;
            end
        end
    end 

    assign sample_tick = (clk_count == RX_CLK_LIMIT - 1); //sample_tick is high when clk_count == 26, this is 16 times faster than baude rate

    //fsm
    reg [1:0] current_state; //fsm states
    reg [3:0] tick_count;   //count the 16 oversampling ticks per bit
    reg [2:0] bit_index;    //track which data bit you are receiving
    reg [7:0] rx_data_reg;  //accumulate the bits as they arrive

    always @(posedge clk) begin
        if (!rst_n) begin
            current_state <= STATE_IDLE;
            tick_count <= 0;
            bit_index <= 0;
            rx_ready <= 0;
            rx_data <= 0;
        end
        else begin
            rx_ready <= 1'b0; //ensures that if it becomes 1 in STATE_STOP, it automatically drops back down to 0 on the very next clock cycle, giving us a perfect 1-cycle pulse.
            case(current_state) 
                STATE_IDLE: if (!rx_serial) begin
                    tick_count <= 0;
                    current_state <= STATE_START;
                end
                STATE_START: if(sample_tick) begin 
                    if(tick_count < 7) tick_count <= tick_count + 1;
                    else begin
                        if (!rx_serial) begin
                            tick_count <= 0;
                            bit_index <= 0;
                            current_state <= STATE_DATA;
                        end
                        else current_state <= STATE_IDLE;
                end
        end
                STATE_DATA: 
                if(sample_tick) begin
                    if(tick_count < 15) tick_count <= tick_count + 1;
                    else if(tick_count == 15) begin
                    rx_data_reg[bit_index] <= rx_serial;
                    tick_count <= 0;
                
                if (bit_index == 7) current_state <= STATE_STOP;
                else bit_index <= bit_index + 1;
                end
                end

                STATE_STOP:
                if(sample_tick) begin
                    if(tick_count < 15) tick_count <= tick_count + 1;
                    else begin
                        if (rx_serial) begin
                            rx_data <= rx_data_reg;
                            rx_ready <= 1'b1;
                        end
                        else current_state <= STATE_IDLE;
                    end
                end

        endcase
        end
    end
    
endmodule