.code16
.global _start

_start:
    movb $0xff, %al
    outb %al, $0x80
    ljmp $0xf000, $0x0000

.org 0x10000

demo:
    cli
    movb $0x55, %al

blink:
    outb %al, $0x80

    movw $0x0020, %dx
outer:
    movw $0xffff, %cx
inner:
    loop inner
    decw %dx
    jnz outer

    xorb $0xff, %al
    jmp blink
