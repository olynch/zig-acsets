const std = @import("std");
const testing = std.testing;
const print = std.debug.print;
const TypeInfo = std.builtin.TypeInfo;
const Allocator = std.mem.Allocator;

fn pi_type(comptime n: usize, comptime fnames: [n]([]const u8), comptime Ts: [n]type) type {
    comptime const fields: [n]TypeInfo.StructField = comptime init: {
        var tmp: [n]TypeInfo.StructField = undefined;
        for (tmp) |*field, i| {
            field.* = .{
                .name = fnames[i],
                .field_type = Ts[i],
                .default_value = null,
                .is_comptime = false,
                .alignment = @alignOf(Ts[i])
            };
        }
        break :init tmp;
    };
    comptime const decls: [0]TypeInfo.Declaration = .{};
    comptime const s: TypeInfo.Struct = .{
        .layout = TypeInfo.ContainerLayout.Auto,
        .fields = &fields,
        .decls = &decls,
        .is_tuple = true,
    };
    return @Type(TypeInfo { .Struct = s});
}

fn Dataframe(comptime n: usize, comptime fnames: [n]([]const u8), comptime Ts: [n]type) type {
    comptime const array_Ts: [n]type = comptime init: {
        var tmp: [n]type = undefined;
        inline for (tmp) |*T, i| {
            T.* = std.ArrayListUnmanaged(Ts[i]);
        }
        break :init tmp;
    };

    comptime const cols_t: type = pi_type(n, fnames, array_Ts);
    comptime const row_t: type = pi_type(n, fnames, Ts);

    return struct {
        const Self = @This();
        cols: cols_t,
        len: usize,
        alloc: *Allocator,

        pub fn init(alloc: *Allocator, capacity: usize) !Self {
            const cols: cols_t = init: {
                var tmp: cols_t = undefined;
                inline for (fnames) |_fname, i| {
                    tmp[i] = try std.ArrayListUnmanaged(Ts[i]).initCapacity(alloc, capacity);
                }
                break :init tmp;
            };

            return Self{
                .cols = cols,
                .len = 0,
                .alloc = alloc
            };
        }

        pub fn add_row(self: *Self, row: row_t) !void {
            inline for (fnames) |_fname, i| {
                try self.cols[i].append(self.alloc, row[i]);
            }
            self.len += 1;
        }

        fn col2i(comptime col: []const u8) usize {
            comptime var found = false;
            inline for (fnames) |fname, i| {
                if (std.mem.eql(u8, col, fname)) {
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
    

const Points = Dataframe(2, .{"x", "y"}, .{ []const u8, i32 });

test "new points" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var alloc = &gpa.allocator;
    var pts = try Points.init(alloc, 10);
    std.debug.assert(pts.len == 0);
    try pts.add_row(.{ .x = "foo", .y = 3 });
    std.debug.assert(pts.len == 1);
    std.debug.assert(std.mem.eql(u8, try pts.get_col("x", 0), "foo"));
    const y1 = try pts.get_col("y", 0);
}
