const builtin = @import("builtin");
const std = @import("std");
const LaggHTTP = @import("LaggHTTP");

pub const std_options: std.Options = .{
    // Set the log level to info to .debug. use the scope levels instead
    .log_level = switch (builtin.mode) {
        .Debug => .debug,
        .ReleaseSafe => .debug,
        .ReleaseSmall => .err,
        .ReleaseFast => .err,
    },
    .log_scope_levels = &[_]std.log.ScopeLevel{
        .{ .scope = .HttpServer, .level = .info },
        .{ .scope = .Perf, .level = .info },
    },
};

pub fn main() !void {
    try debugStandardHttpServer();
    // try debugTCPListener();
    // try debug_ws2_32();
}

fn debug_ws2_32_old() !void {
    //https://heyulong3d.medium.com/network-programming-simple-hello-world-tcp-in-c-c-on-windows-and-unix-539d5f47733e

    const utils = LaggHTTP.utils;
    const ws2_32 = std.os.windows.ws2_32;
    var wsaData: ws2_32.WSADATA = undefined;
    const WSAStartupResult = ws2_32.WSAStartup(0x202, &wsaData);
    if (WSAStartupResult != 0) {
        ws2_32.WSASetLastError(WSAStartupResult);
        return utils.meta.EnumValueToError(ws2_32.WinsockError, ws2_32.WSAGetLastError());
    }
    std.log.debug("WSAStartup() success!", .{});

    const serv_sock = ws2_32.socket(ws2_32.AF.INET, ws2_32.SOCK.STREAM, 0);
    if (serv_sock == ws2_32.INVALID_SOCKET) return utils.meta.EnumValueToError(ws2_32.WinsockError, ws2_32.WSAGetLastError());
    defer _ = ws2_32.closesocket(serv_sock);
    std.log.debug("socket() success!", .{});

    var serv_addr: ws2_32.sockaddr.in = ws2_32.sockaddr.in{
        .addr = ws2_32.inet_addr("127.0.0.1"),
        .family = ws2_32.AF.INET,
        .port = ws2_32.htons(5500),
    };

    const bind_result = ws2_32.bind(serv_sock, @ptrCast(&serv_addr), @sizeOf(@TypeOf(serv_addr)));
    if (bind_result == ws2_32.SOCKET_ERROR) return utils.meta.EnumValueToError(ws2_32.WinsockError, ws2_32.WSAGetLastError());
    std.log.debug("socket() success!", .{});

    const listen_result = ws2_32.listen(serv_sock, ws2_32.SOMAXCONN);
    if (listen_result == ws2_32.SOCKET_ERROR) return utils.meta.EnumValueToError(ws2_32.WinsockError, ws2_32.WSAGetLastError());
    std.log.debug("listen() success!", .{});

    var read_arr: [65_536]u8 = undefined;
    var read_buf: []u8 = read_arr[0..];

    const rsp_arr = "HTTP/1.1 200 OK\r\nContent-Length: 0\r\n\r\n";
    var rsp: []const u8 = rsp_arr[0..];
    while (true) {
        read_buf = read_arr[0..];
        @memset(read_buf, 0);
        var clnt_addr: ws2_32.sockaddr.in = undefined;
        var sz_clnt_addr: i32 = @sizeOf(@TypeOf(clnt_addr));
        const clnt_sock = ws2_32.accept(serv_sock, @ptrCast(&clnt_addr), &sz_clnt_addr);
        std.log.debug("accept() success!", .{});
        defer _ = ws2_32.closesocket(clnt_sock);

        if (clnt_sock == ws2_32.INVALID_SOCKET) {
            const err = utils.meta.EnumValueToError(ws2_32.WinsockError, ws2_32.WSAGetLastError());
            std.log.err("{any}{any}", .{ err, @errorReturnTrace() });
            continue;
        }

        const new_len = ws2_32.recv(clnt_sock, read_buf.ptr, @intCast(read_arr.len), @as(i32, 0));
        read_buf.len = @intCast(new_len);
        std.log.debug("recv() sucess!:\n\"{s}\"", .{read_buf});

        const send_result = ws2_32.send(clnt_sock, rsp.ptr, @intCast(rsp.len), @as(i32, 0));
        const send_len: usize = @intCast(send_result);
        std.log.debug("sent resposne:\n\"{s}\"", .{rsp[0..send_len]});
    }
}

