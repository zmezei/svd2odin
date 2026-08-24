// ──────────────────────────────────────────────────────────────────────
// usart.odin — Thin HAL for STM32F0 USART
//
// Basic polling-based UART transmit/receive.
// STM32F0 uses ISR (not SR) and TDR/RDR (not DR).
// ──────────────────────────────────────────────────────────────────────

package stm32f0

// ── Public API ──

// Initialize USART for basic TX/RX at a given baud rate.
// Assumes the GPIO pins are already configured as alternate function.
usart_init :: proc(usart: ^USART_Reg, baud_rate: u32, system_clock_hz: u32) {
    // Disable USART
    usart.CR1 = 0

    // Set baud rate (USARTDIV = system_clock / baud_rate)
    usart.BRR = system_clock_hz / baud_rate

    // Enable TX, RX, and USART
    usart.CR1 = USART_CR1_UE_BIT | USART_CR1_TE_BIT | USART_CR1_RE_BIT
}

// Wait for transmit data register to be empty, then write a byte
usart_write_byte :: proc(usart: ^USART_Reg, byte: u8) {
    while (usart.ISR & USART_ISR_TXE_BIT) == 0 {}
    usart.TDR = u32(byte)
}

// Wait for a byte to be received
usart_read_byte :: proc(usart: ^USART_Reg) -> u8 {
    while (usart.ISR & USART_ISR_RXNE_BIT) == 0 {}
    return u8(usart.RDR & 0xFF)
}

// Write a string
usart_write_string :: proc(usart: ^USART_Reg, s: string) {
    for c in s {
        usart_write_byte(usart, u8(c))
    }
}

// Write a single character
usart_write_char :: proc(usart: ^USART_Reg, c: rune) {
    usart_write_byte(usart, u8(c))
}

// Write a newline (CRLF)
usart_write_line :: proc(usart: ^USART_Reg) {
    usart_write_byte(usart, '\r')
    usart_write_byte(usart, '\n')
}

// Check if data is available to read
usart_data_available :: proc(usart: ^USART_Reg) -> bool {
    return (usart.ISR & USART_ISR_RXNE_BIT) != 0
}

// Check if transmission is complete
usart_tx_complete :: proc(usart: ^USART_Reg) -> bool {
    return (usart.ISR & USART_ISR_TC_BIT) != 0
}

// Flush any pending receive data
usart_flush_rx :: proc(usart: ^USART_Reg) {
    while (usart.ISR & USART_ISR_RXNE_BIT) != 0 {
        _ = usart.RDR
    }
}

// ── Convenience: USART1 on PA9 (TX) / PA10 (RX) ──

// Initialize USART1 with default pin configuration for STM32F051
// PA9 = USART1_TX (AF1), PA10 = USART1_RX (AF1)
usart1_init :: proc(baud_rate: u32, system_clock_hz: u32) {
    // Enable GPIOA and USART1 clocks
    rcc_enable_gpio(gpioa)
    rcc_enable_apb2(RCC_APB2ENR_USART1EN_BIT)

    // Configure PA9 (TX) and PA10 (RX) as alternate function AF1
    gpio_config_af(gpioa, 9, .AF1, .PushPull, .High)
    gpio_config_af(gpioa, 10, .AF1, .PushPull, .High)

    usart_init(usart1, baud_rate, system_clock_hz)
}
