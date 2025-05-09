const std = @import("std");
const ast = @import("ast.zig");

const Statement = ast.Statement;

const Evaluator = struct {
    statements: []*const Statement,

    // pub fn evaluate(self: *Evaluator) !void {
    //     for (self.statements) |stmt_ptr| {
    //         const stmt = stmt_ptr.*;
    //         switch (stmt) {
    //             Statement.ExpressionStatement => |expr_stmt| {
    //                 const expr = expr_stmt.*;
    //             },
    //         }
    //     }
    // }

    // fn evaluate_expression_statement(expr_stmt: Statement.ExpressionStatement) void {}
};
