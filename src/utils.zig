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
// pub fn deinit_expression_tree(alloc: std.mem.Allocator, root_expr: *ast.Expression) void {
//     switch (root_expr.*) {
//         .IntLiteral => {}, // No children to deallocate
//         .Identifier => {}, // No children to deallocate
//         .Unary => |*unary_expr| {
//             // std.debug.panic(">>>>>>>>>>>> {any}\n", .{unary_expr});
//             // Assuming 'epxression' is a typo and should be 'expression'
//             deinit_expression_tree(alloc, @constCast(unary_expr.epxression));
//         },
//         .Binary => |*binary_expr| {
//             std.debug.print(">>>>>>>>>>>>>>>>> Deinit binary\n", .{});
//             // Need to cast away const for deallocation if you are sure
//             // these pointers are uniquely owned and being destroyed.
//             // A better design might be to have *Expression for children
//             // if they are to be deallocated this way.
//             deinit_expression_tree(alloc, @constCast(binary_expr.left));
//             deinit_expression_tree(alloc, @constCast(binary_expr.right));
//         },
//     }
//     alloc.destroy(root_expr);
// }

const MAX_DEPTH = 64;

/// Pretty prints an expression tree
pub fn pretty_print_expression(expr: ast.Expression) void {
    var treeLines: [MAX_DEPTH]bool = undefined;
    prettyPrintRec(expr, 0, &treeLines, true);
}

fn prettyPrintRec(
    expr: ast.Expression,
    depth: usize,
    treeLines: *[MAX_DEPTH]bool,
    isLast: bool,
) void {
    // 1) Print the indentation bars for all ancestor levels
    if (depth > 0) {
        // we only loop up to depth-1, because the last indent
        // slot is for the branch itself
        for (0..depth) |i| {
            if (treeLines[i]) {
                std.debug.print("│   ", .{});
            } else {
                std.debug.print("    ", .{});
            }
        }
        // 2) Print the branch
        if (isLast) std.debug.print("└── ", .{}) else std.debug.print("├── ", .{});
    }

    // 3) Print this node
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

            // mark at this depth whether we should draw a
            // vertical bar for deeper siblings
            treeLines[depth] = !isLast;
            // recurse on the single child (always the last one)
            prettyPrintRec(u.right.*, depth + 1, treeLines, true);
        },
        .Binary => |b| {
            const op_str = switch (b.operator) {
                .Plus => "+",
                .Minus => "-",
                .Multiply => "*",
                .Divide => "/",
                .Exponent => "^",
                .Equal => "==",
                .NotEqual => "!=",
                .LessThan => "<",
                .GreaterThan => ">",
                .LessThanOrEqual => "<=",
                .GreaterThanOrEqual => ">=",
                .LogicalAnd => "&&",
                .LogicalOr => "||",
            };
            std.debug.print("Binary {s}\n", .{op_str});

            treeLines[depth] = !isLast;
            // left is not last
            prettyPrintRec(b.left.*, depth + 1, treeLines, false);
            // right is last
            prettyPrintRec(b.right.*, depth + 1, treeLines, true);
        },
    }
}
