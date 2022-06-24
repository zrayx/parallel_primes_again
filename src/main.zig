const std = @import("std");
const croc = std.testing.allocator;
const dbg = std.debug.print;

const Primes = struct {
    primes: std.ArrayList(u64),

    const Self = @This();

    pub fn init() !Primes {
        var primes = Primes{
            .primes = std.ArrayList(u64).init(croc),
        };
        try primes.primes.append(2);
        try primes.primes.append(3);
        try primes.primes.append(5);
        try primes.primes.append(7);
        try primes.primes.append(11);
        try primes.primes.append(13);
        return primes;
    }

    fn len(self: Self) u64 {
        return self.primes.items.len;
    }

    fn last(self: Self) u64 {
        const l = self.primes.items.len;
        return self.primes.items[l - 1];
    }

    fn deinit(self: Self) void {
        self.primes.deinit();
    }

    fn isPrime(n: u64) u64 {
        if (n < 3) return 1;
        var i: u64 = 2;
        while (i * i <= n) : (i += 1) {
            if (n % i == 0) return 0;
        }
        return 1;
    }

    fn toPrime(self: *Self, n: u64) !u64 {
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

        for (self.primes.items) |p| {
            // dbg("n: {d}, i: {d}\n", .{ n, i });
            //dbg("c1: testing {d}%{d} at {d}\n", .{ n, p, i });
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

    // list must be empty
    fn prime_slice_thread(self: *Self, start: u64, end: u64, list: *std.ArrayList(u64)) !void {
        var i = start;
        // dbg("b1 start: {d}, end: {d}, self.primes.len: {d}\n", .{ start, end, self.primes.items.len });
        while (i < end) : (i += 2) {
            try self.is_prime_store(i, list);
        }
        return;
    }

    fn prime_slice_store(self: *Self, v: []const u64) !void {
        try self.primes.appendSlice(v);
    }
};

var timer: i64 = undefined;
fn time_diff() i64 {
    return std.time.milliTimestamp() - timer;
}

fn p9_thread(primes: *Primes, start: u64, end: u64, list: *std.ArrayList(u64)) !void {
    return primes.prime_slice_thread(start, end, list);
}

// memoization in 1 thread
fn p9(max_prime: u64) !void {
    timer = std.time.milliTimestamp();

    var sum: u64 = 6;
    var primes = try Primes.init();
    defer primes.deinit();

    const STEP_SIZE: u64 = 6000000;
    const MAX_THREADS: u64 = 32;
    const THREADS: u64 = 32;

    var last: u64 = 15; // primes up to 13 are already stored
    var list: [MAX_THREADS]std.ArrayList(u64) = undefined;
    var threads: [MAX_THREADS]std.Thread = undefined;

    var i: usize = 0;
    while (i < MAX_THREADS) : (i += 1) {
        list[i] = std.ArrayList(u64).init(croc);
    }

    while (last < max_prime) {
        const step_to_max = max((max_prime - last) / THREADS, 50);
        const step_root = (last * last - last) / THREADS;
        const step = max(min(min(step_to_max, step_root), STEP_SIZE), 40) & 0xfffffffffffffffe;
        i = 0;
        while (i < THREADS) : (i += 1) {
            try list[i].resize(0);
            threads[i] = try std.Thread.spawn(.{}, p9_thread, .{ &primes, last, last + step, &list[i] });
            last = min(last + step, max_prime + 2 - step);
        }

        i = 0;
        while (i < THREADS) : (i += 1) {
            threads[i].join();
            sum += list[i].items.len;
        }

        i = 0;
        while (i < THREADS) : (i += 1) {
            try primes.prime_slice_store(list[i].items);
        }

        last = primes.last();
    }

    std.debug.print("P9: Time elapsed: {}, sum: {}, max_prime: {}\n", .{ time_diff(), sum, max_prime });

    i = 0;
    for (list) |j| {
        j.deinit();
    }
}

fn p6_thread(primes: *Primes, start: u64, end: u64, list: *std.ArrayList(u64)) !void {
    return primes.prime_slice_thread(start, end, list);
}

// memoization in 1 thread
fn p6(max_prime: u64) !void {
    var time_start = std.time.milliTimestamp();

    var sum: u64 = 6;
    var primes = try Primes.init();
    defer primes.deinit();

    const STEP_SIZE: u64 = 3000;
    const THREADS: u64 = 4;
    var last: u64 = 15; // primes up to 13 are already stored
    var list = std.ArrayList(u64).init(croc);
    defer list.deinit();

    while (last < max_prime) {
        try list.resize(0);
        const step_to_max = (max_prime - last) / THREADS;
        const step_root = (last * last - last) / THREADS;
        const step = max(min(min(step_to_max, step_root), STEP_SIZE), 4) & 0xfffffffffffffffe;

        const thread = try std.Thread.spawn(.{}, p6_thread, .{ &primes, last, last + step, &list });
        thread.join();

        last += step;
        sum += list.items.len;
        try primes.prime_slice_store(list.items);
    }

    var time_elapsed = std.time.milliTimestamp() - time_start;
    std.debug.print("P6: Time elapsed: {}, sum: {}, max_prime: {}\n", .{ time_elapsed, sum, max_prime });
}

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
        sum += try primes.toPrime(i);
    }

    var time_elapsed = std.time.milliTimestamp() - time_start;
    std.debug.print("P3: Time elapsed: {}, sum: {}, max_prime: {}\n", .{ time_elapsed, sum, max_prime });
}

fn p1(max_prime: u64) void {
    var time_start = std.time.milliTimestamp();

    var sum: u64 = 0;
    var i: u64 = 1;
    while (i < max_prime) : (i += 1) {
        sum += Primes.isPrime(i);
    }

    var time_elapsed = std.time.milliTimestamp() - time_start;
    std.debug.print("P1: Time elapsed: {}, sum: {}, max_prime: {}\n", .{ time_elapsed, sum, max_prime });
}

pub fn main() anyerror!void {
    const num = 30_000_000;
    try p9(num);
    try p6(num);
    try p5(num);
    try p3(num);
    p1(num);
}

test "basic test" {
    try std.testing.expectEqual(10, 3 + 7);
}
