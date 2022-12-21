// zig-gccjit --- Zig bindings for libgccjit
// Copyright © 2012-2022 Maya Tomasek <maya.tomasek@disroot.org>
// This program is free software: you can redistribute it and/or modify it under the terms
// of the GNU Lesser General Public License as published by the Free Software Foundation,
// either version 3 of the License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
// without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
// See the GNU Lesser General Public License for more details.
//
// You should have received a copy of the GNU Lesser General Public License along with this
// program. If not, see <https://www.gnu.org/licenses/>.

const std = @import("std");
const c = @cImport({
    @cInclude("libgccjit.h");
});
const assert = std.debug.assert;

pub const Context = struct {
    ctx: *c.gcc_jit_context,
    dump: [*c]u8 = null,

    const Self = @This();

    const Options = struct {
        program_name: [:0]const u8 = "libzig-gccjit",
        optimization_level: u2 = 0,
        debug_info: bool = false,
        dump_initial_tree: bool = false,
        dump_initial_gimple: bool = false,
        dump_generated_code: bool = false,
        dump_summary: bool = false,
        dump_everything: bool = false,
        selfcheck_gc: bool = false,
        keep_intermediates: bool = false,
        command_line_options: [][:0]const u8 = ([_][:0]const u8{})[0..],
        driver_options: [][:0]const u8 = ([_][:0]const u8{})[0..],
        logfile: ?*align(8) std.c.FILE = null,
        allow_unreachable_blocks: bool = false,
        print_errors_to_stderr: bool = false,
        use_external_driver: bool = false,
    };

    pub fn set_options(self: *Self, options: Options) void {
        //TODO: const progname: [:0]const u8 = options.program_name[0.. :0];
        c.gcc_jit_context_set_str_option(self.ctx, c.GCC_JIT_STR_OPTION_PROGNAME, options.program_name);
        c.gcc_jit_context_set_int_option(self.ctx, c.GCC_JIT_INT_OPTION_OPTIMIZATION_LEVEL, options.optimization_level);
        c.gcc_jit_context_set_bool_option(self.ctx, c.GCC_JIT_BOOL_OPTION_DEBUGINFO, @boolToInt(options.debug_info));
        c.gcc_jit_context_set_bool_option(self.ctx, c.GCC_JIT_BOOL_OPTION_DUMP_INITIAL_TREE, @boolToInt(options.dump_initial_tree));
        c.gcc_jit_context_set_bool_option(self.ctx, c.GCC_JIT_BOOL_OPTION_DUMP_INITIAL_GIMPLE, @boolToInt(options.dump_initial_gimple));
        c.gcc_jit_context_set_bool_option(self.ctx, c.GCC_JIT_BOOL_OPTION_DUMP_GENERATED_CODE, @boolToInt(options.dump_generated_code));
        c.gcc_jit_context_set_bool_option(self.ctx, c.GCC_JIT_BOOL_OPTION_DUMP_SUMMARY, @boolToInt(options.dump_summary));
        c.gcc_jit_context_set_bool_option(self.ctx, c.GCC_JIT_BOOL_OPTION_DUMP_EVERYTHING, @boolToInt(options.dump_everything));
        c.gcc_jit_context_set_bool_option(self.ctx, c.GCC_JIT_BOOL_OPTION_SELFCHECK_GC, @boolToInt(options.selfcheck_gc));
        c.gcc_jit_context_set_bool_option(self.ctx, c.GCC_JIT_BOOL_OPTION_KEEP_INTERMEDIATES, @boolToInt(options.keep_intermediates));
        if (@hasDecl(c, c.LIBGCCJIT_HAVE_gcc_jit_context_set_bool_allow_unreachable_blocks)) {
            c.gcc_jit_context_set_bool_allow_unreachable_blocks(self.ctx, @boolToInt(options.allow_unreachable_blocks));
        }
        if (@hasDecl(c, c.LIBGCCJIT_HAVE_gcc_jit_context_set_bool_print_errors_to_stderr)) {
            c.gcc_jit_context_set_bool_print_errors_to_stderr(self.ctx, @boolToInt(options.print_errors_to_stderr));
        }
        if (@hasDecl(c, c.LIBGCCJIT_HAVE_gcc_jit_context_set_bool_use_external_driver)) {
            c.gcc_jit_context_set_bool_use_external_driver(self.cxt, @boolToInt(options.use_external_driver));
        }
        if (@hasDecl(c, c.LIBGCCJIT_HAVE_gcc_jit_context_add_command_line_option)) {
            for (options.command_line_options) |cmd_option| {
                const cmd_opt: [:0]const u8 = cmd_option[0.. :0];
                c.gcc_jit_context_add_command_line_option(self.ctx, cmd_opt);
            }
        }
        if (@hasDecl(c, c.LIBGCCJIT_HAVE_gcc_jit_context_add_driver_option)) {
            for (options.driver_options) |driver_option| {
                const drv_opt: [:0]const u8 = driver_option[0.. :0];
                c.gcc_jit_context_add_driver_option(self.ctx, drv_opt);
            }
        }
        if (options.logfile) |log_file| {
            c.gcc_jit_context_set_logfile(self.ctx, @ptrCast([*c]c.struct__IO_FILE, log_file), 0, 0);
        }
    }

    pub fn compile(self: *Self) !Result {
        return Result{ .res = c.gcc_jit_context_compile(self.ctx) orelse return error.Compile };
    }

    pub fn compile_to_file(self: *Self, output_kind: OutputKind, output_path: [:0]const u8) void {
        c.gcc_jit_context_compile_to_file(self.ctx, @enumToInt(output_kind), output_path);
    }

    pub fn dump_to_file(self: *Self, path: [:0]const u8, update_locations: bool) void {
        c.gcc_jit_context_dump_to_file(self.ctx, path, @boolToInt(update_locations));
    }

    pub fn get_first_error(self: *Self) ?[:0]const u8 {
        const c_err = c.gcc_jit_context_get_first_error(self.ctx);
        return std.mem.span(c_err orelse return null);
    }

    pub fn get_last_error(self: *Self) ?[:0]const u8 {
        const c_err = c.gcc_jit_context_get_last_error(self.ctx);
        return std.mem.span(c_err orelse return null);
    }

    pub fn new_location(self: *Self, filename: [:0]const u8, line: c_int, column: c_int) Location {
        const loc_ptr = c.gcc_jit_context_new_location(self.ctx, filename, line, column);
        return Location{ .loc = loc_ptr };
    }

    pub fn get_type(self: *Self, type_: Types) !Type {
        const type_ptr = c.gcc_jit_context_get_type(self.ctx, @enumToInt(type_));
        return Type{ .typ = type_ptr orelse return error.GetType };
    }

    pub fn get_int_type(self: *Self, number_of_bytes: c_int, is_signed: bool) !Type {
        const type_ptr = c.gcc_jit_context_get_int_type(self.ctx, number_of_bytes, @boolToInt(is_signed));
        return Type{ .typ = type_ptr orelse return error.GetIntType };
    }

    pub fn new_array_type(self: *Self, location: Location, element_type: Type, number_of_elements: c_int) !Type {
        const type_ptr = c.gcc_jit_context_new_array_type(self.ctx, location.loc, element_type.typ, number_of_elements);
        return Type{ .typ = type_ptr orelse return error.CreateArrayType };
    }

    pub fn new_field(self: *Self, location: Location, field_type: Type, name: [:0]const u8) !Field {
        const field_ptr = c.gcc_jit_context_new_field(self.ctx, location.loc, field_type.typ, name);
        return Field{ .fie = field_ptr orelse return error.CreateField };
    }

    pub fn new_bitfield(self: *Self, location: Location, field_type: Type, width: c_int, name: [:0]const u8) !Field {
        comptime assert(@hasDecl(c, "LIBGCCJIT_HAVE_gcc_jit_context_new_bitfield"));
        const field_ptr = c.gcc_jit_context_new_bitfield(self.ctx, location.loc, field_type.typ, width, name);
        return Field{ .fie = field_ptr orelse return error.CreateBitfield };
    }

    pub fn new_struct_type(self: *Self, location: Location, name: [:0]const u8, fields: []align(8) Field) !Struct {
        //TODO: check if this works, but it should
        const num_fields = @intCast(c_int, fields.len);
        const fields_ptr = @ptrCast([*c]?*c.gcc_jit_field, fields.ptr);

        const struct_ptr = c.gcc_jit_context_new_struct_type(self.ctx, location.loc, name, num_fields, fields_ptr);
        return Struct{ .str = struct_ptr orelse return error.CreateStruct };
    }

    pub fn new_opaque_struct(self: *Self, location: Location, name: [:0]const u8) !Struct {
        const struct_ptr = c.gcc_jit_context_new_opaque_struct(self.ctx, location.loc, name);
        return Struct{ .str = struct_ptr orelse return error.CreateOpaqueStruct };
    }

    pub fn new_union_type(self: *Self, location: Location, name: [:0]const u8, fields: []align(8) Field) !Type {
        //TODO: check if this works, but it should
        const num_fields = @intCast(c_int, fields.len);
        const fields_ptr = @ptrCast([*c]?*c.gcc_jit_field, fields.ptr);

        const union_ptr = c.gcc_jit_context_new_union_type(self.ctx, location.loc, name, num_fields, fields_ptr);
        return Type{ .typ = union_ptr orelse return error.CreateUnion };
    }

    pub fn new_function_pointer_type(self: *Self, location: Location, return_type: Type, parameter_types: []align(8) Type, is_variadic: bool) !Type {
        //TODO: check if this works, but it should
        const num_params = @intCast(c_int, parameter_types.len);
        const param_types = @ptrCast([*c]?*c.gcc_jit_type, parameter_types.ptr);

        const fun_ptr = c.gcc_jit_context_new_function_ptr_type(self.ctx, location.loc, return_type.typ, num_params, param_types, @boolToInt(is_variadic));

        return Type{ .typ = fun_ptr orelse return error.CreateFunctionPointerType };
    }

    pub fn new_parameter(self: *Self, location: Location, parameter_type: Type, name: [:0]const u8) !Parameter {
        const param_ptr = c.gcc_jit_context_new_param(self.ctx, location.loc, parameter_type.typ, name);

        return Parameter{ .prm = param_ptr orelse return error.CreateParameter };
    }

    pub fn new_function(self: *Self, location: Location, kind: FunctionKind, return_type: Type, name: [:0]const u8, parameters: []Parameter, is_variadic: bool) !Function {
        //TODO: check if this works, but it should
        const num_params = @intCast(c_int, parameters.len);
        const param_types = @ptrCast([*c]?*c.gcc_jit_param, parameters.ptr);

        const fun_ptr = c.gcc_jit_context_new_function(self.ctx, location.loc, @enumToInt(kind), return_type.typ, name, num_params, param_types, @boolToInt(is_variadic));

        return Function{ .fun = fun_ptr orelse return error.CreateFunction };
    }

    pub fn get_builtin_function(self: *Self, name: [:0]const u8) !Function {
        const fun_ptr = c.gcc_jit_context_get_builtin_function(self.ctx, name);
        return Function{ .fun = fun_ptr orelse return error.GetBuiltinFunction };
    }

    pub fn new_global(self: *Self, location: Location, kind: GlobalKind, global_type: Type, name: [:0]const u8) !LValue {
        const lva_ptr = c.gcc_jit_context_new_global(self.ctx, location.loc, @enumToInt(kind), global_type.typ, name);
        return LValue{ .lva = lva_ptr orelse return error.CreateGlobal };
    }

    pub fn new_struct_constructor(self: *Self, location: Location, struct_type: Type, fields: []align(8) Field, values: []align(8) RValue) !RValue {
        comptime assert(@hasDecl(c, "LIBGCCJIT_HAVE_CTORS"));
        const num_values = values.len;
        const values_ptr = @ptrCast([*c]?*c.gcc_jit_rvalue, values.ptr);
        const fields_ptr = @ptrCast([*c]?*c.gcc_jit_field, fields.ptr);

        const rva_ptr = c.gcc_jit_context_new_struct_constructor(self.ctx, location.loc, struct_type.typ, num_values, fields_ptr, values_ptr);
        return RValue{ .rva = rva_ptr orelse return error.CreateStructConstructor };
    }

    pub fn new_union_constructor(self: *Self, location: Location, union_type: Type, field: Field, value: RValue) !RValue {
        comptime assert(@hasDecl(c, "LIBGCCJIT_HAVE_CTORS"));
        const rva_ptr = c.gcc_jit_context_new_union_constructor(self.ctx, location.loc, union_type.typ, field.fie, value.rva);
        return RValue{ .rva = rva_ptr orelse return error.CreateUnionConstructor };
    }

    pub fn new_array_constructor(self: *Self, location: Location, array_type: Type, values: []align(8) RValue) !RValue {
        comptime assert(@hasDecl(c, "LIBGCCJIT_HAVE_CTORS"));
        const num_values = values.len;
        const values_ptr = @ptrCast([*c]?*c.gcc_jit_rvalue, values.ptr);
        const rva_ptr = c.gcc_jit_context_new_array_constructor(self.ctx, location.loc, array_type.typ, num_values, values_ptr);
        return RValue{ .rva = rva_ptr orelse return error.CreateArrayConstructor };
    }

    pub fn new_rvalue_from_int(self: *Self, numeric_type: Type, value: c_int) !RValue {
        const rva_ptr = c.gcc_jit_context_new_rvalue_from_int(self.ctx, numeric_type.typ, value);
        return RValue{ .rva = rva_ptr orelse return error.CreateRValueFromInt };
    }

    pub fn new_rvalue_from_long(self: *Self, numeric_type: Type, value: c_long) !RValue {
        const rva_ptr = c.gcc_jit_context_new_rvalue_from_long(self.ctx, numeric_type.typ, value);
        return RValue{ .rva = rva_ptr orelse return error.CreateRValueFromInt };
    }

    pub fn zero(self: *Self, numeric_type: Type) !RValue {
        const rva_ptr = c.gcc_jit_context_zero(self.ctx, numeric_type.typ);
        return RValue{ .rva = rva_ptr orelse return error.Zero };
    }

    pub fn one(self: *Self, numeric_type: Type) !RValue {
        const rva_ptr = c.gcc_jit_context_one(self.ctx, numeric_type.typ);
        return RValue{ .rva = rva_ptr orelse return error.One };
    }

    pub fn new_rvalue_from_double(self: *Self, numeric_type: Type, value: f64) !RValue {
        const rva_ptr = c.gcc_jit_context_new_rvalue_from_double(self.ctx, numeric_type.typ, value);
        return RValue{ .rva = rva_ptr orelse return error.CreateRValueFromDouble };
    }

    pub fn new_rvalue_from_pointer(self: *Self, pointer_type: Type, value: *anyopaque) !RValue {
        const rva_ptr = c.gcc_jit_context_new_rvalue_from_ptr(self.ctx, pointer_type.typ, value);
        return RValue{ .rva = rva_ptr orelse return error.CreateRValueFromPointer };
    }

    pub fn null_(self: *Self, pointer_type: Type) !RValue {
        const rva_ptr = c.gcc_jit_context_null(self.ctx, pointer_type.typ);
        return RValue{ .rva = rva_ptr orelse return error.Null };
    }

    pub fn new_string_literal(self: *Self, value: [:0]const u8) !RValue {
        const rva_ptr = c.gcc_jit_context_new_string_literal(self.ctx, value);
        return RValue{ .rva = rva_ptr orelse return error.CreateStringLiteral };
    }

    pub fn new_unary_operation(self: *Self, location: Location, op: UnaryOperation, result_type: Type, rvalue: RValue) !RValue {
        const rva_ptr = c.gcc_jit_context_new_unary_op(self.ctx, location.loc, @enumToInt(op), result_type.typ, rvalue.rva);
        return RValue{ .rva = rva_ptr orelse return error.CreateUnaryOperation };
    }

    pub fn new_binary_operation(self: *Self, location: Location, op: BinaryOperation, result_type: Type, a: RValue, b: RValue) !RValue {
        const rva_ptr = c.gcc_jit_context_new_binary_op(self.ctx, location.loc, @enumToInt(op), result_type.typ, a.rva, b.rva);
        return RValue{ .rva = rva_ptr orelse return error.CreateBinaryOperation };
    }

    pub fn new_comparison(self: *Self, location: Location, op: Comparison, a: RValue, b: RValue) !RValue {
        const rva_ptr = c.gcc_jit_context_new_comparison(self.ctx, location.loc, @enumToInt(op), a.rva, b.rva);
        return RValue{ .rva = rva_ptr orelse return error.CreateComparison };
    }

    pub fn new_call(self: *Self, location: Location, function: Function, args: []align(8) RValue) !RValue {
        const num_args = @intCast(c_int, args.len);
        const args_ptr = @ptrCast([*c]?*c.gcc_jit_rvalue, args.ptr);

        const rva_ptr = c.gcc_jit_context_new_call(self.ctx, location.loc, function.fun, num_args, args_ptr);
        return RValue{ .rva = rva_ptr orelse return error.CreateCall };
    }

    pub fn new_call_through_pointer(self: *Self, location: Location, function_pointer: RValue, args: []align(8) RValue) !RValue {
        const num_args = @intCast(c_int, args.len);
        const args_ptr = @ptrCast([*c]?*c.gcc_jit_rvalue, args.ptr);

        const rva_ptr = c.gcc_jit_context_new_call_through_ptr(self.ctx, location.loc, function_pointer.rva, num_args, args_ptr);
        return RValue{ .rva = rva_ptr orelse return error.CreateCallThroughPointer };
    }

    pub fn new_cast(self: *Self, location: Location, rvalue: RValue, destination_type: Type) !RValue {
        const rva_ptr = c.gcc_jit_context_new_cast(self.ctx, location.loc, rvalue.rva, destination_type.typ);
        return RValue{ .rva = rva_ptr orelse return error.CreateCast };
    }

    pub fn new_bitcast(self: *Self, location: Location, rvalue: RValue, destination_type: Type) !RValue {
        comptime assert(@hasDecl(c, "LIBGCCJIT_HAVE_gcc_jit_context_new_bitcast"));
        const rva_ptr = c.gcc_jit_context_new_bitcast(self.ctx, location.loc, rvalue.rva, destination_type.typ);
        return RValue{ .rva = rva_ptr orelse return error.CreateBitcast };
    }

    pub fn new_array_access(self: *Self, location: Location, pointer: RValue, index: RValue) !LValue {
        const lva_ptr = c.gcc_jit_context_new_array_access(self.ctx, location.loc, pointer.rva, index.rva);
        return LValue{ .lva = lva_ptr orelse return error.CreateArrayAccess };
    }

    pub fn new_case(self: *Self, min_value: RValue, max_value: RValue, destination_block: Block) !Case {
        comptime assert(@hasDecl(c, "LIBGCCJIT_HAVE_SWITCH_STATEMENTS"));
        const case_ptr = c.gcc_jit_context_new_case(self.ctx, min_value.rva, max_value.rva, destination_block.blk);
        return Case{ .cas = case_ptr orelse return error.CreateCase };
    }

    pub fn new_child_context(self: *Self) !Self {
        const ctx_ptr = c.gcc_jit_context_new_child_context(self.ctx);
        return Self{ .ctx = ctx_ptr orelse return error.CreateChildContext };
    }

    pub fn dump_reproducer_to_file(self: *Self, path: [:0]const u8) void {
        c.gcc_jit_context_dump_reproducer_to_file(self.ctx, path);
    }

    pub fn enable_dump(self: *Self, dump_name: [:0]const u8) void {
        c.gcc_jit_context_enable_dump(self.ctx, dump_name, &self.dump);
    }

    pub fn set_timer(self: *Self, timer: Timer) void {
        comptime assert(@hasDecl(c, "LIBGCCJIT_HAVE_TIMING_API"));
        c.gcc_jit_context_set_timer(self.ctx, timer.tmr);
    }

    pub fn get_timer(self: *Self) !Timer {
        comptime assert(@hasDecl(c, "LIBGCCJIT_HAVE_TIMING_API"));
        const timer_ptr = c.gcc_jit_context_get_timer(self.ctx);
        return Timer{ .tmr = timer_ptr orelse return error.GetTimer };
    }

    pub fn new_rvalue_from_vector(self: *Self, location: Location, vector_type: Type, elements: []align(8) RValue) !RValue {
        comptime assert(@hasDecl(c, "LIBGCCJIT_HAVE_gcc_jit_context_new_rvalue_from_vector"));

        //TODO: check if this works, but it should
        const num_elements = elements.len;
        const elements_ptr = @ptrCast([*c]?*c.gcc_jit_rvalue, elements.ptr);

        const rva_ptr = c.gcc_jit_context_new_rvalue_from_vector(self.ctx, location.loc, vector_type.typ, num_elements, elements_ptr);
        return RValue{ .rva = rva_ptr orelse return error.CreateRValueFromVector };
    }

    pub fn add_top_level_assembly(self: *Self, location: Location, assembly_statements: [:0]const u8) void {
        comptime assert(@hasDecl(c, "LIBGCCJIT_HAVE_ASM_STATEMENTS"));
        c.gcc_jit_context_add_top_level_asm(self.ctx, location.loc, assembly_statements);
    }

    pub fn init(options: Options) !Self {
        const ctx_m = c.gcc_jit_context_acquire();
        var ctx = if (ctx_m) |ctx| Self{ .ctx = ctx } else return error.AcquireContext;
        ctx.set_options(options);
        return ctx;
    }

    pub fn deinit(self: *Self) void {
        c.gcc_jit_context_release(self.ctx);
        if (self.dump) |dump_ptr| {
            _ = std.c.free(dump_ptr);
        }
    }
};

