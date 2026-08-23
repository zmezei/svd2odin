/*
 * stm32f051.ld — Linker script for STM32F051x8
 *
 * Flash: 64KB at 0x08000000
 * RAM:   8KB at 0x20000000
 *
 * Stack grows downward from the top of RAM.
 */

ENTRY(reset_handler)

MEMORY
{
    FLASH (rx)  : ORIGIN = 0x08000000, LENGTH = 64K
    RAM   (rwx) : ORIGIN = 0x20000000, LENGTH = 8K
}

_stack_top = ORIGIN(RAM) + LENGTH(RAM);

SECTIONS
{
    /* Vector table at the start of flash */
    .isr_vector :
    {
        . = ALIGN(4);
        KEEP(*(.isr_vector))
        . = ALIGN(4);
    } > FLASH

    /* Code */
    .text :
    {
        . = ALIGN(4);
        *(.text)
        *(.text.*)
        *(.rodata)
        *(.rodata.*)
        . = ALIGN(4);
        _etext = .;
    } > FLASH

    /* .data — initialized variables, copied from flash to RAM at startup */
    _sidata = LOADADDR(.data);
    .data : AT (ADDR(.text) + SIZEOF(.text))
    {
        . = ALIGN(4);
        _sdata = .;
        *(.data)
        *(.data.*)
        . = ALIGN(4);
        _edata = .;
    } > RAM

    /* .bss — zero-initialized variables */
    .bss :
    {
        . = ALIGN(4);
        _sbss = .;
        *(.bss)
        *(.bss.*)
        *(COMMON)
        . = ALIGN(4);
        _ebss = .;
    } > RAM

    /* Heap starts after .bss, grows toward stack */
    _heap_start = .;
    _heap_end = _stack_top - 1024;  /* Reserve 1KB for stack */
}
