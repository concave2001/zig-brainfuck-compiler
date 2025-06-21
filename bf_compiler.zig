const std       = @import("std");
const codegen   = @import("imports/codegen.zig");
const defs      = @import("imports/utils/defs.zig");
const execgen   = @import("imports/execgen.zig");

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

fn usage() void {
    std.debug.print("Usage: ./bf_compiler [OPTIONAL_FLAGS] source_file\n", .{});
    std.debug.print("Run ./bf_compiler --help for available optional arguments.\n", .{});
}

fn display_help() void {
    std.debug.print("Usage: ./bf_compiler [OPTIONAL_ARGUMENTS] source_file\n\n", .{});

    std.debug.print("The following optional arguments are available:\n", .{});
    std.debug.print("\t--ir         : the program will also output the created intermediate representation of the provided source file (as an '.ir' file)\n", .{});
    std.debug.print("\t--help       : display the available optional arguments and exits the program.\n", .{});

    std.debug.print("\t--target     : sets the target os/platform for the final executable.\n", .{});
    std.debug.print("\t  Available targets:\n", .{});
    for (defs.AVAILABLE_TARGETS) |t| {
        std.debug.print("\t\t{s}\n", .{t});
    }
    std.debug.print("\n", .{});

    std.debug.print("\t--assembler  : sets the assembler that will be used to create the final executable from the generated assembly code.\n", .{});
    std.debug.print("\t  Available assemblers:\n", .{});
    for (defs.AVAILABLE_ASSEMBLERS) |as| {
        std.debug.print("\t\t{s}\n", .{as});
    }
    std.debug.print("\n", .{});
}

fn parse_cmd_inputs(args: [][:0]u8) !defs.PARAMS {

    var params: defs.PARAMS = .{};

    var i: u64 = 1;
    while (i < args.len) {
        if (!std.mem.eql(u8, args[i][0..2], "--")) {

            if (args[i][0] == '-') {
                std.debug.print("All available arguments use \'--argument\' notation.\n\n", .{});
                display_help();
                return params;
            }

            params.src_provided = true;

            var file_exists: bool = true;

            std.fs.cwd().access(args[i], .{}) catch |e| {
                file_exists = if (e == error.FileNotFound) false else true;
            };

            if (!file_exists) {
                std.debug.print("No source file with the name '{s}' found.\n", .{args[i]});
                params.src = null;
            }

            if (!(check_src_file_extension(args[i]))) {
                std.debug.print("Invalid source file name. The file name must have either the '.b' or the '.bf' file extension'\n", .{});
                params.src = null;
            }

            params.src = args[i];


        } else {
            const arg_stripped: []const u8 = args[i][2..];

            if (std.mem.eql(u8, arg_stripped, "ir")) {
                params.ir = true;
            } else if (std.mem.eql(u8, arg_stripped, "help")) {
                params.help = true;
            } else if (std.mem.eql(u8, arg_stripped, "target")) {
                if (i == (args.len - 1)) {
                    break;
                }

                i += 1;
                const target_arg: []const u8 = args[i];
                for (defs.AVAILABLE_TARGETS) |t| {
                    if (std.mem.eql(u8, target_arg, t)) {
                        params.target = t;
                    }
                }
            } else if (std.mem.eql(u8, arg_stripped, "assembler")) {
                if (i == (args.len - 1)) {
                    break;
                }

                i += 1;
                const assembler_arg: []const u8 = args[i];
                for (defs.AVAILABLE_ASSEMBLERS) |as| {
                    if (std.mem.eql(u8, assembler_arg, as)) {
                        params.assembler = as;
                    }
                }
                
            } else {
                params.contains_invalid_arg = true;
                params.invalid_arg          = arg_stripped;
            }
        }  

        i += 1; 
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

    const params: defs.PARAMS = try parse_cmd_inputs(args);

    if (params.help == true) {
        display_help();
        return;
    }

    if (params.contains_invalid_arg == true) {
        std.debug.print("Invalid optinal argument provided: {s}. Add the --help argument for a list of the available arguments.\n", .{params.invalid_arg.?});
        return;
    }

    if (params.src == null and !params.src_provided) {
        std.debug.print("No source file was provided.\n", .{});
        return;
    }

    if (params.target == null) {
        std.debug.print("The provided target is not supported or is invalid. Check --help for a list of supported targets.\n", .{});
        return;
    }

    if (params.assembler == null) {
        std.debug.print("The provided assembler is not supported or is invalid. Check --help for a list of supported assemblers.\n", .{});
        return;
    }

    var input_file = try std.fs.cwd().openFile(params.src.?, .{ .mode = .read_only });
    defer input_file.close();

    const buffer = try input_file.readToEndAlloc(allocator, std.math.maxInt(u16));
    defer allocator.free(buffer);

    const ir = try codegen.generate_ir(allocator, buffer);
    defer ir.deinit();

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

    try codegen.generate_assembly(allocator, ir, output_file_name_stripped, params.target.?, params.assembler.?);
    try execgen.generate_exec(allocator, output_file_name_stripped, params.target.?, params.assembler.?);
}