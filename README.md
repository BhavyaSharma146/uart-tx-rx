**Overview**

A UART (Universal Asynchronous Receiver-Transmitter) *loopback system* designed in verilog. This acts as a *hardware validation test*. This system receives Serial data at 115,200 baud, converts it to parallel data, and immediately echoes it back via the transmitter.

​```mermaid
graph LR
    rx_pin([rx_pin]) -->|rx_serial| rx
    tx -->|tx_serial| tx_pin([tx_pin])
    subgraph top_module ["top_module.v / uart_loopback.v"]
        rx[uart_rx]
        tx[uart_tx]
        rx -->|"w_data [7:0] (rx_data ──► tx_data)"| tx
        rx -->|"w_ready (rx_ready ──► tx_start)"| tx
    end
    style rx fill:#e8f4fd,stroke:#1d8cf8,stroke-width:2px
    style tx fill:#fef3e9,stroke:#ff8d72,stroke-width:2px
    style top_module fill:#fdfdfd,stroke:#888,stroke-width:1px,stroke-dasharray: 5 5
    style rx_pin fill:#fff,stroke:#333,stroke-width:1.5px
    style tx_pin fill:#fff,stroke:#333,stroke-width:1.5px
​```

### Clock-to-Baud Math

| Step | Calculation | Result |
|---|---|---|
| FPGA clock | — | 50 MHz (50,000,000 cycles/sec) |
| Target baud rate | — | 115,200 bits/sec |
| TX: clocks per bit period | 50,000,000 / 115,200 | ≈ 434 → `TX_CLK_LIMIT` |
| RX: clocks per oversample tick | 434 / 16 | ≈ 27 → `RX_CLK_LIMIT` |

> **Note:** 434/16 = 27.125, not a whole number — `RX_CLK_LIMIT` is rounded to 27. This introduces a small timing drift (~7 clocks accumulated by the last data bit), which is tolerated because RX samples at the *midpoint* of each bit, giving enough margin to absorb it.

### Parameters

| Parameter | Module | Value | Meaning |
|---|---|---|---|
| `TX_CLK_LIMIT` | `uart_tx` | 434 | Number of `clk` cycles per bit period (generates `bit_tick`) |
| `RX_CLK_LIMIT` | `uart_rx` | 27 | Number of `clk` cycles per oversample tick (generates `sample_tick`, 16 per bit period) |
| Clock frequency | both | 50 MHz | System clock driving both modules |
| Baud rate | both | 115,200 bps | Target serial communication speed |
| Oversampling factor | `uart_rx` | 16× | Number of `sample_tick` pulses per bit period, used to locate the midpoint of each bit |

> These parameters are tied together: retargeting this design to a different clock frequency or baud rate means recalculating both `TX_CLK_LIMIT` (`clk_freq / baud_rate`) and `RX_CLK_LIMIT` (`TX_CLK_LIMIT / 16`).

### Transmitter (`uart_tx`)

**Trigger:** Transmission starts when `tx_start` is asserted while the FSM is in `STATE_IDLE`. On this trigger, the byte to send (`tx_data`) is latched into an internal holding register (`tx_data_reg`), `bit_index` is reset to 0, and the FSM moves to `STATE_START`.

**States:**
- `STATE_IDLE`: `tx_serial` is held high (idle line). The FSM waits here until `tx_start` is asserted.
- `STATE_START`: `tx_serial` is driven low (the start bit). The FSM waits for one full bit period (`bit_tick`) before moving to `STATE_DATA`.
- `STATE_DATA`: `tx_serial` outputs `tx_data_reg[bit_index]` — the current bit being sent. On every `bit_tick`, `bit_index` increments, until all 8 bits (index 0–7) have been sent, at which point the FSM moves to `STATE_STOP`.
- `STATE_STOP`: `tx_serial` is driven high (the stop bit). After one more `bit_tick`, the FSM returns to `STATE_IDLE`, ready for the next byte.

**Timing:** `bit_tick` is a pulse generated once every `TX_CLK_LIMIT` (434) clock cycles — i.e., once per bit period at 115200 baud. Since TX is the source of the signal it's generating, it doesn't need to measure or interpret anything external — `bit_tick` firing is simply "time to move to the next bit/state," and the FSM advances directly on that pulse.

**`tx_busy`:** Asserted whenever the FSM is in `STATE_START`, `STATE_DATA`, or `STATE_STOP` — i.e., whenever a transmission is actively in progress, letting external logic know not to assert `tx_start` again until the current byte finishes.
​
