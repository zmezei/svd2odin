// ──────────────────────────────────────────────────────────────────────
// timer.odin — Thin HAL for STM32F0 timers
//
// Basic timer configuration for delays and periodic interrupts.
// Supports TIM1 (advanced), TIM2/TIM3 (general-purpose 16-bit).
// ──────────────────────────────────────────────────────────────────────

package stm32f0

// TIM CR1 bits
TIM_CR1_CEN  :: 1 << 0   // Counter Enable
TIM_CR1_UDIS :: 1 << 1   // Update Disable
TIM_CR1_URS  :: 1 << 2   // Update Request Source
TIM_CR1_ARPE :: 1 << 7   // Auto-Reload Preload Enable

// TIM DIER bits
TIM_DIER_UIE :: 1 << 0   // Update Interrupt Enable

// TIM SR bits
TIM_SR_UIF   :: 1 << 0   // Update Interrupt Flag

// ── Public API ──

// Initialize a timer for periodic updates at a given frequency.
// The timer counts up and generates an update event when it reaches the
// auto-reload value.
//
// timer_clock_hz: the clock feeding the timer (usually system_clock or system_clock/2)
// frequency_hz: desired update frequency (e.g. 1000 for 1 kHz = 1ms period)
timer_init_periodic :: proc(tim: ^TIM_Reg, timer_clock_hz: u32, frequency_hz: u32) {
    // Disable counter
    tim.CR1 &= ~TIM_CR1_CEN

    // Prescaler: divide timer clock to get 1 MHz (1 us per tick)
    presc := timer_clock_hz / 1_000_000
    tim.PSC = presc - 1

    // Auto-reload: 1 MHz / frequency = period in microseconds
    period := 1_000_000 / frequency_hz
    tim.ARR = period

    // Generate update event to load PSC and ARR
    tim.EGR = 1  // UG bit

    // Clear update flag
    tim.SR &= ~TIM_SR_UIF
}

// Start the timer counter
timer_start :: proc(tim: ^TIM_Reg) {
    tim.CR1 |= TIM_CR1_CEN
}

// Stop the timer counter
timer_stop :: proc(tim: ^TIM_Reg) {
    tim.CR1 &= ~TIM_CR1_CEN
}

// Enable update interrupt
timer_enable_interrupt :: proc(tim: ^TIM_Reg) {
    tim.DIER |= TIM_DIER_UIE
}

// Disable update interrupt
timer_disable_interrupt :: proc(tim: ^TIM_Reg) {
    tim.DIER &= ~TIM_DIER_UIE
}

// Clear the update interrupt flag
timer_clear_flag :: proc(tim: ^TIM_Reg) {
    tim.SR &= ~TIM_SR_UIF
}

// Check if update interrupt flag is set
timer_get_flag :: proc(tim: ^TIM_Reg) -> bool {
    return (tim.SR & TIM_SR_UIF) != 0
}

// Get current counter value
timer_get_counter :: proc(tim: ^TIM_Reg) -> u32 {
    return tim.CNT
}

// Set counter value
timer_set_counter :: proc(tim: ^TIM_Reg, value: u32) {
    tim.CNT = value
}

// ── Microsecond/millisecond delay using busy-wait ──

// Initialize TIM2 for microsecond timing (1 MHz tick rate)
tim2_init_us :: proc(system_clock_hz: u32) {
    rcc_enable_apb1(RCC_APB1ENR_TIM2EN)
    timer_init_periodic(tim2, system_clock_hz, 1_000_000)
    timer_start(tim2)
}

// Delay in microseconds using TIM2
delay_us :: proc(us: u32) {
    start := timer_get_counter(tim2)
    while (timer_get_counter(tim2) - start) < us {}
}

// Delay in milliseconds using TIM2
delay_ms :: proc(ms: u32) {
    delay_us(ms * 1000)
}

// ── Simple cycle-count delay (no timer needed) ──
// Use this before timers are initialized. Approximate for 48 MHz clock.

delay_cycles :: proc(count: u32) {
    for i in 0..<count {
        // Empty loop — compiler barrier via volatile read
    }
}
