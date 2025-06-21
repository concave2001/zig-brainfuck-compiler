build: bf_compiler.zig
	# zig build-exe -static bf_compiler.zig
	# ^ will be removed in the future
	zig build --summary all -p .

	# rm -rf .zig-cache/

clean:
	rm -rf *.o *.asm *.ir *.exe .zig-cache/ zig-out/

clean_all:
	rm -rf *.o *.asm *.ir *.exe .zig-cache/ zig-out/
	rm -rf bin/