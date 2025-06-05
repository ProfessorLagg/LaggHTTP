const builtin = @import("builtin");
const std = @import("std");
const utils = @import("utils.zig");
const log = std.log.scoped(.tcp);

// const c = struct {
//     pub usingnamespace @cImport("netinet/in.h");
//     pub usingnamespace @cImport("sys/types.h");
//     pub usingnamespace @cImport("sys/socket.h");
//     pub usingnamespace @cImport("unistd.h");
// };

// const c = switch (builtin.target.os.tag) {
//     .windows => @cImport({
//         @cInclude("winsock2.h");
//     }),
//     // .linux => @cImport({
//     //     @cInclude("unistd.h");
//     //     @cInclude("arpa/inet.h");
//     //     @cInclude("sys/socket.h"); // socket, bind, listen, accept, AF_INET, SOCK_STREAM
//     //     const SOCKET: type = c_int;
//     //     @cDefine("INVALID_SOCKET -1");

//     // }),
//     else => @compileError("Not implemented"),
// };

pub const TCPHeader = packed struct {
    /// Identifies the sending port.
    sourcePort: u16,
    /// Identifies the receiving port.
    destinationPort: u16,
    /// If the SYN flag is set (1), then this is the initial sequence number.
    /// The sequence number of the actual first data byte and the acknowledged number in the corresponding ACK are then this sequence number plus 1.
    /// If the SYN flag is unset (0), then this is the accumulated sequence number of the first data byte of this segment for the current session.
    sequenceNumber: u32,
    /// Has a dual role:
    /// - If the SYN flag is set (1), then this is the initial sequence number. The sequence number of the actual first data byte and the acknowledged number in the corresponding ACK are then this sequence number plus 1.
    /// - If the SYN flag is unset (0), then this is the accumulated sequence number of the first data byte of this segment for the current session.
    acknowledgmentNumber: u32,
    /// Specifies the size of the TCP header in 32-bit words.
    /// The minimum size header is 5 words and the maximum is 15 words thus giving the minimum size of 20 bytes and maximum of 60 bytes, allowing for up to 40 bytes of options in the header.
    /// This field gets its name from the fact that it is also the offset from the start of the TCP segment to the actual data.
    dataOffset: u4,
    /// From 2003 to 2017, the last bit (bit 103 of the header) was defined as the NS (Nonce Sum) flag by the experimental RFC 3540, ECN-nonce. ECN-nonce never gained widespread use and the RFC was moved to Historic status.
    /// For future use and should be set to zero; senders should not set these and receivers should ignore them if set, in the absence of further specification and implementation.
    reserved: u4,

    /// Congestion window reduced (CWR) flag is set by the sending host to indicate that it received a TCP segment with the ECE flag set and had responded in congestion control mechanism.
    flagCWR: u1,
    /// ECN-Echo has a dual role, depending on the value of the SYN flag:
    /// - If the SYN flag is set (1), the TCP peer is ECN capable.
    /// - If the SYN flag is unset (0), a packet with the Congestion Experienced flag set (ECN=11) in its IP header was received during normal transmission. This serves as an indication of network congestion (or impending congestion) to the TCP sender.
    flagECE: u1,
    /// Indicates that the Urgent pointer field is significant.
    flagURG: u1,
    /// Indicates that the Acknowledgment field is significant. All packets after the initial SYN packet sent by the client should have this flag set.
    flagACK: u1,
    /// Push function. Asks to push the buffered data to the receiving application.
    flagPSH: u1,
    /// Reset the connection
    flagRST: u1,
    /// Synchronize sequence numbers. Only the first packet sent from each end should have this flag set. Some other flags and fields change meaning based on this flag, and some are only valid when it is set, and others when it is clear.
    flagSYN: u1,
    /// Last packet from sender
    flagFIN: u1,
    /// The size of the receive window, which specifies the number of window size units that the sender of this segment is currently willing to receive.
    window: u16,
    /// The 16-bit checksum field is used for error-checking of the TCP header, the payload and an IP pseudo-header. The pseudo-header consists of the source IP address, the destination IP address, the protocol number for the TCP protocol (6) and the length of the TCP headers and payload (in bytes).
    checksum: u16,
    /// If the URG flag is set, then this 16-bit field is an offset from the sequence number indicating the last urgent data byte.
    urgentPointer: u16,
};

pub const TCPOptions = packed struct {
    // TODO Actually parse these

    /// Just here so the size matches
    temp: u320 = undefined,
};

pub const TCPFrame = packed struct {
    header: TCPHeader,
    options: TCPOptions,
    data: utils.PackedSlice(u8),
};

pub const TCPListener = switch (builtin.target.os.tag) {
    .windows => WindowsTCPListener,
    else => @compileError("Not implemented"),
};

