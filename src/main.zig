const std = @import("std");
const testing = std.testing;
const print = std.debug.print;
const TypeInfo = std.builtin.TypeInfo;
const Allocator = std.mem.Allocator;

fn Dataframe(comptime n: usize, comptime fnames: [n]([]const u8), comptime Ts: [n]type) type {
    comptime const cols_t: type = comptime blk: {
        const nulfield: TypeInfo.StructField = .{
            .name = "empty",
            .field_type = i32,
            .default_value = 0,
            .is_comptime = true,
            .alignment = 4
        };
        var fields: [n]TypeInfo.StructField = .{nulfield} ** n;
        var i = 0;
        inline while (i < n) : (i += 1) {
            fields[i] = .{
                .name = fnames[i],
                .field_type = std.ArrayListUnmanaged(Ts[i]),
                .default_value = null,
                .is_comptime = false,
                .alignment = @alignOf(std.ArrayListUnmanaged(Ts[i]))
            };
        }
        const decls: [0]TypeInfo.Declaration = .{};
        const s: TypeInfo.Struct = .{
            .layout = TypeInfo.ContainerLayout.Auto,
            .fields = &fields,
            .decls = &decls,
            .is_tuple = true,
        };
        break :blk @Type(TypeInfo { .Struct = s});
    };
    comptime const row_t: type = comptime blk: {
        const nulfield: TypeInfo.StructField = .{
            .name = "empty",
            .field_type = i32,
            .default_value = 0,
            .is_comptime = true,
            .alignment = 4
        };
        var fields: [n]TypeInfo.StructField = .{nulfield} ** n;
        var i = 0;
        inline while (i < n) : (i += 1) {
            fields[i] = .{
                .name = fnames[i],
                .field_type = Ts[i],
                .default_value = null,
                .is_comptime = false,
                .alignment = @alignOf(std.ArrayListUnmanaged(Ts[i]))
            };
        }
        const decls: [0]TypeInfo.Declaration = .{};
        const s: TypeInfo.Struct = .{
            .layout = TypeInfo.ContainerLayout.Auto,
            .fields = &fields,
            .decls = &decls,
            .is_tuple = true,
        };
        break :blk @Type(TypeInfo { .Struct = s});
    };


    return struct {
        const Self = @This();
        cols: cols_t,
        len: usize,
        alloc: *Allocator,

        pub fn init(alloc: *Allocator, capacity: usize) !Self {
            var cols: cols_t = undefined;
            comptime var i = 0;
            inline while(i < n) : (i += 1) {
                cols[i] = try std.ArrayListUnmanaged(Ts[i]).initCapacity(alloc, capacity);
            }
            return Self{
                .cols = cols,
                .len = 0,
                .alloc = alloc
            };
        }

        pub fn add_row(self: *Self, row: row_t) !void {
            comptime var i = 0;
            inline while(i < n) : (i += 1) {
                try self.cols[i].append(self.alloc, row[i]);
            }
            self.len += 1;
        }

        fn col2i(comptime col: []const u8) usize {
            comptime var i = 0;
            comptime var found = false;
            inline while (i < n) : (i += 1) {
                if (std.mem.eql(u8, col, fnames[i])) {
                    found = true;
                    return i;
                }
            }
            if (!found) {
                @compileError("passed in an invalid column");
            }
            unreachable;
        }

        pub fn get_col(self: Self, comptime col: []const u8, row: usize) !Ts[col2i(col)] {
            comptime const idx = col2i(col);
            if (row >= self.len) {
                return error.OutOfBounds;
            }
            return self.cols[idx].items[row];
        }
    };
}
    

export fn add(a: i32, b: i32) i32 {
    return a + b;
}

test "basic add functionality" {
    try testing.expect(add(3, 7) == 10);
}

const Points = Dataframe(2, .{"x", "y"}, .{ []const u8, i32 });

const LinkedList = struct {
    pub const Node = struct {
        prev: ?*Node,
        next: ?*Node,
        data: i32,
    };

    first: ?*Node,
    last: ?*Node,
    len: usize,
};

test "new points" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var alloc = &gpa.allocator;
    var pts = try Points.init(alloc, 10);
    std.debug.assert(pts.len == 0);
    try pts.add_row(.{ .x = "foo", .y = 3 });
    std.debug.assert(pts.len == 1);
    std.debug.assert(std.mem.eql(u8, try pts.get_col("x", 0), "foo"));
    const y1 = try pts.get_col("y",1);
}
