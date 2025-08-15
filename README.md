# AXI-Lite UART Controller

This SystemVerilog core contains a complete UART implementation with AXI-Lite interface, configurable via a single 32-bit register for just about any baud rate, one or two stop bits, five through eight data bits, and odd, even, mark, or space parity. If you are looking for an example SystemVerilog UART module containing all these features with formal verification, then you have just found it.

The module goes beyond simple transmit and receive to include a synchronous FIFO and complete AXI-Lite slave interface. Unlike other UART controllers, this implementation can be configured with a single 32-bit register write, making setup simple and straightforward.

## Features

* Complete AXI-Lite interface for direct SoC integration
* Single 32-bit configuration register for all UART parameters
* Configurable baud rates, data bits (5-8), parity modes, stop bits
* Integrated FIFOs with parameterizable depth (16-1024 entries)
* Error detection and interrupt support
* Formal verification with SystemVerilog Assertions

## Quick Start

```bash
git clone https://github.com/rrameshh/uart-axi-controller.git
cd uart-axi-controller
make integration_test      # Test complete system
gtkwave sim/waveforms/integration_test.vcd  # View results
```

## Register Interface

Eight 32-bit registers accessible via AXI-Lite:

| Offset | Register   | Description                    |
|--------|------------|--------------------------------|
| 0x00   | CONFIG     | Configuration register         |
| 0x04   | CONTROL    | Control register               |
| 0x08   | STATUS     | Status register                |
| 0x0C   | TX_DATA    | Transmit data                  |
| 0x10   | RX_DATA    | Receive data                   |
| 0x14   | FIFO_CTRL  | FIFO control                   |
| 0x18   | INT_CTRL   | Interrupt control              |
| 0x1C   | INT_STAT   | Interrupt status               |

The CONFIG register contains all UART parameters:
- Bits 31-16: Baud rate divisor  
- Bits 15-13: FIFO size
- Bits 12-9: Enable flags and stop bits
- Bits 8-4: Parity and data bits

## Usage Examples

115200 baud, 8N1: `CONFIG = 0x0363_5C30`  
9600 baud, 7E2: `CONFIG = 0x28B0_5EA0`

## Implementation

Key modules: axiluart.sv (AXI-Lite wrapper), uart_controller.sv (main controller), configurable baud/TX/RX modules, and fifo.sv. Resource usage: ~200 LUTs, 2 BRAMs on Spartan-7. Validated up to 100MHz, 921k baud.

## Testing

```bash
make integration_test   # Complete system test
make axiluart_test     # AXI-Lite interface test  
make formal_verify     # Formal verification
```

Includes comprehensive testbenches and formal verification with SystemVerilog Assertions.

