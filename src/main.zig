const std = @import("std");
const token = @import("tokens.zig");
const lexer = @import("lexer.zig");

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

    const source = "abcdef != 123 + 420 - 69 = \n 123456= 1 ==";
    var lex = try lexer.Lexer.init(source, test_alloc);
    defer lex.deinit();
    try lex.tokenize();

    std.debug.print("tok: {any}\n", .{lex.tokens.items[0]});

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

    var actual_tokens: [expected_tokens.len]token.TokenType = undefined;
    for (lex.tokens.items, 0..) |tok_, i| {
        actual_tokens[i] = tok_.type;
    }

    // try std.testing.expectEqual(expected_tokens, actual_tokens);
    for (lex.tokens.items, expected_tokens) |actual_token, expected_token| {
        // Use expectEqualDeep for robust comparison, especially with unions/structs
        try std.testing.expectEqualDeep(expected_token, actual_token.type);
        // Optional: Add a print statement if it fails to see which index
        // if (!std.meta.eql(expected_token.type, actual_token.type)) {
        //     std.debug.print("Mismatch at index {d}: expected {any}, got {any}\n", .{i, expected_token.type, actual_token.type});
        //     try std.testing.expectEqualDeep(expected_token.type, actual_token.type); // Assert again to get Zig's detailed error
        // }

        // You could also test pos and line here if desired
        // try std.testing.expectEqual(expected_token.pos, actual_token.pos);
        // try std.testing.expectEqual(expected_token.line, actual_token.line);
    }
}
