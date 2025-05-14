const std = @import("std");
const ast = @import("ast.zig");
const checker = @import("checker.zig");

pub fn is_digit(c: u8) bool {
    return c >= '0' and c <= '9';
}

pub fn is_alpha(c: u8) bool {
    return (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z');
}

pub fn is_alpha_numeric(c: u8) bool {
    return is_alpha(c) or is_digit(c);
}

const MAX_DEPTH = 64;

// ********** CHECKED EXPRESSION PRETTY PRINTING *********
pub fn pretty_print_checked_expression(expr: checker.CheckedExpression) void {
    var treeLines: [MAX_DEPTH]bool = undefined;
    prettyPrintRecCheck(expr, 0, &treeLines, true);
}

fn prettyPrintRecCheck(
    expr: checker.CheckedExpression,
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
    switch (expr.data) {
        .IntLiteral => |val| {
            std.debug.print("IntLiteral {d} (type {d})\n", .{ val, expr.type_id });
        },
        .Identifier => |name| {
            std.debug.print("Identifier {s}\n", .{name});
        },
        .BoolLiteral => |val| {
            std.debug.print("BoolLiteral {s} (type {d})\n", .{ if (val) "true" else "false", expr.type_id });
        },
        .Unary => |u| {
            const op_str = switch (u.operator) {
                .Plus => "+",
                .Minus => "-",
                .Not => "!",
            };
            std.debug.print("Unary {s} (type {d})\n", .{ op_str, expr.type_id });

            // mark at this depth whether we should draw a
            // vertical bar for deeper siblings
            treeLines[depth] = !isLast;
            // recurse on the single child (always the last one)
            prettyPrintRecCheck(u.right.*, depth + 1, treeLines, true);
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
            std.debug.print("Binary {s} (type {d})\n", .{ op_str, expr.type_id });

            treeLines[depth] = !isLast;
            // left is not last
            prettyPrintRecCheck(b.left.*, depth + 1, treeLines, false);
            // right is last
            prettyPrintRecCheck(b.right.*, depth + 1, treeLines, true);
        },
    }
}

// ********* EXPRESSION TREE PRETTY PRINTING *********
pub fn pretty_print_statement(stmt: ast.Statement) !void {
    try switch (stmt.kind) {
        .ExpressionStatement => |expr| pretty_print_expression(expr.*),
        .LetStatement => |statement| {
            std.debug.print("LetStatement {s} =\n", .{statement.name});
            std.debug.print("   ", .{});
            pretty_print_expression(statement.value.*);
        },
        else => error.NoPrettyPrintForStatementType,
    };
}
/// Pretty prints an expression tree
pub fn pretty_print_expression(expr: ast.Expression) void {
    var treeLines: [MAX_DEPTH]bool = undefined;
    prettyPrintRec(expr.kind, 0, &treeLines, true);
}

fn prettyPrintRec(
    expr: ast.ExpressionKind,
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
        .BoolLiteral => |val| {
            std.debug.print("BoolLiteral {s}\n", .{if (val) "true" else "false"});
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
            prettyPrintRec(u.right.*.kind, depth + 1, treeLines, true);
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
            prettyPrintRec(b.left.*.kind, depth + 1, treeLines, false);
            // right is last
            prettyPrintRec(b.right.*.kind, depth + 1, treeLines, true);
        },
    }
}
