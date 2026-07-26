`timescale 1ns / 1ps

module uart_tb;
parameter CLK_PERIOD = 20;
parameter FAST_TX_LIMIT = 16; // Scaled down for fast simulation
parameter FAST_RX_LIMIT = 1;  // Scaled down (approx 10/16 ~ 1)

//system signals
reg clk;
reg rst_n;

// Signal Declarations
reg        tx_start; //Control signal pulsed HIGH by testbench to trigger sending a byte.
reg  [7:0] tx_data; //8-bit register holding the byte value to transmit.
wire       bit_tick; //Output net from transmitter indicating each bit duration boundary.
wire       tx_busy; //Output flag from transmitter: 1 when transmitting, 0 when idle.
wire       tx_serial; //A 1-bit net (wire) that carries the serial data stream bit-by-bit.

wire [7:0] rx_data; //An 8-bit bus holding the fully reconstructed byte received over serial.
wire       rx_ready; //A 1-bit flag pulsed HIGH for one clock cycle when a byte is completely received.

// 2. Module Instantiations (DUT)
uart_tx #(
        .TX_CLK_LIMIT(FAST_TX_LIMIT)
    ) u_uart_tx (
        .clk       (clk),
        .rst_n     (rst_n),
        .tx_start  (tx_start),
        .tx_data   (tx_data),
        .bit_tick  (bit_tick),
        .tx_serial (tx_serial),
        .tx_busy   (tx_busy)
    );

// Instantiate UART Receiver (Loopback: rx_serial connected to tx_serial)
    uart_rx #(
        .RX_CLK_LIMIT(FAST_RX_LIMIT)
    ) u_uart_rx (
        .clk       (clk),
        .rst_n     (rst_n),
        .rx_serial (tx_serial), // Directly wired to TX serial output!
        .rx_data   (rx_data),
        .rx_ready  (rx_ready)
    );

// Clock Generation
    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD / 2) clk = ~clk;
    end

// VCD Waveform Recording
    initial begin
        $dumpfile("uart_sim.vcd");
        $dumpvars(0, uart_tb);
    end

//Verification Task
task send_and_check(input [7:0] test_byte);
        begin
            @(posedge clk);
            
            if (tx_busy) begin
                $display("[%0t ns] [WAIT] Waiting for TX to become idle...", $time);
                wait (!tx_busy);
                @(posedge clk);
            end

            tx_data  <= test_byte;
            tx_start <= 1'b1;
            @(posedge clk);
            tx_start <= 1'b0;

            $display("[%0t ns] [TX] Started sending byte: 0x%0h (8'b%0b)", $time, test_byte, test_byte);

            @(posedge rx_ready);
            
            if (rx_data === test_byte) begin
                $display("[%0t ns] [PASS] Successfully received matching byte: 0x%0h\n", $time, rx_data);
            end else begin
                $display("[%0t ns] [FAIL] ERROR! Sent: 0x%0h | Received: 0x%0h\n", $time, test_byte, rx_data);
            end
        end
    endtask


    //Test Sequence Execution
    initial begin
        rst_n    = 1'b0;
        tx_start = 1'b0;
        tx_data  = 8'h00;

        #(CLK_PERIOD * 5);
        rst_n = 1'b1;
        #(CLK_PERIOD * 5);

        $display("\n==================================================");
        $display("       STARTING UART LOOPBACK VERIFICATION        ");
        $display("==================================================\n");

        send_and_check(8'hA5);
        send_and_check(8'h5A);
        send_and_check(8'h55);
        send_and_check(8'hFF);

        $display("==================================================");
        $display("          ALL TESTS COMPLETED SUCCESSFULLY        ");
        $display("==================================================\n");

        $finish;
    end


endmodule