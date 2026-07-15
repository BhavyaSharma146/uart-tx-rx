module top_module (input clk, input rst_n, input rx_pin, output tx_pin);
    wire [7:0] w_data;
    wire w_ready;
    uart_rx receiver (.clk(clk),
        .rst_n(rst_n),
        .rx_serial(rx_pin),
        .rx_data(w_data),
        .rx_ready(w_ready));
    uart_tx transmitter (.clk(clk), .rst_n(rst_n), .tx_start(w_ready), .tx_data(w_data), .tx_serial(tx_pin),.tx_busy(), .bit_tick());

endmodule




