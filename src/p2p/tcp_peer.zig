const std = @import("std");
const net = std.net;

const Peer = @import("transport.zig").Peer;

const Self = @This();

conn: net.Stream,
outbound: bool,
interface: Peer,

pub fn init(allocator: std.mem.Allocator, conn: net.Stream, outbound: bool) *Peer {
    const self = try allocator.create(Self);

    self.* = .{
        .conn = conn,
        .outbound = outbound,
        .interface = .{
            .ptr = self,
            .vtable = &.{
                .close = struct {
                    fn wrapper(ctx: *anyopaque) void {
                        const s: *Self = @ptrCast(@alignCast(ctx));
                        return s.close();
                    }
                }.wrapper,
            },
        },
    };
}

pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
    if self.conn.
}

pub fn close(self: *Self) void {
    self.conn.close();
}
