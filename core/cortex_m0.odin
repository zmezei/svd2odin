// ──────────────────────────────────────────────────────────────────────
// cortex_m0.odin — Cortex-M0 core register definitions
//
// These are the CPU core registers (SysTick, NVIC, SCB) that are
// common to all Cortex-M0 chips. They are NOT in the SVD file
// (or are in a separate CPU SVD), so we define them here by hand.
// ──────────────────────────────────────────────────────────────────────

package cortex_m0

import "core:mem"
import "base:intrinsics"

// ── System Control Block (SCB) ──

SCB_BASE :: 0xE000ED00

SCB :: struct {
    CPACR:   u32,  // 0x88 — Coprocessor Access Control (not on M0, reserved)
    RES0:    [0x24 - 0x04]u8,
    CCR:     u32,  // 0x14 — Configuration and Control
    RES1:    [0x20 - 0x18]u8,
    SHPR:    [3]u32, // 0x1C-0x24 — System Handler Priority Register (2/3 on M0)
    RES2:    [0x30 - 0x28]u8,
    SHCSR:   u32,  // 0x24 — System Handler Control and State
    RES3:    [0x3C - 0x28]u8,
    CFSR:    u32,  // 0x28 — Configurable Fault Status Reg (M0: only MMFSR+BFSR+USFSR)
    RES4:    [0x34 - 0x2C]u8,
    HFSR:    u32,  // 0x2C — HardFault Status Register
    RES5:    [0x3C - 0x30]u8,
    DFSR:    u32,  // 0x30 — Debug Fault Status Register
    RES6:    [0x3C - 0x34]u8,
    MMFAR:   u32,  // 0x34 — MemManage Fault Address (not on M0)
    BFAR:    u32,  // 0x38 — BusFault Address (not on M0)
    RES7:    [0x3C - 0x3C]u8,
    AFSR:    u32,  // 0x3C — Auxiliary Fault Status Register (not on M0)
}

scb := (^SCB)(rawptr(uintptr(SCB_BASE)))

// SCB.CCR bits
SCB_CCR_STKALIGN :: 1 << 9
SCB_CCR_BFHFNMIGN :: 1 << 8
SCB_CCR_DIV_0_TRP :: 1 << 4
SCB_CCR_UNALIGN_TRP :: 1 << 3

// SCB.SHCSR bits
SCB_SHCSR_SVCALLPENDED :: 1 << 15
SCB_SHCSR_BUSFAULTPENDED :: 1 << 14
SCB_SHCSR_MEMFAULTPENDED :: 1 << 13
SCB_SHCSR_USGFAULTPENDED :: 1 << 12
SCB_SHCSR_SVCALLACT :: 1 << 7
SCB_SHCSR_BUSFAULTACT :: 1 << 1
SCB_SHCSR_MEMFAULTACT :: 1 << 0

// ── SysTick Timer ──

SYSTICK_BASE :: 0xE000E010

SysTick :: struct {
    CSR:    u32,  // 0x00 — Control and Status
    RVR:    u32,  // 0x04 — Reload Value
    CVR:    u32,  // 0x08 — Current Value
    CALIB:  u32,  // 0x0C — Calibration Value
}

systick := (^SysTick)(rawptr(uintptr(SYSTICK_BASE)))

// SysTick.CSR bits
SYSTICK_CSR_ENABLE :: 1 << 0
SYSTICK_CSR_TICKINT :: 1 << 1
SYSTICK_CSR_CLKSOURCE :: 1 << 2
SYSTICK_CSR_COUNTFLAG :: 1 << 16

// ── Nested Vectored Interrupt Controller (NVIC) ──

NVIC_BASE :: 0xE000E100

NVIC :: struct {
    ISER: [2]u32,   // 0x00 — Interrupt Set Enable (0-63)
    RES0: [0x80 - 0x08]u8,
    ICER: [2]u32,   // 0x80 — Interrupt Clear Enable (0-63)
    RES1: [0x100 - 0x88]u8,
    ISPR: [2]u32,   // 0x100 — Interrupt Set Pending (0-63)
    RES2: [0x180 - 0x108]u8,
    ICPR: [2]u32,   // 0x180 — Interrupt Clear Pending (0-63)
    RES3: [0x200 - 0x188]u8,
    IPR:  [32]u8,   // 0x200 — Interrupt Priority (8-bit each, 2-bit used on M0)
}

nvic := (^NVIC)(rawptr(uintptr(NVIC_BASE)))

// ── Application Interrupt and Reset Control (AIRCR) ──

SCB_AIRCR :: 0xE000ED0C
SCB_AIRCR_VECTKEY :: 0x5FA << 16
SCB_AIRCR_SYSRESETREQ :: 1 << 2

// ── Helper functions ──

// Enable a specific interrupt (IRQn 0-31 for Cortex-M0)
nvic_enable_irq :: proc(irqn: i32) {
    if irqn >= 0 && irqn < 32 {
        current := intrinsics.volatile_load(&nvic.ISER[0])
        intrinsics.volatile_store(&nvic.ISER[0], current | (1 << irqn))
    }
}

// Disable a specific interrupt
nvic_disable_irq :: proc(irqn: i32) {
    if irqn >= 0 && irqn < 32 {
        current := intrinsics.volatile_load(&nvic.ICER[0])
        intrinsics.volatile_store(&nvic.ICER[0], current | (1 << irqn))
    }
}

// Set interrupt priority (0 = highest, 3 = lowest on Cortex-M0)
nvic_set_priority :: proc(irqn: i32, priority: u8) {
    if irqn >= 0 && irqn < 32 {
        // Cortex-M0 uses top 2 bits of each priority byte
        shifted :: priority & 0x3
        intrinsics.volatile_store(&nvic.IPR[irqn], shifted << 6)
    }
}

// Configure SysTick for periodic interrupts
// reload = clock_hz / ticks_per_sec - 1
systick_config :: proc(reload: u32, enable_interrupt: bool) {
    intrinsics.volatile_store(&systick.RVR, reload)
    intrinsics.volatile_store(&systick.CVR, 0)
    ctrl: u32 = SYSTICK_CSR_ENABLE | SYSTICK_CSR_CLKSOURCE
    if enable_interrupt {
        ctrl |= SYSTICK_CSR_TICKINT
    }
    intrinsics.volatile_store(&systick.CSR, ctrl)
}

// Get SysTick counter value (counts down from reload to 0)
systick_get_value :: proc() -> u32 {
    return intrinsics.volatile_load(&systick.CVR)
}

// Check if SysTick has wrapped (COUNTFLAG set)
systick_check_overflow :: proc() -> bool {
    return (intrinsics.volatile_load(&systick.CSR) & SYSTICK_CSR_COUNTFLAG) != 0
}

// Global interrupt control
enable_interrupts :: proc() {
    asm {
        cpsie i
    }
}

disable_interrupts :: proc() -> bool {
    was_enabled: bool
    asm {
        mrs r0, PRIMASK
        cpsid i
    }
    // PRIMASK: 0 = interrupts enabled, 1 = disabled
    return !was_enabled
}

// System reset
system_reset :: proc() {
    scb_raw := (^u32)(rawptr(uintptr(SCB_AIRCR)))
    intrinsics.volatile_store(scb_raw, SCB_AIRCR_VECTKEY | SCB_AIRCR_SYSRESETREQ)
    for {}
}
