const std = @import("std");
const print = std.debug.print;

const OPERATION_TYPE = enum(u8) {
    MOV_RIGHT,
    MOV_LEFT,
    INCREMENT,
    DECREMENT,
    PRINT,
    GET_INPUT,
    JUMP_IF_ZERO,
    JUMP_IF_NOT_ZERO,
    COMMENT // not currently used
};

const OPERATION = struct {
    op_type: OPERATION_TYPE,
    operand: u64
};

const PARAMS = struct {
    ir: bool          = false,
    help: bool        = false,
 
    src_provided: bool = false,
    src: ?[]const u8   = null,

    contains_invalid_arg: bool  = false,
    invalid_arg: []const u8     = undefined
};

fn str_eq(s1: []const u8, s2: []const u8) bool {
    if (s1.len != s2.len)
        return false;

    for (0..s1.len) |i| {
        if (s1[i] != s2[i])
            return false;
    }

    return true;
}

fn strip_file_extension(s: []const u8) []const u8 {
    var curr    = s.len - 1;
    var cutoff  = curr;     

    while (true) {
        if (s[curr] == '.')
            cutoff = curr;

        if (curr == 0)
            break;
        
        curr -= 1;
    }

    return s[0..cutoff];
}

fn check_src_file_extension(s: []const u8) bool {
    var curr    = s.len - 1;
    var cutoff  = curr;     

    while (true) {
        if (s[curr] == '.') {
            cutoff = curr;
            break;
        }

        if (curr == 0)
            return false;
        
        curr -= 1;
    }

    const s_cutoff = s[cutoff..];

    if (s_cutoff.len > 3)
        return false;
    if (s_cutoff[1] != 'b')
        return false;
    if (s_cutoff[2] != 'f')
        return false;

    return true;
}

fn get_op_type(c: u8) OPERATION_TYPE {
    switch (c) {
        '>' => {return OPERATION_TYPE.MOV_RIGHT;},
        '<' => {return OPERATION_TYPE.MOV_LEFT;},
        '+' => {return OPERATION_TYPE.INCREMENT;},
        '-' => {return OPERATION_TYPE.DECREMENT;},
        '.' => {return OPERATION_TYPE.PRINT;},
        ',' => {return OPERATION_TYPE.GET_INPUT;},
        '[' => {return OPERATION_TYPE.JUMP_IF_ZERO;},
        ']' => {return OPERATION_TYPE.JUMP_IF_NOT_ZERO;},

        else => {return OPERATION_TYPE.COMMENT;}
    }

    unreachable;
}

fn usage() void {
    print("Usage: ./bf_compiler [OPTIONAL_FLAGS] source_file\n", .{});
    print("Run ./bf_compiler --help for available optional arguments.\n", .{});
}

fn display_help() void {
    print("Usage: ./bf_compiler [OPTIONAL_FLAGS] source_file\n\n", .{});

    print("The following optional arguments are available:\n", .{});
    print("\t--ir : the program will also output the created intermediate representation of the provided source file (as an '.ir' file)\n", .{});
    print("\t--help : display the available optional arguments.\n", .{});
}

