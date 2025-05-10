const std = @import("std");
const token = @import("tokens.zig");
const lexer = @import("lexer.zig");
const parser = @import("parser.zig");
const ast = @import("ast.zig");
const utils = @import("utils.zig");
const diagnostics = @import("diagnostics.zig");

pub fn main() !void {
    // const tok = token.Token{
    //     .type = .{ .Identifier = "foo" },
    //     .pos = token.Span{ .start = 0, .size = 3 },
    //     .line = 1,
    // };

    // var lex = lexer.Lexer.init("123 + 420 - 69 = \n 123456 a") catch |err| {
    //     std.debug.print("Error initializing lexer: {}\n", .{err});
    //     return err;
    // };
    //
    // lex.tokenize() catch |err| {
    //     std.debug.print("Error making token: {}\n", .{err});
    //     return err;
    // };
    //
    // for (lex.tokens.items) |tok_| {
    //     std.debug.print("Token: {s} at position {any} on line {d}\n", .{ token.token_type_to_string(tok_.type), tok_.pos, tok_.line });
    // }

    std.debug.print("Hello, world!\n", .{});
    // std.debug.print("Token: {s}\n", .{token.token_type_to_string(tok.type)});
    // Prints to stderr (it's a shortcut based on `std.io.getStdErr()`)

    // stdout is for the actual output of your application, for example if you
    // are implementing gzip, then only the compressed bytes should be sent to
    // stdout, not any debugging messages.
    // const stdout_file = std.io.getStdOut().writer();
    // var bw = std.io.bufferedWriter(stdout_file);
    // const stdout = bw.writer();
    //
    //
    // try bw.flush(); // don't forget to flush!
}

test "basic syntax test" {
    const test_alloc = std.testing.allocator;

    const source = "abcdef != 123 + 420 - 69 = 123456 = 1 ==";
    var lex = try lexer.Lexer.init(source, test_alloc);
    defer lex.deinit();
    try lex.tokenize();

    // for (lex.tokens.items) |tok_| {
    //     std.debug.print("Token: {s}\n", .{tok_});
    // }
    const expected_tokens = [_]token.TokenType{
        .{ .Identifier = "abcdef" },
        .NotEqual,
        .{ .IntLiteral = 123 },
        .Plus,
        .{ .IntLiteral = 420 },
        .Minus,
        .{ .IntLiteral = 69 },
        .Equal,
        .{ .IntLiteral = 123456 },
        .Equal,
        .{ .IntLiteral = 1 },
        .DoubleEqual,
        .Eof,
    };

    // std.debug.print("Tokens(\n\t{s}\n):\n", .{source});
    // var actual_tokens: [expected_tokens.len]token.TokenType = undefined;
    // for (lex.tokens.items, 0..) |tok_, i| {
    //     actual_tokens[i] = tok_.type;
    //     std.debug.print("   > {s}\n", .{lex.tokens.items[i]});
    // }

    for (lex.tokens.items, expected_tokens) |actual_token, expected_token| {
        // Use expectEqualDeep for robust comparison, especially with unions/structs
        try std.testing.expectEqualDeep(expected_token, actual_token.type);
        // Optional: Add a print statement if it fails to see which index
    }
}

test "actual syntax test" {
    const test_alloc = std.testing.allocator;

    const source = "const a = 123 + 420 - 69;\na == 1 && b == 2;\nfalse";
    var lex = try lexer.Lexer.init(source, test_alloc);
    defer lex.deinit();
    try lex.tokenize();

    const expected_tokens = [_]token.TokenType{
        .{ .Identifier = "const" },
        .{ .Identifier = "a" },
        .Equal,
        .{ .IntLiteral = 123 },
        .Plus,
        .{ .IntLiteral = 420 },
        .Minus,
        .{ .IntLiteral = 69 },
        .Semicolon,
        .{ .Identifier = "a" },
        .DoubleEqual,
        .{ .IntLiteral = 1 },
        .DoubleAmpersand,
        .{ .Identifier = "b" },
        .DoubleEqual,
        .{ .IntLiteral = 2 },
        .Semicolon,
        .False,
        .Eof,
    };

    std.debug.print("Tokens(\n{s}\n):\n", .{source});
    for (lex.tokens.items, 0..) |_, i| {
        std.debug.print("   > {s}\n", .{lex.tokens.items[i]});
    }

    // var actual_tokens: [expected_tokens.len]token.TokenType = undefined;
    // for (lex.tokens.items, 0..) |tok_, i| {
    //     actual_tokens[i] = tok_.type;
    //     std.debug.print("   > {s}\n", .{lex.tokens.items[i]});
    // }

    for (lex.tokens.items, expected_tokens) |actual_token, expected_token| {
        try std.testing.expectEqualDeep(expected_token, actual_token.type);
    }
}
//
// test "error test" {
//     const test_alloc = std.testing.allocator;
//
//     const source = "const a = 123 + 420 - 69;\na == 1 && b == 2;";
//     var lex = try lexer.Lexer.init(source, test_alloc);
//     defer lex.deinit();
//     try lex.tokenize();
//
//     const res = lex.dummy(12);
//
//     switch (res) {
//         .ok => {},
//         .err => |err| {
//             std.debug.print("{}\n", .{err});
//         },
//     }
// }
//
test "parse int literal" {
    const test_alloc = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(test_alloc);
    defer arena.deinit();
    const arena_alloc = arena.allocator();

    const diagnostics_list = std.ArrayList(diagnostics.Diagnostic).init(arena_alloc);

    // const source = "(5 + 3 * (10 - 2) / 4 == 7) && (9 >= 8 || 6 < 5)";
    // const source = "2 ^ 3 ^ 4";
    const source = "let a = 2";

    var lex = try lexer.Lexer.init(source, arena_alloc);
    defer lex.deinit();
    try lex.tokenize();

    var p = parser.Parser.init(lex.tokens.items, arena_alloc, @constCast(&diagnostics_list));
    const t = try p.parse();
    defer t.deinit();

    std.debug.print("LEN: {d}\n", .{diagnostics_list.items.len});
    if (diagnostics_list.items.len > 0) {
        std.debug.print("Diagnostics:\n", .{});
        for (diagnostics_list.items) |diag| {
            std.debug.print("  >>>>>> {any}\n", .{diag});
        }
    }

    std.debug.print("\n{any}\n", .{t.items[0].*.span});

    std.debug.print("Statements for {s}:\n", .{source});
    std.debug.print("---------\n", .{});

    for (t.items) |item| {
        std.debug.print("   ", .{});
        try utils.pretty_print_statement(item.*);
        std.debug.print("---------\n", .{});
    }
}
