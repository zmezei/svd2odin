// ──────────────────────────────────────────────────────────────────────
// gpio.odin — Thin HAL for STM32F0 GPIO
//
// Hand-written wrappers on top of generated SVD register definitions.
// One file per peripheral, readable, no state machines.
// ──────────────────────────────────────────────────────────────────────

package stm32f0

// GPIO pin modes (MODER register)
GPIO_Mode :: enum u32 {
    Input   = 0x0,
    Output  = 0x1,
    AF      = 0x2,  // Alternate function
    Analog  = 0x3,
}

// Output type (OTYPER register)
GPIO_OType :: enum u32 {
    PushPull  = 0x0,
    OpenDrain = 0x1,
}

// Output speed (OSPEEDR register)
GPIO_Speed :: enum u32 {
    Low    = 0x0,
    Medium = 0x1,
    High   = 0x3,
}

// Pull-up / pull-down (PUPDR register)
GPIO_Pull :: enum u32 {
    None   = 0x0,
    Up     = 0x1,
    Down   = 0x2,
}

// Alternate function selection (AFRL/AFRH registers)
GPIO_AF :: enum u32 {
    AF0 = 0x0,
    AF1 = 0x1,
    AF2 = 0x2,
    AF3 = 0x3,
    AF4 = 0x4,
    AF5 = 0x5,
    AF6 = 0x6,
    AF7 = 0x7,
}

// ── Public API ──

gpio_set_mode :: proc(port: ^GPIO_Reg, pin: u8, mode: GPIO_Mode) {
    pos := u32(pin) * 2
    port.MODER = (port.MODER & ~(0x3 << pos)) | (u32(mode) << pos)
}

gpio_set_otype :: proc(port: ^GPIO_Reg, pin: u8, otype: GPIO_OType) {
    if otype == .OpenDrain {
        port.OTYPER |= 1 << pin
    } else {
        port.OTYPER &= ~(1 << pin)
    }
}

gpio_set_speed :: proc(port: ^GPIO_Reg, pin: u8, speed: GPIO_Speed) {
    pos := u32(pin) * 2
    port.OSPEEDR = (port.OSPEEDR & ~(0x3 << pos)) | (u32(speed) << pos)
}

gpio_set_pull :: proc(port: ^GPIO_Reg, pin: u8, pull: GPIO_Pull) {
    pos := u32(pin) * 2
    port.PUPDR = (port.PUPDR & ~(0x3 << pos)) | (u32(pull) << pos)
}

gpio_set_af :: proc(port: ^GPIO_Reg, pin: u8, af: GPIO_AF) {
    if pin < 8 {
        pos := u32(pin) * 4
        port.AFRL = (port.AFRL & ~(0xF << pos)) | (u32(af) << pos)
    } else {
        pos := (u32(pin) - 8) * 4
        port.AFRH = (port.AFRH & ~(0xF << pos)) | (u32(af) << pos)
    }
}

// Set pin high (atomic via BSRR)
gpio_set :: proc(port: ^GPIO_Reg, pin: u8) {
    port.BSRR = 1 << pin
}

// Set pin low (atomic via BSRR)
gpio_clear :: proc(port: ^GPIO_Reg, pin: u8) {
    port.BSRR = 1 << (pin + 16)
}

// Toggle pin via ODR
gpio_toggle :: proc(port: ^GPIO_Reg, pin: u8) {
    port.ODR ^= 1 << pin
}

// Read pin input value
gpio_read :: proc(port: ^GPIO_Reg, pin: u8) -> bool {
    return (port.IDR & (1 << pin)) != 0
}

// Read output data register value
gpio_read_odr :: proc(port: ^GPIO_Reg, pin: u8) -> bool {
    return (port.ODR & (1 << pin)) != 0
}

// Configure a pin as output with given speed and type
gpio_config_output :: proc(port: ^GPIO_Reg, pin: u8, otype: GPIO_OType = .PushPull, speed: GPIO_Speed = .Low) {
    gpio_set_mode(port, pin, .Output)
    gpio_set_otype(port, pin, otype)
    gpio_set_speed(port, pin, speed)
}

// Configure a pin as alternate function
gpio_config_af :: proc(port: ^GPIO_Reg, pin: u8, af: GPIO_AF, otype: GPIO_OType = .PushPull, speed: GPIO_Speed = .High) {
    gpio_set_mode(port, pin, .AF)
    gpio_set_af(port, pin, af)
    gpio_set_otype(port, pin, otype)
    gpio_set_speed(port, pin, speed)
}

// Configure a pin as input with optional pull resistor
gpio_config_input :: proc(port: ^GPIO_Reg, pin: u8, pull: GPIO_Pull = .None) {
    gpio_set_mode(port, pin, .Input)
    gpio_set_pull(port, pin, pull)
}
