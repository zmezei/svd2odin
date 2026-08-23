/*
 * startup_stm32f051.s — Cortex-M0 startup code for STM32F051x8
 *
 * Vector table + reset handler. The vector table goes at the very
 * beginning of flash (0x08000000). The initial stack pointer is
 * loaded from the first entry.
 *
 * Customize the interrupt handler names to match your application.
 */

    .syntax unified
    .cpu cortex-m0
    .thumb

    .section .isr_vector, "a", %progbits
    .global __isr_vector
__isr_vector:
    .word _stack_top          /* 0: Initial stack pointer */
    .word reset_handler       /* 1: Reset */
    .word nmi_handler         /* 2: NMI */
    .word hard_fault_handler  /* 3: HardFault */
    .word 0                   /* 4: MemManage (not on M0) */
    .word 0                   /* 5: BusFault (not on M0) */
    .word 0                   /* 6: UsageFault (not on M0) */
    .word 0                   /* 7: Reserved */
    .word 0                   /* 8: Reserved */
    .word 0                   /* 9: Reserved */
    .word 0                   /* 10: Reserved */
    .word sv_call_handler     /* 11: SVCall */
    .word 0                   /* 12: Debug Monitor (not on M0) */
    .word 0                   /* 13: Reserved */
    .word pend_sv_handler     /* 14: PendSV */
    .word systick_handler     /* 15: SysTick */

    /* STM32F051 external interrupts (16+) */
    .word wwdg_handler        /* 16: Window Watchdog */
    .word pvd_handler         /* 17: PVD through EXTI */
    .word rtc_handler         /* 18: RTC */
    .word flash_handler       /* 19: Flash */
    .word rcc_crs_handler     /* 20: RCC / CRS */
    .word exti0_1_handler     /* 21: EXTI Line 0 and 1 */
    .word exti2_3_handler     /* 22: EXTI Line 2 and 3 */
    .word exti4_15_handler    /* 23: EXTI Line 4 to 15 */
    .word tsc_handler         /* 24: Touch Sensing Controller */
    .word dma1_channel1_handler /* 25: DMA1 Channel 1 */
    .word dma1_channel2_3_handler /* 26: DMA1 Channel 2 and 3 */
    .word dma1_channel4_5_handler /* 27: DMA1 Channel 4 and 5 */
    .word adc1_comp_handler   /* 28: ADC1 and COMP */
    .word tim1_brk_up_trg_handler /* 29: TIM1 Break, Up, Trg */
    .word tim1_cc_handler     /* 30: TIM1 Capture Compare */
    .word tim2_handler        /* 31: TIM2 */
    .word tim3_handler        /* 32: TIM3 */
    .word tim6_dac_handler    /* 33: TIM6 and DAC */
    .word tim7_handler        /* 34: TIM7 */
    .word tim14_handler       /* 35: TIM14 */
    .word tim15_handler       /* 36: TIM15 */
    .word tim16_handler       /* 37: TIM16 */
    .word tim17_handler       /* 38: TIM17 */
    .word i2c1_handler        /* 39: I2C1 */
    .word i2c2_handler        /* 40: I2C2 */
    .word spi1_handler        /* 41: SPI1 */
    .word spi2_handler        /* 42: SPI2 */
    .word usart1_handler      /* 43: USART1 */
    .word usart2_handler      /* 44: USART2 */
    .word 0                   /* 45: Reserved */
    .word 0                   /* 46: Reserved */
    .word 0                   /* 47: Reserved */
    .word cec_can_handler     /* 48: CEC and CAN */

    .section .text
    .global reset_handler
    .thumb_func
reset_handler:
    /* Copy .data from flash to RAM */
    ldr r0, =_sidata
    ldr r1, =_sdata
    ldr r2, =_edata
copy_data:
    cmp r1, r2
    bcs copy_data_done
    ldr r3, [r0], #4
    str r3, [r1], #4
    b copy_data
copy_data_done:

    /* Zero .bss */
    ldr r1, =_sbss
    ldr r2, =_ebss
    movs r3, #0
zero_bss:
    cmp r1, r2
    bcs zero_bss_done
    str r3, [r1], #4
    b zero_bss
zero_bss_done:

    /* Call main */
    bl main

    /* If main returns, loop forever */
hang:
    b hang

    .weak nmi_handler
    .weak hard_fault_handler
    .weak sv_call_handler
    .weak pend_sv_handler
    .weak systick_handler
    .weak wwdg_handler
    .weak pvd_handler
    .weak rtc_handler
    .weak flash_handler
    .weak rcc_crs_handler
    .weak exti0_1_handler
    .weak exti2_3_handler
    .weak exti4_15_handler
    .weak tsc_handler
    .weak dma1_channel1_handler
    .weak dma1_channel2_3_handler
    .weak dma1_channel4_5_handler
    .weak adc1_comp_handler
    .weak tim1_brk_up_trg_handler
    .weak tim1_cc_handler
    .weak tim2_handler
    .weak tim3_handler
    .weak tim6_dac_handler
    .weak tim7_handler
    .weak tim14_handler
    .weak tim15_handler
    .weak tim16_handler
    .weak tim17_handler
    .weak i2c1_handler
    .weak i2c2_handler
    .weak spi1_handler
    .weak spi2_handler
    .weak usart1_handler
    .weak usart2_handler
    .weak cec_can_handler

    .thumb_set nmi_handler, hang
    .thumb_set hard_fault_handler, hang
    .thumb_set sv_call_handler, hang
    .thumb_set pend_sv_handler, hang
    .thumb_set systick_handler, hang
    .thumb_set wwdg_handler, hang
    .thumb_set pvd_handler, hang
    .thumb_set rtc_handler, hang
    .thumb_set flash_handler, hang
    .thumb_set rcc_crs_handler, hang
    .thumb_set exti0_1_handler, hang
    .thumb_set exti2_3_handler, hang
    .thumb_set exti4_15_handler, hang
    .thumb_set tsc_handler, hang
    .thumb_set dma1_channel1_handler, hang
    .thumb_set dma1_channel2_3_handler, hang
    .thumb_set dma1_channel4_5_handler, hang
    .thumb_set adc1_comp_handler, hang
    .thumb_set tim1_brk_up_trg_handler, hang
    .thumb_set tim1_cc_handler, hang
    .thumb_set tim2_handler, hang
    .thumb_set tim3_handler, hang
    .thumb_set tim6_dac_handler, hang
    .thumb_set tim7_handler, hang
    .thumb_set tim14_handler, hang
    .thumb_set tim15_handler, hang
    .thumb_set tim16_handler, hang
    .thumb_set tim17_handler, hang
    .thumb_set i2c1_handler, hang
    .thumb_set i2c2_handler, hang
    .thumb_set spi1_handler, hang
    .thumb_set spi2_handler, hang
    .thumb_set usart1_handler, hang
    .thumb_set usart2_handler, hang
    .thumb_set cec_can_handler, hang
