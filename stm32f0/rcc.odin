// ──────────────────────────────────────────────────────────────────────
// rcc.odin — Thin HAL for STM32F0 Reset and Clock Control
//
// Clock enable/disable helpers for peripheral buses.
// ──────────────────────────────────────────────────────────────────────

package stm32f0

// AHB peripheral clock enable bits (RCC.AHBENR)
RCC_AHBENR_DMA1EN    :: 1 << 0
RCC_AHBENR_DMA2EN    :: 1 << 1
RCC_AHBENR_SRAMEN    :: 1 << 2
RCC_AHBENR_FLITFEN   :: 1 << 4
RCC_AHBENR_CRCEN     :: 1 << 6
RCC_AHBENR_GPIOAEN   :: 1 << 17
RCC_AHBENR_GPIOBEN   :: 1 << 18
RCC_AHBENR_GPIOCEN   :: 1 << 19
RCC_AHBENR_GPIODEN   :: 1 << 20
RCC_AHBENR_GPIOFEN   :: 1 << 22

// APB1 peripheral clock enable bits (RCC.APB1ENR)
RCC_APB1ENR_TIM2EN   :: 1 << 0
RCC_APB1ENR_TIM3EN   :: 1 << 1
RCC_APB1ENR_TIM6EN   :: 1 << 4
RCC_APB1ENR_TIM7EN   :: 1 << 5
RCC_APB1ENR_TIM14EN  :: 1 << 8
RCC_APB1ENR_WWDGEN   :: 1 << 11
RCC_APB1ENR_SPI2EN   :: 1 << 14
RCC_APB1ENR_USART2EN :: 1 << 17
RCC_APB1ENR_I2C1EN   :: 1 << 21
RCC_APB1ENR_I2C2EN   :: 1 << 22

// APB2 peripheral clock enable bits (RCC.APB2ENR)
RCC_APB2ENR_SYSCFGEN :: 1 << 0
RCC_APB2ENR_ADC1EN   :: 1 << 9
RCC_APB2ENR_TIM1EN   :: 1 << 11
RCC_APB2ENR_SPI1EN   :: 1 << 12
RCC_APB2ENR_USART1EN :: 1 << 14
RCC_APB2ENR_TIM15EN  :: 1 << 16
RCC_APB2ENR_TIM16EN  :: 1 << 17
RCC_APB2ENR_TIM17EN  :: 1 << 18

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

// System clock source selection (RCC.CFGR SW bits)
RCC_CFGR_SW_HSI :: 0x0  // 8 MHz internal RC
RCC_CFGR_SW_HSI48 :: 0x3  // 48 MHz internal RC (STM32F0x1/F0x2/F0x8)
RCC_CFGR_SW_PLL :: 0x2   // PLL output
RCC_CFGR_SW_HSE :: 0x1   // External crystal

// Configure system clock to 48 MHz using HSI48 (STM32F051)
// This is the simplest path — no PLL, no external crystal needed.
rcc_config_48mhz_hsi48 :: proc() {
    // Enable HSI48
    rcc.CR2 |= 1 << 16  // HSI48ON
    // Wait for HSI48 ready
    while (rcc.CR2 & (1 << 17)) == 0 {}  // HSI48RDY

    // Select HSI48 as system clock
    rcc.CFGR = (rcc.CFGR & ~0x3) | RCC_CFGR_SW_HSI48

    // Wait for switch to complete
    while (rcc.CFGR & (0x3 << 2)) != (RCC_CFGR_SW_HSI48 << 2) {}
}

// Configure system clock to 48 MHz using PLL from HSI (8 MHz * 6 = 48 MHz)
rcc_config_48mhz_pll :: proc() {
    // Enable HSI (should already be on at reset)
    rcc.CR |= 1 << 0  // HSION
    while (rcc.CR & (1 << 1)) == 0 {}  // HSIRDY

    // Configure PLL: HSI/2 * 12 = 48 MHz
    // PLLSRC = HSI/2 (bit 16 = 0)
    // PLLMUL = 12 (bits 18-21 = 0b1010)
    rcc.CFGR = (rcc.CFGR & ~(0xF << 18)) | (0xA << 18)

    // Enable PLL
    rcc.CR |= 1 << 24  // PLLON
    while (rcc.CR & (1 << 25)) == 0 {}  // PLLRDY

    // Select PLL as system clock
    rcc.CFGR = (rcc.CFGR & ~0x3) | RCC_CFGR_SW_PLL
    while (rcc.CFGR & (0x3 << 2)) != (RCC_CFGR_SW_PLL << 2) {}
}
