pub const OPERATION_TYPE = enum(u8) {
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

pub const OPERATION = struct {
    op_type: OPERATION_TYPE,
    operand: u64
};


pub const AVAILABLE_TARGETS = [_][]const u8 {
    "x86_64-linux-gnu",
};

pub const AVAILABLE_ASSEMBLERS = [_][]const u8 {
    "nasm",
};

pub const PARAMS = struct {
    ir: bool   = false,
    help: bool = false,

    target: ?[]const u8    = null,
    assembler: ?[]const u8 = null,
 
    src_provided: bool = false,
    src: ?[]const u8   = null,

    contains_invalid_arg: bool = false,
    invalid_arg: ?[]const u8   = null,
};

pub fn get_op_type(c: u8) OPERATION_TYPE {
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