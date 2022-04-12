const std = @import("std");
const net  = std.net;
const StreamServer = net.StreamServer;
const Address = net.Address;
const GeneralPurposeAllocator = std.heap.GeneralPurposeAllocator;
pub const io_mode = .evented; // For Async
const print = std.debug.print;

pub fn main() anyerror!void {
    var gpa = GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var stream_server = StreamServer.init(.{});
    defer stream_server.close();
    const address = try Address.resolveIp("127.0.0.1",8080);
    try stream_server.listen(address);

    while(true){
        const connection = try stream_server.accept();
        try handler(allocator , connection.stream);
    }
}

const ParsingError = error {
    MethodNotValid,
    VersionNotValid
};
const Method = enum {
    GET,
    POST,
    PUT,
    PATCH,
    OPTION,
    DELETE,
    pub fn formString(s: []const u8) !Method {
        if (std.mem.eql(u8,"GET",s))return .POST;
        if (std.mem.eql(u8,"PUT",s))return .PUT;
        if (std.mem.eql(u8,"PATCH",s))return .PATCH;
        if (std.mem.eql(u8,"OPTION",s))return .OPTION;
        if (std.mem.eql(u8,"DELETE",s))return .DELETE;
        return ParsingError.MethodNotValid;
    }
};

const Version = enum {
    @"1.1",
    @"2",
    pub fn formString(s: []const u8) !Version{
        if(std.mem.eql(u8,"HTTP/1.1",s)) return .@"1.1";
        if(std.mem.eql(u8,"HTTP/2",s)) return .@"2";
        return ParsingError.VersionNotValid;
    }
};
const HTTPContext = struct {
    method: Method,
    uri: []const u8,
    version: Version,
    headers: std.StringHashMap([]const u8),
    stream: net.Stream,

    pub fn body(self: *HTTPContext) net.Sream.Reader {
        return self.stream.reader();
    }

    pub fn response(self: *HTTPContext) net.Stream.writer {
        return self.stream.writer();
    }

    pub fn debugPrintRequest(self: *HTTPContext) void {
        print("method: {s}\nuri: {s}\nversion: {s}\n", .{self.method,self.uri,self.version});
        var header_itter = self.headers.iterator();
        while (header_itter.next()) |entry| {
            print("{s}: {s}\n", .{entry.key_ptr.*,entry.value_ptr.*});
        }
    }

    pub fn init(allocator: std.mem.Allocator,stream: net.Stream) !HTTPContext {
        var first_line = try stream.reader().readUntilDelimiterAlloc(allocator,'\n',std.math.maxInt(usize));
        first_line = first_line[0..first_line.len - 1];
        var first_line_iter = std.mem.split(u8,first_line," ");

        const method = first_line_iter.next().?;
        const uri = first_line_iter.next().?;
        const version = first_line_iter.next().?;

        var headers = std.StringHashMap([]const u8).init(allocator);
        while(true){
            var line = try stream.reader().readUntilDelimiterAlloc(allocator,'\n',std.math.maxInt(usize));
            if(line.len == 1 and std.mem.eql(u8,line,"\r")) break;
            line  = line[0..line.len];
            var line_iter = std.mem.split(u8,line,":");
            const key = line_iter.next().?;
            var value = line_iter.next().?;
            if(value[0] == ' ') value = value[1..];
            try headers.put(key,value);
        }

        return HTTPContext{
            .headers= headers,
            .method = try Method.formString(method),
            .version = try Version.formString(version),
            .uri = uri,
            .stream = stream,
        };
    }
};
fn handler(allocator: std.mem.Allocator ,stream: net.Stream) !void{
    defer stream.close();
    var http_context  = try HTTPContext.init(allocator,stream);
    http_context.debugPrintRequest();
}