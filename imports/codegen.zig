const std  = @import("std");
const defs = @import("utils/defs.zig");

pub fn generate_ir(a: std.mem.Allocator, buffer: []const u8) !std.ArrayList(defs.OPERATION) {
    var ir = std.ArrayList(defs.OPERATION).init(a);

    var bracket_stack = std.ArrayList(u64).init(a);
    defer bracket_stack.deinit();

    var bracket_count: u64 = 0;

    for (buffer) |c| {

        const op: defs.OPERATION_TYPE = defs.get_op_type(c);

        switch (op) {
            defs.OPERATION_TYPE.MOV_RIGHT,   defs.OPERATION_TYPE.MOV_LEFT,
            defs.OPERATION_TYPE.INCREMENT,   defs.OPERATION_TYPE.DECREMENT,
            defs.OPERATION_TYPE.PRINT,       defs.OPERATION_TYPE.GET_INPUT    => {

                if (ir.items.len > 0 and ir.items[ir.items.len - 1].op_type == op) {
                    ir.items[ir.items.len - 1].operand += 1;
                } else {
                    try ir.append( .{.op_type = op, .operand = 1} );
                }
            },

            defs.OPERATION_TYPE.JUMP_IF_ZERO => {
                try ir.append( .{.op_type = op, .operand = bracket_count} );
                try bracket_stack.append(bracket_count);

                bracket_count += 1;
            },

            defs.OPERATION_TYPE.JUMP_IF_NOT_ZERO => {
                const pair_bracket: u64 = bracket_stack.pop().?;
                try ir.append( .{.op_type = op, .operand = pair_bracket} );
            },

            else => continue
        }
    }

    return ir;
}

