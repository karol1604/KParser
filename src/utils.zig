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

// we probably don't need this function
/// Recursively deinits an epxression tree
pub fn deinit_expression_tree(alloc: std.mem.Allocator, root_expr: *ast.Expression) void {
    switch (root_expr.*) {
        .IntLiteral => {}, // No children to deallocate
        .Identifier => {}, // No children to deallocate
        .Unary => |*unary_expr| {
            // std.debug.panic(">>>>>>>>>>>> {any}\n", .{unary_expr});
            // Assuming 'epxression' is a typo and should be 'expression'
            deinit_expression_tree(alloc, @constCast(unary_expr.epxression));
        },
        .Binary => |*binary_expr| {
            std.debug.print(">>>>>>>>>>>>>>>>> Deinit binary\n", .{});
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

/// Pretty prints an expression tree
pub fn pretty_print_expression(root: ast.Expression) void {
    prettyPrint(root, 0);
}

fn prettyPrint(expr: ast.Expression, indent: usize) void {
    // └──
    // ├──
    // │
    //
    // 1) Print indentation
    var i: usize = 0;
    while (i < indent) : (i += 1) {
        std.debug.print("  ", .{});
    }

    // 2) Print the node kind + any immediate value/operator
    switch (expr) {
        .IntLiteral => |val| {
            std.debug.print("IntLiteral {d}\n", .{val});
        },
        .Identifier => |name| {
            std.debug.print("Identifier {s}\n", .{name});
        },
        .Unary => |u| {
            const op_str = switch (u.operator) {
                .Plus => "+",
                .Minus => "-",
                .Not => "!",
            };
            std.debug.print("Unary {s}\n", .{op_str});
            // recurse on the single child
            prettyPrint(u.epxression.*, indent + 1);
        },
        .Binary => |b| {
            const op_str = switch (b.operator) {
                .Plus => "+",
                .Minus => "-",
                .Divide => "/",
                .Multiply => "*",
                .Exponent => "^",

                .Equal => "==",
                .NotEqual => "!=",
                .LessThan => "<",
                .GreaterThan => ">",
                .LessThanOrEqual => "<=",
                .GreaterThanOrEqual => ">=",

                .LogicalOr => "||",
                .LogicalAnd => "&&",
            };
            std.debug.print("Binary {s}\n", .{op_str});
            // recurse on LHS and RHS
            prettyPrint(b.left.*, indent + 1);
            prettyPrint(b.right.*, indent + 1);
        },
    }
}
