# Makefile for UART TX Verilator simulation with SystemVerilog

# Configuration
TOP_MODULE = uart_tx_tb
VERILOG_SOURCES = uart_tx_tb.sv
CPP_SOURCES = uart_tb.cpp

# Verilator configuration - added --no-timing to disable timing features
VERILATOR = verilator
# VFLAGS = -Wall --cc --trace --no-timing -Wno-WIDTHEXPAND -Wno-DECLFILENAME
VFLAGS = -Wall --cc --trace --timing -Wno-WIDTHEXPAND -Wno-DECLFILENAME

# Build directories
OBJ_DIR = obj_dir

# Verilator include path
VERILATOR_ROOT ?= $(shell $(VERILATOR) -V | grep VERILATOR_ROOT | head -1 | sed -e "s/^.*=\s*//")
VINC = $(VERILATOR_ROOT)/include

# Compiler settings
CXX = g++
CXXFLAGS = -std=c++14 -Wall -I$(VINC) -I$(VINC)/vltstd -I$(OBJ_DIR)

# Default target
all: sim

# Generate C++ from SystemVerilog
$(OBJ_DIR)/V$(TOP_MODULE).cpp: $(VERILOG_SOURCES)
	$(VERILATOR) $(VFLAGS) -cc $(VERILOG_SOURCES)

# Build verilator library
$(OBJ_DIR)/V$(TOP_MODULE)__ALL.a: $(OBJ_DIR)/V$(TOP_MODULE).cpp
	$(MAKE) -j4 -C $(OBJ_DIR) -f V$(TOP_MODULE).mk

# Build the simulation executable
# sim: $(OBJ_DIR)/V$(TOP_MODULE)__ALL.a $(CPP_SOURCES)
# 	$(CXX) $(CXXFLAGS) $(VINC)/verilated.cpp $(VINC)/verilated_vcd_c.cpp \
# 	       $(VINC)/verilated_threads.cpp $(CPP_SOURCES) $(OBJ_DIR)/V$(TOP_MODULE)__ALL.a -o sim

sim:
	$(VERILATOR) $(VFLAGS) --exe --build $(CPP_SOURCES) $(VERILOG_SOURCES)


# Run the simulation
run: sim
	./obj_dir/V$(TOP_MODULE)

# View waveforms (requires GTKWave)
waves: uart_tx.vcd
	gtkwave uart_tx.vcd &

# Clean build artifacts
clean:
	rm -rf $(OBJ_DIR) sim *.vcd

# Help target
help:
	@echo "Available targets:"
	@echo "  all     - Build the simulation"
	@echo "  run     - Build and run the simulation"
	@echo "  waves   - Open waveform viewer (requires GTKWave)"
	@echo "  clean   - Clean build artifacts"
	@echo "  help    - Show this help"

.PHONY: all run waves clean help