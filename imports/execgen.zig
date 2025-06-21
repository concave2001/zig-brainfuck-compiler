const std  = @import("std");
const defs = @import("utils/defs.zig");

fn generate_exec_x86_64_LINUX_GNU_NASM(a: std.mem.Allocator, out_file_name: []const u8) !void {
    const asm_file_name = try std.fmt.allocPrint(a, "{s}.asm", .{out_file_name});
    defer a.free(asm_file_name);

    const obj_file_name = try std.fmt.allocPrint(a, "{s}.o", .{out_file_name});
    defer a.free(obj_file_name);

    //TODO this should depend on the params
    const create_obj_file_cmd_argv = [_][]const u8 {
        "nasm", "-f", "elf64", asm_file_name
    };

    var create_obj_file_proc = std.process.Child.init(&create_obj_file_cmd_argv, a);

    create_obj_file_proc.stdin_behavior  = .Ignore;
    create_obj_file_proc.stdout_behavior = .Ignore;
    create_obj_file_proc.stderr_behavior = .Ignore;

    try create_obj_file_proc.spawn();

    var term = try create_obj_file_proc.wait();
    if (term.Exited != 0) {
        std.debug.print("Error occured when trying to create the object file.\n", .{});
    }

    const exe_file_name = try std.fmt.allocPrint(a, "{s}.exe", .{out_file_name});
    defer a.free(exe_file_name);

    const create_exec_file_cmd_argv = [_][]const u8 {
        "gcc", "-no-pie", "-fno-pie", "-m64", "-o", exe_file_name, obj_file_name
    };

    var create_exec_proc = std.process.Child.init(&create_exec_file_cmd_argv, a);

    create_exec_proc.stdin_behavior  = .Ignore;
    create_exec_proc.stdout_behavior = .Ignore;
    create_exec_proc.stderr_behavior = .Ignore;
    
    try create_exec_proc.spawn();

    term = try create_exec_proc.wait();
    if (term.Exited != 0) {
        std.debug.print("Error occured when trying to create the executable file.\n", .{});
    }
}

pub fn generate_exec(a: std.mem.Allocator, out_file_name: []const u8, target: []const u8, assembler: []const u8) !void {
                
    if (std.mem.eql(u8, target, "x86_64-linux-gnu")) {
        if (std.mem.eql(u8, assembler, "nasm")) {
            try generate_exec_x86_64_LINUX_GNU_NASM(a, out_file_name);
        }
    } else {
        unreachable;
    }
}