pub const WindowsTCPListener = struct {
    // based on https://heyulong3d.medium.com/network-programming-simple-hello-world-tcp-in-c-c-on-windows-and-unix-539d5f47733e
    const ws2_32 = std.os.windows.ws2_32;
    comptime {
        if (builtin.target.os.tag != .windows) @compileError("Only works on windows");
    }

    inline fn GetLastWinsockError() anyerror {
        return utils.meta.EnumValueToError(ws2_32.WinsockError, ws2_32.WSAGetLastError());
    }
    const WindowsTCPListenerError = error{
        /// The socket returned by c.socket function was invalid
        invalidSocket,

        /// c.bind function returned SOCKET_ERROR
        bindFailed,

        /// c.listen function returned SOCKET_ERROR
        listenFailed,

        /// accept function returned SOCKET_ERROR
        acceptFailed,
    };

    pub const IpAddressFamily = enum(c_int) {
        /// The Internet Protocol version 4 (IPv4) address family
        IPv4 = ws2_32.AF.INET,
        /// The Internet Protocol version 6 (IPv4) address family
        IPv6 = ws2_32.AF.INET6,
    };
    pub const IpAddress = union(IpAddressFamily) {
        IPv4: u32,
        IPv6: u128,

        pub fn initIPv4(bytes: [4]u8) IpAddress {
            return IpAddress{ .IPv4 = std.mem.bytesToValue(u32, bytes[0..]) };
        }

        pub fn initIPv6(bytes: [16]u8) IpAddress {
            return IpAddress{ .IPv6 = std.mem.bytesToValue(u128, bytes[0..]) };
        }
    };

    pub const WindowsTCPStream = struct {
        socket: ws2_32.SOCKET,

        pub fn read(self: *const WindowsTCPStream, buf: []const u8) !usize {
            const result = ws2_32.recv(self.socket, buf.ptr, buf.len, 0);
            if (result == ws2_32.SOCKET_ERROR) return GetLastWinsockError();
            return result;
        }

        pub fn write(self: *const WindowsTCPStream, buf: []u8) !usize {
            const result = ws2_32.send(self.socket, buf.ptr, buf.len, 0);
            if (result == ws2_32.SOCKET_ERROR) return GetLastWinsockError();
            return result;
        }

        pub fn close(self: *const WindowsTCPStream) !void {
            const result = ws2_32.closesocket(self.socket);
            if (result == ws2_32.SOCKET_ERROR) return GetLastWinsockError();
        }
    };

    var wsaData: ws2_32.WSADATA = undefined;
    var wsaDataLoaded: bool = false;
    fn preinit() !void {
        if (wsaDataLoaded) return;
        const WSAStartup_result = ws2_32.WSAStartup(0x202, &wsaData);
        switch (WSAStartup_result) {
            0 => wsaDataLoaded = true,
            else => {
                ws2_32.WSASetLastError(WSAStartup_result);
                return GetLastWinsockError();
            },
        }
    }

    address: ws2_32.sockaddr = undefined,
    socket: ws2_32.SOCKET = undefined,

    fn adress_string(addr: *const ws2_32.sockaddr) []const u8 {
        return switch (addr.sin_family) {
            @as(@TypeOf(addr.sin_family), @intFromEnum(ws2_32.AF.INET)) => @panic("Not yet implemented"),
            @as(@TypeOf(addr.sin_family), @intFromEnum(ws2_32.AF.INET6)) => @panic("Not yet implemented"),
            else => unreachable,
        };
    }
    pub fn initIPv4(addr: u32, port: u16) !WindowsTCPListener {
        try WindowsTCPListener.preinit();

        var r: WindowsTCPListener = .{};
        r.address.sin_family = @intFromEnum(ws2_32.AF.INET);
        r.address.sin_addr = @bitCast(addr);
        r.address.sin_port = ws2_32.htons(@intCast(port));
        r.socket = ws2_32.socket(@intFromEnum(ws2_32.AF.INET), ws2_32.SOCK.STREAM, 0);
        log.debug("new IPv4 TCPListener:\n\taddr: {s}, port: {d}", .{ adress_string(&r.address), ws2_32.ntohs(r.address.sin_port) });
        return r;
    }
    pub fn initIPv6(addr: u128, port: u16) !WindowsTCPListener {
        _ = &addr;
        _ = &port;
        return utils.UtilError.NotYetImplemented;
    }
    pub fn init(addr: IpAddress, port: u16) !WindowsTCPListener {
        return switch (addr) {
            .IPv4 => return try initIPv4(addr.IPv4, port),
            .IPv6 => return try initIPv6(addr.IPv6, port),
        };
    }
    pub fn deinit(self: *WindowsTCPListener) !void {
        const result = ws2_32.closesocket(self.socket);
        if (result == ws2_32.SOCKET_ERROR) return GetLastWinsockError();
    }

    pub fn bind(self: *WindowsTCPListener) !void {
        const addr_ptr: [*]ws2_32.SOCKET_ADDRESS = @ptrFromInt(@intFromPtr(&self.address));
        const bind_result = ws2_32.bind(self.socket, addr_ptr, @sizeOf(@TypeOf(self.address)));
        log.debug("{any}", .{self});
        if (bind_result == ws2_32.SOCKET_ERROR) return GetLastWinsockError();
    }

    pub fn listen(self: *WindowsTCPListener) !void {
        const listen_result = ws2_32.listen(self.socket, ws2_32.SOMAXCONN);
        if (listen_result == ws2_32.SOCKET_ERROR) return GetLastWinsockError();
    }

    pub fn accept(self: *WindowsTCPListener) !WindowsTCPStream {
        var r: WindowsTCPStream = .{
            .socket = undefined,
        };
        const addr_ptr: *ws2_32.SOCKET_ADDRESS = @ptrCast(&self.address);
        r.socket = ws2_32.accept(self.socket, addr_ptr, @sizeOf(ws2_32.SOCKET_ADDRESS));
        if (r.socket == ws2_32.SOCKET_ERROR) return GetLastWinsockError();
        return r;
    }
};
