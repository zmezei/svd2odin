// ──────────────────────────────────────────────────────────────────────
// blinky/main.odin — Blinky example for STM32F051 Bluepill
//
// Toggles PC13 (on-board LED) at 1 Hz using a simple delay loop.
// Demonstrates: RCC clock enable, GPIO output, delay.
//
// Build:
//   odin build main.odin -file -out:blinky.elf \
//     -target:freestanding_arm32_none_eabi -no-crt -no-thread-local \
//     -default-to-nil-allocator -vet
//   arm-none-eabi-objcopy -O binary blinky.elf blinky.bin
//   st-flash write blinky.bin 0x08000000
// ──────────────────────────────────────────────────────────────────────

package main

import "stm32f0"

SYSTEM_CLOCK_HZ :: 48_000_000
LED_PIN :: 13  // PC13 on Bluepill

main :: proc() {
    // Configure system clock to 48 MHz
    stm32f0.rcc_config_48mhz_hsi48()

    // Enable GPIOC clock
    stm32f0.rcc_enable_gpio(stm32f0.gpioc)

    // Configure PC13 as push-pull output
    stm32f0.gpio_config_output(stm32f0.gpioc, LED_PIN, .PushPull, .Low)

    // Initialize TIM2 for delay timing
    stm32f0.tim2_init_us(SYSTEM_CLOCK_HZ)

    // Blink loop
    for {
        stm32f0.gpio_toggle(stm32f0.gpioc, LED_PIN)
        stm32f0.delay_ms(500)
    }
}