pub const OutputKind = enum(c_uint) {
    Assebler = c.GCC_JIT_OUTPUT_KIND_ASSEMBLER,
    ObjectFile = c.GCC_JIT_OUTPUT_KIND_OBJECT_FILE,
    DynamicLibrary = c.GCC_JIT_OUTPUT_KIND_DYNAMIC_LIBRARY,
    Executable = c.GCC_JIT_OUTPUT_KIND_EXECUTABLE,
};

pub const Result = struct {
    res: *c.gcc_jit_result,

    const Self = @This();

    pub fn get_code(self: *Self, function_name: [:0]const u8) !*anyopaque {
        const opaque_ptr = c.gcc_jit_result_get_code(self.res, function_name);
        return opaque_ptr orelse return error.GetCode;
    }

    pub fn get_global(self: *Self, name: [:0]const u8) !*anyopaque {
        const opaque_ptr = c.gcc_jit_result_get_global(self.res, name);
        return opaque_ptr orelse return error.GetGlobal;
    }

    pub fn deinit(self: *Self) void {
        c.gcc_jit_result_release(self.res);
    }
};

pub const Object = struct {
    obj: *c.gcc_jit_object,

    const Self = @This();

    pub fn get_context(self: *Self) !Context {
        const ctx_ptr = c.gcc_jit_object_get_context(self.obj);

        return Context{ .ctx = ctx_ptr orelse return error.GetContext };
    }

    pub fn get_debug_string(self: *Self) ?[:0]const u8 {
        const str = c.gcc_jit_object_get_debug_string(self.obj);
        return std.mem.span(@ptrCast([*:0]const u8, str orelse return null));
    }
};

