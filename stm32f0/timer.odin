// ──────────────────────────────────────────────────────────────────────
// timer.odin — Thin HAL for STM32F0 timers
//
// Basic timer configuration for delays and periodic interrupts.
// Supports TIM1 (advanced), TIM2/TIM3 (general-purpose 16-bit).
// ──────────────────────────────────────────────────────────────────────

package stm32f0

import "base:intrinsics"

// ── Public API ──

// Initialize a timer for periodic updates at a given frequency.
// The timer counts up and generates an update event when it reaches the
// auto-reload value.
//
// timer_clock_hz: the clock feeding the timer (usually system_clock or system_clock/2)
// frequency_hz: desired update frequency (e.g. 1000 for 1 kHz = 1ms period)
timer_init_periodic :: proc(tim: ^TIM_Reg, timer_clock_hz: u32, frequency_hz: u32) {
    // Disable counter
    current_cr1 := intrinsics.volatile_load(&tim.CR1)
    intrinsics.volatile_store(&tim.CR1, current_cr1 & ~u32(TIM_CR1_CEN_BIT))

    // Prescaler: divide timer clock to get 1 MHz (1 us per tick)
    presc := timer_clock_hz / 1_000_000
    intrinsics.volatile_store(&tim.PSC, presc - 1)

    // Auto-reload: 1 MHz / frequency = period in microseconds
    period := 1_000_000 / frequency_hz
    intrinsics.volatile_store(&tim.ARR, period)

    // Generate update event to load PSC and ARR
    intrinsics.volatile_store(&tim.EGR, {.UG})

    // Clear update flag
    current_sr := intrinsics.volatile_load(&tim.SR)
    intrinsics.volatile_store(&tim.SR, current_sr - {.UIF})
}

// Start the timer counter
timer_start :: proc(tim: ^TIM_Reg) {
    current_cr1 := intrinsics.volatile_load(&tim.CR1)
    intrinsics.volatile_store(&tim.CR1, current_cr1 | TIM_CR1_CEN_BIT)
}

// Stop the timer counter
timer_stop :: proc(tim: ^TIM_Reg) {
    current_cr1 := intrinsics.volatile_load(&tim.CR1)
    intrinsics.volatile_store(&tim.CR1, current_cr1 & ~u32(TIM_CR1_CEN_BIT))
}

// Enable update interrupt
timer_enable_interrupt :: proc(tim: ^TIM_Reg) {
    current_dier := intrinsics.volatile_load(&tim.DIER)
    intrinsics.volatile_store(&tim.DIER, current_dier + {.UIE})
}

// Disable update interrupt
timer_disable_interrupt :: proc(tim: ^TIM_Reg) {
    current_dier := intrinsics.volatile_load(&tim.DIER)
    intrinsics.volatile_store(&tim.DIER, current_dier - {.UIE})
}

// Clear the update interrupt flag
timer_clear_flag :: proc(tim: ^TIM_Reg) {
    current_sr := intrinsics.volatile_load(&tim.SR)
    intrinsics.volatile_store(&tim.SR, current_sr - {.UIF})
}

// Check if update interrupt flag is set
timer_get_flag :: proc(tim: ^TIM_Reg) -> bool {
    return .UIF in intrinsics.volatile_load(&tim.SR)
}

// Get current counter value
timer_get_counter :: proc(tim: ^TIM_Reg) -> u32 {
    return intrinsics.volatile_load(&tim.CNT)
}

// Set counter value
timer_set_counter :: proc(tim: ^TIM_Reg, value: u32) {
    intrinsics.volatile_store(&tim.CNT, value)
}

// ── Microsecond/millisecond delay using busy-wait ──

// Initialize TIM2 for microsecond timing (1 MHz tick rate, free-running)
tim2_init_us :: proc(system_clock_hz: u32) {
    rcc_enable_apb1({.TIM2EN})

    // Disable counter
    current_cr1 := intrinsics.volatile_load(&tim2.CR1)
    intrinsics.volatile_store(&tim2.CR1, current_cr1 & ~u32(TIM_CR1_CEN_BIT))

    // Prescaler: divide timer clock to get 1 MHz (1 us per tick)
    presc := system_clock_hz / 1_000_000
    intrinsics.volatile_store(&tim2.PSC, presc - 1)

    // Auto-reload: maximum value for free-running 32-bit counter
    intrinsics.volatile_store(&tim2.ARR, 0xFFFFFFFF)

    // Generate update event to load PSC and ARR
    intrinsics.volatile_store(&tim2.EGR, {.UG})

    // Clear update flag
    current_sr := intrinsics.volatile_load(&tim2.SR)
    intrinsics.volatile_store(&tim2.SR, current_sr - {.UIF})

    // Start the counter
    timer_start(tim2)
}

// Delay in microseconds using TIM2
delay_us :: proc(us: u32) {
    start := timer_get_counter(tim2)
    for (timer_get_counter(tim2) - start) < us {}
}

// Delay in milliseconds using TIM2
delay_ms :: proc(ms: u32) {
    delay_us(ms * 1000)
}

// ── Simple cycle-count delay (no timer needed) ──
// Use this before timers are initialized. Approximate for 48 MHz clock.

delay_cycles :: proc(count: u32) {
    for _ in 0 ..< count {
        // Empty loop — compiler barrier via volatile read
    }
}