fn generate_assembly_x86_64_LINUX_GNU_NASM(a: std.mem.Allocator, ir: std.ArrayList(defs.OPERATION), out_file_name: []const u8) !void {
    
    const asm_file_name = try std.fmt.allocPrint(a, "{s}.asm", .{out_file_name});
    defer a.free(asm_file_name);

    const asm_file = try std.fs.cwd().createFile(asm_file_name, .{});
    defer asm_file.close();

    // section .data //
    _ = try asm_file.write("section .data\n\n");
    _ = try asm_file.write("\tarray:  TIMES 256 db 0\n");
    _ = try asm_file.write("\tpos:    dw 0\n\n");

    // section .text //
    _ = try asm_file.write("section .text\n\n");
    
    _ = try asm_file.write("print:\n");
    _ = try asm_file.write("\tpush rax\n");
    _ = try asm_file.write("\tpush rbx\n");
    _ = try asm_file.write("\tpush rcx\n");
    _ = try asm_file.write("\tpush rdx\n");
    _ = try asm_file.write("\tpush rdi\n");
    _ = try asm_file.write("\tpush rsi\n");
    _ = try asm_file.write("\n\tpush rbp\n");

    _ = try asm_file.write("\tmov rsi, array\n");
    _ = try asm_file.write("\tadd rsi, [pos]\n");

    _ = try asm_file.write("\tmov rdx, 1\n");
    _ = try asm_file.write("\tmov rdi, 1\n");
    _ = try asm_file.write("\tmov rax, 1\n");

    _ = try asm_file.write("\tsyscall\n\n");

    _ = try asm_file.write("\tpop rbp\n\n");
    _ = try asm_file.write("\tpop rsi\n");
    _ = try asm_file.write("\tpop rdi\n");
    _ = try asm_file.write("\tpop rdx\n");
    _ = try asm_file.write("\tpop rcx\n");
    _ = try asm_file.write("\tpop rbx\n");
    _ = try asm_file.write("\tpop rax\n");

    _ = try asm_file.write("\n\tret\n\n");


    _ = try asm_file.write("scan:\n");
    _ = try asm_file.write("\tpush rax\n");
    _ = try asm_file.write("\tpush rbx\n");
    _ = try asm_file.write("\tpush rcx\n");
    _ = try asm_file.write("\tpush rdx\n");
    _ = try asm_file.write("\tpush rdi\n");
    _ = try asm_file.write("\tpush rsi\n");
    _ = try asm_file.write("\n\tpush rbp\n");

    _ = try asm_file.write("\tmov rsi, array\n");
    _ = try asm_file.write("\tadd rsi, [pos]\n");

    _ = try asm_file.write("\tmov rdx, 1\n");
    _ = try asm_file.write("\txor rdi, rdi\n");
    _ = try asm_file.write("\txor rax, rax\n");

    _ = try asm_file.write("\tsyscall\n\n");

    _ = try asm_file.write("\tpop rbp\n\n");
    _ = try asm_file.write("\tpop rsi\n");
    _ = try asm_file.write("\tpop rdi\n");
    _ = try asm_file.write("\tpop rdx\n");
    _ = try asm_file.write("\tpop rcx\n");
    _ = try asm_file.write("\tpop rbx\n");
    _ = try asm_file.write("\tpop rax\n");

    _ = try asm_file.write("\n\tret\n\n");

    // main start //
    _ = try asm_file.write("global main\n");
    _ = try asm_file.write("main:\n\n");

    // bf instructions //
    for (0..ir.items.len) |i| {
        const op_num_str = try std.fmt.allocPrint(a, "\n.op_{d}:\n", .{i});
        defer a.free(op_num_str);

        _ = try asm_file.write(op_num_str);

        switch (ir.items[i].op_type) {

            defs.OPERATION_TYPE.MOV_RIGHT => {
                _ = try asm_file.write("\txor rdx, rdx\n");
                _ = try asm_file.write("\tmov rax, [pos]\n");

                const mov_right_inc_steps_str = try std.fmt.allocPrint(a, "\tadd rax, {d}\n", .{ir.items[i].operand});
                defer a.free(mov_right_inc_steps_str);
                _ = try asm_file.write(mov_right_inc_steps_str);

                _ = try asm_file.write("\tmov rcx, 256\n");
                _ = try asm_file.write("\tdiv rcx\n");
                _ = try asm_file.write("\tmov [pos], rdx\n");
            },

            defs.OPERATION_TYPE.MOV_LEFT => {
                _ = try asm_file.write("\tmov rax, [pos]\n");

                const mov_left_dec_steps_str = try std.fmt.allocPrint(a, "\tsub rax, {d}\n", .{ir.items[i].operand});
                defer a.free(mov_left_dec_steps_str);
                _ = try asm_file.write(mov_left_dec_steps_str);

                _ = try asm_file.write("\tcmp rax, 0\n");

                const wrap_left_jmp_str = try std.fmt.allocPrint(a, "\tjl .wrap_left_{d}\n\n", .{i});
                defer a.free(wrap_left_jmp_str);
                _ = try asm_file.write(wrap_left_jmp_str);

                const no_wrap_left_jmp_str = try std.fmt.allocPrint(a, "\tjmp .no_wrap_left_{d}\n\n", .{i});
                defer a.free(no_wrap_left_jmp_str);
                _ = try asm_file.write(no_wrap_left_jmp_str);

                const wrap_left_str = try std.fmt.allocPrint(a, ".wrap_left_{d}:\n", .{i});
                defer a.free(wrap_left_str);
                _ = try asm_file.write(wrap_left_str);

                _ = try asm_file.write("\tadd rax, 256\n");
                _ = try asm_file.write("\tcmp rax, 0\n");

                _ = try asm_file.write(wrap_left_jmp_str);

                const no_wrap_left_str = try std.fmt.allocPrint(a, ".no_wrap_left_{d}:\n", .{i});
                defer a.free(no_wrap_left_str);
                _ = try asm_file.write(no_wrap_left_str);

                _ = try asm_file.write("\tmov [pos], rax\n");
                
            },

            defs.OPERATION_TYPE.INCREMENT => {
                _ = try asm_file.write("\tmov rdi, array\n");
                _ = try asm_file.write("\tadd rdi, [pos]\n");

                _ = try asm_file.write("\txor rax, rax\n");
                _ = try asm_file.write("\tmov al, BYTE [rdi]\n");

                const inc_count_string = try std.fmt.allocPrint(a, "\tmov rcx, {d}\n", .{ir.items[i].operand});
                defer a.free(inc_count_string);
                _ = try asm_file.write(inc_count_string);

                const inc_loop_string = try std.fmt.allocPrint(a, ".increment_loop_{d}:\n", .{i});
                defer a.free(inc_loop_string);
                _ = try asm_file.write(inc_loop_string);

                _ = try asm_file.write("\tcmp rcx, 0\n");

                const inc_loop_end_jmp_string = try std.fmt.allocPrint(a, "\tje .increment_loop_end_{d}\n", .{i});
                defer a.free(inc_loop_end_jmp_string);
                _ = try asm_file.write(inc_loop_end_jmp_string);

                _ = try asm_file.write("\tdec rcx\n");
                _ = try asm_file.write("\tcmp rax, 255\n");

                const wrap_around_jmp_str = try std.fmt.allocPrint(a, "\tje .wrap_around_{d}\n", .{i});
                defer a.free(wrap_around_jmp_str);
                _ = try asm_file.write(wrap_around_jmp_str);

                const no_wrap_around_jmp_str = try std.fmt.allocPrint(a, "\tjmp .no_wrap_around_{d}\n", .{i});
                defer a.free(no_wrap_around_jmp_str);
                _ = try asm_file.write(no_wrap_around_jmp_str);

                const wrap_around_str = try std.fmt.allocPrint(a, ".wrap_around_{d}:\n", .{i});
                defer a.free(wrap_around_str);
                _ = try asm_file.write(wrap_around_str);
    
                _ = try asm_file.write("\txor rax, rax\n");

                const inc_loop_jmp_string = try std.fmt.allocPrint(a, "\tjmp .increment_loop_{d}\n", .{i});
                defer a.free(inc_loop_jmp_string);
                _ = try asm_file.write(inc_loop_jmp_string);

                const no_wrap_around_str = try std.fmt.allocPrint(a, ".no_wrap_around_{d}:\n", .{i});
                defer a.free(no_wrap_around_str);
                _ = try asm_file.write(no_wrap_around_str);

                _ = try asm_file.write("\tinc rax\n");
                _ = try asm_file.write(inc_loop_jmp_string);

                const inc_loop_end_string = try std.fmt.allocPrint(a, ".increment_loop_end_{d}:\n", .{i});
                defer a.free(inc_loop_end_string);
                _ = try asm_file.write(inc_loop_end_string);

                _ = try asm_file.write("\tmov [rdi], al\n");
            }, 

            defs.OPERATION_TYPE.DECREMENT => {
                _ = try asm_file.write("\tmov rdi, array\n");
                _ = try asm_file.write("\tadd rdi, [pos]\n");

                _ = try asm_file.write("\txor rax, rax\n");
                _ = try asm_file.write("\tmov al, BYTE [rdi]\n");

                const dec_count_string = try std.fmt.allocPrint(a, "\tmov rcx, {d}\n", .{ir.items[i].operand});
                defer a.free(dec_count_string);
                _ = try asm_file.write(dec_count_string);

                const dec_loop_string = try std.fmt.allocPrint(a, ".decrement_loop_{d}:\n", .{i});
                defer a.free(dec_loop_string);
                _ = try asm_file.write(dec_loop_string);

                _ = try asm_file.write("\tcmp rcx, 0\n");

                const dec_loop_end_jmp_string = try std.fmt.allocPrint(a, "\tje .decrement_loop_end_{d}\n", .{i});
                defer a.free(dec_loop_end_jmp_string);
                _ = try asm_file.write(dec_loop_end_jmp_string);

                _ = try asm_file.write("\tdec rcx\n");
                _ = try asm_file.write("\tcmp rax, 0\n");

                const wrap_around_jmp_str = try std.fmt.allocPrint(a, "\tje .wrap_around_{d}\n", .{i});
                defer a.free(wrap_around_jmp_str);
                _ = try asm_file.write(wrap_around_jmp_str);

                const no_wrap_around_jmp_str = try std.fmt.allocPrint(a, "\tjmp .no_wrap_around_{d}\n", .{i});
                defer a.free(no_wrap_around_jmp_str);
                _ = try asm_file.write(no_wrap_around_jmp_str);

                const wrap_around_str = try std.fmt.allocPrint(a, ".wrap_around_{d}:\n", .{i});
                defer a.free(wrap_around_str);
                _ = try asm_file.write(wrap_around_str);
    
                _ = try asm_file.write("\tmov rax, 255\n");

                const dec_loop_jmp_string = try std.fmt.allocPrint(a, "\tjmp .decrement_loop_{d}\n", .{i});
                defer a.free(dec_loop_jmp_string);
                _ = try asm_file.write(dec_loop_jmp_string);

                const no_wrap_around_str = try std.fmt.allocPrint(a, ".no_wrap_around_{d}:\n", .{i});
                defer a.free(no_wrap_around_str);
                _ = try asm_file.write(no_wrap_around_str);

                _ = try asm_file.write("\tdec rax\n");
                _ = try asm_file.write(dec_loop_jmp_string);

                const dec_loop_end_string = try std.fmt.allocPrint(a, ".decrement_loop_end_{d}:\n", .{i});
                defer a.free(dec_loop_end_string);
                _ = try asm_file.write(dec_loop_end_string);

                _ = try asm_file.write("\tmov [rdi], al\n");
            },

            defs.OPERATION_TYPE.PRINT => {
                for (0..ir.items[i].operand) |_| 
                    _ = try asm_file.write("\tcall print\n");
            },

            defs.OPERATION_TYPE.GET_INPUT => {
                for (0..ir.items[i].operand) |_|
                    _ = try asm_file.write("\tcall scan\n");        
            },

            defs.OPERATION_TYPE.JUMP_IF_ZERO => {
                const bracket_loop_string = try std.fmt.allocPrint(a, ".bracket_loop_{d}:\n", .{ir.items[i].operand});
                defer a.free(bracket_loop_string);
                _ = try asm_file.write(bracket_loop_string);

                _ = try asm_file.write("\tmov rdi, array\n");
                _ = try asm_file.write("\tadd rdi, [pos]\n");
                _ = try asm_file.write("\txor rax, rax\n");
                _ = try asm_file.write("\tmov al, BYTE [rdi]\n");

                _ = try asm_file.write("\tcmp rax, 0\n");

                const bracket_loop_end_jmp_string = try std.fmt.allocPrint(a, "\tje .bracket_loop_end_{d}\n", .{ir.items[i].operand});
                defer a.free(bracket_loop_end_jmp_string);
                _ = try asm_file.write(bracket_loop_end_jmp_string);
            },

            defs.OPERATION_TYPE.JUMP_IF_NOT_ZERO => {
                const bracket_loop_continue_string = try std.fmt.allocPrint(a, ".bracket_continue_{d}:\n", .{ir.items[i].operand});
                defer a.free(bracket_loop_continue_string);
                _ = try asm_file.write(bracket_loop_continue_string);

                const bracket_loop_continue_jmp_string = try std.fmt.allocPrint(a, "\tjmp .bracket_loop_{d}\n", .{ir.items[i].operand});
                defer a.free(bracket_loop_continue_jmp_string);
                _ = try asm_file.write(bracket_loop_continue_jmp_string);

                const bracket_loop_end_string = try std.fmt.allocPrint(a, ".bracket_loop_end_{d}:\n", .{ir.items[i].operand});
                defer a.free(bracket_loop_end_string);
                _ = try asm_file.write(bracket_loop_end_string);
            },
            
            else => continue // TODO
        }
    }

    // main end //
    _ = try asm_file.write("\n.end_main:\n\tret\n");
    
}

pub fn generate_assembly(a: std.mem.Allocator, ir:std.ArrayList(defs.OPERATION), out_file_name: []const u8, target: []const u8, assembler: []const u8) !void {
                
    if (std.mem.eql(u8, target, "x86_64-linux-gnu")) {
        if (std.mem.eql(u8, assembler, "nasm")) {
            try generate_assembly_x86_64_LINUX_GNU_NASM(a, ir, out_file_name);
        }
    } else {
        unreachable;
    }
}