# ──────────────────────────────────────────────────────────────────────
# Makefile — Build system for odin-svd examples
#
# Usage:
#   make blinky          — Build the blinky example
#   make uart_echo       — Build the UART echo example
#   make flash-blinky    — Build and flash blinky to the board
#   make flash-uart-echo — Build and flash UART echo to the board
#   make clean           — Remove build artifacts
#   make generate        — Re-generate Odin register definitions from SVD
# ──────────────────────────────────────────────────────────────────────

# ── Configuration ──
ODIN        := odin
OBJCOPY     := arm-none-eabi-objcopy
OBJDUMP     := arm-none-eabi-objdump
STFLASH     := st-flash
GDB         := arm-none-eabi-gdb

# ── Paths ──
ROOT        := $(CURDIR)
STM32F0_DIR := $(ROOT)/stm32f0
CORE_DIR    := $(ROOT)/core
STARTUP     := $(CORE_DIR)/startup/startup_stm32f051.s
LINKER      := $(CORE_DIR)/linker/stm32f051.ld
SVD_FILE    := $(ROOT)/svd/stm32f051.svd
SVD_GEN     := $(STM32F0_DIR)/registers.odin

# ── Odin compiler flags ──
ODIN_TARGET := -target:freestanding_arm32_none_eabi
ODIN_FLAGS  := -file -no-crt -no-thread-local -default-to-nil-allocator -vet \
               -collection:stm32f0=$(ROOT)

# ── Build directory ──
BUILD_DIR   := build

# ── Examples ──
EXAMPLES := blinky uart_echo

.PHONY: all clean generate flash-blinky flash-uart-echo $(EXAMPLES)

all: $(EXAMPLES)

# ── Generate register definitions from SVD ──
generate: $(SVD_GEN)

$(SVD_GEN): $(SVD_FILE) tools/svd2odin.py
	@echo "Generating Odin register definitions from SVD..."
	python3 tools/svd2odin.py $(SVD_FILE) $(SVD_GEN) --package stm32f0

# ── Build examples ──
blinky: $(BUILD_DIR)/blinky.bin

uart_echo: $(BUILD_DIR)/uart_echo.bin

$(BUILD_DIR)/%.elf: examples/%/main.odin $(SVD_GEN) $(STARTUP)
	@mkdir -p $(BUILD_DIR)
	@echo "Building $*..."
	# Compile startup assembly
	arm-none-eabi-gcc -c -mcpu=cortex-m0 -mthumb $(STARTUP) -o $(BUILD_DIR)/startup.o
	# Compile Odin source
	$(ODIN) build examples/$*/main.odin $(ODIN_TARGET) $(ODIN_FLAGS) \
		-out:$@ -build-mode:obj
	# Link
	arm-none-eabi-gcc -nostdlib -mcpu=cortex-m0 -mthumb \
		-T$(LINKER) -Wl,--gc-sections \
		$(BUILD_DIR)/startup.o $@ -o $@
	# Show size
	arm-none-eabi-size $@

$(BUILD_DIR)/%.bin: $(BUILD_DIR)/%.elf
	$(OBJCOPY) -O binary $< $@
	@echo "Built $@"

# ── Flash to board ──
flash-blinky: $(BUILD_DIR)/blinky.bin
	$(STFLASH) write $(BUILD_DIR)/blinky.bin 0x08000000

flash-uart-echo: $(BUILD_DIR)/uart_echo.bin
	$(STFLASH) write $(BUILD_DIR)/uart_echo.bin 0x08000000

# ── Debug ──
debug: $(BUILD_DIR)/blinky.elf
	$(GDB) -ex "target extended-remote :4242" \
		-ex "load" \
		-ex "monitor reset halt" \
		$<

# ── Clean ──
clean:
	rm -rf $(BUILD_DIR)
	@echo "Cleaned."
