const std = @import("std");
const net  = std.net;
const StreamServer = net.StreamServer;
const Address = net.Address;
pub const io_mode = .evented; // For Async

pub fn main() anyerror!void {
    var stream_server = StreamServer.init(.{});
    defer stream_server.close();
    const address = try Address.resolveIp("127.0.0.1",8080);
    try stream_server.listen(address);

    while(true){
        const connection = try stream_server.accept();
        try connection.stream.writer().print("Hello World", .{} );
        connection.stream.close();
    }
}
