#include <stdio.h>
#include <stdint.h>

/**
 * @brief Performs bit-reversal on a 32-bit integer using a custom RISC-V instruction.
 *
 * This function utilizes an inline assembly instruction to execute a custom RISC-V 
 * operation (BITREV), which reverses the order of bits in the input value.
 *
 * @param val The 32-bit integer whose bits will be reversed.
 * @return uint32_t The bit-reversed result.
 *
 * The `.insn` directive is used to encode a custom RISC-V instruction with the following format:
 *
 * .insn r opcode, funct3, funct7, rd, rs1, rs2
 *
 * - `r` specifies that this is an R-type (register-based) instruction.
 * - `0x2B` (0101011) is on of the opcodes for custom RISC-V extensions.
 * - `0x7` is the `funct3` field, which helps define the operation.
 * - `0x02` (00000_10) is the `funct7` field, which further specifies the BITREV operation.
 * - `%0` (rd) is the destination register where the output (result) is stored.
 * - `%1` (rs1) is the source register containing the input value (val).
 * - `zero` (rs2) is a hardcoded register operand set to zero, as this instruction only requires one input register.
 */
static inline uint32_t xbitrev(uint32_t val) {
    uint32_t result;
    asm volatile (
        ".insn r 0x2B, 0x7, 0x02, %0, %1, zero"  // Custom encoding for BITREV
        : "=r"(result) // Output operand (rd)
        : "r"(val)     // Input operand (rs1)
    );
    return result;
}

int main() {
    volatile uint32_t x = 0b10110000;
    volatile uint32_t reversed;

    reversed = xbitrev(x);

    printf("Input:    0x%08X\n", x);
    printf("Reversed: 0x%08X\n", reversed);

    return 0;
}
