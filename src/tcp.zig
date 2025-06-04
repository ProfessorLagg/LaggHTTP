const builtin = @import("builtin");
const std = @import("std");
const utils = @import("utils.zig");

// const c = struct {
//     pub usingnamespace @cImport("netinet/in.h");
//     pub usingnamespace @cImport("sys/types.h");
//     pub usingnamespace @cImport("sys/socket.h");
//     pub usingnamespace @cImport("unistd.h");
// };

// based on https://heyulong3d.medium.com/network-programming-simple-hello-world-tcp-in-c-c-on-windows-and-unix-539d5f47733e
const c = switch (builtin.target.os.tag) {
    .windows => @cImport({
        @cInclude("winsock2.h");
    }),
    // .linux => @cImport({
    //     @cInclude("unistd.h");
    //     @cInclude("arpa/inet.h");
    //     @cInclude("sys/socket.h"); // socket, bind, listen, accept, AF_INET, SOCK_STREAM
    //     const SOCKET: type = c_int;
    //     @cDefine("INVALID_SOCKET -1");

    // }),
    else => @compileError("Not implemented"),
};

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
    temp: [40]u8 = undefined,
};

pub const TCPFrame = packed struct {
    header: TCPHeader,
    options: TCPOptions,
    data: []const u8,
};

pub const TCPListener = switch (builtin.target.os.tag) {
    .windows => WindowsTCPListener,
    else => @compileError("Not implemented"),
};

const WindowsTCPListener = struct {
    const WindowsTCPListenerError = error{
        // See https://learn.microsoft.com/en-us/windows/win32/winsock/windows-sockets-error-codes-2

        /// The underlying network subsystem is not ready for network communication.
        WSASYSNOTREADY,
        /// The version of Windows Sockets support requested is not provided by this particular Windows Sockets implementation.
        WSAVERNOTSUPPORTED,
        /// A blocking Windows Sockets 1.1 operation is in progress.
        WSAEINPROGRESS,
        /// A limit on the number of tasks supported by the Windows Sockets implementation has been reached.
        WSAEPROCLIM,
        /// The lpWSAData parameter is not a valid pointer.
        WSAEFAULT,

        /// The socket returned by c.socket function was invalid
        InvalidSocket,

        /// c.bind function returned SOCKET_ERROR
        BindFailed,

        /// c.listen function returned SOCKET_ERROR
        ListenFailed,
    };

    comptime {
        if (builtin.target.os.tag != .windows) @compileError("Only works on windows");
    }

    fn preinit() !void {
        if (!wsaDataLoaded) {
            switch (c.WSAStartup(c.MAKEWORD(2, 2), &wsaData)) {
                0 => {
                    wsaDataLoaded = true;
                    return void;
                },
                c.WSASYSNOTREADY => return WindowsTCPListenerError.WSASYSNOTREADY,
                c.WSAVERNOTSUPPORTED => return WindowsTCPListenerError.WSAVERNOTSUPPORTED,
                c.WSAEINPROGRESS => return WindowsTCPListenerError.WSAEINPROGRESS,
                c.WSAEPROCLIM => return WindowsTCPListenerError.WSAEPROCLIM,
                c.WSAEFAULT => return WindowsTCPListenerError.WSAEFAULT,
            }
        }
    }

    pub const IpAddressFamily = enum(c_int) {
        /// The Internet Protocol version 4 (IPv4) address family
        IPv4 = c.AF_INET,
        /// The Internet Protocol version 6 (IPv4) address family
        IPv6 = c.AF_INET6,
    };
    pub const IpAddress = union(IpAddressFamily) {
        IPv4: u32,
        IPv6: u128,

        pub fn initIPv4(bytes: [4]u8) IpAddress {
            return IpAddress{ .IPv4 = std.mem.bytesToValue(u32, bytes) };
        }

        pub fn initIPv6(bytes: [16]u8) IpAddress {
            return IpAddress{ .IPv6 = std.mem.bytesToValue(u128, bytes) };
        }
    };

    var wsaData: c.WSADATA = undefined;
    var wsaDataLoaded: bool = false;

    serv_addr: c.SOCKADDR_IN = undefined,
    serv_socket: c.SOCKET = undefined,

    pub fn initIPv4(addr: u32, port: u16) !WindowsTCPListener {
        try WindowsTCPListener.preinit();

        var r: WindowsTCPListener = .{};
        r.serv_addr.sin_family = @intFromEnum(IpAddressFamily.IPv4);
        r.serv_addr.sin_addr.s_addr = c.htonl(addr);
        r.serv_addr.sin_port = c.htons(@intCast(port));
    }
    pub fn initIPv6(addr: u128, port: u16) !WindowsTCPListener {
        _ = &addr;
        _ = &port;
        @compileError("Not yet Implemented");
    }
    pub fn init(addr: IpAddress, port: u16) !WindowsTCPListener {
        return switch (addr) {
            .IPv4 => return try initIPv4(addr.IPv4, port),
            .IPv6 => return try initIPv6(addr.IPv6, port),
        };
    }
    pub fn deinit(self: *WindowsTCPListener) void {
        c.closesocket(self.serv_socket);

    }

    pub fn bind(self: *WindowsTCPListener) !void {
        const addr_ptr: *c.SOCKADDR = @ptrCast(&self.serv_addr);
        const bind_result = c.bind(self.serv_sock, addr_ptr, @sizeOf(c.SOCKADDR_IN));
        if (bind_result == c.SOCKET_ERROR) {
            return WindowsTCPListenerError.BindFailed;
        }
    }

    pub fn listen(self: *WindowsTCPListener) !void {
        // try self.bind();
        const listen_result = c.listen(self.serv_socket, c.SOMAXCONN);
        if (listen_result == c.SOCKET_ERROR) return WindowsTCPListenerError.ListenFailed;
    }

    pub fn accept(self: *WindowsTCPListener) !TCPFrame {
        // TODO
        _ = self;
        @compileError("Not yet implemented");
    }
};
