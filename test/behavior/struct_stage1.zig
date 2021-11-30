const std = @import("std");
const builtin = @import("builtin");
const native_endian = builtin.target.cpu.arch.endian();
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectEqualSlices = std.testing.expectEqualSlices;
const maxInt = std.math.maxInt;

const StructFoo = struct {
    a: i32,
    b: bool,
    c: f32,
};

const Node = struct {
    val: Val,
    next: *Node,
};

const Val = struct {
    x: i32,
};

test "empty struct method call" {
    const es = EmptyStruct{};
    try expect(es.method() == 1234);
}
const EmptyStruct = struct {
    fn method(es: *const EmptyStruct) i32 {
        _ = es;
        return 1234;
    }
};

const EmptyStruct2 = struct {};
fn testReturnEmptyStructFromFn() EmptyStruct2 {
    return EmptyStruct2{};
}

const APackedStruct = packed struct {
    x: u8,
    y: u8,
};

test "packed struct" {
    var foo = APackedStruct{
        .x = 1,
        .y = 2,
    };
    foo.y += 1;
    const four = foo.x + foo.y;
    try expect(four == 4);
}

const BitField1 = packed struct {
    a: u3,
    b: u3,
    c: u2,
};

const bit_field_1 = BitField1{
    .a = 1,
    .b = 2,
    .c = 3,
};

test "bit field access" {
    var data = bit_field_1;
    try expect(getA(&data) == 1);
    try expect(getB(&data) == 2);
    try expect(getC(&data) == 3);
    comptime try expect(@sizeOf(BitField1) == 1);

    data.b += 1;
    try expect(data.b == 3);

    data.a += 1;
    try expect(data.a == 2);
    try expect(data.b == 3);
}

fn getA(data: *const BitField1) u3 {
    return data.a;
}

fn getB(data: *const BitField1) u3 {
    return data.b;
}

fn getC(data: *const BitField1) u2 {
    return data.c;
}

const Foo24Bits = packed struct {
    field: u24,
};
const Foo96Bits = packed struct {
    a: u24,
    b: u24,
    c: u24,
    d: u24,
};

test "packed struct 24bits" {
    comptime {
        try expect(@sizeOf(Foo24Bits) == 4);
        if (@sizeOf(usize) == 4) {
            try expect(@sizeOf(Foo96Bits) == 12);
        } else {
            try expect(@sizeOf(Foo96Bits) == 16);
        }
    }

    var value = Foo96Bits{
        .a = 0,
        .b = 0,
        .c = 0,
        .d = 0,
    };
    value.a += 1;
    try expect(value.a == 1);
    try expect(value.b == 0);
    try expect(value.c == 0);
    try expect(value.d == 0);

    value.b += 1;
    try expect(value.a == 1);
    try expect(value.b == 1);
    try expect(value.c == 0);
    try expect(value.d == 0);

    value.c += 1;
    try expect(value.a == 1);
    try expect(value.b == 1);
    try expect(value.c == 1);
    try expect(value.d == 0);

    value.d += 1;
    try expect(value.a == 1);
    try expect(value.b == 1);
    try expect(value.c == 1);
    try expect(value.d == 1);
}

const Foo32Bits = packed struct {
    field: u24,
    pad: u8,
};

const FooArray24Bits = packed struct {
    a: u16,
    b: [2]Foo32Bits,
    c: u16,
};

// TODO revisit this test when doing https://github.com/ziglang/zig/issues/1512
test "packed array 24bits" {
    comptime {
        try expect(@sizeOf([9]Foo32Bits) == 9 * 4);
        try expect(@sizeOf(FooArray24Bits) == 2 + 2 * 4 + 2);
    }

    var bytes = [_]u8{0} ** (@sizeOf(FooArray24Bits) + 1);
    bytes[bytes.len - 1] = 0xaa;
    const ptr = &std.mem.bytesAsSlice(FooArray24Bits, bytes[0 .. bytes.len - 1])[0];
    try expect(ptr.a == 0);
    try expect(ptr.b[0].field == 0);
    try expect(ptr.b[1].field == 0);
    try expect(ptr.c == 0);

    ptr.a = maxInt(u16);
    try expect(ptr.a == maxInt(u16));
    try expect(ptr.b[0].field == 0);
    try expect(ptr.b[1].field == 0);
    try expect(ptr.c == 0);

    ptr.b[0].field = maxInt(u24);
    try expect(ptr.a == maxInt(u16));
    try expect(ptr.b[0].field == maxInt(u24));
    try expect(ptr.b[1].field == 0);
    try expect(ptr.c == 0);

    ptr.b[1].field = maxInt(u24);
    try expect(ptr.a == maxInt(u16));
    try expect(ptr.b[0].field == maxInt(u24));
    try expect(ptr.b[1].field == maxInt(u24));
    try expect(ptr.c == 0);

    ptr.c = maxInt(u16);
    try expect(ptr.a == maxInt(u16));
    try expect(ptr.b[0].field == maxInt(u24));
    try expect(ptr.b[1].field == maxInt(u24));
    try expect(ptr.c == maxInt(u16));

    try expect(bytes[bytes.len - 1] == 0xaa);
}