pub const Location = struct {
    loc: ?*c.gcc_jit_location,

    const Self = @This();

    pub fn as_object(self: *Self) !Object {
        const obj_ptr = c.gcc_jit_location_as_object(self.loc orelse return error.NullLocation);
        return Object{ .obj = obj_ptr orelse return error.LocationAsObject };
    }

    pub fn empty() Self {
        return Self{
            .loc = null,
        };
    }
};

pub const Type = packed struct {
    typ: *c.gcc_jit_type,

    const Self = @This();

    pub fn as_object(self: *Self) !Object {
        const obj_ptr = c.gcc_jit_type_as_object(self.typ);
        return Object{ .obj = obj_ptr orelse return error.TypeAsObject };
    }

    pub fn get_pointer(self: *Self) !Self {
        const ptr_ptr = c.gcc_jit_type_get_pointer(self.typ);
        return Type{ .typ = ptr_ptr orelse return error.GetPointer };
    }

    pub fn get_const(self: *Self) !Self {
        const const_ptr = c.gcc_jit_type_get_const(self.typ);
        return Type{ .typ = const_ptr orelse return error.GetConst };
    }

    pub fn get_volatile(self: *Self) !Self {
        const volatile_ptr = c.gcc_jit_type_get_volatile(self.typ);
        return Type{ .typ = volatile_ptr orelse return error.GetVolatile };
    }

    pub fn compatible_types(self: *Self, rtype: Self) bool {
        comptime assert(@hasDecl(c, "LIBGCCJIT_HAVE_SIZED_INTEGERS"));
        return c.gcc_jit_compatible_types(self.typ, rtype.typ) != 0;
    }

    pub fn get_size(self: *Self) isize {
        comptime assert(@hasDecl(c, "LIBGCCJIT_HAVE_SIZED_INTEGERS"));
        return c.gcc_jit_type_get_size(self.typ);
    }

    pub fn get_aligned(self: *Self, alignment_in_bytes: usize) !Type {
        comptime assert(@hasDecl(c, "LIBGCCJIT_HAVE_gcc_jit_type_get_aligned"));
        const type_ptr = c.gcc_jit_type_get_aligned(self.typ, alignment_in_bytes);
        return Type{ .typ = type_ptr orelse return error.GetAligned };
    }

    pub fn get_vector(self: *Self, number_of_units: usize) !Type {
        comptime assert(@hasDecl(c, "LIBGCCJIT_HAVE_gcc_jit_type_get_vector"));
        const type_ptr = c.gcc_jit_type_get_vector(self.typ, number_of_units);
        return Type{ .typ = type_ptr orelse return error.GetAligned };
    }

    pub fn dynamically_cast_array(self: *Self) !Type {
        comptime assert(@hasDecl(c, "LIBGCCJIT_HAVE_REFLECTION"));
        const type_ptr = c.gcc_jit_type_dyncast_array(self.typ);
        return Type{ .typ = type_ptr orelse return error.DynamicallyCastArray };
    }

    pub fn dynamically_cast_function_pointer_type(self: *Self) !FunctionType {
        comptime assert(@hasDecl(c, "LIBGCCJIT_HAVE_REFLECTION"));
        const type_ptr = c.gcc_jit_type_dyncast_function_ptr_type(self.typ);
        return FunctionType{ .ftp = type_ptr orelse return error.DynamicallyCastFunction };
    }

    pub fn is_bool(self: *Self) bool {
        comptime assert(@hasDecl(c, "LIBGCCJIT_HAVE_REFLECTION"));
        return c.gcc_jit_type_is_bool(self.typ) != 0;
    }

    pub fn is_integral(self: *Self) bool {
        comptime assert(@hasDecl(c, "LIBGCCJIT_HAVE_REFLECTION"));
        return c.gcc_jit_type_is_integral(self.typ) != 0;
    }

    pub fn is_pointer(self: *Self) ?Type {
        comptime assert(@hasDecl(c, "LIBGCCJIT_HAVE_REFLECTION"));
        const type_ptr = c.gcc_jit_type_is_pointer(self.typ);
        return Type{ .typ = type_ptr orelse return null };
    }

    pub fn dynamically_cast_vector(self: *Self) !VectorType {
        comptime assert(@hasDecl(c, "LIBGCCJIT_HAVE_REFLECTION"));
        const type_ptr = c.gcc_jit_type_dyncast_vector(self.typ);
        return VectorType{ .vct = type_ptr orelse return error.DynamicallyCastVector };
    }

    pub fn is_struct(self: *Self) ?Struct {
        comptime assert(@hasDecl(c, "LIBGCCJIT_HAVE_REFLECTION"));
        const struct_ptr = c.gcc_jit_type_is_struct(self.typ);
        return Struct{ .str = struct_ptr orelse return null };
    }

    pub fn unqualified(self: *Self) !Type {
        comptime assert(@hasDecl(c, "LIBGCCJIT_HAVE_REFLECTION"));
        const type_ptr = c.gcc_jit_type_unqualified(self.typ);
        return Type{ .typ = type_ptr orelse return error.Unqualified };
    }
};

