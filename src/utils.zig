const std = @import("std");
const ast = @import("ast.zig");

pub fn is_digit(c: u8) bool {
    return c >= '0' and c <= '9';
}

pub fn is_alpha(c: u8) bool {
    return (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z');
}

pub fn is_alpha_numeric(c: u8) bool {
    return is_alpha(c) or is_digit(c);
}

pub fn deinit_expression_tree(alloc: std.mem.Allocator, root_expr: *ast.Expression) void {
    switch (root_expr.*) {
        .IntLiteral => {}, // No children to deallocate
        .Identifier => {}, // No children to deallocate
        .Unary => |unary_expr| {
            // std.debug.panic(">>>>>>>>>>>> {any}\n", .{unary_expr});
            // Assuming 'epxression' is a typo and should be 'expression'
            deinit_expression_tree(alloc, @constCast(unary_expr.epxression));
        },
        .Binary => |*binary_expr| {
            // Need to cast away const for deallocation if you are sure
            // these pointers are uniquely owned and being destroyed.
            // A better design might be to have *Expression for children
            // if they are to be deallocated this way.
            deinit_expression_tree(alloc, @constCast(binary_expr.left));
            deinit_expression_tree(alloc, @constCast(binary_expr.right));
        },
    }
    alloc.destroy(root_expr);
}
