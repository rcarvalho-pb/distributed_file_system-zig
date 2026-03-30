const std = @import("std");

const Thread = std.Thread;
const Allocator = std.mem.Allocator;

pub fn BufferedQueue(comptime T: type) type {
    return struct {
        const Self = @This();

        buf: [10]T = undefined,
        maxItens: u5 = 10,
        count: u32 = 0,
        mu: Thread.Mutex = .{},
        cond_full: Thread.Condition = .{},
        cond_empty: Thread.Condition = .{},

        pub fn init(allocator: Allocator) *Self {}
    };
}