pub const Types = enum(c_uint) {
    Void = c.GCC_JIT_TYPE_VOID,
    VoidPtr = c.GCC_JIT_TYPE_VOID_PTR,
    Bool = c.GCC_JIT_TYPE_BOOL,
    Char = c.GCC_JIT_TYPE_CHAR,
    SignedChar = c.GCC_JIT_TYPE_SIGNED_CHAR,
    UnsignedChar = c.GCC_JIT_TYPE_UNSIGNED_CHAR,
    Short = c.GCC_JIT_TYPE_SHORT,
    UnsignedShort = c.GCC_JIT_TYPE_UNSIGNED_SHORT,
    Int = c.GCC_JIT_TYPE_INT,
    UnsignedInt = c.GCC_JIT_TYPE_UNSIGNED_INT,
    Long = c.GCC_JIT_TYPE_LONG,
    UnsignedLong = c.GCC_JIT_TYPE_UNSIGNED_LONG,
    LongLong = c.GCC_JIT_TYPE_LONG_LONG,
    UnsignedLongLong = c.GCC_JIT_TYPE_UNSIGNED_LONG_LONG,
    Float = c.GCC_JIT_TYPE_FLOAT,
    Double = c.GCC_JIT_TYPE_DOUBLE,
    LongDouble = c.GCC_JIT_TYPE_LONG_DOUBLE,
    ConstCharPtr = c.GCC_JIT_TYPE_CONST_CHAR_PTR,
    SizeT = c.GCC_JIT_TYPE_SIZE_T,
    FilePtr = c.GCC_JIT_TYPE_FILE_PTR,
    ComplexFloat = c.GCC_JIT_TYPE_COMPLEX_FLOAT,
    ComplexDouble = c.GCC_JIT_TYPE_COMPLEX_DOUBLE,
    ComplexLongDouble = c.GCC_JIT_TYPE_COMPLEX_LONG_DOUBLE,
    UInt8 = c.GCC_JIT_TYPE_UINT8_T,
    UInt16 = c.GCC_JIT_TYPE_UINT16_T,
    UInt32 = c.GCC_JIT_TYPE_UINT32_T,
    UInt64 = c.GCC_JIT_TYPE_UINT64_T,
    UInt128 = c.GCC_JIT_TYPE_UINT128_T,
    Int8 = c.GCC_JIT_TYPE_INT8_T,
    Int16 = c.GCC_JIT_TYPE_INT16_T,
    Int32 = c.GCC_JIT_TYPE_INT32_T,
    Int64 = c.GCC_JIT_TYPE_INT64_T,
    Int128 = c.GCC_JIT_TYPE_INT128_T,
};

