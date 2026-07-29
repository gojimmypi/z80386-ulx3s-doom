.code16
.intel_syntax noprefix
.section .text
.global _start

# Emit the current test number before performing each operation. If a check
# fails or the CPU hangs, the LEDs retain the failing test number.
.macro progress value
    mov al, \value
    out dx, al
.endm

# Establish OF=1 and CF=1 for count-zero flag-preservation checks.
.macro set_of_cf
    mov ax, 0x7fff
    add ax, 1
    stc
.endm

_start:
    # 386 reset vector at physical FFFFFFF0.
    .byte 0xea, 0x00, 0x00, 0x00, 0xf0
    .fill 11, 1, 0x90

    # Binary offset 0x10000 maps to physical 000F0000.
    .org 0x10000

regression_start:
    cli
    mov dx, 0x0080

    # SHL counts 0, 1, 16, 17.
    progress 0x01
    set_of_cf
    mov bx, 0x8123
    shl bx, 0
    jno fail
    jnc fail
    cmp bx, 0x8123
    jne fail

    progress 0x02
    mov bx, 0x8123
    shl bx, 1
    jno fail
    jnc fail
    cmp bx, 0x0246
    jne fail

    progress 0x03
    mov bx, 0x8123
    shl bx, 16
    cmp bx, 0x0000
    jne fail

    progress 0x04
    mov bx, 0x8123
    shl bx, 17
    cmp bx, 0x0000
    jne fail

    # SHR counts 0, 1, 16, 17.
    progress 0x05
    set_of_cf
    mov bx, 0x8123
    shr bx, 0
    jno fail
    jnc fail
    cmp bx, 0x8123
    jne fail

    progress 0x06
    mov bx, 0x8123
    shr bx, 1
    jno fail
    jnc fail
    cmp bx, 0x4091
    jne fail

    progress 0x07
    mov bx, 0x8123
    shr bx, 16
    cmp bx, 0x0000
    jne fail

    progress 0x08
    mov bx, 0x8123
    shr bx, 17
    cmp bx, 0x0000
    jne fail

    # SAR counts 0, 1, 16, 17.
    progress 0x09
    set_of_cf
    mov bx, 0x8123
    sar bx, 0
    jno fail
    jnc fail
    cmp bx, 0x8123
    jne fail

    progress 0x0a
    mov bx, 0x8123
    sar bx, 1
    jo fail
    jnc fail
    cmp bx, 0xc091
    jne fail

    progress 0x0b
    mov bx, 0x8123
    sar bx, 16
    cmp bx, 0xffff
    jne fail

    progress 0x0c
    mov bx, 0x8123
    sar bx, 17
    cmp bx, 0xffff
    jne fail

    # ROL counts 0, 1, 16, 17.
    progress 0x0d
    set_of_cf
    mov bx, 0x8123
    rol bx, 0
    jno fail
    jnc fail
    cmp bx, 0x8123
    jne fail

    progress 0x0e
    mov bx, 0x8123
    rol bx, 1
    jno fail
    jnc fail
    cmp bx, 0x0247
    jne fail

    # ROL count 16 has an effective rotation count of zero, so the result is
    # unchanged. Because the masked count is nonzero, CF is still updated to
    # bit 0 of the result. OF is undefined for counts other than one.
    progress 0x0f
    clc
    mov bx, 0x8123
    rol bx, 16
    jnc fail
    cmp bx, 0x8123
    jne fail

    # Count 17 produces the same result and CF as count one. OF is undefined
    # because the masked count is 17 rather than one.
    progress 0x10
    clc
    mov bx, 0x8123
    rol bx, 17
    jnc fail
    cmp bx, 0x0247
    jne fail

    # ROR counts 0, 1, 16, 17.
    progress 0x11
    set_of_cf
    mov bx, 0x8123
    ror bx, 0
    jno fail
    jnc fail
    cmp bx, 0x8123
    jne fail

    progress 0x12
    mov bx, 0x8123
    ror bx, 1
    jo fail
    jnc fail
    cmp bx, 0xc091
    jne fail

    # ROR count 16 also leaves the result unchanged while updating CF to
    # the high bit of the result. OF is undefined for counts other than one.
    progress 0x13
    clc
    mov bx, 0x8123
    ror bx, 16
    jnc fail
    cmp bx, 0x8123
    jne fail

    # Count 17 produces the same result and CF as count one. Do not inspect OF.
    progress 0x14
    clc
    mov bx, 0x8123
    ror bx, 17
    jnc fail
    cmp bx, 0xc091
    jne fail

    # RCL counts 0, 1, 16, 17.
    progress 0x15
    set_of_cf
    mov bx, 0x8123
    rcl bx, 0
    jno fail
    jnc fail
    cmp bx, 0x8123
    jne fail

    progress 0x16
    stc
    mov bx, 0x8123
    rcl bx, 1
    jno fail
    jnc fail
    cmp bx, 0x0247
    jne fail

    progress 0x17
    stc
    mov bx, 0x8123
    rcl bx, 16
    jnc fail
    cmp bx, 0xc091
    jne fail

    progress 0x18
    clc
    mov bx, 0x8123
    rcl bx, 17
    jc fail
    cmp bx, 0x8123
    jne fail

    # RCR counts 0, 1, 16, 17.
    progress 0x19
    set_of_cf
    mov bx, 0x8123
    rcr bx, 0
    jno fail
    jnc fail
    cmp bx, 0x8123
    jne fail

    progress 0x1a
    stc
    mov bx, 0x8123
    rcr bx, 1
    jo fail
    jnc fail
    cmp bx, 0xc091
    jne fail

    progress 0x1b
    stc
    mov bx, 0x8123
    rcr bx, 16
    jnc fail
    cmp bx, 0x0247
    jne fail

    progress 0x1c
    clc
    mov bx, 0x8123
    rcr bx, 17
    jc fail
    cmp bx, 0x8123
    jne fail

    # SHLD counts 0, 1, 16, 17.
    progress 0x1d
    set_of_cf
    mov bx, 0x8123
    mov si, 0x4567
    shld bx, si, 0
    jno fail
    jnc fail
    cmp bx, 0x8123
    jne fail

    progress 0x1e
    mov bx, 0x8123
    mov si, 0x4567
    shld bx, si, 1
    jnc fail
    cmp bx, 0x0246
    jne fail

    progress 0x1f
    mov bx, 0x8123
    mov si, 0x4567
    shld bx, si, 16
    jnc fail
    cmp bx, 0x4567
    jne fail

    # Count 17 is architecturally undefined for a 16-bit SHLD operand. Verify
    # that the instruction completes without corrupting an unrelated canary.
    progress 0x20
    mov di, 0x5aa5
    mov bx, 0x8123
    mov si, 0x4567
    shld bx, si, 17
    cmp di, 0x5aa5
    jne fail

    # SHRD counts 0, 1, 16, 17.
    progress 0x21
    set_of_cf
    mov bx, 0x8123
    mov si, 0x4567
    shrd bx, si, 0
    jno fail
    jnc fail
    cmp bx, 0x8123
    jne fail

    progress 0x22
    mov bx, 0x8123
    mov si, 0x4567
    shrd bx, si, 1
    jnc fail
    cmp bx, 0xc091
    jne fail

    progress 0x23
    mov bx, 0x8123
    mov si, 0x4567
    shrd bx, si, 16
    jnc fail
    cmp bx, 0x4567
    jne fail

    # Count 17 is architecturally undefined for a 16-bit SHRD operand. Verify
    # that the instruction completes without corrupting an unrelated canary.
    progress 0x24
    mov di, 0x5aa5
    mov bx, 0x8123
    mov si, 0x4567
    shrd bx, si, 17
    cmp di, 0x5aa5
    jne fail

    # BSR has no count operand. Test zero input and highest set-bit positions
    # 0, 1, 16, and 17 using 32-bit operands in 16-bit code.
    progress 0x25
    mov eax, 0x00000000
    mov ecx, 0x12345678
    mov bx, 1
    or bx, bx                 # Establish ZF=0 before BSR zero input.
    bsr ecx, eax
    jnz fail                  # Zero input must set ZF=1.

    progress 0x26
    mov eax, 0x00000001
    xor bx, bx                # Establish ZF=1 before nonzero BSR.
    bsr ecx, eax
    jz fail
    cmp ecx, 0
    jne fail

    progress 0x27
    mov eax, 0x00000002
    xor bx, bx
    bsr ecx, eax
    jz fail
    cmp ecx, 1
    jne fail

    progress 0x28
    mov eax, 0x00010000
    xor bx, bx
    bsr ecx, eax
    jz fail
    cmp ecx, 16
    jne fail

    progress 0x29
    mov eax, 0x00020000
    xor bx, bx
    bsr ecx, eax
    jz fail
    cmp ecx, 17
    jne fail

    # All tests passed. Alternate A5 and 5A slowly enough to observe.
    mov al, 0xa5
pass_blink:
    out dx, al
    mov si, 0x0020
pass_outer:
    mov cx, 0xffff
pass_inner:
    loop pass_inner
    dec si
    jnz pass_outer
    xor al, 0xff
    jmp pass_blink

fail:
    jmp fail

    # Keep the final mapped word deterministic.
    .fill 2, 1, 0x90
