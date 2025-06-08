build: bf_compiler.zig
	zig build-exe -static -O ReleaseFast bf_compiler.zig
	rm -f bf_compiler.o

clean:
	rm -f *.o *.asm *.ir *.exe
	rm -f bf_compiler