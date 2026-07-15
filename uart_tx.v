module uart_tx #(
    parameter TX_CLK_LIMIT = 434 // 50,000,000 / 115,200
)(input clk, input rst_n, input tx_start, input [7:0] tx_data, output bit_tick, output reg tx_serial, output tx_busy);
    reg [15:0] clk_count;
    reg [1:0] current_state;
    reg [2:0] bit_index;   // i need this to count from bit 0 to bit 7 during transmission
    reg [7:0] tx_data_reg; // A safe holding register to store the data while i transmit it hit by bit

    localparam STATE_IDLE  = 2'b00;
    localparam STATE_START = 2'b01;
    localparam STATE_DATA  = 2'b10;
    localparam STATE_STOP  = 2'b11;

    // for baud rate generation
    always @(posedge clk) begin
        if (!rst_n) begin
        clk_count <= 0;
        end else if (current_state == STATE_IDLE && tx_start) begin
        clk_count <= 0; // Force-reset the metronome when a new packet begins
        end else begin
            if (clk_count == TX_CLK_LIMIT - 1) begin
                clk_count <= 0;
            end else begin
                clk_count <= clk_count + 1;
            end
        end
    end 
        assign bit_tick = (clk_count == TX_CLK_LIMIT - 1);
    
    //fsm 
    always @(posedge clk) begin
        if (!rst_n) begin
            current_state <= STATE_IDLE;
            tx_serial     <= 1'b1;
            bit_index     <= 0;
            tx_data_reg   <= 0;
        end else begin
            case (current_state)
                STATE_IDLE: begin
                    tx_serial <= 1'b1; // Idle line is always high
                    if (tx_start) begin
                        tx_data_reg   <= tx_data;
                        bit_index     <= 0;
                        current_state <= STATE_START;
                    end
                end

                STATE_START: begin
                    tx_serial <= 1'b0; // Start bit is always low
                    if (bit_tick) begin
                        current_state <= STATE_DATA;
                    end
                end

                STATE_DATA: begin
                    tx_serial <= tx_data_reg[bit_index];// 1. Set tx_serial to the current bit of tx_data_reg using bit_index
                    if (bit_tick) begin
                            if (bit_index == 7) current_state <= STATE_STOP;
                            else bit_index <= bit_index + 1;
                    end // 2. If a bit_tick happens, check if we hit index 7 to move to STATE_STOP, 
                    //    otherwise increment bit_index.
                end

                STATE_STOP: begin
                    tx_serial <= 1'b1; // 1. Set tx_serial back to 1'b1
                    if (bit_tick) current_state <= STATE_IDLE; // 2. If a bit_tick happens, go back to STATE_IDLE
                end
                
                default: current_state <= STATE_IDLE;
            endcase
        end
    end

    assign tx_busy = ((current_state == STATE_START)||(current_state == STATE_DATA)||(current_state == STATE_STOP));

endmodule