const FooStructAligned = packed struct {
    a: u8,
    b: u8,
};

const FooArrayOfAligned = packed struct {
    a: [2]FooStructAligned,
};

test "aligned array of packed struct" {
    comptime {
        try expect(@sizeOf(FooStructAligned) == 2);
        try expect(@sizeOf(FooArrayOfAligned) == 2 * 2);
    }

    var bytes = [_]u8{0xbb} ** @sizeOf(FooArrayOfAligned);
    const ptr = &std.mem.bytesAsSlice(FooArrayOfAligned, bytes[0..])[0];

    try expect(ptr.a[0].a == 0xbb);
    try expect(ptr.a[0].b == 0xbb);
    try expect(ptr.a[1].a == 0xbb);
    try expect(ptr.a[1].b == 0xbb);
}

test "runtime struct initialization of bitfield" {
    const s1 = Nibbles{
        .x = x1,
        .y = x1,
    };
    const s2 = Nibbles{
        .x = @intCast(u4, x2),
        .y = @intCast(u4, x2),
    };

    try expect(s1.x == x1);
    try expect(s1.y == x1);
    try expect(s2.x == @intCast(u4, x2));
    try expect(s2.y == @intCast(u4, x2));
}

var x1 = @as(u4, 1);
var x2 = @as(u8, 2);

const Nibbles = packed struct {
    x: u4,
    y: u4,
};

const Bitfields = packed struct {
    f1: u16,
    f2: u16,
    f3: u8,
    f4: u8,
    f5: u4,
    f6: u4,
    f7: u8,
};

test "native bit field understands endianness" {
    var all: u64 = if (native_endian != .Little)
        0x1111222233445677
    else
        0x7765443322221111;
    var bytes: [8]u8 = undefined;
    @memcpy(&bytes, @ptrCast([*]u8, &all), 8);
    var bitfields = @ptrCast(*Bitfields, &bytes).*;

    try expect(bitfields.f1 == 0x1111);
    try expect(bitfields.f2 == 0x2222);
    try expect(bitfields.f3 == 0x33);
    try expect(bitfields.f4 == 0x44);
    try expect(bitfields.f5 == 0x5);
    try expect(bitfields.f6 == 0x6);
    try expect(bitfields.f7 == 0x77);
}

test "align 1 field before self referential align 8 field as slice return type" {
    const result = alloc(Expr);
    try expect(result.len == 0);
}

const Expr = union(enum) {
    Literal: u8,
    Question: *Expr,
};

fn alloc(comptime T: type) []T {
    return &[_]T{};
}

test "implicit cast packed struct field to const ptr" {
    const LevelUpMove = packed struct {
        move_id: u9,
        level: u7,

        fn toInt(value: u7) u7 {
            return value;
        }
    };

    var lup: LevelUpMove = undefined;
    lup.level = 12;
    const res = LevelUpMove.toInt(lup.level);
    try expect(res == 12);
}

test "pointer to packed struct member in a stack variable" {
    const S = packed struct {
        a: u2,
        b: u2,
    };

    var s = S{ .a = 2, .b = 0 };
    var b_ptr = &s.b;
    try expect(s.b == 0);
    b_ptr.* = 2;
    try expect(s.b == 2);
}

test "non-byte-aligned array inside packed struct" {
    const Foo = packed struct {
        a: bool,
        b: [0x16]u8,
    };
    const S = struct {
        fn bar(slice: []const u8) !void {
            try expectEqualSlices(u8, slice, "abcdefghijklmnopqurstu");
        }
        fn doTheTest() !void {
            var foo = Foo{
                .a = true,
                .b = "abcdefghijklmnopqurstu".*,
            };
            const value = foo.b;
            try bar(&value);
        }
    };
    try S.doTheTest();
    comptime try S.doTheTest();
}

