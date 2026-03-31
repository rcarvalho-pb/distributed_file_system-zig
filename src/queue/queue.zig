const std = @import("std");

const Mutex = std.Thread.Mutex;
const Condition = std.Thread.Condition;
const Allocator = std.mem.Allocator;

pub fn GenericQueue(comptime T: type) type {
    return struct {
        mutex: Mutex = .{},
        cond_empty: Condition = .{},
        cond_full: Condition = .{},
        fifo: std.DoublyLinkedList = .{},
        allocator: Allocator,
        maxItems: u32 = 10,
        count: u32 = 0,

        const Self = @This();

        const FifoData = struct {
            value: T,
            node: std.DoublyLinkedList.Node = .{},
        };

        pub fn init(allocator: Allocator) !*Self {
            const self = try allocator.create(Self);
            self.* = .{
                .allocator = allocator,
            };

            return self;
        }

        pub fn deinit(self: *Self) void {
            while (self.fifo.pop()) |node| {
                const fifoData: *FifoData = @fieldParentPtr("node", node);
                self.allocator.destroy(fifoData);
            }
            self.allocator.destroy(self);
        }

        pub fn enqueue(self: *Self, value: T) !void {
            self.mutex.lock();
            defer self.mutex.unlock();

            while (self.count == @as(u32, self.maxItems)) self.cond_full.wait(&self.mutex);

            const node_ptr = try self.allocator.create(FifoData);
            node_ptr.* = .{ .value = value };
            self.count += 1;
            self.fifo.append(&node_ptr.node);
            self.cond_empty.signal();
        }

        pub fn dequeue(self: *Self) !?T {
            self.mutex.lock();
            defer self.mutex.unlock();

            while (self.count == 0) self.cond_empty.wait(&self.mutex);

            const node_ptr = self.fifo.popFirst();
            if (node_ptr) |node| {
                const fifoData: *FifoData = @fieldParentPtr("node", node);
                const value = fifoData.value;
                self.allocator.destroy(fifoData);
                self.count -= 1;
                self.cond_full.signal();
                return value;
            } else {
                return null;
            }
        }

        pub fn len(self: Self) usize {
            return self.count;
        }
    };
}

test "Create a queue" {
    const allocator = std.testing.allocator;
    var queue = try GenericQueue(i32).init(allocator);
    defer queue.deinit();
    try std.testing.expectEqual(@as(usize, 0), queue.len());
}

// test "Push and pop to queue" {
//     const allocator = std.testing.allocator;
//     var queue = try GenericQueue(i32).init(allocator);
// }
