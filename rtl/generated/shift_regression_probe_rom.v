`default_nettype none

// Generated file. Do not edit by hand.
// Source binary: shift_regression.bin
// Binary SHA-256: 3154845bea9f9eaf750f093da1fe9e23caddd52adf0a849386a33e6f3686d77d
// Assembly SHA-256: ccfc19f153b5a75f4569428af4b4b461cc781fc2f24efbc3d43d534ae5f0c37c
// Binary-to-physical mappings:
//   binary +0x00000000 -> physical 0xfffffff0, 0x10 bytes
//   binary +0x00010000 -> physical 0x000f0000, to end of binary
//
// Source assembly: rom/shift_regression.asm
//
// ---- BEGIN SOURCE ASSEMBLY ----
// | .code16
// | .intel_syntax noprefix
// | .section .text
// | .global _start
// | 
// | # Emit the current test number before performing each operation. If a check
// | # fails or the CPU hangs, the LEDs retain the failing test number.
// | .macro progress value
// |     mov al, \value
// |     out dx, al
// | .endm
// | 
// | # Establish OF=1 and CF=1 for count-zero flag-preservation checks.
// | .macro set_of_cf
// |     mov ax, 0x7fff
// |     add ax, 1
// |     stc
// | .endm
// | 
// | _start:
// |     # 386 reset vector at physical FFFFFFF0.
// |     .byte 0xea, 0x00, 0x00, 0x00, 0xf0
// |     .fill 11, 1, 0x90
// | 
// |     # Binary offset 0x10000 maps to physical 000F0000.
// |     .org 0x10000
// | 
// | regression_start:
// |     cli
// |     mov dx, 0x0080
// | 
// |     # SHL counts 0, 1, 16, 17.
// |     progress 0x01
// |     set_of_cf
// |     mov bx, 0x8123
// |     shl bx, 0
// |     jno fail
// |     jnc fail
// |     cmp bx, 0x8123
// |     jne fail
// | 
// |     progress 0x02
// |     mov bx, 0x8123
// |     shl bx, 1
// |     jno fail
// |     jnc fail
// |     cmp bx, 0x0246
// |     jne fail
// | 
// |     progress 0x03
// |     mov bx, 0x8123
// |     shl bx, 16
// |     cmp bx, 0x0000
// |     jne fail
// | 
// |     progress 0x04
// |     mov bx, 0x8123
// |     shl bx, 17
// |     cmp bx, 0x0000
// |     jne fail
// | 
// |     # SHR counts 0, 1, 16, 17.
// |     progress 0x05
// |     set_of_cf
// |     mov bx, 0x8123
// |     shr bx, 0
// |     jno fail
// |     jnc fail
// |     cmp bx, 0x8123
// |     jne fail
// | 
// |     progress 0x06
// |     mov bx, 0x8123
// |     shr bx, 1
// |     jno fail
// |     jnc fail
// |     cmp bx, 0x4091
// |     jne fail
// | 
// |     progress 0x07
// |     mov bx, 0x8123
// |     shr bx, 16
// |     cmp bx, 0x0000
// |     jne fail
// | 
// |     progress 0x08
// |     mov bx, 0x8123
// |     shr bx, 17
// |     cmp bx, 0x0000
// |     jne fail
// | 
// |     # SAR counts 0, 1, 16, 17.
// |     progress 0x09
// |     set_of_cf
// |     mov bx, 0x8123
// |     sar bx, 0
// |     jno fail
// |     jnc fail
// |     cmp bx, 0x8123
// |     jne fail
// | 
// |     progress 0x0a
// |     mov bx, 0x8123
// |     sar bx, 1
// |     jo fail
// |     jnc fail
// |     cmp bx, 0xc091
// |     jne fail
// | 
// |     progress 0x0b
// |     mov bx, 0x8123
// |     sar bx, 16
// |     cmp bx, 0xffff
// |     jne fail
// | 
// |     progress 0x0c
// |     mov bx, 0x8123
// |     sar bx, 17
// |     cmp bx, 0xffff
// |     jne fail
// | 
// |     # ROL counts 0, 1, 16, 17.
// |     progress 0x0d
// |     set_of_cf
// |     mov bx, 0x8123
// |     rol bx, 0
// |     jno fail
// |     jnc fail
// |     cmp bx, 0x8123
// |     jne fail
// | 
// |     progress 0x0e
// |     mov bx, 0x8123
// |     rol bx, 1
// |     jno fail
// |     jnc fail
// |     cmp bx, 0x0247
// |     jne fail
// | 
// |     # ROL count 16 has an effective rotation count of zero, so the result is
// |     # unchanged. Because the masked count is nonzero, CF is still updated to
// |     # bit 0 of the result. OF is undefined for counts other than one.
// |     progress 0x0f
// |     clc
// |     mov bx, 0x8123
// |     rol bx, 16
// |     jnc fail
// |     cmp bx, 0x8123
// |     jne fail
// | 
// |     # Count 17 produces the same result and CF as count one. OF is undefined
// |     # because the masked count is 17 rather than one.
// |     progress 0x10
// |     clc
// |     mov bx, 0x8123
// |     rol bx, 17
// |     jnc fail
// |     cmp bx, 0x0247
// |     jne fail
// | 
// |     # ROR counts 0, 1, 16, 17.
// |     progress 0x11
// |     set_of_cf
// |     mov bx, 0x8123
// |     ror bx, 0
// |     jno fail
// |     jnc fail
// |     cmp bx, 0x8123
// |     jne fail
// | 
// |     progress 0x12
// |     mov bx, 0x8123
// |     ror bx, 1
// |     jo fail
// |     jnc fail
// |     cmp bx, 0xc091
// |     jne fail
// | 
// |     # ROR count 16 also leaves the result unchanged while updating CF to
// |     # the high bit of the result. OF is undefined for counts other than one.
// |     progress 0x13
// |     clc
// |     mov bx, 0x8123
// |     ror bx, 16
// |     jnc fail
// |     cmp bx, 0x8123
// |     jne fail
// | 
// |     # Count 17 produces the same result and CF as count one. Do not inspect OF.
// |     progress 0x14
// |     clc
// |     mov bx, 0x8123
// |     ror bx, 17
// |     jnc fail
// |     cmp bx, 0xc091
// |     jne fail
// | 
// |     # RCL counts 0, 1, 16, 17.
// |     progress 0x15
// |     set_of_cf
// |     mov bx, 0x8123
// |     rcl bx, 0
// |     jno fail
// |     jnc fail
// |     cmp bx, 0x8123
// |     jne fail
// | 
// |     progress 0x16
// |     stc
// |     mov bx, 0x8123
// |     rcl bx, 1
// |     jno fail
// |     jnc fail
// |     cmp bx, 0x0247
// |     jne fail
// | 
// |     progress 0x17
// |     stc
// |     mov bx, 0x8123
// |     rcl bx, 16
// |     jnc fail
// |     cmp bx, 0xc091
// |     jne fail
// | 
// |     progress 0x18
// |     clc
// |     mov bx, 0x8123
// |     rcl bx, 17
// |     jc fail
// |     cmp bx, 0x8123
// |     jne fail
// | 
// |     # RCR counts 0, 1, 16, 17.
// |     progress 0x19
// |     set_of_cf
// |     mov bx, 0x8123
// |     rcr bx, 0
// |     jno fail
// |     jnc fail
// |     cmp bx, 0x8123
// |     jne fail
// | 
// |     progress 0x1a
// |     stc
// |     mov bx, 0x8123
// |     rcr bx, 1
// |     jo fail
// |     jnc fail
// |     cmp bx, 0xc091
// |     jne fail
// | 
// |     progress 0x1b
// |     stc
// |     mov bx, 0x8123
// |     rcr bx, 16
// |     jnc fail
// |     cmp bx, 0x0247
// |     jne fail
// | 
// |     progress 0x1c
// |     clc
// |     mov bx, 0x8123
// |     rcr bx, 17
// |     jc fail
// |     cmp bx, 0x8123
// |     jne fail
// | 
// |     # SHLD counts 0, 1, 16, 17.
// |     progress 0x1d
// |     set_of_cf
// |     mov bx, 0x8123
// |     mov si, 0x4567
// |     shld bx, si, 0
// |     jno fail
// |     jnc fail
// |     cmp bx, 0x8123
// |     jne fail
// | 
// |     progress 0x1e
// |     mov bx, 0x8123
// |     mov si, 0x4567
// |     shld bx, si, 1
// |     jnc fail
// |     cmp bx, 0x0246
// |     jne fail
// | 
// |     progress 0x1f
// |     mov bx, 0x8123
// |     mov si, 0x4567
// |     shld bx, si, 16
// |     jnc fail
// |     cmp bx, 0x4567
// |     jne fail
// | 
// |     # Count 17 is architecturally undefined for a 16-bit SHLD operand. Verify
// |     # that the instruction completes without corrupting an unrelated canary.
// |     progress 0x20
// |     mov di, 0x5aa5
// |     mov bx, 0x8123
// |     mov si, 0x4567
// |     shld bx, si, 17
// |     cmp di, 0x5aa5
// |     jne fail
// | 
// |     # SHRD counts 0, 1, 16, 17.
// |     progress 0x21
// |     set_of_cf
// |     mov bx, 0x8123
// |     mov si, 0x4567
// |     shrd bx, si, 0
// |     jno fail
// |     jnc fail
// |     cmp bx, 0x8123
// |     jne fail
// | 
// |     progress 0x22
// |     mov bx, 0x8123
// |     mov si, 0x4567
// |     shrd bx, si, 1
// |     jnc fail
// |     cmp bx, 0xc091
// |     jne fail
// | 
// |     progress 0x23
// |     mov bx, 0x8123
// |     mov si, 0x4567
// |     shrd bx, si, 16
// |     jnc fail
// |     cmp bx, 0x4567
// |     jne fail
// | 
// |     # Count 17 is architecturally undefined for a 16-bit SHRD operand. Verify
// |     # that the instruction completes without corrupting an unrelated canary.
// |     progress 0x24
// |     mov di, 0x5aa5
// |     mov bx, 0x8123
// |     mov si, 0x4567
// |     shrd bx, si, 17
// |     cmp di, 0x5aa5
// |     jne fail
// | 
// |     # BSR has no count operand. Test zero input and highest set-bit positions
// |     # 0, 1, 16, and 17 using 32-bit operands in 16-bit code.
// |     progress 0x25
// |     mov eax, 0x00000000
// |     mov ecx, 0x12345678
// |     mov bx, 1
// |     or bx, bx                 # Establish ZF=0 before BSR zero input.
// |     bsr ecx, eax
// |     jnz fail                  # Zero input must set ZF=1.
// | 
// |     progress 0x26
// |     mov eax, 0x00000001
// |     xor bx, bx                # Establish ZF=1 before nonzero BSR.
// |     bsr ecx, eax
// |     jz fail
// |     cmp ecx, 0
// |     jne fail
// | 
// |     progress 0x27
// |     mov eax, 0x00000002
// |     xor bx, bx
// |     bsr ecx, eax
// |     jz fail
// |     cmp ecx, 1
// |     jne fail
// | 
// |     progress 0x28
// |     mov eax, 0x00010000
// |     xor bx, bx
// |     bsr ecx, eax
// |     jz fail
// |     cmp ecx, 16
// |     jne fail
// | 
// |     progress 0x29
// |     mov eax, 0x00020000
// |     xor bx, bx
// |     bsr ecx, eax
// |     jz fail
// |     cmp ecx, 17
// |     jne fail
// | 
// |     # All tests passed. Alternate A5 and 5A slowly enough to observe.
// |     mov al, 0xa5
// | pass_blink:
// |     out dx, al
// |     mov si, 0x0020
// | pass_outer:
// |     mov cx, 0xffff
// | pass_inner:
// |     loop pass_inner
// |     dec si
// |     jnz pass_outer
// |     xor al, 0xff
// |     jmp pass_blink
// | 
// | fail:
// |     jmp fail
// | 
// |     # Keep the final mapped word deterministic.
// |     .fill 2, 1, 0x90
// ---- END SOURCE ASSEMBLY ----

module shift_regression_probe_rom (
    input  wire [31:0] address,
    output wire [31:0] data
);

function [31:0] probe_read_data;
    input [31:0] address;
    begin
        case (address)
            32'hffff_fff0: probe_read_data = 32'h0000_00ea;  // binary +0x00000000: EA 00 00 00
            32'hffff_fff4: probe_read_data = 32'h9090_90f0;  // binary +0x00000004: F0 90 90 90
            32'hffff_fff8: probe_read_data = 32'h9090_9090;  // binary +0x00000008: 90 90 90 90
            32'hffff_fffc: probe_read_data = 32'h9090_9090;  // binary +0x0000000c: 90 90 90 90
            32'h000f_0000: probe_read_data = 32'h0080_bafa;  // binary +0x00010000: FA BA 80 00
            32'h000f_0004: probe_read_data = 32'hb8ee_01b0;  // binary +0x00010004: B0 01 EE B8
            32'h000f_0008: probe_read_data = 32'hc083_7fff;  // binary +0x00010008: FF 7F 83 C0
            32'h000f_000c: probe_read_data = 32'h23bb_f901;  // binary +0x0001000c: 01 F9 BB 23
            32'h000f_0010: probe_read_data = 32'h00e3_c181;  // binary +0x00010010: 81 C1 E3 00
            32'h000f_0014: probe_read_data = 32'h03ea_810f;  // binary +0x00010014: 0F 81 EA 03
            32'h000f_0018: probe_read_data = 32'h03e6_830f;  // binary +0x00010018: 0F 83 E6 03
            32'h000f_001c: probe_read_data = 32'h8123_fb81;  // binary +0x0001001c: 81 FB 23 81
            32'h000f_0020: probe_read_data = 32'h03de_850f;  // binary +0x00010020: 0F 85 DE 03
            32'h000f_0024: probe_read_data = 32'hbbee_02b0;  // binary +0x00010024: B0 02 EE BB
            32'h000f_0028: probe_read_data = 32'he3d1_8123;  // binary +0x00010028: 23 81 D1 E3
            32'h000f_002c: probe_read_data = 32'h03d2_810f;  // binary +0x0001002c: 0F 81 D2 03
            32'h000f_0030: probe_read_data = 32'h03ce_830f;  // binary +0x00010030: 0F 83 CE 03
            32'h000f_0034: probe_read_data = 32'h0246_fb81;  // binary +0x00010034: 81 FB 46 02
            32'h000f_0038: probe_read_data = 32'h03c6_850f;  // binary +0x00010038: 0F 85 C6 03
            32'h000f_003c: probe_read_data = 32'hbbee_03b0;  // binary +0x0001003c: B0 03 EE BB
            32'h000f_0040: probe_read_data = 32'he3c1_8123;  // binary +0x00010040: 23 81 C1 E3
            32'h000f_0044: probe_read_data = 32'h00fb_8310;  // binary +0x00010044: 10 83 FB 00
            32'h000f_0048: probe_read_data = 32'h03b6_850f;  // binary +0x00010048: 0F 85 B6 03
            32'h000f_004c: probe_read_data = 32'hbbee_04b0;  // binary +0x0001004c: B0 04 EE BB
            32'h000f_0050: probe_read_data = 32'he3c1_8123;  // binary +0x00010050: 23 81 C1 E3
            32'h000f_0054: probe_read_data = 32'h00fb_8311;  // binary +0x00010054: 11 83 FB 00
            32'h000f_0058: probe_read_data = 32'h03a6_850f;  // binary +0x00010058: 0F 85 A6 03
            32'h000f_005c: probe_read_data = 32'hb8ee_05b0;  // binary +0x0001005c: B0 05 EE B8
            32'h000f_0060: probe_read_data = 32'hc083_7fff;  // binary +0x00010060: FF 7F 83 C0
            32'h000f_0064: probe_read_data = 32'h23bb_f901;  // binary +0x00010064: 01 F9 BB 23
            32'h000f_0068: probe_read_data = 32'h00eb_c181;  // binary +0x00010068: 81 C1 EB 00
            32'h000f_006c: probe_read_data = 32'h0392_810f;  // binary +0x0001006c: 0F 81 92 03
            32'h000f_0070: probe_read_data = 32'h038e_830f;  // binary +0x00010070: 0F 83 8E 03
            32'h000f_0074: probe_read_data = 32'h8123_fb81;  // binary +0x00010074: 81 FB 23 81
            32'h000f_0078: probe_read_data = 32'h0386_850f;  // binary +0x00010078: 0F 85 86 03
            32'h000f_007c: probe_read_data = 32'hbbee_06b0;  // binary +0x0001007c: B0 06 EE BB
            32'h000f_0080: probe_read_data = 32'hebd1_8123;  // binary +0x00010080: 23 81 D1 EB
            32'h000f_0084: probe_read_data = 32'h037a_810f;  // binary +0x00010084: 0F 81 7A 03
            32'h000f_0088: probe_read_data = 32'h0376_830f;  // binary +0x00010088: 0F 83 76 03
            32'h000f_008c: probe_read_data = 32'h4091_fb81;  // binary +0x0001008c: 81 FB 91 40
            32'h000f_0090: probe_read_data = 32'h036e_850f;  // binary +0x00010090: 0F 85 6E 03
            32'h000f_0094: probe_read_data = 32'hbbee_07b0;  // binary +0x00010094: B0 07 EE BB
            32'h000f_0098: probe_read_data = 32'hebc1_8123;  // binary +0x00010098: 23 81 C1 EB
            32'h000f_009c: probe_read_data = 32'h00fb_8310;  // binary +0x0001009c: 10 83 FB 00
            32'h000f_00a0: probe_read_data = 32'h035e_850f;  // binary +0x000100a0: 0F 85 5E 03
            32'h000f_00a4: probe_read_data = 32'hbbee_08b0;  // binary +0x000100a4: B0 08 EE BB
            32'h000f_00a8: probe_read_data = 32'hebc1_8123;  // binary +0x000100a8: 23 81 C1 EB
            32'h000f_00ac: probe_read_data = 32'h00fb_8311;  // binary +0x000100ac: 11 83 FB 00
            32'h000f_00b0: probe_read_data = 32'h034e_850f;  // binary +0x000100b0: 0F 85 4E 03
            32'h000f_00b4: probe_read_data = 32'hb8ee_09b0;  // binary +0x000100b4: B0 09 EE B8
            32'h000f_00b8: probe_read_data = 32'hc083_7fff;  // binary +0x000100b8: FF 7F 83 C0
            32'h000f_00bc: probe_read_data = 32'h23bb_f901;  // binary +0x000100bc: 01 F9 BB 23
            32'h000f_00c0: probe_read_data = 32'h00fb_c181;  // binary +0x000100c0: 81 C1 FB 00
            32'h000f_00c4: probe_read_data = 32'h033a_810f;  // binary +0x000100c4: 0F 81 3A 03
            32'h000f_00c8: probe_read_data = 32'h0336_830f;  // binary +0x000100c8: 0F 83 36 03
            32'h000f_00cc: probe_read_data = 32'h8123_fb81;  // binary +0x000100cc: 81 FB 23 81
            32'h000f_00d0: probe_read_data = 32'h032e_850f;  // binary +0x000100d0: 0F 85 2E 03
            32'h000f_00d4: probe_read_data = 32'hbbee_0ab0;  // binary +0x000100d4: B0 0A EE BB
            32'h000f_00d8: probe_read_data = 32'hfbd1_8123;  // binary +0x000100d8: 23 81 D1 FB
            32'h000f_00dc: probe_read_data = 32'h0322_800f;  // binary +0x000100dc: 0F 80 22 03
            32'h000f_00e0: probe_read_data = 32'h031e_830f;  // binary +0x000100e0: 0F 83 1E 03
            32'h000f_00e4: probe_read_data = 32'hc091_fb81;  // binary +0x000100e4: 81 FB 91 C0
            32'h000f_00e8: probe_read_data = 32'h0316_850f;  // binary +0x000100e8: 0F 85 16 03
            32'h000f_00ec: probe_read_data = 32'hbbee_0bb0;  // binary +0x000100ec: B0 0B EE BB
            32'h000f_00f0: probe_read_data = 32'hfbc1_8123;  // binary +0x000100f0: 23 81 C1 FB
            32'h000f_00f4: probe_read_data = 32'hfffb_8310;  // binary +0x000100f4: 10 83 FB FF
            32'h000f_00f8: probe_read_data = 32'h0306_850f;  // binary +0x000100f8: 0F 85 06 03
            32'h000f_00fc: probe_read_data = 32'hbbee_0cb0;  // binary +0x000100fc: B0 0C EE BB
            32'h000f_0100: probe_read_data = 32'hfbc1_8123;  // binary +0x00010100: 23 81 C1 FB
            32'h000f_0104: probe_read_data = 32'hfffb_8311;  // binary +0x00010104: 11 83 FB FF
            32'h000f_0108: probe_read_data = 32'h02f6_850f;  // binary +0x00010108: 0F 85 F6 02
            32'h000f_010c: probe_read_data = 32'hb8ee_0db0;  // binary +0x0001010c: B0 0D EE B8
            32'h000f_0110: probe_read_data = 32'hc083_7fff;  // binary +0x00010110: FF 7F 83 C0
            32'h000f_0114: probe_read_data = 32'h23bb_f901;  // binary +0x00010114: 01 F9 BB 23
            32'h000f_0118: probe_read_data = 32'h00c3_c181;  // binary +0x00010118: 81 C1 C3 00
            32'h000f_011c: probe_read_data = 32'h02e2_810f;  // binary +0x0001011c: 0F 81 E2 02
            32'h000f_0120: probe_read_data = 32'h02de_830f;  // binary +0x00010120: 0F 83 DE 02
            32'h000f_0124: probe_read_data = 32'h8123_fb81;  // binary +0x00010124: 81 FB 23 81
            32'h000f_0128: probe_read_data = 32'h02d6_850f;  // binary +0x00010128: 0F 85 D6 02
            32'h000f_012c: probe_read_data = 32'hbbee_0eb0;  // binary +0x0001012c: B0 0E EE BB
            32'h000f_0130: probe_read_data = 32'hc3d1_8123;  // binary +0x00010130: 23 81 D1 C3
            32'h000f_0134: probe_read_data = 32'h02ca_810f;  // binary +0x00010134: 0F 81 CA 02
            32'h000f_0138: probe_read_data = 32'h02c6_830f;  // binary +0x00010138: 0F 83 C6 02
            32'h000f_013c: probe_read_data = 32'h0247_fb81;  // binary +0x0001013c: 81 FB 47 02
            32'h000f_0140: probe_read_data = 32'h02be_850f;  // binary +0x00010140: 0F 85 BE 02
            32'h000f_0144: probe_read_data = 32'hf8ee_0fb0;  // binary +0x00010144: B0 0F EE F8
            32'h000f_0148: probe_read_data = 32'hc181_23bb;  // binary +0x00010148: BB 23 81 C1
            32'h000f_014c: probe_read_data = 32'h830f_10c3;  // binary +0x0001014c: C3 10 0F 83
            32'h000f_0150: probe_read_data = 32'hfb81_02b0;  // binary +0x00010150: B0 02 81 FB
            32'h000f_0154: probe_read_data = 32'h850f_8123;  // binary +0x00010154: 23 81 0F 85
            32'h000f_0158: probe_read_data = 32'h10b0_02a8;  // binary +0x00010158: A8 02 B0 10
            32'h000f_015c: probe_read_data = 32'h23bb_f8ee;  // binary +0x0001015c: EE F8 BB 23
            32'h000f_0160: probe_read_data = 32'h11c3_c181;  // binary +0x00010160: 81 C1 C3 11
            32'h000f_0164: probe_read_data = 32'h029a_830f;  // binary +0x00010164: 0F 83 9A 02
            32'h000f_0168: probe_read_data = 32'h0247_fb81;  // binary +0x00010168: 81 FB 47 02
            32'h000f_016c: probe_read_data = 32'h0292_850f;  // binary +0x0001016c: 0F 85 92 02
            32'h000f_0170: probe_read_data = 32'hb8ee_11b0;  // binary +0x00010170: B0 11 EE B8
            32'h000f_0174: probe_read_data = 32'hc083_7fff;  // binary +0x00010174: FF 7F 83 C0
            32'h000f_0178: probe_read_data = 32'h23bb_f901;  // binary +0x00010178: 01 F9 BB 23
            32'h000f_017c: probe_read_data = 32'h00cb_c181;  // binary +0x0001017c: 81 C1 CB 00
            32'h000f_0180: probe_read_data = 32'h027e_810f;  // binary +0x00010180: 0F 81 7E 02
            32'h000f_0184: probe_read_data = 32'h027a_830f;  // binary +0x00010184: 0F 83 7A 02
            32'h000f_0188: probe_read_data = 32'h8123_fb81;  // binary +0x00010188: 81 FB 23 81
            32'h000f_018c: probe_read_data = 32'h0272_850f;  // binary +0x0001018c: 0F 85 72 02
            32'h000f_0190: probe_read_data = 32'hbbee_12b0;  // binary +0x00010190: B0 12 EE BB
            32'h000f_0194: probe_read_data = 32'hcbd1_8123;  // binary +0x00010194: 23 81 D1 CB
            32'h000f_0198: probe_read_data = 32'h0266_800f;  // binary +0x00010198: 0F 80 66 02
            32'h000f_019c: probe_read_data = 32'h0262_830f;  // binary +0x0001019c: 0F 83 62 02
            32'h000f_01a0: probe_read_data = 32'hc091_fb81;  // binary +0x000101a0: 81 FB 91 C0
            32'h000f_01a4: probe_read_data = 32'h025a_850f;  // binary +0x000101a4: 0F 85 5A 02
            32'h000f_01a8: probe_read_data = 32'hf8ee_13b0;  // binary +0x000101a8: B0 13 EE F8
            32'h000f_01ac: probe_read_data = 32'hc181_23bb;  // binary +0x000101ac: BB 23 81 C1
            32'h000f_01b0: probe_read_data = 32'h830f_10cb;  // binary +0x000101b0: CB 10 0F 83
            32'h000f_01b4: probe_read_data = 32'hfb81_024c;  // binary +0x000101b4: 4C 02 81 FB
            32'h000f_01b8: probe_read_data = 32'h850f_8123;  // binary +0x000101b8: 23 81 0F 85
            32'h000f_01bc: probe_read_data = 32'h14b0_0244;  // binary +0x000101bc: 44 02 B0 14
            32'h000f_01c0: probe_read_data = 32'h23bb_f8ee;  // binary +0x000101c0: EE F8 BB 23
            32'h000f_01c4: probe_read_data = 32'h11cb_c181;  // binary +0x000101c4: 81 C1 CB 11
            32'h000f_01c8: probe_read_data = 32'h0236_830f;  // binary +0x000101c8: 0F 83 36 02
            32'h000f_01cc: probe_read_data = 32'hc091_fb81;  // binary +0x000101cc: 81 FB 91 C0
            32'h000f_01d0: probe_read_data = 32'h022e_850f;  // binary +0x000101d0: 0F 85 2E 02
            32'h000f_01d4: probe_read_data = 32'hb8ee_15b0;  // binary +0x000101d4: B0 15 EE B8
            32'h000f_01d8: probe_read_data = 32'hc083_7fff;  // binary +0x000101d8: FF 7F 83 C0
            32'h000f_01dc: probe_read_data = 32'h23bb_f901;  // binary +0x000101dc: 01 F9 BB 23
            32'h000f_01e0: probe_read_data = 32'h00d3_c181;  // binary +0x000101e0: 81 C1 D3 00
            32'h000f_01e4: probe_read_data = 32'h021a_810f;  // binary +0x000101e4: 0F 81 1A 02
            32'h000f_01e8: probe_read_data = 32'h0216_830f;  // binary +0x000101e8: 0F 83 16 02
            32'h000f_01ec: probe_read_data = 32'h8123_fb81;  // binary +0x000101ec: 81 FB 23 81
            32'h000f_01f0: probe_read_data = 32'h020e_850f;  // binary +0x000101f0: 0F 85 0E 02
            32'h000f_01f4: probe_read_data = 32'hf9ee_16b0;  // binary +0x000101f4: B0 16 EE F9
            32'h000f_01f8: probe_read_data = 32'hd181_23bb;  // binary +0x000101f8: BB 23 81 D1
            32'h000f_01fc: probe_read_data = 32'h0181_0fd3;  // binary +0x000101fc: D3 0F 81 01
            32'h000f_0200: probe_read_data = 32'hfd83_0f02;  // binary +0x00010200: 02 0F 83 FD
            32'h000f_0204: probe_read_data = 32'h47fb_8101;  // binary +0x00010204: 01 81 FB 47
            32'h000f_0208: probe_read_data = 32'hf585_0f02;  // binary +0x00010208: 02 0F 85 F5
            32'h000f_020c: probe_read_data = 32'hee17_b001;  // binary +0x0001020c: 01 B0 17 EE
            32'h000f_0210: probe_read_data = 32'h8123_bbf9;  // binary +0x00010210: F9 BB 23 81
            32'h000f_0214: probe_read_data = 32'h0f10_d3c1;  // binary +0x00010214: C1 D3 10 0F
            32'h000f_0218: probe_read_data = 32'h8101_e783;  // binary +0x00010218: 83 E7 01 81
            32'h000f_021c: probe_read_data = 32'h0fc0_91fb;  // binary +0x0001021c: FB 91 C0 0F
            32'h000f_0220: probe_read_data = 32'hb001_df85;  // binary +0x00010220: 85 DF 01 B0
            32'h000f_0224: probe_read_data = 32'hbbf8_ee18;  // binary +0x00010224: 18 EE F8 BB
            32'h000f_0228: probe_read_data = 32'hd3c1_8123;  // binary +0x00010228: 23 81 C1 D3
            32'h000f_022c: probe_read_data = 32'hd182_0f11;  // binary +0x0001022c: 11 0F 82 D1
            32'h000f_0230: probe_read_data = 32'h23fb_8101;  // binary +0x00010230: 01 81 FB 23
            32'h000f_0234: probe_read_data = 32'hc985_0f81;  // binary +0x00010234: 81 0F 85 C9
            32'h000f_0238: probe_read_data = 32'hee19_b001;  // binary +0x00010238: 01 B0 19 EE
            32'h000f_023c: probe_read_data = 32'h837f_ffb8;  // binary +0x0001023c: B8 FF 7F 83
            32'h000f_0240: probe_read_data = 32'hbbf9_01c0;  // binary +0x00010240: C0 01 F9 BB
            32'h000f_0244: probe_read_data = 32'hdbc1_8123;  // binary +0x00010244: 23 81 C1 DB
            32'h000f_0248: probe_read_data = 32'hb581_0f00;  // binary +0x00010248: 00 0F 81 B5
            32'h000f_024c: probe_read_data = 32'hb183_0f01;  // binary +0x0001024c: 01 0F 83 B1
            32'h000f_0250: probe_read_data = 32'h23fb_8101;  // binary +0x00010250: 01 81 FB 23
            32'h000f_0254: probe_read_data = 32'ha985_0f81;  // binary +0x00010254: 81 0F 85 A9
            32'h000f_0258: probe_read_data = 32'hee1a_b001;  // binary +0x00010258: 01 B0 1A EE
            32'h000f_025c: probe_read_data = 32'h8123_bbf9;  // binary +0x0001025c: F9 BB 23 81
            32'h000f_0260: probe_read_data = 32'h800f_dbd1;  // binary +0x00010260: D1 DB 0F 80
            32'h000f_0264: probe_read_data = 32'h830f_019c;  // binary +0x00010264: 9C 01 0F 83
            32'h000f_0268: probe_read_data = 32'hfb81_0198;  // binary +0x00010268: 98 01 81 FB
            32'h000f_026c: probe_read_data = 32'h850f_c091;  // binary +0x0001026c: 91 C0 0F 85
            32'h000f_0270: probe_read_data = 32'h1bb0_0190;  // binary +0x00010270: 90 01 B0 1B
            32'h000f_0274: probe_read_data = 32'h23bb_f9ee;  // binary +0x00010274: EE F9 BB 23
            32'h000f_0278: probe_read_data = 32'h10db_c181;  // binary +0x00010278: 81 C1 DB 10
            32'h000f_027c: probe_read_data = 32'h0182_830f;  // binary +0x0001027c: 0F 83 82 01
            32'h000f_0280: probe_read_data = 32'h0247_fb81;  // binary +0x00010280: 81 FB 47 02
            32'h000f_0284: probe_read_data = 32'h017a_850f;  // binary +0x00010284: 0F 85 7A 01
            32'h000f_0288: probe_read_data = 32'hf8ee_1cb0;  // binary +0x00010288: B0 1C EE F8
            32'h000f_028c: probe_read_data = 32'hc181_23bb;  // binary +0x0001028c: BB 23 81 C1
            32'h000f_0290: probe_read_data = 32'h820f_11db;  // binary +0x00010290: DB 11 0F 82
            32'h000f_0294: probe_read_data = 32'hfb81_016c;  // binary +0x00010294: 6C 01 81 FB
            32'h000f_0298: probe_read_data = 32'h850f_8123;  // binary +0x00010298: 23 81 0F 85
            32'h000f_029c: probe_read_data = 32'h1db0_0164;  // binary +0x0001029c: 64 01 B0 1D
            32'h000f_02a0: probe_read_data = 32'h7fff_b8ee;  // binary +0x000102a0: EE B8 FF 7F
            32'h000f_02a4: probe_read_data = 32'hf901_c083;  // binary +0x000102a4: 83 C0 01 F9
            32'h000f_02a8: probe_read_data = 32'hbe81_23bb;  // binary +0x000102a8: BB 23 81 BE
            32'h000f_02ac: probe_read_data = 32'ha40f_4567;  // binary +0x000102ac: 67 45 0F A4
            32'h000f_02b0: probe_read_data = 32'h810f_00f3;  // binary +0x000102b0: F3 00 0F 81
            32'h000f_02b4: probe_read_data = 32'h830f_014c;  // binary +0x000102b4: 4C 01 0F 83
            32'h000f_02b8: probe_read_data = 32'hfb81_0148;  // binary +0x000102b8: 48 01 81 FB
            32'h000f_02bc: probe_read_data = 32'h850f_8123;  // binary +0x000102bc: 23 81 0F 85
            32'h000f_02c0: probe_read_data = 32'h1eb0_0140;  // binary +0x000102c0: 40 01 B0 1E
            32'h000f_02c4: probe_read_data = 32'h8123_bbee;  // binary +0x000102c4: EE BB 23 81
            32'h000f_02c8: probe_read_data = 32'h0f45_67be;  // binary +0x000102c8: BE 67 45 0F
            32'h000f_02cc: probe_read_data = 32'h0f01_f3a4;  // binary +0x000102cc: A4 F3 01 0F
            32'h000f_02d0: probe_read_data = 32'h8101_2f83;  // binary +0x000102d0: 83 2F 01 81
            32'h000f_02d4: probe_read_data = 32'h0f02_46fb;  // binary +0x000102d4: FB 46 02 0F
            32'h000f_02d8: probe_read_data = 32'hb001_2785;  // binary +0x000102d8: 85 27 01 B0
            32'h000f_02dc: probe_read_data = 32'h23bb_ee1f;  // binary +0x000102dc: 1F EE BB 23
            32'h000f_02e0: probe_read_data = 32'h4567_be81;  // binary +0x000102e0: 81 BE 67 45
            32'h000f_02e4: probe_read_data = 32'h10f3_a40f;  // binary +0x000102e4: 0F A4 F3 10
            32'h000f_02e8: probe_read_data = 32'h0116_830f;  // binary +0x000102e8: 0F 83 16 01
            32'h000f_02ec: probe_read_data = 32'h4567_fb81;  // binary +0x000102ec: 81 FB 67 45
            32'h000f_02f0: probe_read_data = 32'h010e_850f;  // binary +0x000102f0: 0F 85 0E 01
            32'h000f_02f4: probe_read_data = 32'hbfee_20b0;  // binary +0x000102f4: B0 20 EE BF
            32'h000f_02f8: probe_read_data = 32'h23bb_5aa5;  // binary +0x000102f8: A5 5A BB 23
            32'h000f_02fc: probe_read_data = 32'h4567_be81;  // binary +0x000102fc: 81 BE 67 45
            32'h000f_0300: probe_read_data = 32'h11f3_a40f;  // binary +0x00010300: 0F A4 F3 11
            32'h000f_0304: probe_read_data = 32'h5aa5_ff81;  // binary +0x00010304: 81 FF A5 5A
            32'h000f_0308: probe_read_data = 32'h00f6_850f;  // binary +0x00010308: 0F 85 F6 00
            32'h000f_030c: probe_read_data = 32'hb8ee_21b0;  // binary +0x0001030c: B0 21 EE B8
            32'h000f_0310: probe_read_data = 32'hc083_7fff;  // binary +0x00010310: FF 7F 83 C0
            32'h000f_0314: probe_read_data = 32'h23bb_f901;  // binary +0x00010314: 01 F9 BB 23
            32'h000f_0318: probe_read_data = 32'h4567_be81;  // binary +0x00010318: 81 BE 67 45
            32'h000f_031c: probe_read_data = 32'h00f3_ac0f;  // binary +0x0001031c: 0F AC F3 00
            32'h000f_0320: probe_read_data = 32'h00de_810f;  // binary +0x00010320: 0F 81 DE 00
            32'h000f_0324: probe_read_data = 32'h00da_830f;  // binary +0x00010324: 0F 83 DA 00
            32'h000f_0328: probe_read_data = 32'h8123_fb81;  // binary +0x00010328: 81 FB 23 81
            32'h000f_032c: probe_read_data = 32'h00d2_850f;  // binary +0x0001032c: 0F 85 D2 00
            32'h000f_0330: probe_read_data = 32'hbbee_22b0;  // binary +0x00010330: B0 22 EE BB
            32'h000f_0334: probe_read_data = 32'h67be_8123;  // binary +0x00010334: 23 81 BE 67
            32'h000f_0338: probe_read_data = 32'hf3ac_0f45;  // binary +0x00010338: 45 0F AC F3
            32'h000f_033c: probe_read_data = 32'hc183_0f01;  // binary +0x0001033c: 01 0F 83 C1
            32'h000f_0340: probe_read_data = 32'h91fb_8100;  // binary +0x00010340: 00 81 FB 91
            32'h000f_0344: probe_read_data = 32'hb985_0fc0;  // binary +0x00010344: C0 0F 85 B9
            32'h000f_0348: probe_read_data = 32'hee23_b000;  // binary +0x00010348: 00 B0 23 EE
            32'h000f_034c: probe_read_data = 32'hbe81_23bb;  // binary +0x0001034c: BB 23 81 BE
            32'h000f_0350: probe_read_data = 32'hac0f_4567;  // binary +0x00010350: 67 45 0F AC
            32'h000f_0354: probe_read_data = 32'h830f_10f3;  // binary +0x00010354: F3 10 0F 83
            32'h000f_0358: probe_read_data = 32'hfb81_00a8;  // binary +0x00010358: A8 00 81 FB
            32'h000f_035c: probe_read_data = 32'h850f_4567;  // binary +0x0001035c: 67 45 0F 85
            32'h000f_0360: probe_read_data = 32'h24b0_00a0;  // binary +0x00010360: A0 00 B0 24
            32'h000f_0364: probe_read_data = 32'h5aa5_bfee;  // binary +0x00010364: EE BF A5 5A
            32'h000f_0368: probe_read_data = 32'hbe81_23bb;  // binary +0x00010368: BB 23 81 BE
            32'h000f_036c: probe_read_data = 32'hac0f_4567;  // binary +0x0001036c: 67 45 0F AC
            32'h000f_0370: probe_read_data = 32'hff81_11f3;  // binary +0x00010370: F3 11 81 FF
            32'h000f_0374: probe_read_data = 32'h850f_5aa5;  // binary +0x00010374: A5 5A 0F 85
            32'h000f_0378: probe_read_data = 32'h25b0_0088;  // binary +0x00010378: 88 00 B0 25
            32'h000f_037c: probe_read_data = 32'h00b8_66ee;  // binary +0x0001037c: EE 66 B8 00
            32'h000f_0380: probe_read_data = 32'h6600_0000;  // binary +0x00010380: 00 00 00 66
            32'h000f_0384: probe_read_data = 32'h3456_78b9;  // binary +0x00010384: B9 78 56 34
            32'h000f_0388: probe_read_data = 32'h0001_bb12;  // binary +0x00010388: 12 BB 01 00
            32'h000f_038c: probe_read_data = 32'h0f66_db09;  // binary +0x0001038c: 09 DB 66 0F
            32'h000f_0390: probe_read_data = 32'h6e75_c8bd;  // binary +0x00010390: BD C8 75 6E
            32'h000f_0394: probe_read_data = 32'h66ee_26b0;  // binary +0x00010394: B0 26 EE 66
            32'h000f_0398: probe_read_data = 32'h0000_01b8;  // binary +0x00010398: B8 01 00 00
            32'h000f_039c: probe_read_data = 32'h66db_3100;  // binary +0x0001039c: 00 31 DB 66
            32'h000f_03a0: probe_read_data = 32'h74c8_bd0f;  // binary +0x000103a0: 0F BD C8 74
            32'h000f_03a4: probe_read_data = 32'hf983_665d;  // binary +0x000103a4: 5D 66 83 F9
            32'h000f_03a8: probe_read_data = 32'hb057_7500;  // binary +0x000103a8: 00 75 57 B0
            32'h000f_03ac: probe_read_data = 32'hb866_ee27;  // binary +0x000103ac: 27 EE 66 B8
            32'h000f_03b0: probe_read_data = 32'h0000_0002;  // binary +0x000103b0: 02 00 00 00
            32'h000f_03b4: probe_read_data = 32'h0f66_db31;  // binary +0x000103b4: 31 DB 66 0F
            32'h000f_03b8: probe_read_data = 32'h4674_c8bd;  // binary +0x000103b8: BD C8 74 46
            32'h000f_03bc: probe_read_data = 32'h01f9_8366;  // binary +0x000103bc: 66 83 F9 01
            32'h000f_03c0: probe_read_data = 32'h28b0_4075;  // binary +0x000103c0: 75 40 B0 28
            32'h000f_03c4: probe_read_data = 32'h00b8_66ee;  // binary +0x000103c4: EE 66 B8 00
            32'h000f_03c8: probe_read_data = 32'h3100_0100;  // binary +0x000103c8: 00 01 00 31
            32'h000f_03cc: probe_read_data = 32'hbd0f_66db;  // binary +0x000103cc: DB 66 0F BD
            32'h000f_03d0: probe_read_data = 32'h662f_74c8;  // binary +0x000103d0: C8 74 2F 66
            32'h000f_03d4: probe_read_data = 32'h7510_f983;  // binary +0x000103d4: 83 F9 10 75
            32'h000f_03d8: probe_read_data = 32'hee29_b029;  // binary +0x000103d8: 29 B0 29 EE
            32'h000f_03dc: probe_read_data = 32'h0000_b866;  // binary +0x000103dc: 66 B8 00 00
            32'h000f_03e0: probe_read_data = 32'hdb31_0002;  // binary +0x000103e0: 02 00 31 DB
            32'h000f_03e4: probe_read_data = 32'hc8bd_0f66;  // binary +0x000103e4: 66 0F BD C8
            32'h000f_03e8: probe_read_data = 32'h8366_1874;  // binary +0x000103e8: 74 18 66 83
            32'h000f_03ec: probe_read_data = 32'h1275_11f9;  // binary +0x000103ec: F9 11 75 12
            32'h000f_03f0: probe_read_data = 32'hbeee_a5b0;  // binary +0x000103f0: B0 A5 EE BE
            32'h000f_03f4: probe_read_data = 32'hffb9_0020;  // binary +0x000103f4: 20 00 B9 FF
            32'h000f_03f8: probe_read_data = 32'h4efe_e2ff;  // binary +0x000103f8: FF E2 FE 4E
            32'h000f_03fc: probe_read_data = 32'hff34_f875;  // binary +0x000103fc: 75 F8 34 FF
            32'h000f_0400: probe_read_data = 32'hfeeb_f0eb;  // binary +0x00010400: EB F0 EB FE
            32'h000f_0404: probe_read_data = 32'h9090_9090;  // binary +0x00010404: 90 90 90 90
            default: probe_read_data = 32'h9090_9090;
        endcase
    end
endfunction

assign data = probe_read_data(address);

endmodule

`default_nettype wire
