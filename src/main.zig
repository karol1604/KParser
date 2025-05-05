const std = @import("std");
const token = @import("tokens.zig");
const lexer = @import("lexer.zig");

pub fn main() !void {
    // const tok = token.Token{
    //     .type = .{ .Identifier = "foo" },
    //     .pos = token.Span{ .start = 0, .size = 3 },
    //     .line = 1,
    // };

    var lex = lexer.Lexer.init("123 + 420 - 69 = \n 123456") catch |err| {
        std.debug.print("Error initializing lexer: {}\n", .{err});
        return err;
    };

    lex.tokenize() catch |err| {
        std.debug.print("Error making token: {}\n", .{err});
        return err;
    };

    for (lex.tokens.items) |tok_| {
        std.debug.print("Token: {s} at position {any} on line {d}\n", .{ token.token_type_to_string(tok_.type), tok_.pos, tok_.line });
    }

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
