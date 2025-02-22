const std = @import("std");
const net = std.net;
const posix = std.posix;


test "TCP" {
    const address = try std.net.Address.parseIp("127.0.0.1", 5882);

    const tpe: u32 = posix.SOCK.STREAM;
    const protocol = posix.IPPROTO.TCP;
    const listener = try posix.socket(address.any.family, tpe, protocol);
    defer posix.close(listener);
}