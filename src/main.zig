const std = @import("std");
const print = std.debug.print;
const heap = std.heap;

const GenericQueue = @import("p2p/message_queue.zig").GenericQueue;
const TcpTransport = @import("p2p/tcp_transport.zig");

pub fn main() !void {
    var gpa = heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    var tcp_impl = try TcpTransport.init(allocator, "127.0.0.1:3000");
    const itransport = &tcp_impl.interface;
    defer itransport.deinit();

    try itransport.listenAndAccept();

    var queue = try GenericQueue(i32).init(allocator);
    defer queue.deinit();
    print("queue size: {d}\n", .{queue.len()});
    try queue.enqueue(10);
    print("queue size: {d}\n", .{queue.len()});
    const v = queue.dequeue() catch |err| if (err == error.EmptyQueue) null else unreachable;

    if (v) |value| {
        print("Dequeued value: {d}\n", .{value});
    }
    print("queue size: {d}\n", .{queue.len()});
    _ = queue.dequeue() catch |err| switch (err) {
        error.EmptyQueue => blk: {
            print("empty Queue", .{});
            break :blk null;
        },
        else => unreachable,
    };
}
