# Brainfuck compiler written in Zig

**This project is just a hobby project and nothing too serious.**

It compiles Brainfuck code into linux-x86\_64 assembly.
Uses nasm to compile the assembly code into an executable file.

It uses 30.000 cells, each being 1 byte (8 bits) large.
(Support for making these parameters more configurable will be added soonTM (maybe).)

Dependencies:
* zig compiler
* gcc
* nasm

Run `make` or `make build` to build the program.
It will be called "bf\_compiler".

Try `./bf_compiler --help` to see the available parameters.

Supplied are a few example files.

You can compile them as such: `./bf_compiler hello.bf` .

The compiler will output both the generated assembly file and the final
executable.

To also see the Intermediate Representation of the compiler, you may use
`./bf_compiler --ir hello.bf` .

Run `make clean` to clean all the extra created files (executables, object files, .ir files, assembly files).
