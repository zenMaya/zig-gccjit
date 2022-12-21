const std = @import("std");
const gccjit = @import("gccjit.zig");

test "Compile all definitions" {
    std.testing.refAllDecls(gccjit);
    std.testing.refAllDecls(gccjit.Context);
    std.testing.refAllDecls(gccjit.Result);
    std.testing.refAllDecls(gccjit.Object);
    std.testing.refAllDecls(gccjit.Location);
    std.testing.refAllDecls(gccjit.Type);
    std.testing.refAllDecls(gccjit.Field);
    std.testing.refAllDecls(gccjit.Struct);
    std.testing.refAllDecls(gccjit.FunctionType);
    std.testing.refAllDecls(gccjit.VectorType);
    std.testing.refAllDecls(gccjit.Function);
    std.testing.refAllDecls(gccjit.Block);
    std.testing.refAllDecls(gccjit.RValue);
    std.testing.refAllDecls(gccjit.LValue);
    std.testing.refAllDecls(gccjit.Parameter);
    std.testing.refAllDecls(gccjit.Case);
    std.testing.refAllDecls(gccjit.Timer);
    std.testing.refAllDecls(gccjit.ExtendedAssembly);
}

test "create a global" {
    var context = try gccjit.Context.init(.{});
    const tp = try context.get_type(gccjit.Types.UInt8);
    const idk = try context.new_global(.{ .loc = null }, gccjit.GlobalKind.Internal, tp, "test");
    _ = idk;
    std.debug.print("Context: {}\n", .{context});
    context.deinit();
}

test "init context and free it" {
    var ctx = try gccjit.Context.init(.{});
    ctx.deinit();
}