pub const Field = packed struct {
    fie: *c.gcc_jit_field,

    const Self = @This();

    pub fn as_object(self: *Self) !Object {
        const obj_ptr = c.gcc_jit_field_as_object(self.fie);
        return Object{ .obj = obj_ptr orelse return error.FieldAsObject };
    }
};

pub const Struct = struct {
    str: *c.gcc_jit_struct,

    const Self = @This();

    pub fn as_type(self: *Self) !Type {
        const type_ptr = c.gcc_jit_struct_as_type(self.str);
        return Type{ .typ = type_ptr orelse return error.StructAsType };
    }

    pub fn set_fields(self: *Self, location: Location, fields: []align(8) Field) void {
        //TODO: check if this works, but it should
        const num_fields = @intCast(c_int, fields.len);
        const fields_ptr = @ptrCast([*c]?*c.gcc_jit_field, fields.ptr);

        c.gcc_jit_struct_set_fields(self.str, location.loc, num_fields, fields_ptr);
    }

    pub fn get_field(self: *Self, index: usize) !Field {
        const field_ptr = c.gcc_jit_struct_get_field(self.str, index);
        return Field{ .fie = field_ptr orelse return error.GetField };
    }

    pub fn get_field_count(self: *Self) usize {
        return c.gcc_jit_struct_get_field_count(self.str);
    }
};

pub const FunctionKind = enum(c_uint) {
    Exported = c.GCC_JIT_FUNCTION_EXPORTED,
    Internal = c.GCC_JIT_FUNCTION_INTERNAL,
    Imported = c.GCC_JIT_FUNCTION_IMPORTED,
    AlwaysInline = c.GCC_JIT_FUNCTION_ALWAYS_INLINE,
};

pub const ThredLocalStorageModel = enum(c_uint) {
    None = c.GCC_JIT_TLS_MODEL_NONE,
    GlobalDynamic = c.GCC_JIT_TLS_MODEL_GLOBAL_DYNAMIC,
    LocalDynamic = c.GCC_JIT_TLS_MODEL_LOCAL_DYNAMIC,
    InitialExec = c.GCC_JIT_TLS_MODEL_INITIAL_EXEC,
    LocalExec = c.GCC_JIT_TLS_MODEL_LOCAL_EXEC,
};

