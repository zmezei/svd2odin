// ──────────────────────────────────────────────────────────────────────
// uart_echo/main.odin — UART echo example for STM32F051 Bluepill
//
// Initializes USART1 on PA9 (TX) / PA10 (RX) at 115200 baud.
// Echoes received characters back, toggling PC13 LED on each byte.
//
// Build:
//   odin build main.odin -file -out:uart_echo.elf \
//     -target:freestanding_arm32_none_eabi -no-crt -no-thread-local \
//     -default-to-nil-allocator -collection:stm32f0=../.. -vet
//   arm-none-eabi-objcopy -O binary uart_echo.elf uart_echo.bin
//   st-flash write uart_echo.bin 0x08000000
// ──────────────────────────────────────────────────────────────────────

package main

import "stm32f0:stm32f0"

SYSTEM_CLOCK_HZ :: 48_000_000
LED_PIN :: 13  // PC13 on Bluepill

main :: proc() {
    // Configure system clock to 48 MHz
    stm32f0.rcc_config_48mhz_hsi48()

    // Enable GPIOC and configure LED
    stm32f0.rcc_enable_gpio(stm32f0.gpioc)
    stm32f0.gpio_config_output(stm32f0.gpioc, LED_PIN, .PushPull, .Low)

    // Initialize TIM2 for delay timing
    stm32f0.tim2_init_us(SYSTEM_CLOCK_HZ)

    // Initialize USART1 at 115200 baud
    stm32f0.usart1_init(115200, SYSTEM_CLOCK_HZ)

    // Send startup message
    stm32f0.usart_write_string(stm32f0.usart1, "STM32F051 UART Echo\r\n")
    stm32f0.usart_write_string(stm32f0.usart1, "Ready. Type characters to echo.\r\n")

    // Echo loop
    for {
        if stm32f0.usart_data_available(stm32f0.usart1) {
            byte := stm32f0.usart_read_byte(stm32f0.usart1)
            stm32f0.usart_write_byte(stm32f0.usart1, byte)
            stm32f0.gpio_toggle(stm32f0.gpioc, LED_PIN)
        }
    }
}
