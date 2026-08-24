// ──────────────────────────────────────────────────────────────────────
// rcc.odin — Thin HAL for STM32F0 Reset and Clock Control
//
// Clock enable/disable helpers for peripheral buses.
// ──────────────────────────────────────────────────────────────────────

package stm32f0

// ── Public API ──

// Enable AHB peripheral clock
rcc_enable_ahb :: proc(bits: u32) {
	rcc.AHBENR |= bits
}

// Disable AHB peripheral clock
rcc_disable_ahb :: proc(bits: u32) {
	rcc.AHBENR &= ~bits
}

// Enable APB1 peripheral clock
rcc_enable_apb1 :: proc(bits: u32) {
	rcc.APB1ENR |= bits
}

// Disable APB1 peripheral clock
rcc_disable_apb1 :: proc(bits: u32) {
	rcc.APB1ENR &= ~bits
}

// Enable APB2 peripheral clock
rcc_enable_apb2 :: proc(bits: u32) {
	rcc.APB2ENR |= bits
}

// Disable APB2 peripheral clock
rcc_disable_apb2 :: proc(bits: u32) {
	rcc.APB2ENR &= ~bits
}

// Convenience: enable GPIO port clock by port pointer
rcc_enable_gpio :: proc(port: ^GPIO_Reg) {
	// Derive the AHBENR bit from the base address
	base := uintptr(port)
	// GPIOA=0x48000000, each port is 0x400 apart
	index := (base - GPIOA_BASE) / 0x400
	rcc.AHBENR |= 1 << (17 + u32(index))
}

// ── Clock configuration ──

// System clock source selection values (RCC.CFGR SW field)
RCC_CFGR_SW_HSI :: 0x0 // 8 MHz internal RC
RCC_CFGR_SW_HSE :: 0x1 // External crystal
RCC_CFGR_SW_PLL :: 0x2 // PLL output
RCC_CFGR_SW_HSI48 :: 0x3 // 48 MHz internal RC (STM32F0x1/F0x2/F0x8)

// Configure system clock to 48 MHz using HSI48 (STM32F051)
// This is the simplest path — no PLL, no external crystal needed.
rcc_config_48mhz_hsi48 :: proc() {
	// Enable HSI48
	rcc.CR2 |= RCC_CR2_HSI48ON_BIT
	// Wait for HSI48 ready
	while(rcc.CR2 & RCC_CR2_HSI48RDY_BIT) == 0; {}

	// Select HSI48 as system clock
	rcc.CFGR = (rcc.CFGR & ~RCC_CFGR_SW_MSK) | RCC_CFGR_SW_HSI48

	// Wait for switch to complete
	while(rcc.CFGR & RCC_CFGR_SWS_MSK) != (RCC_CFGR_SW_HSI48 << RCC_CFGR_SWS_POS); {}
}

// Configure system clock to 48 MHz using PLL from HSI (8 MHz * 6 = 48 MHz)
rcc_config_48mhz_pll :: proc() {
	// Enable HSI (should already be on at reset)
	rcc.CR |= RCC_CR_HSION_BIT
	while(rcc.CR & RCC_CR_HSIRDY_BIT) == 0; {}

	// Configure PLL: HSI/2 * 12 = 48 MHz
	// PLLSRC = HSI/2 (bit 16 = 0)
	// PLLMUL = 12 (bits 18-21 = 0b1010)
	rcc.CFGR = (rcc.CFGR & ~RCC_CFGR_PLLMUL_MSK) | (0xA << RCC_CFGR_PLLMUL_POS)

	// Enable PLL
	rcc.CR |= RCC_CR_PLLON_BIT
	while(rcc.CR & RCC_CR_PLLRDY_BIT) == 0; {}

	// Select PLL as system clock
	rcc.CFGR = (rcc.CFGR & ~RCC_CFGR_SW_MSK) | RCC_CFGR_SW_PLL
	while(rcc.CFGR & RCC_CFGR_SWS_MSK) != (RCC_CFGR_SW_PLL << RCC_CFGR_SWS_POS); {}
}