pub const FunctionType = struct {
    ftp: *c.gcc_jit_function_type,

    const Self = @This();

    pub fn get_return_type(self: *Self) !Type {
        comptime assert(@hasDecl(c, "LIBGCCJIT_HAVE_REFLECTION"));
        const type_ptr = c.gcc_jit_function_type_get_return_type(self.ftp);
        return Type{ .typ = type_ptr orelse return error.GetReturnType };
    }

    pub fn get_parameter_count(self: *Self) usize {
        comptime assert(@hasDecl(c, "LIBGCCJIT_HAVE_REFLECTION"));
        return c.gcc_jit_function_type_get_param_count(self.ftp);
    }

    pub fn get_parameter_type(self: *Self, index: usize) !Type {
        comptime assert(@hasDecl(c, "LIBGCCJIT_HAVE_REFLECTION"));
        const type_ptr = c.gcc_jit_function_type_get_param_type(self.ftp, index);
        return Type{ .typ = type_ptr orelse return error.GetParameterType };
    }
};

pub const VectorType = struct {
    vct: *c.gcc_jit_vector_type,

    const Self = @This();

    pub fn get_number_of_units(self: *Self) usize {
        comptime assert(@hasDecl(c, "LIBGCCJIT_HAVE_REFLECTION"));
        return c.gcc_jit_vector_type_get_num_units(self.vct);
    }

    pub fn get_element_type(self: *Self) !Type {
        comptime assert(@hasDecl(c, "LIBGCCJIT_HAVE_REFLECTION"));
        const type_ptr = c.gcc_jit_vector_type_get_element_type(self.vct);
        return Type{ .typ = type_ptr orelse return error.GetElementType };
    }
};

pub const Function = struct {
    fun: *c.gcc_jit_function,

    const Self = @This();

    pub fn as_object(self: *Self) !Object {
        const obj_ptr = c.gcc_jit_function_as_object(self.fun);
        return Object{ .obj = obj_ptr orelse return error.FunctionAsObject };
    }

    pub fn get_parameter(self: *Self, index: c_int) !Parameter {
        const param_ptr = c.gcc_jit_function_get_param(self.fun, index);
        return Parameter{ .prm = param_ptr orelse return error.GetParameter };
    }

    pub fn to_dot(self: *Self, path: [:0]const u8) void {
        c.gcc_jit_function_dump_to_dot(self.fun, path);
    }

    pub fn new_block(self: *Self, name: [:0]const u8) !Block {
        const blk_ptr = c.gcc_jit_function_new_block(self.fun, name);
        return Block{ .blk = blk_ptr orelse return error.CreateBlock };
    }

    pub fn new_local(self: Self, location: Location, local_type: Type, name: [:0]const u8) !LValue {
        const lva_ptr = c.gcc_jit_function_new_local(self.fun, location.loc, local_type.typ, name);
        return LValue{ .lva = lva_ptr orelse return error.CreateLocal };
    }

    pub fn get_address(self: *Self, location: Location) !RValue {
        comptime assert(@hasDecl(c, "LIBGCCJIT_HAVE_gcc_jit_function_get_address"));
        const rva_ptr = c.gcc_jit_function_get_address(self.fun, location.loc);
        return RValue{ .rva = rva_ptr orelse return error.GetAddress };
    }

    pub fn get_return_type(self: *Self) !Type {
        comptime assert(@hasDecl(c, "LIBGCCJIT_HAVE_REFLECTION"));
        const type_ptr = c.gcc_jit_function_get_return_type(self.fun);
        return Type{ .typ = type_ptr orelse return error.GetReturnType };
    }

    pub fn get_parameter_count(self: *Self) usize {
        comptime assert(@hasDecl(c, "LIBGCCJIT_HAVE_REFLECTION"));
        return c.gcc_jit_function_get_param_count(self.fun);
    }
};

pub const Block = struct {
    blk: *c.gcc_jit_block,

    const Self = @This();

    pub fn as_object(self: *Self) !Object {
        const obj_ptr = c.gcc_jit_block_as_object(self.blk);
        return Object{ .obj = obj_ptr orelse return error.BlockAsObject };
    }

    pub fn get_function(self: *Self) !Function {
        const fun_ptr = c.gcc_jit_block_get_function(self.blk);
        return Function{ .fun = fun_ptr orelse return error.GetFunction };
    }

    pub fn add_evaluation(self: *Self, location: Location, rvalue: RValue) void {
        c.gcc_jit_block_add_eval(self.blk, location.loc, rvalue.rva);
    }

    pub fn add_assignment(self: *Self, location: Location, lvalue: LValue, rvalue: RValue) void {
        c.gcc_jit_block_add_assignment(self.blk, location.loc, lvalue.lva, rvalue.rva);
    }

    pub fn add_assignment_op(self: *Self, location: Location, lvalue: LValue, binary_operation: BinaryOperation, rvalue: RValue) void {
        c.gcc_jit_block_add_assignment_op(self.blk, location.loc, lvalue.lva, @enumToInt(binary_operation), rvalue.rva);
    }

    pub fn add_comment(self: *Self, location: Location, text: [:0]const u8) void {
        c.gcc_jit_block_add_comment(self.blk, location.loc, text);
    }

    pub fn end_with_conditional(self: *Self, location: Location, boolean_value: RValue, on_true: Self, on_false: Self) void {
        c.gcc_jit_block_end_with_conditional(self.blk, location.loc, boolean_value.rva, on_true.blk, on_false.blk);
    }

    pub fn end_with_jump(self: *Self, location: Location, target: Self) void {
        c.gcc_jit_block_end_with_jump(self.blk, location.loc, target.blk);
    }

    pub fn end_with_return(self: *Self, location: Location, rvalue: RValue) void {
        c.gcc_jit_block_end_with_return(self.blk, location.loc, rvalue.rva);
    }

    pub fn end_with_void_return(self: *Self, location: Location) void {
        c.gcc_jit_block_end_with_void_return(self.blk, location.loc);
    }

    /// comment
    pub fn end_with_switch(self: *Self, location: Location, expression: RValue, default_block: Self, cases: []align(8) Case) void {
        comptime assert(@hasDecl(c, "LIBGCCJIT_HAVE_SWITCH_STATEMENTS"));

        //TODO: check if this works, but it should
        const num_cases = @intCast(c_int, cases.len);
        const cases_ptr = @ptrCast([*c]?*c.gcc_jit_case, cases.ptr);

        c.gcc_jit_block_end_with_switch(self.blk, location.loc, expression.rva, default_block.blk, num_cases, cases_ptr);
    }

    pub fn add_extended_assembly(self: *Self, location: Location, assembly_template: [:0]const u8) !ExtendedAssembly {
        comptime assert(@hasDecl(c, "LIBGCCJIT_HAVE_ASM_STATEMENTS"));
        const asm_ptr = c.gcc_jit_block_add_extended_asm(self.blk, location.loc, assembly_template);
        return ExtendedAssembly{ .amb = asm_ptr orelse return error.AddExtendedAssembly };
    }

    pub fn end_with_extended_assembly_goto(self: *Self, location: Location, assembly_template: [:0]const u8, goto_blocks: []align(8) Self, fallthrough_block: Self) !ExtendedAssembly {
        comptime assert(@hasDecl(c, "LIBGCCJIT_HAVE_ASM_STATEMENTS"));

        //TODO: check if this works, but it should
        const num_goto_blocks = @intCast(c_int, goto_blocks.len);
        const goto_blocks_ptr = @ptrCast([*c]?*c.gcc_jit_block, goto_blocks.ptr);

        const asm_ptr = c.gcc_jit_block_end_with_extended_asm_goto(self.blk, location.loc, assembly_template, num_goto_blocks, goto_blocks_ptr, fallthrough_block.blk);
        return ExtendedAssembly{ .amb = asm_ptr orelse return error.EndWithExtendedAssembly };
    }
};

