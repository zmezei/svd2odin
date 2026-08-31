# svd2odin

SVD-to-Odin code generator and thin HAL for bare-metal STM32 development in [Odin](https://odin-lang.org/).

This is the Odin equivalent of Rust's [svd2rust](https://docs.rs/svd2rust/) — parse a CMSIS-SVD file, generate Odin register definitions, then write a thin HAL on top. No C framework required.

## Architecture

```
STM32F051.svd ──[svd2odin.py]──> stm32f0/registers.odin   (registers, fields, enums)
                                      │
                                      v
                            stm32f0/*.odin              (thin HAL: gpio, rcc, usart, timer)
                                      │
                                      v
                            examples/*/main.odin         (your application)
                                      │
                            core/startup/*.s             (vector table, reset handler)
                            core/linker/*.ld             (flash/RAM layout)
                            core/cortex_m0.odin          (SysTick, NVIC, SCB)
```

### Three layers

| Layer | Source | Editable? | Description |
|-------|--------|-----------|-------------|
| **Generated** | SVD file | No — regenerate | Register structs, field masks, base addresses |
| **HAL** | Hand-written | Yes | Thin wrappers: `gpio_set_mode()`, `usart_write_byte()`, etc. |
| **Core** | Hand-written | Yes | Startup assembly, linker scripts, Cortex-M0 core registers |

## Tested hardware

Both examples have been tested on an **STM32F051 Bluepill** development board:

- **MCU:** STM32F051R8T6 (Cortex-M0, 48 MHz, 64 KB flash, 8 KB SRAM)
- **LED:** PC13 (active-low, on-board)
- **UART:** USART1 on PA9 (TX) / PA10 (RX) at 115200 baud
- **Flasher:** ST-Link V2 (SWD)
- **Clock:** HSI + PLL at 48 MHz

## Quick start

### Prerequisites

- [Odin compiler](https://odin-lang.org/docs/install/) (latest)
- ARM GCC toolchain: `arm-none-eabi-gcc`, `arm-none-eabi-objcopy`, `arm-none-eabi-size`
- [stlink](https://github.com/stlink-org/stlink) for flashing (`st-flash`)
- Python 3.10+ (for the generator)

### 1. Get an SVD file

Download the SVD file for your chip from [ST's website](https://www.st.com/en/microcontrollers-microprocessors/stm32-32-bit-arm-cortex-mcus.html) or [Keil's SVD repository](https://github.com/KeilMD/packs).

For STM32F051:

```bash
# Place the SVD file in the svd/ directory
cp /path/to/STM32F051.svd svd/stm32f051.svd
```

### 2. Generate register definitions

```bash
make generate
# or manually:
python3 tools/svd2odin.py svd/stm32f051.svd stm32f0/registers.odin --package stm32f0
```

### 3. Build and flash an example

```bash
# Build blinky
make blinky

# Flash to board (connect ST-Link to Bluepill)
make flash-blinky
```

The on-board LED (PC13) should blink at 1 Hz.

```bash
# Build and flash UART echo
make uart_echo
make flash-uart-echo
```

Connect a serial adapter to PA9 (TX) / PA10 (RX) at 115200 baud. The board sends a startup message and echoes back any characters you type.

## Using the HAL

```odin
package main

import "stm32f0:stm32f0"

@(export=true)
entry :: proc() {
    // Configure 48 MHz clock (HSI + PLL)
    stm32f0.rcc_config_48mhz_pll()

    // Enable GPIOC and set PC13 as output
    stm32f0.rcc_enable_gpio(stm32f0.gpioc)
    stm32f0.gpio_config_output(stm32f0.gpioc, 13, .PushPull, .Low)

    // Initialize timer for delays
    stm32f0.tim2_init_us(48_000_000)

    // Blink
    for {
        stm32f0.gpio_toggle(stm32f0.gpioc, 13)
        stm32f0.delay_ms(500)
    }
}
```

### UART

```odin
// Initialize USART1 on PA9 (TX) / PA10 (RX) at 115200 baud
stm32f0.usart1_init(115200, 48_000_000)
stm32f0.usart_write_string(stm32f0.usart1, "Hello from Odin!\r\n")

// Echo loop
for {
    if stm32f0.usart_data_available(stm32f0.usart1) {
        byte := stm32f0.usart_read_byte(stm32f0.usart1)
        stm32f0.usart_write_byte(stm32f0.usart1, byte)
    }
}
```

## Adding a new chip

1. Download the SVD file for the new chip
2. Run the generator: `python3 tools/svd2odin.py <new_chip>.svd <new_chip>/registers.odin --package <name>`
3. If the chip is in the same family (e.g., STM32F030 vs STM32F051), the existing HAL works as-is
4. If it's a new family, create a new directory and write thin wrappers
5. Add a linker script in `core/linker/` with the correct flash/RAM addresses
6. Add startup assembly in `core/startup/` with the correct vector table

## Project structure

```
svd2odin/
├── tools/
│   └── svd2odin.py          # SVD → Odin register generator
├── stm32f0/                 # Generated + HAL for STM32F0 family
│   ├── registers.odin       # Generated (do not edit)
│   ├── gpio.odin            # HAL
│   ├── rcc.odin             # HAL
│   ├── usart.odin           # HAL
│   └── timer.odin           # HAL
├── core/
│   ├── cortex_m0.odin       # SysTick, NVIC, SCB core registers
│   ├── startup/
│   │   └── startup_stm32f051.s
│   └── linker/
│       └── stm32f051.ld
├── examples/
│   ├── blinky/
│   │   └── main.odin
│   └── uart_echo/
│       └── main.odin
├── svd/                     # Place your SVD files here
├── ols.json                 # OLS language server config
├── odinfmt.json             # Formatter config
├── Makefile
└── README.md
```

## Generated code patterns

The generator produces three kinds of register field representations depending on the SVD field layout:

### Bit sets (all 1-bit fields)

Registers composed entirely of 1-bit flags (e.g., status registers, interrupt enable registers) are emitted as Odin `bit_set` types with a backing `enum`:

```odin
RCC_AHBENR_Flag :: enum u32 {
    DMA1EN = 0,
    SRAMEN = 2,
    IOPAEN = 17,
    // ...
}

RCC_AHBENR_Set :: bit_set[RCC_AHBENR_Flag; u32]
```

This lets you use set algebra instead of manual bitmath:

```odin
rcc_enable_ahb({.IOPAEN, .CRCEN})    // set bits
rcc_disable_ahb({.DMA1EN})           // clear bits
.IOPAEN in intrinsics.volatile_load(&rcc.AHBENR)  // test bit
```

### Plain integers (mixed-width fields)

Registers with multi-bit fields (e.g., 2-bit mode selectors, 4-bit prescalers) stay as plain `u32` with `_POS`, `_MSK`, and `_BIT` constants:

```odin
GPIO_MODER_MODER0_POS :: 0
GPIO_MODER_MODER0_MSK :: 0x3
```

### Enumerated values (from SVD `<enumeratedValues>`)

When the SVD provides enumerated values for a field, the generator emits an Odin enum:

```odin
TEST_CR_MODE_Val :: enum u32 {
    Disabled = 0,
    Enabled  = 1,
    Auto     = 2,
}
```

### Compile-time size checks

Every generated register struct includes a `#assert(size_of(...))` check to catch layout bugs at compile time:

```odin
#assert(size_of(GPIO_Reg) == 44)
```

### Volatile access

The HAL uses `intrinsics.volatile_load` and `intrinsics.volatile_store` for all register access, preventing the compiler from optimizing away or caching hardware register reads and writes.

## Supported chips

Chips are classified by verification level:

| Tier | Meaning |
|------|---------|
| **Maintainer-tested** | Flashed and verified on physical hardware by the maintainer |
| **Community-tested** | Flashed and verified by a PR contributor on their hardware |
| **Generated, untested** | Bindings generated from SVD but never flashed to silicon |

| Chip | SVD | HAL | Startup | Linker | Tier |
|------|-----|-----|---------|--------|------|
| STM32F051x8 | Yes | stm32f0 | Yes | Yes | Maintainer-tested |
| STM32F030 | Yes | stm32f0 | — | — | Generated, untested |
| STM32F103 | Yes | — | — | — | Generated, untested |

Adding support for a new family (F1, F4, G0, etc.) requires writing a new HAL directory and startup/linker files. The generator works with any CMSIS-SVD file.

### Contributing new chip support

When submitting a PR for a chip the maintainer does not own:

1. Include a runnable example (e.g., `examples/blinky`)
2. Paste a flash log or serial output in the PR description
3. The chip will be marked **Community-tested** in the table above

## License

[MIT](LICENSE)
