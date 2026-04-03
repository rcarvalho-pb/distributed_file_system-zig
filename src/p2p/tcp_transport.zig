const std = @import("std");
const print = std.debug.print;

const Allocator = std.mem.Allocator;
const Reader = std.Io.Reader;

const Transport = @import("transport.zig").Transport;
const RPC = @import("rpc.zig");
const TCPPeer = @import("tcp_peer.zig");
const Peer = @import("transport.zig").Peer;

const Channel = @import("channel").Channel;

pub const HandshakeFunc: type = *const fn (Peer) anyerror!void;
pub const DecodeFunc = *const fn (std.Io.Reader, *RPC) anyerror!void;
pub const OnPeerFunc = *const fn (Peer) anyerror!void;

const TYPE: type = RPC;
const SIZE: usize = 1;

opts: TCPOprtions,
rpc_chan: *Channel(TYPE, SIZE),
listener: ?std.net.Server = null,
allocator: Allocator,
interface: Transport,

const Self = @This();

pub const TCPOprtions = struct {
    listenAddr: []const u8,
    handshake: HandshakeFunc,
    decode: DecodeFunc,
    onPeer: ?OnPeerFunc = null,
};

pub fn init(allocator: Allocator, opts: TCPOprtions) !*Self {
    const self = try allocator.create(Self);
    self.* = .{
        .allocator = allocator,
        .opts = opts,
        .chan = try Channel(TYPE, SIZE).init(allocator),
        .interface = initInterface(self),
    };
    return self;
}

fn initInterface(self: *Self) Transport {
    return .{
        .ptr = self,
        .vtable = &.{
            .listenAndAccept = struct {
                fn wrapper(ctx: *anyopaque) anyerror!void {
                    const s: *Self = @ptrCast(@alignCast(ctx));
                    return s.listenAndAccept();
                }
            }.wrapper,
            .consume = struct {
                fn wrapper(ctx: *anyopaque) anyerror!RPC {
                    const s: *Self = @ptrCast(@alignCast(ctx));
                    return s.consume();
                }
            }.wrapper,
            .deinit = struct {
                fn wrapper(ctx: *anyopaque) void {
                    const s: *Self = @ptrCast(@alignCast(ctx));
                    return s.deinit();
                }
            }.wrapper,
        },
    };
}

fn listenAndAccept(self: *Self) anyerror!void {
    const address = try std.net.Address.parseIp4(self.opts.listenAddr, 0);
    self.listener = try address.listen(.{ .reuse_address = true });

    const thread = try std.Thread.spawn(.{}, startAcceptLoop, .{self});
    thread.detach();
}

fn startAcceptLoop(self: *Self) void {
    if (self.listener) |*s| {
        while (true) {
            const conn = s.accept() catch |err| {
                print("TCP accept error: {any}\n", .{err});
                return;
            };
            const thread = std.Thread.spawn(.{}, handleConn, .{ self, conn }) catch |err| {
                print("error accepting conn: {any}\n", .{err});
                return;
            };
            thread.detach();
        }
    } else {
        return;
    }
}

pub fn handleConn(self: *Self, conn: std.net.Server.Connection) void {
    var success: bool = false;
    defer if (!success) conn.stream.close();

    const peer = TCPPeer{ .conn = conn, .outbound = true };

    self.opts.handshake(peer) catch return;

    if (self.opts.onPeer) |on_peer| {
        on_peer(peer) catch return;
    }

    success = true;

    while (true) {
        var rpc = RPC{};
        self.opts.decode(conn.stream, &rpc) catch |err| {
            if (err != error.EndOfStream) {
                print("Decoder error: {any}\n", .{err});
            }
            conn.stream.close();
            break;
        };
        rpc.from = conn.address;
        self.rpc_chan.send(self.allocator, rpc) catch break;
    }
}

fn consume(self: *Self) anyerror!RPC {
    return self.rpc_chan.receive(self.allocator);
}

fn deinit(self: *Self) void {
    const allocator = self.allocator;
    if (self.listener) |*s| s.deinit();
    self.rpc_chan.deinit(allocator);
    allocator.destroy(self);
}
