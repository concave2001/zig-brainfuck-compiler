# Brainfuck compiler written in Zig

**This project is just a hobby project and nothing too serious.**

It compiles Brainfuck code into linux-x86\_64 assembly.
Uses nasm to compile the assembly code into an executable file.

It uses 256 cells, each being 1 byte (8 bits) large.
(Support for making these parameters more configurable will be added soonTM (maybe).)

Dependencies:
* zig compiler
* gcc
* nasm

Run `make` or `make build` to build the program.
It will be called "bf\_compiler" and it will be located in the ./bin folder.

Try `./bin/bf_compiler --help` to see the available parameters.

Supplied are a few example files.

You can compile them as such: `./bin/bf_compiler hello.bf --target x86_64-linux-gnu --assembler nasm` .

The compiler will output both the generated assembly file and the final executable.

To also see the Intermediate Representation of the compiler, you may use
`./bin/bf_compiler hello.bf --target x86_64-linux-gnu --assembler nasm --ir` .

Run `make clean` to clean all the extra created files (executables, object files, .ir files, assembly files, zig cache).

Run `make clean_all` to clean all the extra created files (executables, object files, .ir files, assembly files, zig cache) and the bf_compiler executable.
