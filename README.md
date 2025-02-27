# CV-X-IF Coprocessor

[CV-X-IF](https://docs.openhwgroup.org/projects/openhw-group-core-v-xif/en/latest/intro.html)
compatible example coprocessor that implements a bit reversal instruction. To be used
with the cv32e40px core. This example provides a template and showcases the steps needed
to connect more complex coprocessors via the CV-X-IF, for example using the [X-HEEP](https://github.com/esl-epfl/x-heep)
platform. The initial design of this coprocessor comes from [Coprosit](https://github.com/esl-epfl/Coprosit).

The bit reversal operation `BITREV rd, rs1` follows a custom R-type RISC-V instruction
which reverses the bit order of `rs1` and stores the result in `rd`. For example, input
`10110000` will result in `00001101`. This operation is needed in Fast Fourier Transform
(FFT), cryptography, and error correction codes.

The top-level module of the coprocessor can be found in `hw/xif_copro/xif_copro.sv`,
which includes the XIF signals in its ports. The computation of the bit reversal
operation is defined in different places:
- The definition of the operation is in `hw/xif_copro/xif_copro_pkg.sv`, in the
`copro_op_e` enum.
- The bit-level definition of the RISC-V instruction is in `hw/xif_copro/xif_copro_predecoder_pkg.sv`
and `hw/xif_copro/xif_copro_instr_pkg.sv`.
- The decoding takes place in `hw/xif_copro/xif_copro_decoder.sv`.
- The actual bit reversal execution is done in `hw/xif_copro/xif_copro_ex_stage.sv`.

You can also find an example application that uses the bit reversal instruction in
`sw/example.c`.