pub const GlobalKind = enum(c_uint) {
    Exported = c.GCC_JIT_GLOBAL_EXPORTED,
    Internal = c.GCC_JIT_GLOBAL_INTERNAL,
    Imported = c.GCC_JIT_GLOBAL_IMPORTED,
};

pub const RValue = packed struct {
    rva: *c.gcc_jit_rvalue,

    const Self = @This();

    pub fn as_object(self: *Self) !Object {
        const obj_ptr = c.gcc_jit_rvalue_as_object(self.rva);
        return Object{ .obj = obj_ptr orelse return error.RValueAsObject };
    }

    pub fn get_type(self: *Self) !Type {
        const type_ptr = c.gcc_jit_rvalue_get_type(self.rva);
        return Type{ .typ = type_ptr orelse return error.GetType };
    }

    pub fn access_field(self: *Self, location: Location, field: Field) !RValue {
        const rva_ptr = c.gcc_jit_rvalue_access_field(self.rva, location.loc, field.fie);
        return RValue{ .rva = rva_ptr orelse return error.AccessField };
    }

    pub fn dereference_field(self: *Self, location: Location, field: Field) !LValue {
        const lva_ptr = c.gcc_jit_rvalue_dereference_field(self.rva, location.loc, field.fie);
        return LValue{ .lva = lva_ptr orelse return error.DereferenceField };
    }

    pub fn dereference(self: *Self, location: Location) !LValue {
        const lva_ptr = c.gcc_jit_rvalue_dereference(self.rva, location.loc);
        return LValue{ .lva = lva_ptr orelse return error.Dereference };
    }

    pub fn set_require_tail_call(self: *Self, require_tail_call: bool) void {
        comptime assert(@hasDecl(c, "LIBGCCJIT_HAVE_gcc_jit_rvalue_set_bool_require_tail_call"));
        c.gcc_jit_rvalue_set_bool_require_tail_call(self.rva, @boolToInt(require_tail_call));
    }
};

pub const LValue = struct {
    lva: *c.gcc_jit_lvalue,

    const Self = @This();

    pub fn set_initializer_rvalue(self: *Self, init_value: RValue) !void {
        comptime assert(@hasDecl(c, "LIBGCCJIT_HAVE_CTORS"));
        _ = c.gcc_jit_global_set_initializer_rvalue(self.lva, init_value.rva) orelse return error.SetInitilializerRValue;
        return;
    }

    pub fn set_initializer(self: *Self, blob: *anyopaque, number_of_bytes: usize) !void {
        comptime assert(@hasDecl(c, "LIBGCCJIT_HAVE_gcc_jit_global_set_initializer"));
        _ = c.gcc_jit_global_set_initializer(self.lva, blob, number_of_bytes) orelse return error.SetInitilializer;
        return;
    }

    pub fn as_object(self: *Self) !Object {
        const obj_ptr = c.gcc_jit_lvalue_as_object(self.lva);
        return Object{ .obj = obj_ptr orelse return error.LValueAsObject };
    }

    pub fn as_rvalue(self: *Self) !RValue {
        const rva_ptr = c.gcc_jit_lvalue_as_rvalue(self.lva);
        return RValue{ .rva = rva_ptr orelse return error.LValueAsRValue };
    }

    pub fn set_alignment(self: *Self, bytes: c_uint) void {
        comptime assert(@hasDecl(c, "LIBGCCJIT_HAVE_ALIGNMENT"));
        c.gcc_jit_lvalue_set_alignment(self.lva, bytes);
    }

    pub fn get_alignment(self: *Self) c_uint {
        comptime assert(@hasDecl(c, "LIBGCCJIT_HAVE_ALIGNMENT"));
        return c.gcc_jit_lvalue_get_alignment(self.lva);
    }

    pub fn access_field(self: *Self, location: Location, field: Field) !LValue {
        const lva_ptr = c.gcc_jit_lvalue_access_field(self.lva, location.loc, field.fie);
        return LValue{ .lva = lva_ptr orelse return error.AccessField };
    }

    pub fn get_address(self: *Self, location: Location) !RValue {
        const rva_ptr = c.gcc_jit_lvalue_get_address(self.lva, location.loc);
        return RValue{ .rva = rva_ptr orelse return error.GetAddress };
    }

    pub fn set_tls_model(self: *Self, model: ThredLocalStorageModel) void {
        comptime assert(@hasDecl(c, "LIBGCCJIT_HAVE_gcc_jit_lvalue_set_tls_model"));
        c.gcc_jit_lvalue_set_tls_model(self.lva, @enumToInt(model));
    }

    pub fn set_link_section(self: *Self, section_name: [:0]const u8) void {
        comptime assert(@hasDecl(c, "LIBGCCJIT_HAVE_gcc_jit_lvalue_set_link_section"));
        c.gcc_jit_lvalue_set_link_section(self.lva, section_name);
    }

    fn set_register_name(self: *Self, register_name: [:0]const u8) void {
        comptime assert(@hasDecl(c, "LIBGCCJIT_HAVE_gcc_jit_lvalue_set_register_name"));
        c.gcc_jit_lvalue_set_register_name(self.lva, register_name);
    }
};

pub const Parameter = struct {
    prm: *c.gcc_jit_param,

    const Self = @This();

    pub fn as_object(self: *Self) !Object {
        const obj_ptr = c.gcc_jit_param_as_object(self.prm);

        return Object{ .obj = obj_ptr orelse return error.ParameterAsObject };
    }

    pub fn as_lvalue(self: *Self) !LValue {
        const lva_ptr = c.gcc_jit_param_as_lvalue(self.prm);

        return LValue{ .lva = lva_ptr orelse return error.ParameterAsLValue };
    }

    pub fn as_rvalue(self: *Self) !RValue {
        const rva_ptr = c.gcc_jit_param_as_rvalue(self.prm);
        return RValue{ .rva = rva_ptr orelse return error.ParameterAsRValue };
    }
};