test "packed struct with u0 field access" {
    const S = packed struct {
        f0: u0,
    };
    var s = S{ .f0 = 0 };
    comptime try expect(s.f0 == 0);
}

const S0 = struct {
    bar: S1,

    pub const S1 = struct {
        value: u8,
    };

    fn init() @This() {
        return S0{ .bar = S1{ .value = 123 } };
    }
};

var g_foo: S0 = S0.init();

test "access to global struct fields" {
    g_foo.bar.value = 42;
    try expect(g_foo.bar.value == 42);
}

test "packed struct with fp fields" {
    const S = packed struct {
        data: [3]f32,

        pub fn frob(self: *@This()) void {
            self.data[0] += self.data[1] + self.data[2];
            self.data[1] += self.data[0] + self.data[2];
            self.data[2] += self.data[0] + self.data[1];
        }
    };

    var s: S = undefined;
    s.data[0] = 1.0;
    s.data[1] = 2.0;
    s.data[2] = 3.0;
    s.frob();
    try expectEqual(@as(f32, 6.0), s.data[0]);
    try expectEqual(@as(f32, 11.0), s.data[1]);
    try expectEqual(@as(f32, 20.0), s.data[2]);
}

test "default struct initialization fields" {
    const S = struct {
        a: i32 = 1234,
        b: i32,
    };
    const x = S{
        .b = 5,
    };
    var five: i32 = 5;
    const y = S{
        .b = five,
    };
    if (x.a + x.b != 1239) {
        @compileError("it should be comptime known");
    }
    try expectEqual(y, x);
    try expectEqual(1239, x.a + x.b);
}

test "fn with C calling convention returns struct by value" {
    const S = struct {
        fn entry() !void {
            var x = makeBar(10);
            try expectEqual(@as(i32, 10), x.handle);
        }

        const ExternBar = extern struct {
            handle: i32,
        };

        fn makeBar(t: i32) callconv(.C) ExternBar {
            return ExternBar{
                .handle = t,
            };
        }
    };
    try S.entry();
    comptime try S.entry();
}

test "zero-bit field in packed struct" {
    const S = packed struct {
        x: u10,
        y: void,
    };
    var x: S = undefined;
    _ = x;
}

test "packed struct with non-ABI-aligned field" {
    const S = packed struct {
        x: u9,
        y: u183,
    };
    var s: S = undefined;
    s.x = 1;
    s.y = 42;
    try expect(s.x == 1);
    try expect(s.y == 42);
}

test "non-packed struct with u128 entry in union" {
    const U = union(enum) {
        Num: u128,
        Void,
    };

    const S = struct {
        f1: U,
        f2: U,
    };

    var sx: S = undefined;
    var s = &sx;
    try std.testing.expect(@ptrToInt(&s.f2) - @ptrToInt(&s.f1) == @offsetOf(S, "f2"));
    var v2 = U{ .Num = 123 };
    s.f2 = v2;
    try std.testing.expect(s.f2.Num == 123);
}

test "packed struct field passed to generic function" {
    const S = struct {
        const P = packed struct {
            b: u5,
            g: u5,
            r: u5,
            a: u1,
        };

        fn genericReadPackedField(ptr: anytype) u5 {
            return ptr.*;
        }
    };

    var p: S.P = undefined;
    p.b = 29;
    var loaded = S.genericReadPackedField(&p.b);
    try expect(loaded == 29);
}

test "anonymous struct literal syntax" {
    const S = struct {
        const Point = struct {
            x: i32,
            y: i32,
        };

        fn doTheTest() !void {
            var p: Point = .{
                .x = 1,
                .y = 2,
            };
            try expect(p.x == 1);
            try expect(p.y == 2);
        }
    };
    try S.doTheTest();
    comptime try S.doTheTest();
}

test "fully anonymous struct" {
    const S = struct {
        fn doTheTest() !void {
            try dump(.{
                .int = @as(u32, 1234),
                .float = @as(f64, 12.34),
                .b = true,
                .s = "hi",
            });
        }
        fn dump(args: anytype) !void {
            try expect(args.int == 1234);
            try expect(args.float == 12.34);
            try expect(args.b);
            try expect(args.s[0] == 'h');
            try expect(args.s[1] == 'i');
        }
    };
    try S.doTheTest();
    comptime try S.doTheTest();
}

