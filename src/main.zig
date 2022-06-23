const std = @import("std");
const croc = std.testing.allocator;

const Primes = struct {
    primes: std.ArrayList(u64),

    const Self = @This();

    pub fn init() !Primes {
        var primes = Primes{ .primes = std.ArrayList(u64).init(croc) };
        try primes.primes.append(2);
        try primes.primes.append(3);
        try primes.primes.append(5);
        try primes.primes.append(7);
        try primes.primes.append(11);
        try primes.primes.append(13);
        return primes;
    }

    fn deinit(self: Self) void {
        self.primes.deinit();
    }

    fn is_prime1(n: u64) u64 {
        if (n < 3) return 1;
        var i: u64 = 2;
        while (i * i <= n) : (i += 1) {
            if (n % i == 0) return 0;
        }
        return 1;
    }

    fn to_prime(self: *Self, n: u64) !u64 {
        if (n <= 1)
            return 0;
        if (n > 1 and n <= 3) {
            try self.primes.append(n);
            return 1;
        }

        var i: usize = 0;
        while (true) : (i += 1) {
            const p = self.primes.items[i];
            if (p * p > n) break;
            if (n % p == 0) return 0;
        }
        try self.primes.append(n);
        return 1;
    }

    fn is_prime_store(self: Self, n: u64, list: *std.ArrayList(u64)) !void {
        if (n <= 1)
            return;
        if (n > 1 and n <= 3) {
            try list.append(n);
            return;
        }

        var i: usize = 0;
        while (true) : (i += 1) {
            const p = self.primes.items[i];
            if (p * p > n) break;
            if (n % p == 0) return;
        }
        try list.append(n);
    }

    fn prime_slice(self: *Self, start: u64, end: u64) !std.ArrayList(u64) {
        var list = std.ArrayList(u64).init(croc);
        var i = start;
        while (i < end) : (i += 2) {
            try self.is_prime_store(i, &list);
        }
        return list;
    }

    fn prime_slice_store(self: *Self, v: []const u64) !void {
        try self.primes.appendSlice(v);
    }
};

fn p5(max_prime: u64) !void {
    var time_start = std.time.milliTimestamp();

    var sum: u64 = 6;
    var primes = try Primes.init();
    defer primes.deinit();

    const STEP_SIZE: u64 = 3000;
    const THREADS: u64 = 4;
    var last: u64 = 15; // primes up to 13 are already stored

    while (last < max_prime) {
        const step_to_max = (max_prime - last) / THREADS;
        const step_root = (last * last - last) / THREADS;
        const step = max(min(min(step_to_max, step_root), STEP_SIZE), 4) & 0xfffffffffffffffe;
        const v = try primes.prime_slice(last, last + step);
        defer v.deinit();
        last += step;
        sum += v.items.len;
        try primes.prime_slice_store(v.items);
    }

    var time_elapsed = std.time.milliTimestamp() - time_start;
    std.debug.print("P5: Time elapsed: {}, sum: {}, max_prime: {}\n", .{ time_elapsed, sum, max_prime });
}

fn min(a: u64, b: u64) u64 {
    return if (a > b) b else a;
}

fn max(a: u64, b: u64) u64 {
    return if (a < b) b else a;
}

fn p3(max_prime: u64) !void {
    var time_start = std.time.milliTimestamp();

    var sum: u64 = 6;
    var i: u64 = 5;
    var primes = try Primes.init();
    defer primes.deinit();

    while (i < max_prime) : (i += 1) {
        sum += try primes.to_prime(i);
    }

    var time_elapsed = std.time.milliTimestamp() - time_start;
    std.debug.print("P3: Time elapsed: {}, sum: {}, max_prime: {}\n", .{ time_elapsed, sum, max_prime });
}

fn p1(max_prime: u64) void {
    var time_start = std.time.milliTimestamp();

    var sum: u64 = 0;
    var i: u64 = 1;
    while (i < max_prime) : (i += 1) {
        sum += Primes.is_prime1(i);
    }

    var time_elapsed = std.time.milliTimestamp() - time_start;
    std.debug.print("P1: Time elapsed: {}, sum: {}, max_prime: {}\n", .{ time_elapsed, sum, max_prime });
}

pub fn main() anyerror!void {
    try p5(3_000_000);
    try p3(3_000_000);
    p1(3_000_000);
}

test "basic test" {
    try std.testing.expectEqual(10, 3 + 7);
}
