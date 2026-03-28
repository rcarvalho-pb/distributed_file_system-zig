const std = @import("std");
const print = std.debug.print;

const Allocator = std.mem.Allocator;
const Reader = std.Io.Reader;

const Transport = @import("transport.zig").Transport;
const RPC = @import("rpc.zig");
const Peer = @import("transport.zig").Peer;

address: []const u8,
// handshakeFunc: *const fn (Peer) anyerror,
// decodeFunc: *const fn (Reader, *RPC) anyerror,
allocator: Allocator,
interface: Transport,

const Self = @This();

pub fn init(allocator: Allocator, address: []const u8) !*Self {
    const self = try allocator.create(Self);
    self.* = .{
        .address = address,
        .allocator = allocator,
        .interface = initInterface(self),
    };
    return self;
}

fn initInterface(self: *Self) Transport {
    return .{
        .ptr = self,
        .vtable = &.{
            .listenAndAccept = listenAndAccept,
            .consume = consume,
            .deinit = deinit,
        },
    };
}

fn listenAndAccept(ctx: *anyopaque) anyerror!void {
    const self: *Self = @ptrCast(@alignCast(ctx));
    print("Escutando TCP em {s}...\n", .{self.address});
}

fn consume(ctx: *anyopaque) anyerror!RPC {
    _ = ctx;
    return RPC{ .from = "server", .payload = "ping" };
}

fn deinit(ctx: *anyopaque) void {
    const self: *Self = @ptrCast(@alignCast(ctx));
    const allocator = self.allocator;
    allocator.destroy(self);
}
