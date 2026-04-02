const std = @import("std");

const Thread = std.Thread;
const Allocator = std.mem.Allocator;

pub fn Channel(comptime T: type, comptime size: usize) type {
    return struct {
        const Self = @This();

        buf: [size]*T = undefined,
        head: usize = 0,
        tail: usize = 0,
        count: usize = 0,
        mutex: Thread.Mutex = .{},
        cond_empty: Thread.Condition = .{},
        cond_full: Thread.Condition = .{},

        pub fn init(allocator: Allocator) !*Self {
            const self = try allocator.create(Self);
            self.* = .{};
            return self;
        }

        pub fn deinit(self: *Self, allocator: Allocator) void {
            while (self.count > 0) {
                _ = self.receive(allocator);
            }
            allocator.destroy(self);
        }

        fn walk_buf(self: *Self, func: *const fn (*T) void) void {
            var i = self.head;
            while (i < self.count) : (i += 1) {
                const pos = (self.head + i) % size;
                func(self.buf[pos]);
            }
        }

        fn walk_head(self: *Self) void {
            self.head = (self.head + 1) % size;
        }

        fn walk_tail(self: *Self) void {
            self.tail = (self.tail + 1) % size;
        }

        pub fn send(self: *Self, allocator: Allocator, value: T) !void {
            self.mutex.lock();
            defer self.mutex.unlock();

            while (self.count == size) self.cond_full.wait(&self.mutex);

            const v = try allocator.create(T);
            v.* = value;

            self.buf[self.tail] = v;
            self.walk_tail();
            self.count += 1;

            self.cond_empty.signal();
        }

        pub fn receive(self: *Self, allocator: Allocator) T {
            self.mutex.lock();
            defer self.mutex.unlock();

            while (self.count == 0) self.cond_empty.wait(&self.mutex);

            const v = self.buf[self.head];
            self.walk_head();
            self.count -= 1;

            self.cond_full.signal();

            const value = v.*;

            allocator.destroy(v);

            return value;
        }
    };
}

test "Create channel" {
    const size: usize = 5;

    const allocator = std.testing.allocator;
    var chan = try Channel(i32, size).init(allocator);
    defer chan.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 0), chan.tail);
    try std.testing.expectEqual(@as(usize, 0), chan.head);
    try std.testing.expectEqual(@as(usize, 0), chan.count);
    try std.testing.expectEqual(size, chan.buf.len);
}

test "Send to channel and receive from it" {
    const size: usize = 5;
    const allocator = std.testing.allocator;

    var chan = try Channel(i32, size).init(allocator);
    defer chan.deinit(allocator);

    try chan.send(allocator, @as(i32, 10));

    try std.testing.expectEqual(@as(usize, 1), chan.count);
    try std.testing.expectEqual(@as(usize, 1), chan.tail);
    try std.testing.expectEqual(@as(usize, 0), chan.head);

    try chan.send(allocator, @as(i32, 20));
    try chan.send(allocator, @as(i32, 30));
    try chan.send(allocator, @as(i32, 40));
    try chan.send(allocator, @as(i32, 50));

    try std.testing.expectEqual(@as(i32, 10), chan.receive(allocator));
    try std.testing.expectEqual(@as(i32, 20), chan.receive(allocator));

    try std.testing.expectEqual(@as(i32, 30), chan.buf[chan.head].*);
}