fn debug_ws2_32() !void {
    //https://learn.microsoft.com/en-us/windows/win32/winsock/complete-server-code

    const utils = LaggHTTP.utils;
    const ws2_32 = std.os.windows.ws2_32;

    var iResult: i32 = 0;

    var wsaData: ws2_32.WSADATA = undefined;
    const WSAStartupResult = ws2_32.WSAStartup(0x202, &wsaData);
    if (WSAStartupResult != 0) {
        ws2_32.WSASetLastError(WSAStartupResult);
        return utils.meta.EnumValueToError(ws2_32.WinsockError, ws2_32.WSAGetLastError());
    }
    defer _ = ws2_32.WSACleanup();
    std.log.debug("WSAStartup() success!", .{});

    // var result: ws2_32.addrinfo = undefined;
    var result: ?*ws2_32.addrinfo = null;

    var hints: ws2_32.addrinfo = std.mem.zeroes(ws2_32.addrinfo);
    hints.family = ws2_32.AF.INET;
    hints.socktype = ws2_32.SOCK.STREAM;
    hints.protocol = ws2_32.IPPROTO.TCP;
    hints.flags = ws2_32.AI{};

    // Resolve the server address and port
    iResult = ws2_32.getaddrinfo("127.0.0.1", "5500", &hints, &result);
    if (iResult != 0) {
        ws2_32.WSASetLastError(iResult);
        return utils.meta.EnumValueToError(ws2_32.WinsockError, ws2_32.WSAGetLastError());
    }
    std.log.debug("getaddrinfo() succes!: {any}", .{result.?.*});

    const ListenSocket = ws2_32.socket(result.?.family, result.?.socktype, result.?.protocol);
    if (ListenSocket == ws2_32.INVALID_SOCKET) return utils.meta.EnumValueToError(ws2_32.WinsockError, ws2_32.WSAGetLastError());
    defer _ = ws2_32.closesocket(ListenSocket);
    std.log.debug("socket() success!", .{});

    iResult = ws2_32.bind(ListenSocket, result.?.addr.?, @intCast(result.?.addrlen));
    if (iResult == ws2_32.SOCKET_ERROR) return utils.meta.EnumValueToError(ws2_32.WinsockError, ws2_32.WSAGetLastError());
    std.log.debug("socket() success!", .{});

    ws2_32.freeaddrinfo(result);

    const listen_result = ws2_32.listen(ListenSocket, ws2_32.SOMAXCONN);
    if (listen_result == ws2_32.SOCKET_ERROR) return utils.meta.EnumValueToError(ws2_32.WinsockError, ws2_32.WSAGetLastError());
    std.log.debug("listen() success!", .{});

    var read_arr: [65_536]u8 = undefined;
    var read_buf: []u8 = read_arr[0..];

    const rsp_arr = "HTTP/1.1 200 OK\r\nContent-Length: 0\r\n\r\n";
    var rsp: []const u8 = rsp_arr[0..];
    while (true) {
        read_buf = read_arr[0..];
        @memset(read_buf, 0);
        const ClientSocket = ws2_32.accept(ListenSocket, null, null);
        defer {
            _ = ws2_32.shutdown(ClientSocket, ws2_32.SD_BOTH);
            _ = ws2_32.closesocket(ClientSocket);
        }
        std.log.debug("accept() success!", .{});

        if (ClientSocket == ws2_32.INVALID_SOCKET) {
            const err = utils.meta.EnumValueToError(ws2_32.WinsockError, ws2_32.WSAGetLastError());
            std.log.err("{any}{any}", .{ err, @errorReturnTrace() });
            continue;
        }

        const recv_result = ws2_32.recv(ClientSocket, read_buf.ptr, @intCast(read_arr.len), @as(i32, 0));
        if (recv_result == ws2_32.SOCKET_ERROR) {
            const err = utils.meta.EnumValueToError(ws2_32.WinsockError, ws2_32.WSAGetLastError());
            std.log.err("recv() failed: {any}{any}", .{ err, @errorReturnTrace() });
            continue;
        }
        read_buf.len = @intCast(recv_result);
        std.log.debug("recv() sucess!:\n\"{s}\"", .{read_buf});

        const send_result = ws2_32.send(ClientSocket, rsp.ptr, @intCast(rsp.len), @as(i32, 0));
        if (send_result == ws2_32.SOCKET_ERROR) {
            const err = utils.meta.EnumValueToError(ws2_32.WinsockError, ws2_32.WSAGetLastError());
            std.log.err("send() failed: {any}{any}", .{ err, @errorReturnTrace() });
            continue;
        }
        const send_len: usize = @intCast(send_result);
        std.log.debug("send() sucess!:\n\"{s}\"", .{rsp[0..send_len]});
    }
}

fn debugTCPListener() !void {
    const TCPListener = LaggHTTP.tcp.WindowsTCPListener;
    const IpAddress = TCPListener.IpAddress;
    const addr: IpAddress = IpAddress.initIPv4(.{ 127, 0, 0, 1 });
    var listener: TCPListener = try TCPListener.init(addr, 5500);
    std.log.debug("listener: {any}", .{listener});
    try listener.bind();
    try listener.listen();
    const connection = try listener.accept();

    _ = &connection;
}

fn debugStandardHttpServer() !void {
    // const allocator = std.heap.c_allocator;
    const address: std.net.Address = std.net.Address.initIp4(.{ 127, 0, 0, 1 }, 5500);
    var listener: std.net.Server = try address.listen(.{});
    var buffer: [65_536]u8 = undefined;
    while (true) {
        const connection = try listener.accept();
        var server = std.http.Server.init(connection, buffer[0..]);
        var request = try server.receiveHead();
        try request.respond("", .{});
    }
}

fn debugHttpServer() !void {
    const allocator = std.heap.c_allocator;
    const address: std.net.Address = std.net.Address.initIp4(.{ 127, 0, 0, 1 }, 5500);
    var server = LaggHTTP.HttpServer(.{}).init(allocator, address);
    defer server.deinit();

    try server.listen();
}
