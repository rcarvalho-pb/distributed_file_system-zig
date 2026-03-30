const std = @import("std");

from: []const u8,
payload: []const u8,

const Self = @This();

test "Create RPC Message" {
    const expectedFrom = "127.0.0.1:3000";
    const expectedPayload = "data test";
    const msg = Self{
        .from = expectedFrom,
        .payload = expectedPayload,
    };

    try std.testing.expectEqual(expectedFrom, msg.from);
    try std.testing.expectEqual(expectedPayload, msg.payload);
}