test "fully anonymous list literal" {
    const S = struct {
        fn doTheTest() !void {
            try dump(.{ @as(u32, 1234), @as(f64, 12.34), true, "hi" });
        }
        fn dump(args: anytype) !void {
            try expect(args.@"0" == 1234);
            try expect(args.@"1" == 12.34);
            try expect(args.@"2");
            try expect(args.@"3"[0] == 'h');
            try expect(args.@"3"[1] == 'i');
        }
    };
    try S.doTheTest();
    comptime try S.doTheTest();
}

test "anonymous struct literal assigned to variable" {
    var vec = .{ @as(i32, 22), @as(i32, 55), @as(i32, 99) };
    try expect(vec.@"0" == 22);
    try expect(vec.@"1" == 55);
    try expect(vec.@"2" == 99);
}

test "struct with var field" {
    const Point = struct {
        x: anytype,
        y: anytype,
    };
    const pt = Point{
        .x = 1,
        .y = 2,
    };
    try expect(pt.x == 1);
    try expect(pt.y == 2);
}

test "comptime struct field" {
    const T = struct {
        a: i32,
        comptime b: i32 = 1234,
    };

    var foo: T = undefined;
    comptime try expect(foo.b == 1234);
}

test "anon struct literal field value initialized with fn call" {
    const S = struct {
        fn doTheTest() !void {
            var x = .{foo()};
            try expectEqualSlices(u8, x[0], "hi");
        }
        fn foo() []const u8 {
            return "hi";
        }
    };
    try S.doTheTest();
    comptime try S.doTheTest();
}

test "struct with union field" {
    const Value = struct {
        ref: u32 = 2,
        kind: union(enum) {
            None: usize,
            Bool: bool,
        },
    };

    var True = Value{
        .kind = .{ .Bool = true },
    };
    try expectEqual(@as(u32, 2), True.ref);
    try expectEqual(true, True.kind.Bool);
}

test "type coercion of anon struct literal to struct" {
    const S = struct {
        const S2 = struct {
            A: u32,
            B: []const u8,
            C: void,
            D: Foo = .{},
        };

        const Foo = struct {
            field: i32 = 1234,
        };

        fn doTheTest() !void {
            var y: u32 = 42;
            const t0 = .{ .A = 123, .B = "foo", .C = {} };
            const t1 = .{ .A = y, .B = "foo", .C = {} };
            const y0: S2 = t0;
            var y1: S2 = t1;
            try expect(y0.A == 123);
            try expect(std.mem.eql(u8, y0.B, "foo"));
            try expect(y0.C == {});
            try expect(y0.D.field == 1234);
            try expect(y1.A == y);
            try expect(std.mem.eql(u8, y1.B, "foo"));
            try expect(y1.C == {});
            try expect(y1.D.field == 1234);
        }
    };
    try S.doTheTest();
    comptime try S.doTheTest();
}

test "type coercion of pointer to anon struct literal to pointer to struct" {
    const S = struct {
        const S2 = struct {
            A: u32,
            B: []const u8,
            C: void,
            D: Foo = .{},
        };

        const Foo = struct {
            field: i32 = 1234,
        };

        fn doTheTest() !void {
            var y: u32 = 42;
            const t0 = &.{ .A = 123, .B = "foo", .C = {} };
            const t1 = &.{ .A = y, .B = "foo", .C = {} };
            const y0: *const S2 = t0;
            var y1: *const S2 = t1;
            try expect(y0.A == 123);
            try expect(std.mem.eql(u8, y0.B, "foo"));
            try expect(y0.C == {});
            try expect(y0.D.field == 1234);
            try expect(y1.A == y);
            try expect(std.mem.eql(u8, y1.B, "foo"));
            try expect(y1.C == {});
            try expect(y1.D.field == 1234);
        }
    };
    try S.doTheTest();
    comptime try S.doTheTest();
}

test "packed struct with undefined initializers" {
    const S = struct {
        const P = packed struct {
            a: u3,
            _a: u3 = undefined,
            b: u3,
            _b: u3 = undefined,
            c: u3,
            _c: u3 = undefined,
        };

        fn doTheTest() !void {
            var p: P = undefined;
            p = P{ .a = 2, .b = 4, .c = 6 };
            // Make sure the compiler doesn't touch the unprefixed fields.
            // Use expect since i386-linux doesn't like expectEqual
            try expect(p.a == 2);
            try expect(p.b == 4);
            try expect(p.c == 6);
        }
    };

    try S.doTheTest();
    comptime try S.doTheTest();
}
