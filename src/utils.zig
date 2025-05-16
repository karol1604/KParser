const std = @import("std");
const ast = @import("ast.zig");
const checker = @import("checker.zig");

pub fn isDigit(c: u8) bool {
    return c >= '0' and c <= '9';
}

pub fn isAlpha(c: u8) bool {
    return (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z');
}

pub fn isAlphaNumeric(c: u8) bool {
    return isAlpha(c) or isDigit(c);
}

pub fn readFile(allocator: std.mem.Allocator, path: []const u8) ![]u8 {
    const cwd = std.fs.cwd();
    // Open the file for reading
    const file = try cwd.openFile(path, .{ .mode = .read_only });
    defer file.close();

    // Read whole file into a buffer (initial capacity 4 KiB)
    return try file.readToEndAlloc(allocator, 4096);
}

const MAX_DEPTH = 64;

// ********** CHECKED EXPRESSION PRETTY PRINTING *********
pub fn prettyPrintCheckedExpression(expr: checker.CheckedExpression) void {
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
            std.debug.print("IntLiteral {d} (type {d})\n", .{ val, expr.typeId });
        },
        .Identifier => |name| {
            std.debug.print("Identifier {s} (type {d})\n", .{ name, expr.typeId });
        },
        .BoolLiteral => |val| {
            std.debug.print("BoolLiteral {s} (type {d})\n", .{ if (val) "true" else "false", expr.typeId });
        },
        .Unary => |u| {
            const opStr = switch (u.operator) {
                .Plus => "+",
                .Minus => "-",
                .Not => "!",
            };
            std.debug.print("Unary {s} (type {d})\n", .{ opStr, expr.typeId });

            // mark at this depth whether we should draw a
            // vertical bar for deeper siblings
            treeLines[depth] = !isLast;
            // recurse on the single child (always the last one)
            prettyPrintRecCheck(u.right.*, depth + 1, treeLines, true);
        },
        .Binary => |b| {
            const opStr = switch (b.operator) {
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
            std.debug.print("Binary {s} (type {d})\n", .{ opStr, expr.typeId });

            treeLines[depth] = !isLast;
            // left is not last
            prettyPrintRecCheck(b.left.*, depth + 1, treeLines, false);
            // right is last
            prettyPrintRecCheck(b.right.*, depth + 1, treeLines, true);
        },
        .VariableDeclaration => |varDecl| {
            std.debug.print("VariableDecl {s} (type {d})\n", .{ varDecl.name, expr.typeId });
            treeLines[depth] = !isLast;
            prettyPrintRecCheck(varDecl.value.*, depth + 1, treeLines, true);
        },
        .FunctionDeclaration => |decl| {
            std.debug.print("Function (", .{});
            for (decl.parameters.items, 0..) |param, i| {
                std.debug.print("{s}:{d}", .{ param.name, param.typeId });
                if (i != decl.parameters.items.len - 1) std.debug.print(", ", .{});
            }

            std.debug.print(")", .{});
            std.debug.print(" -> {d}\n", .{decl.returnType});
            // std.debug.print("   {d} statements\n", .{decl.body.items.len});
            for (decl.body.items, 0..) |stmt, i| {
                prettyPrintRecCheck(stmt.*.expr.*, depth + 1, treeLines, i == decl.body.items.len - 1);
            }
        },
        .Block => |block| {
            std.debug.print("Block ({d} statements)\n", .{block.items.len});
            for (block.items, 0..) |stmt, i| {
                prettyPrintRecCheck(stmt.*.expr.*, depth + 1, treeLines, i == block.items.len - 1);
            }
        },
        // else => {},
    }
}

// ********* EXPRESSION TREE PRETTY PRINTING *********
pub fn prettyPrintStatement(stmt: ast.Statement) !void {
    try switch (stmt.kind) {
        .ExpressionStatement => |expr| prettyPrintExpression(expr.*),
        .VariableDeclaration => |statement| {
            if (statement.type) |ty| {
                std.debug.print("VariableDecl {s} ({s}) =\n", .{ statement.name, ty });
            } else {
                std.debug.print("VariableDecl {s} =\n", .{statement.name});
            }
            std.debug.print("   ", .{});
            prettyPrintExpression(statement.value.*);
        },
        else => error.NoPrettyPrintForStatementType,
    };
}
/// Pretty prints an expression tree
pub fn prettyPrintExpression(expr: ast.Expression) void {
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
        .FunctionDeclaration => |decl| {
            std.debug.print("Function (", .{});
            for (decl.parameters.items, 0..) |param, i| {
                std.debug.print("{s}:{s}", .{ param.name, param.type });
                if (i != decl.parameters.items.len - 1) std.debug.print(", ", .{});
            }

            std.debug.print(")", .{});
            if (decl.returnType) |ty| {
                std.debug.print(" -> {s}\n", .{ty});
            } else {
                std.debug.print("\n", .{});
            }
            std.debug.print("   {d} statements\n", .{decl.body.items.len});
        },
        .Unary => |u| {
            const opStr = switch (u.operator) {
                .Plus => "+",
                .Minus => "-",
                .Not => "!",
            };
            std.debug.print("Unary {s}\n", .{opStr});

            // mark at this depth whether we should draw a
            // vertical bar for deeper siblings
            treeLines[depth] = !isLast;
            // recurse on the single child (always the last one)
            prettyPrintRec(u.right.*.kind, depth + 1, treeLines, true);
        },
        .Binary => |b| {
            const opStr = switch (b.operator) {
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
            std.debug.print("Binary {s}\n", .{opStr});

            treeLines[depth] = !isLast;
            // left is not last
            prettyPrintRec(b.left.*.kind, depth + 1, treeLines, false);
            // right is last
            prettyPrintRec(b.right.*.kind, depth + 1, treeLines, true);
        },
        .Block => |block| {
            for (block.body.items) |stmt| {
                switch (stmt.*.kind) {
                    .ExpressionStatement => |expr_| {
                        // std.debug.print("   ExpressionStatement\n", .{});
                        // prettyPrintRec(expr_.*.kind, depth + 1, treeLines, true);
                        prettyPrintExpression(expr_.*);
                    },
                    .VariableDeclaration => |varDecl| {
                        // std.debug.print("   VariableDecl {s}\n", .{varDecl.name});
                        // prettyPrintRec(varDecl.value.*.kind, depth + 1, treeLines, true);
                        prettyPrintExpression(varDecl.value.*);
                    },
                    else => {},
                }
            }
        },
        // else => {},
    }
}
