// Copyright 2022 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Nicole Narr <narrn@student.ethz.ch>
// Christopher Reinwardt <creinwar@student.ethz.ch>
// Paul Scheffler <paulsc@iis.ee.ethz.ch>

// TODO: Avoid hardcoding in addresses and offsets

#include "smp.h"

.section .text._start

// Minimal bootrom loader
.global _start
.align 4
_start:
    // Reset all integer GPRs; we do *not* assume FP in the boot ROM.
    li x1, 0
    li x4, 0
    li x5, 0
    li x6, 0
    li x7, 0
    li x8, 0
    li x9, 0
    li x10, 0
    li x11, 0
    li x12, 0
    li x13, 0
    li x14, 0
    li x15, 0
    li x16, 0
    li x17, 0
    li x18, 0
    li x19, 0
    li x20, 0
    li x21, 0
    li x22, 0
    li x23, 0
    li x24, 0
    li x25, 0
    li x26, 0
    li x27, 0
    li x28, 0
    li x29, 0
    li x30, 0
    li x31, 0

    // Pause SMP harts
    smp_pause(t0, t1)

    // Init stack and global pointer with safe, linked values
    la sp, __stack_pointer$
    .option push
    .option norelax
    la gp, __global_pointer$
    .option pop

    // If LLC present: Wait for end of BIST, then extend stack and set to all SPM
    la t0, __base_regs
    lw t0, 80(t0)   // regs.HW_FEATURES
    andi t0, t0, 2  // regs.HW_FEATURES.llc
    beqz t0, _prom_check_run
    la t0, __base_llc
_wait_llc_bist:
    lw t1, 72(t0)   // llc.BIST_STATUS_DONE_BIT
    beqz t1, _wait_llc_bist
    li t1, -1
    sw t1, 0(t0)    // llc.CFG_SPM_LOW
    sw t1, 4(t0)    // llc.CFG_SPM_HIGH
    li t1, 1
    sw t1, 16(t0)   // llc.CFG_COMMIT
    // Correct stack to start at end of SPM
    la t0, __base_regs
    la sp, __base_spm
    lw t0, 84(t0)   // regs.LLC_SIZE
    add sp, sp, t0
    addi sp, sp, -8

// Enter Platform ROM if present.
_prom_check_run:
    // Note that we have internal access to SPM here *if and only if* there is an LLC.
    la t0, __base_regs
    lw t0, 72(t0)   // regs.PLATFORM_ROM
    beqz t0, _boot
    jalr t0

// Reset regs, full fence, then jump to main
_boot:
    li t0, 0
    li t1, 0
    fence
    fence.i
    call main

// If main returns, we end up here
.global _exit
.align 4
_exit:
    // Save the return value to scratch register 2, try `ebreak`, then wait forever
    slli a0, a0, 1
    ori  a0, a0, 1
    la t0, __base_regs
    sw a0, 8(t0)     // regs.SCRATCH[2]
    ebreak
1:  wfi
    j 1b

.global boot_next_stage
.align 4
boot_next_stage:
    // Non-SMP hart: Write boot address into global scratch registers
    la t0, __base_regs
    sw a0, 16(t0)   // regs.SCRATCH[4]
    srli a0, a0, 32
    sw a0, 20(t0)   // regs.SCRATCH[5]
    fence
    // Resume SMP harts
    smp_resume(t0, t1, t2)
    // Load boot address from global scratch registers
    la t0, __base_regs
    lwu t1, 20(t0)  // regs.SCRATCH[5]
    slli t1, t1, 32
    lwu t0, 16(t0)  // regs.SCRATCH[4]
    or t0, t0, t1
    // Store hartid to a0
    csrr a0, mhartid
    // Jump to boot address
    jalr ra, 0(t0)
    // We should never get here
    ret
