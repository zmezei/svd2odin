// ──────────────────────────────────────────────────────────────────────
// rcc.odin — Thin HAL for STM32F0 Reset and Clock Control
//
// Clock enable/disable helpers for peripheral buses.
// ──────────────────────────────────────────────────────────────────────

package stm32f0

import "base:intrinsics"

// ── Public API ──

// Enable AHB peripheral clock
rcc_enable_ahb :: proc(flags: RCC_AHBENR_Set) {
    current := intrinsics.volatile_load(&rcc.AHBENR)
    intrinsics.volatile_store(&rcc.AHBENR, current + flags)
}

// Disable AHB peripheral clock
rcc_disable_ahb :: proc(flags: RCC_AHBENR_Set) {
    current := intrinsics.volatile_load(&rcc.AHBENR)
    intrinsics.volatile_store(&rcc.AHBENR, current - flags)
}

// Enable APB1 peripheral clock
rcc_enable_apb1 :: proc(flags: RCC_APB1ENR_Set) {
    current := intrinsics.volatile_load(&rcc.APB1ENR)
    intrinsics.volatile_store(&rcc.APB1ENR, current + flags)
}

// Disable APB1 peripheral clock
rcc_disable_apb1 :: proc(flags: RCC_APB1ENR_Set) {
    current := intrinsics.volatile_load(&rcc.APB1ENR)
    intrinsics.volatile_store(&rcc.APB1ENR, current - flags)
}

// Enable APB2 peripheral clock
rcc_enable_apb2 :: proc(flags: RCC_APB2ENR_Set) {
    current := intrinsics.volatile_load(&rcc.APB2ENR)
    intrinsics.volatile_store(&rcc.APB2ENR, current + flags)
}

// Disable APB2 peripheral clock
rcc_disable_apb2 :: proc(flags: RCC_APB2ENR_Set) {
    current := intrinsics.volatile_load(&rcc.APB2ENR)
    intrinsics.volatile_store(&rcc.APB2ENR, current - flags)
}

// Convenience: enable GPIO port clock by port pointer
rcc_enable_gpio :: proc(port: ^GPIO_Reg) {
    // Derive the AHBENR bit from the base address
    base := uintptr(port)
    // GPIOA=0x48000000, each port is 0x400 apart
    index := (base - GPIOA_BASE) / 0x400
    flag := RCC_AHBENR_Flag(17 + u32(index))
    current := intrinsics.volatile_load(&rcc.AHBENR)
    intrinsics.volatile_store(&rcc.AHBENR, current + {flag})
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
    current_cr2 := intrinsics.volatile_load(&rcc.CR2)
    intrinsics.volatile_store(&rcc.CR2, current_cr2 | RCC_CR2_HSI48ON_BIT)
    // Wait for HSI48 ready
    for (intrinsics.volatile_load(&rcc.CR2) & RCC_CR2_HSI48RDY_BIT) == 0 {}

    // Select HSI48 as system clock
    current_cfgr := intrinsics.volatile_load(&rcc.CFGR)
    intrinsics.volatile_store(&rcc.CFGR, (current_cfgr & ~u32(RCC_CFGR_SW_MSK)) | RCC_CFGR_SW_HSI48)

    // Wait for switch to complete
    for (intrinsics.volatile_load(&rcc.CFGR) & RCC_CFGR_SWS_MSK) != (RCC_CFGR_SW_HSI48 << RCC_CFGR_SWS_POS) {}
}

// Configure system clock to 48 MHz using PLL from HSI (8 MHz * 6 = 48 MHz)
rcc_config_48mhz_pll :: proc() {
    // Enable HSI (should already be on at reset)
    current_cr := intrinsics.volatile_load(&rcc.CR)
    intrinsics.volatile_store(&rcc.CR, current_cr | RCC_CR_HSION_BIT)
    for (intrinsics.volatile_load(&rcc.CR) & RCC_CR_HSIRDY_BIT) == 0 {}

    // Configure PLL: HSI/2 * 12 = 48 MHz
    // PLLSRC = HSI/2 (bit 16 = 0)
    // PLLMUL = 12 (bits 18-21 = 0b1010)
    current_cfgr := intrinsics.volatile_load(&rcc.CFGR)
    intrinsics.volatile_store(&rcc.CFGR, (current_cfgr & ~u32(RCC_CFGR_PLLMUL_MSK)) | (0xA << RCC_CFGR_PLLMUL_POS))

    // Enable PLL
    current_cr = intrinsics.volatile_load(&rcc.CR)
    intrinsics.volatile_store(&rcc.CR, current_cr | RCC_CR_PLLON_BIT)
    for (intrinsics.volatile_load(&rcc.CR) & RCC_CR_PLLRDY_BIT) == 0 {}

    // Select PLL as system clock
    current_cfgr = intrinsics.volatile_load(&rcc.CFGR)
    intrinsics.volatile_store(&rcc.CFGR, (current_cfgr & ~u32(RCC_CFGR_SW_MSK)) | RCC_CFGR_SW_PLL)
    for (intrinsics.volatile_load(&rcc.CFGR) & RCC_CFGR_SWS_MSK) != (RCC_CFGR_SW_PLL << RCC_CFGR_SWS_POS) {}
}