fn parse_cmd_inputs(args: [][:0]u8) PARAMS {

    var params: PARAMS = .{};

    for (1..args.len) |i| {
        if (!str_eq(args[i][0..2], "--")) {
            // check if this is the source file to be compiled

            params.src_provided = true;

            var file_exists: bool = true;

            std.fs.cwd().access(args[i], .{}) catch |e| {
                file_exists = if (e == error.FileNotFound) false else true;
            };

            if (!file_exists) {
                print("No source file with the name '{s}' found.\n", .{args[i]});
                params.src = null;
            }

            if (!(check_src_file_extension(args[i]))) {
                print("Invalid source file name. The file name must have either the '.b' or the '.bf' file extension'\n", .{});
                params.src = null;
            }

            params.src = args[i];

        } else {
            const arg_stripped: []const u8 = args[i][2..];

            if (str_eq(arg_stripped, "ir")) {
                params.ir = true;
            } else if (str_eq(arg_stripped, "help")) {
                params.help = true;
            } else {
                params.contains_invalid_arg = true;
                params.invalid_arg          = arg_stripped;
            }
        }   
    }

    return params;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        usage();
        return; 
    }

    const params: PARAMS = parse_cmd_inputs(args);

    if (params.help == true) {
        display_help();
        return;
    }

    if (params.contains_invalid_arg == true) {
        print("Invalid optinal argument provided: {s}.\n", .{params.invalid_arg});
    }

    if (params.src == null and !params.src_provided) {
        print("No source file was provided.\n", .{});
        return;
    }


    var input_file = try std.fs.cwd().openFile(params.src.?, .{ .mode = .read_only });
    defer input_file.close();

    const buffer = try input_file.readToEndAlloc(allocator, std.math.maxInt(u16));
    defer allocator.free(buffer);

    var ir = std.ArrayList(OPERATION).init(allocator);
    defer ir.deinit();

    var bracket_stack = std.ArrayList(u64).init(allocator);
    defer bracket_stack.deinit();

    var bracket_count: u64 = 0;

    for (buffer) |c| {
        const op: OPERATION_TYPE = get_op_type(c);

        switch (op) {
            OPERATION_TYPE.MOV_RIGHT,   OPERATION_TYPE.MOV_LEFT,
            OPERATION_TYPE.INCREMENT,   OPERATION_TYPE.DECREMENT,
            OPERATION_TYPE.PRINT,       OPERATION_TYPE.GET_INPUT    => {

                if (ir.items.len > 0 and ir.items[ir.items.len - 1].op_type == op) {
                    ir.items[ir.items.len - 1].operand += 1;
                } else {
                    try ir.append( .{.op_type = op, .operand = 1} );
                }
            },

            OPERATION_TYPE.JUMP_IF_ZERO => {
                try ir.append( .{.op_type = op, .operand = bracket_count} );
                try bracket_stack.append(bracket_count);

                bracket_count += 1;
            },

            OPERATION_TYPE.JUMP_IF_NOT_ZERO => {
                const pair_bracket: u64 = bracket_stack.pop().?;
                try ir.append( .{.op_type = op, .operand = pair_bracket} );
            },

            else => continue
        }
    }

    const output_file_name_stripped: []const u8 = strip_file_extension(params.src.?);

    if (params.ir == true) {
        const ir_file_name = try std.fmt.allocPrint(allocator, "{s}.ir", .{output_file_name_stripped});
        defer allocator.free(ir_file_name);

        const ir_file = try std.fs.cwd().createFile(ir_file_name, .{});
        defer ir_file.close();

        for (0..ir.items.len) |i| {
            const op_str = try std.fmt.allocPrint(allocator, "{s}({d})\n", .{@tagName(ir.items[i].op_type), ir.items[i].operand});
            defer allocator.free(op_str);
            _ = try ir_file.write(op_str); 
        }
    }

    // codegen //
    const asm_file_name = try std.fmt.allocPrint(allocator, "{s}.asm", .{output_file_name_stripped});
    defer allocator.free(asm_file_name);

    const asm_file = try std.fs.cwd().createFile(asm_file_name, .{});
    defer asm_file.close();

    // if (arch == x86_64) TODO
    if (true) {
        // section .data //
        _ = try asm_file.write("section .data\n\n");
        //_ = try asm_file.write("\tfmt:    db \"cell content = %d\", 10, 0\n");
        _ = try asm_file.write("\tarray:  TIMES 30000 db 0\n");
        _ = try asm_file.write("\tpos:    dw 0\n\n");
        // _ = try asm_file.write("\textern printf\n\n");

        // section .text //
        _ = try asm_file.write("section .text\n\n");

        // FIXME this form of the print function is temporary and only used for debugging
        
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
        //_ = try asm_file.write("\tmov rsi, rdi\n");
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
        
        // FIXME this form of the scan function is temporary and only used for debugging

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
        //_ = try asm_file.write("\tmov rsi, rdi\n");
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
            const op_num_str = try std.fmt.allocPrint(allocator, "\n.op_{d}:\n", .{i});
            defer allocator.free(op_num_str);

            _ = try asm_file.write(op_num_str);

            switch (ir.items[i].op_type) {

                OPERATION_TYPE.MOV_RIGHT => {
                    _ = try asm_file.write("\txor rdx, rdx\n");
                    _ = try asm_file.write("\tmov rax, [pos]\n");

                    const mov_right_inc_steps_str = try std.fmt.allocPrint(allocator, "\tadd rax, {d}\n", .{ir.items[i].operand});
                    defer allocator.free(mov_right_inc_steps_str);
                    _ = try asm_file.write(mov_right_inc_steps_str);

                    _ = try asm_file.write("\tmov rcx, 256\n");
                    _ = try asm_file.write("\tdiv rcx\n");
                    _ = try asm_file.write("\tmov [pos], rdx\n");
                },

                OPERATION_TYPE.MOV_LEFT => {
                    _ = try asm_file.write("\tmov rax, [pos]\n");

                    const mov_left_dec_steps_str = try std.fmt.allocPrint(allocator, "\tsub rax, {d}\n", .{ir.items[i].operand});
                    defer allocator.free(mov_left_dec_steps_str);
                    _ = try asm_file.write(mov_left_dec_steps_str);

                    _ = try asm_file.write("\tcmp rax, 0\n");

                    const wrap_left_jmp_str = try std.fmt.allocPrint(allocator, "\tjl .wrap_left_{d}\n\n", .{i});
                    defer allocator.free(wrap_left_jmp_str);
                    _ = try asm_file.write(wrap_left_jmp_str);

                    const no_wrap_left_jmp_str = try std.fmt.allocPrint(allocator, "\tjmp .no_wrap_left_{d}\n\n", .{i});
                    defer allocator.free(no_wrap_left_jmp_str);
                    _ = try asm_file.write(no_wrap_left_jmp_str);

                    const wrap_left_str = try std.fmt.allocPrint(allocator, ".wrap_left_{d}:\n", .{i});
                    defer allocator.free(wrap_left_str);
                    _ = try asm_file.write(wrap_left_str);

                    _ = try asm_file.write("\tadd rax, 256\n");
                    _ = try asm_file.write("\tcmp rax, 0\n");

                    _ = try asm_file.write(wrap_left_jmp_str);

                    const no_wrap_left_str = try std.fmt.allocPrint(allocator, ".no_wrap_left_{d}:\n", .{i});
                    defer allocator.free(no_wrap_left_str);
                    _ = try asm_file.write(no_wrap_left_str);

                    _ = try asm_file.write("\tmov [pos], rax\n");
                    
                },

                OPERATION_TYPE.INCREMENT => {
                    _ = try asm_file.write("\tmov rdi, array\n");
                    _ = try asm_file.write("\tadd rdi, [pos]\n");

                    _ = try asm_file.write("\txor rax, rax\n");
                    _ = try asm_file.write("\tmov al, BYTE [rdi]\n");

                    const inc_count_string = try std.fmt.allocPrint(allocator, "\tmov rcx, {d}\n", .{ir.items[i].operand});
                    defer allocator.free(inc_count_string);
                    _ = try asm_file.write(inc_count_string);

                    const inc_loop_string = try std.fmt.allocPrint(allocator, ".increment_loop_{d}:\n", .{i});
                    defer allocator.free(inc_loop_string);
                    _ = try asm_file.write(inc_loop_string);

                    _ = try asm_file.write("\tcmp rcx, 0\n");

                    const inc_loop_end_jmp_string = try std.fmt.allocPrint(allocator, "\tje .increment_loop_end_{d}\n", .{i});
                    defer allocator.free(inc_loop_end_jmp_string);
                    _ = try asm_file.write(inc_loop_end_jmp_string);

                    _ = try asm_file.write("\tdec rcx\n");
                    _ = try asm_file.write("\tcmp rax, 255\n");

                    const wrap_around_jmp_str = try std.fmt.allocPrint(allocator, "\tje .wrap_around_{d}\n", .{i});
                    defer allocator.free(wrap_around_jmp_str);
                    _ = try asm_file.write(wrap_around_jmp_str);

                    const no_wrap_around_jmp_str = try std.fmt.allocPrint(allocator, "\tjmp .no_wrap_around_{d}\n", .{i});
                    defer allocator.free(no_wrap_around_jmp_str);
                    _ = try asm_file.write(no_wrap_around_jmp_str);

                    const wrap_around_str = try std.fmt.allocPrint(allocator, ".wrap_around_{d}:\n", .{i});
                    defer allocator.free(wrap_around_str);
                    _ = try asm_file.write(wrap_around_str);
        
                    _ = try asm_file.write("\txor rax, rax\n");

                    const inc_loop_jmp_string = try std.fmt.allocPrint(allocator, "\tjmp .increment_loop_{d}\n", .{i});
                    defer allocator.free(inc_loop_jmp_string);
                    _ = try asm_file.write(inc_loop_jmp_string);

                    const no_wrap_around_str = try std.fmt.allocPrint(allocator, ".no_wrap_around_{d}:\n", .{i});
                    defer allocator.free(no_wrap_around_str);
                    _ = try asm_file.write(no_wrap_around_str);

                    _ = try asm_file.write("\tinc rax\n");
                    _ = try asm_file.write(inc_loop_jmp_string);

                    const inc_loop_end_string = try std.fmt.allocPrint(allocator, ".increment_loop_end_{d}:\n", .{i});
                    defer allocator.free(inc_loop_end_string);
                    _ = try asm_file.write(inc_loop_end_string);

                    _ = try asm_file.write("\tmov [rdi], al\n");
                }, 

                OPERATION_TYPE.DECREMENT => {
                    _ = try asm_file.write("\tmov rdi, array\n");
                    _ = try asm_file.write("\tadd rdi, [pos]\n");

                    _ = try asm_file.write("\txor rax, rax\n");
                    _ = try asm_file.write("\tmov al, BYTE [rdi]\n");

                    const dec_count_string = try std.fmt.allocPrint(allocator, "\tmov rcx, {d}\n", .{ir.items[i].operand});
                    defer allocator.free(dec_count_string);
                    _ = try asm_file.write(dec_count_string);

                    const dec_loop_string = try std.fmt.allocPrint(allocator, ".decrement_loop_{d}:\n", .{i});
                    defer allocator.free(dec_loop_string);
                    _ = try asm_file.write(dec_loop_string);

                    _ = try asm_file.write("\tcmp rcx, 0\n");

                    const dec_loop_end_jmp_string = try std.fmt.allocPrint(allocator, "\tje .decrement_loop_end_{d}\n", .{i});
                    defer allocator.free(dec_loop_end_jmp_string);
                    _ = try asm_file.write(dec_loop_end_jmp_string);

                    _ = try asm_file.write("\tdec rcx\n");
                    _ = try asm_file.write("\tcmp rax, 0\n");

                    const wrap_around_jmp_str = try std.fmt.allocPrint(allocator, "\tje .wrap_around_{d}\n", .{i});
                    defer allocator.free(wrap_around_jmp_str);
                    _ = try asm_file.write(wrap_around_jmp_str);

                    const no_wrap_around_jmp_str = try std.fmt.allocPrint(allocator, "\tjmp .no_wrap_around_{d}\n", .{i});
                    defer allocator.free(no_wrap_around_jmp_str);
                    _ = try asm_file.write(no_wrap_around_jmp_str);

                    const wrap_around_str = try std.fmt.allocPrint(allocator, ".wrap_around_{d}:\n", .{i});
                    defer allocator.free(wrap_around_str);
                    _ = try asm_file.write(wrap_around_str);
        
                    _ = try asm_file.write("\tmov rax, 255\n");

                    const dec_loop_jmp_string = try std.fmt.allocPrint(allocator, "\tjmp .decrement_loop_{d}\n", .{i});
                    defer allocator.free(dec_loop_jmp_string);
                    _ = try asm_file.write(dec_loop_jmp_string);

                    const no_wrap_around_str = try std.fmt.allocPrint(allocator, ".no_wrap_around_{d}:\n", .{i});
                    defer allocator.free(no_wrap_around_str);
                    _ = try asm_file.write(no_wrap_around_str);

                    _ = try asm_file.write("\tdec rax\n");
                    _ = try asm_file.write(dec_loop_jmp_string);

                    const dec_loop_end_string = try std.fmt.allocPrint(allocator, ".decrement_loop_end_{d}:\n", .{i});
                    defer allocator.free(dec_loop_end_string);
                    _ = try asm_file.write(dec_loop_end_string);

                    _ = try asm_file.write("\tmov [rdi], al\n");
                },

                OPERATION_TYPE.PRINT => {
                    for (0..ir.items[i].operand) |_| 
                        _ = try asm_file.write("\tcall print\n");
                },

                OPERATION_TYPE.GET_INPUT => {
                    for (0..ir.items[i].operand) |_|
                        _ = try asm_file.write("\tcall scan\n");        
                },

                OPERATION_TYPE.JUMP_IF_ZERO => {
                    const bracket_loop_string = try std.fmt.allocPrint(allocator, ".bracket_loop_{d}:\n", .{ir.items[i].operand});
                    defer allocator.free(bracket_loop_string);
                    _ = try asm_file.write(bracket_loop_string);

                    _ = try asm_file.write("\tmov rdi, array\n");
                    _ = try asm_file.write("\tadd rdi, [pos]\n");
                    _ = try asm_file.write("\txor rax, rax\n");
                    _ = try asm_file.write("\tmov al, BYTE [rdi]\n");

                    _ = try asm_file.write("\tcmp rax, 0\n");

                    const bracket_loop_end_jmp_string = try std.fmt.allocPrint(allocator, "\tje .bracket_loop_end_{d}\n", .{ir.items[i].operand});
                    defer allocator.free(bracket_loop_end_jmp_string);
                    _ = try asm_file.write(bracket_loop_end_jmp_string);
                },

                OPERATION_TYPE.JUMP_IF_NOT_ZERO => {
                    const bracket_loop_continue_string = try std.fmt.allocPrint(allocator, ".bracket_continue_{d}:\n", .{ir.items[i].operand});
                    defer allocator.free(bracket_loop_continue_string);
                    _ = try asm_file.write(bracket_loop_continue_string);

                    const bracket_loop_continue_jmp_string = try std.fmt.allocPrint(allocator, "\tjmp .bracket_loop_{d}\n", .{ir.items[i].operand});
                    defer allocator.free(bracket_loop_continue_jmp_string);
                    _ = try asm_file.write(bracket_loop_continue_jmp_string);

                    const bracket_loop_end_string = try std.fmt.allocPrint(allocator, ".bracket_loop_end_{d}:\n", .{ir.items[i].operand});
                    defer allocator.free(bracket_loop_end_string);
                    _ = try asm_file.write(bracket_loop_end_string);
                },
                
                else => continue // TODO
            }
        }

        // main end //
        _ = try asm_file.write("\n.end_main:\n\tret\n");

        // create executable (nasm-linux-x86_64)) //
        const obj_file_name = try std.fmt.allocPrint(allocator, "{s}.o", .{output_file_name_stripped});
        defer allocator.free(obj_file_name);

        const create_obj_file_cmd_argv = [_][]const u8 {
            "nasm", "-f", "elf64", asm_file_name
        };

        var create_obj_file_proc = std.process.Child.init(&create_obj_file_cmd_argv, allocator);

        create_obj_file_proc.stdin_behavior = .Ignore;
        create_obj_file_proc.stdout_behavior = .Ignore;
        create_obj_file_proc.stderr_behavior = .Ignore;

        try create_obj_file_proc.spawn();

        var term = try create_obj_file_proc.wait();
        if (term.Exited != 0) {
            print("Error occured when trying to create the object file.\n", .{});
        }     


        const exe_file_name = try std.fmt.allocPrint(allocator, "{s}.exe", .{output_file_name_stripped});
        defer allocator.free(exe_file_name);

        const create_exec_file_cmd_argv = [_][]const u8 {
            "gcc", "-no-pie", "-fno-pie", "-m64", "-o", exe_file_name, obj_file_name
        };

        var create_exec_proc = std.process.Child.init(&create_exec_file_cmd_argv, allocator);

        create_exec_proc.stdin_behavior = .Ignore;
        create_exec_proc.stdout_behavior = .Ignore;
        create_exec_proc.stderr_behavior = .Ignore;
        
        try create_exec_proc.spawn();

        term = try create_exec_proc.wait();
        if (term.Exited != 0) {
            print("Error occured when trying to create the executable file.\n", .{});
        }
    }
}