pub const UnaryOperation = enum(c_uint) {
    Minus = c.GCC_JIT_UNARY_OP_MINUS,
    BitwiseNegate = c.GCC_JIT_UNARY_OP_BITWISE_NEGATE,
    LogicalNegate = c.GCC_JIT_UNARY_OP_LOGICAL_NEGATE,
    Abs = c.GCC_JIT_UNARY_OP_ABS,
};

pub const BinaryOperation = enum(c_uint) {
    Plus = c.GCC_JIT_BINARY_OP_PLUS,
    Minus = c.GCC_JIT_BINARY_OP_MINUS,
    Mult = c.GCC_JIT_BINARY_OP_MULT,
    Divide = c.GCC_JIT_BINARY_OP_DIVIDE,
    Modulo = c.GCC_JIT_BINARY_OP_MODULO,
    BitwiseAnd = c.GCC_JIT_BINARY_OP_BITWISE_AND,
    BitwiseXor = c.GCC_JIT_BINARY_OP_BITWISE_XOR,
    BitwiseOr = c.GCC_JIT_BINARY_OP_BITWISE_OR,
    LogicalAnd = c.GCC_JIT_BINARY_OP_LOGICAL_AND,
    LogicalOr = c.GCC_JIT_BINARY_OP_LOGICAL_OR,
    LeftShift = c.GCC_JIT_BINARY_OP_LSHIFT,
    RightShift = c.GCC_JIT_BINARY_OP_RSHIFT,
};

pub const Comparison = enum(c_uint) {
    Eq = c.GCC_JIT_COMPARISON_EQ,
    Ne = c.GCC_JIT_COMPARISON_NE,
    Lt = c.GCC_JIT_COMPARISON_LT,
    Le = c.GCC_JIT_COMPARISON_LE,
    Gt = c.GCC_JIT_COMPARISON_GT,
    Ge = c.GCC_JIT_COMPARISON_GE,
};

pub const Case = packed struct {
    cas: *c.gcc_jit_case,

    const Self = @This();

    pub fn as_object(self: *Self) !Object {
        comptime assert(@hasDecl(c, "LIBGCCJIT_HAVE_SWITCH_STATEMENTS"));
        const obj_ptr = c.gcc_jit_case_as_object(self.cas);
        return Object{ .obj = obj_ptr orelse return error.CaseAsObject };
    }
};

pub const Timer = struct {
    tmr: *c.gcc_jit_timer,

    const Self = @This();

    pub fn init() !Self {
        comptime assert(@hasDecl(c, "LIBGCCJIT_HAVE_TIMING_API"));
        const timer_ptr = c.gcc_jit_timer_new();
        return Self{ .tmr = timer_ptr orelse return error.CreateTimer };
    }

    pub fn deinit(self: *Self) void {
        comptime assert(@hasDecl(c, "LIBGCCJIT_HAVE_TIMING_API"));
        c.gcc_jit_timer_release(self.tmr);
    }

    pub fn push(self: *Self, item_name: [:0]const u8) void {
        comptime assert(@hasDecl(c, "LIBGCCJIT_HAVE_TIMING_API"));
        c.gcc_jit_timer_push(self.tmr, item_name);
    }

    pub fn pop(self: *Self, item_name: [:0]const u8) void {
        comptime assert(@hasDecl(c, "LIBGCCJIT_HAVE_TIMING_API"));
        c.gcc_jit_timer_pop(self.tmr, item_name);
    }

    pub fn print(self: *Self, out: *align(8) std.c.FILE) void {
        comptime assert(@hasDecl(c, "LIBGCCJIT_HAVE_TIMING_API"));
        c.gcc_jit_timer_print(self.tmr, @ptrCast([*c]c.struct__IO_FILE, out));
    }
};

pub fn version_major() c_int {
    comptime assert(@hasDecl(c, "LIBGCCJIT_HAVE_gcc_jit_version"));
    return c.gcc_jit_version_major();
}

pub fn version_minor() c_int {
    comptime assert(@hasDecl(c, "LIBGCCJIT_HAVE_gcc_jit_version"));
    return c.gcc_jit_version_minor();
}

pub fn version_patchlevel() c_int {
    comptime assert(@hasDecl(c, "LIBGCCJIT_HAVE_gcc_jit_version"));
    return c.gcc_jit_version_patchlevel();
}

pub const ExtendedAssembly = struct {
    amb: *c.gcc_jit_extended_asm,

    const Self = @This();

    pub fn as_object(self: *Self) !Object {
        comptime assert(@hasDecl(c, "LIBGCCJIT_HAVE_ASM_STATEMENTS"));
        const obj_ptr = c.gcc_jit_extended_asm_as_object(self.amb);
        return Object{ .obj = obj_ptr orelse return error.ExtendedAssemblyAsObject };
    }

    pub fn set_volatile_flag(self: *Self, flag: bool) void {
        comptime assert(@hasDecl(c, "LIBGCCJIT_HAVE_ASM_STATEMENTS"));
        c.gcc_jit_extended_asm_set_volatile_flag(self.amb, @boolToInt(flag));
    }

    pub fn set_inline_flag(self: *Self, flag: bool) void {
        comptime assert(@hasDecl(c, "LIBGCCJIT_HAVE_ASM_STATEMENTS"));
        c.gcc_jit_extended_asm_set_inline_flag(self.amb, @boolToInt(flag));
    }

    pub fn add_output_operand(self: *Self, assembly_symbolic_name: [:0]const u8, constraint: [:0]const u8, destination: LValue) void {
        comptime assert(@hasDecl(c, "LIBGCCJIT_HAVE_ASM_STATEMENTS"));
        c.gcc_jit_extended_asm_add_output_operand(self.amb, assembly_symbolic_name, constraint, destination.lva);
    }

    pub fn add_input_operand(self: *Self, assembly_symbolic_name: [:0]const u8, constraint: [:0]const u8, source: RValue) void {
        comptime assert(@hasDecl(c, "LIBGCCJIT_HAVE_ASM_STATEMENTS"));
        c.gcc_jit_extended_asm_add_input_operand(self.amb, assembly_symbolic_name, constraint, source.rva);
    }

    pub fn add_clobber(self: *Self, victim: [:0]const u8) void {
        comptime assert(@hasDecl(c, "LIBGCCJIT_HAVE_ASM_STATEMENTS"));
        c.gcc_jit_extended_asm_add_clobber(self.amb, victim);
    }
};
