// ──────────────────────────────────────────────────────────────────────
// blinky/main.odin — Blinky example for STM32F051 Bluepill
//
// Toggles PC13 (on-board LED) at 1 Hz using a hardware timer delay.
// Demonstrates: RCC clock config, GPIO output, TIM2 timer delay.
//
// Build:
//   make blinky
//   make flash-blinky
// ──────────────────────────────────────────────────────────────────────

package main

import "stm32f0:stm32f0"

SYSTEM_CLOCK_HZ :: 48_000_000
LED_PIN :: 13  // PC13 on Bluepill (active-low)

@(export=true)
entry :: proc() {
    // Configure system clock to 48 MHz (HSI + PLL, same as libopencm3)
    stm32f0.rcc_config_48mhz_pll()

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
