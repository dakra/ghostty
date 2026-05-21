const std = @import("std");

const assert = @import("../../../quirks.zig").inlineAssert;

const Parser = @import("../../osc.zig").Parser;
const Command = @import("../../osc.zig").Command;

/// Parse OSC 51.
///
/// OSC 51 is reserved by xterm "for Emacs shell" (see xterm's ctlseqs.txt).
/// No sub-protocol is specified beyond the reservation, so we capture the
/// raw payload and let the embedding application interpret it.
pub fn parse(parser: *Parser, _: ?u8) ?*Command {
    assert(parser.state == .@"51");
    const cap = if (parser.capture) |*c| c else {
        parser.state = .invalid;
        return null;
    };
    cap.writer.writeByte(0) catch {
        parser.state = .invalid;
        return null;
    };
    const data = cap.trailing();
    parser.command = .{
        .emacs_shell = data[0 .. data.len - 1 :0],
    };
    return &parser.command;
}

test "OSC 51: emacs shell raw payload" {
    const testing = std.testing;

    var p: Parser = .init(testing.allocator);
    defer p.deinit();

    const input = "51;E(message \"hi\")";
    for (input) |ch| p.next(ch);

    const cmd = p.end(null).?.*;
    try testing.expect(cmd == .emacs_shell);
    try testing.expectEqualStrings("E(message \"hi\")", cmd.emacs_shell);
}

test "OSC 51: emacs shell directory tracking" {
    const testing = std.testing;

    var p: Parser = .init(testing.allocator);
    defer p.deinit();

    const input = "51;Auser@host:/tmp";
    for (input) |ch| p.next(ch);

    const cmd = p.end(null).?.*;
    try testing.expect(cmd == .emacs_shell);
    try testing.expectEqualStrings("Auser@host:/tmp", cmd.emacs_shell);
}

test "OSC 51: empty payload" {
    const testing = std.testing;

    var p: Parser = .init(testing.allocator);
    defer p.deinit();

    const input = "51;";
    for (input) |ch| p.next(ch);

    const cmd = p.end(null).?.*;
    try testing.expect(cmd == .emacs_shell);
    try testing.expectEqualStrings("", cmd.emacs_shell);
}

test "OSC 51: missing semicolon -> invalid" {
    const testing = std.testing;

    var p: Parser = .init(testing.allocator);
    defer p.deinit();

    const input = "51";
    for (input) |ch| p.next(ch);

    try testing.expect(p.end(null) == null);
}

test "OSC 51: large payload exceeds fixed buffer when no allocator" {
    const testing = std.testing;

    // Without an allocator, capture falls back to the fixed buffer and
    // overflows just like OSC 0/2 do.
    var p: Parser = .init(null);

    const input = "51;E" ++ "x" ** (Parser.MAX_BUF + 16);
    for (input) |ch| p.next(ch);

    try testing.expect(p.end(null) == null);
}

test "OSC 51: large payload with allocator" {
    const testing = std.testing;

    var p: Parser = .init(testing.allocator);
    defer p.deinit();

    const prefix = "51;E";
    const payload = "x" ** (Parser.MAX_BUF * 2);
    const input = prefix ++ payload;
    for (input) |ch| p.next(ch);

    const cmd = p.end(null).?.*;
    try testing.expect(cmd == .emacs_shell);
    try testing.expectEqualStrings("E" ++ payload, cmd.emacs_shell);
}
