const std = @import("std");
const print = std.debug.print;

const RPC = @import("rpc.zig");

pub const Transport = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    const Self = @This();

    pub const VTable = struct {
        listenAndAccept: *const fn (ctx: *anyopaque) anyerror!void,
        consume: *const fn (ctx: *anyopaque) anyerror!RPC,
        deinit: *const fn (ctx: *anyopaque) void,
    };

    pub fn listenAndAccept(self: Self) anyerror!void {
        return self.vtable.listenAndAccept(self.ptr);
    }

    pub fn consume(self: Self) anyerror!RPC {
        return self.vtable.consume(self.ptr);
    }

    pub fn deinit(self: Self) void {
        self.vtable.deinit(self.ptr);
    }
};

pub const Peer = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    const Self = @This();

    pub const VTable = struct {
        close: *const fn (ctx: *anyopaque) void,
    };

    pub fn close(self: Self) void {
        return self.vtable.close(self.ptr);
    }
};
