const std = @import("std");
//const croc = std.mem.allocator;
const croc = std.heap.page_allocator;
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

const Bits = struct {
    data: []u64 = undefined,
    and_table: []u64 = undefined,
    or_table: []u64 = undefined,

    const Self = @This();

    // size: number of bits I want
    pub fn init(croc_local: std.mem.Allocator, size: usize, initial_state: bool) !Bits {
        const data_size = (size + 64 - 1) / 64;
        var data = try croc_local.alloc(u64, data_size);
        var and_table = try croc_local.alloc(u64, 64);
        var or_table = try croc_local.alloc(u64, 64);
        var loop: u64 = 1;
        var i: usize = 0;
        while (i < 64) : (i += 1) {
            or_table[i] = loop;
            and_table[i] = 0xffffffffffffffff ^ loop;
            if (i < 63) loop *= 2;
        }
        if (initial_state) {
            std.mem.set(u64, data, 0xffffffffffffffff);
        }
        return Bits{
            .data = data,
            .and_table = and_table,
            .or_table = or_table,
        };
    }

    pub fn get(self: Self, addr: usize) bool {
        const offset = addr / 64;
        const in = addr % 64;
        return self.data[offset] & self.or_table[in] != 0;
    }

    pub fn set(self: Self, addr: usize) void {
        const offset = addr / 64;
        const in = addr % 64;
        self.data[offset] |= self.or_table[in];
    }

    pub fn clear(self: Self, addr: usize) void {
        const offset = addr / 64;
        const in = addr % 64;
        self.data[offset] &= self.and_table[in];
    }
};

test "Bits" {
    var b = try Bits.init(croc, 300, true);
    b.clear(100);
    const g = b.get(0);
    const g100 = b.get(100);
    try std.testing.expectEqual(true, g);
    try std.testing.expectEqual(false, g100);
}

// returns the number of primes
fn sieve_bits(bits: *Bits, max_prime: usize) usize {
    bits.clear(0);
    bits.clear(1);

    var i: usize = 2;
    var sum: usize = 0;
    while (i * i <= max_prime) : (i += 1) {
        if (bits.get(i)) {
            sum += 1;
            var j = i + i;
            while (j <= max_prime) : (j += i) {
                bits.clear(j);
            }
        }
    }
    // sum up the rest, save an "if" compared to the while above
    while (i < max_prime) : (i += 1) {
        if (bits.get(i)) sum += 1;
    }

    return sum;
}

fn primes_slice_p15(bits: *Bits, seed_end: usize, start: usize, end: usize) void {
    var i: usize = 2;
    var counter: usize = 0;
    while (i < seed_end) : (i += 1) {
        if (bits.get(i)) {
            var j = (start + i - 1) / i * i;
            while (j < end) : (j += i) {
                bits.clear(j);
            }
        }
    }
    i = start;
    while (i < end) : (i += 1) {
        if (bits.get(i)) counter += 1;
    }
    // dbg("seed_end: {d}, start: {d}, end: {d}, counter: {d}\n", .{ seed_end, start, end, counter });
}

// max_prime is exclusive the wanted maximum prime number (other than the name suggests)
fn recursive_primes_p15(bits: *Bits, thread_count: usize, max_prime: usize, page_size: usize) std.Thread.SpawnError!usize {
    if (max_prime < page_size) {
        return sieve_bits(bits, max_prime - 1);
    }

    var seed_end: usize = undefined;

    // make sure primes up to sqrt(max_prime) are calculated
    // recursively call self if needed
    var sum: usize = 0;
    if (max_prime > page_size * page_size) {
        seed_end = (max_prime + 1) / thread_count / 8;
        seed_end = seed_end - seed_end % page_size;
        sum += try recursive_primes_p15(bits, thread_count, seed_end, page_size);
    } else {
        seed_end = page_size;
        sum += sieve_bits(bits, seed_end - 1);
    }

    var threads: [32]std.Thread = undefined;

    var slice_size = (max_prime + 1) / thread_count / 8;
    slice_size = page_size + slice_size - slice_size % page_size;
    var start = seed_end;

    while (true) {
        var idx: usize = 0;
        while (idx < thread_count) : (idx += 1) {
            const end = min(start + slice_size, max_prime);
            // o.k. to call this with start == end
            threads[idx] = try std.Thread.spawn(.{}, primes_slice_p15, .{ bits, seed_end, start, end });
            // primes_slice_p15(list, seed_end, start, end);
            start = end;
        }

        idx = 0;
        while (idx < thread_count) : (idx += 1) {
            threads[idx].join();
        }
        if (start == max_prime) {
            break;
        }
    }

    var i = seed_end;
    while (i < max_prime) : (i += 1) {
        if (bits.get(i)) sum += 1;
    }

    return sum;
}

// Sieve, multithreaded
fn p15(max_prime: u64) !void {
    var bits = try Bits.init(croc, max_prime + 1, true);
    var thread_count: usize = 32;
    while (thread_count <= 32) : (thread_count += 4) {
        var page_size: usize = 4096 * 2;
        while (page_size <= 8192 * 64) : (page_size *= 2) {
            timer = std.time.milliTimestamp();

            const sum = try recursive_primes_p15(&bits, thread_count, max_prime + 1, page_size);

            std.debug.print("P15, Time elapsed: {}, sum: {}, max_prime: {s}, thread_count: {}, page_size: {}k\n", .{ time_diff(), sum, print_num(max_prime), thread_count, page_size / 1024 });
        }
    }
}

fn primes_slice_p14(list: []bool, seed_end: usize, start: usize, end: usize, page_size: usize) void {
    var i: usize = 2;
    // var counter: usize = 0;
    var page: usize = 0;
    while (page < seed_end) : (page += page_size) {
        i = page;
        const e2 = if (page + page_size > seed_end) seed_end else page + page_size;
        while (i < e2) : (i += 1) {
            if (list[i]) {
                var j = (start + i - 1) / i * i;
                while (j < end) : (j += i) {
                    list[j] = false;
                }
            }
        }
    }
    // i = start;
    // while (i < end) : (i += 1) {
    //     if (list[i]) counter += 1;
    // }
    // dbg("seed_end: {d}, start: {d}, end: {d}, counter: {d}\n", .{ seed_end, start, end, counter });
}

// max_prime is exclusive the wanted maximum prime number (other than the name suggests)
fn recursive_primes_p14(list: []bool, thread_count: usize, max_prime: usize, page_size: usize) std.Thread.SpawnError!usize {
    if (max_prime < page_size) {
        return sieve(list, max_prime - 1);
    }

    var seed_end: usize = undefined;

    // make sure primes up to sqrt(max_prime) are calculated
    // recursively call self if needed
    var sum: usize = 0;
    if (max_prime > page_size * page_size) {
        seed_end = (max_prime + 1) / thread_count / 8;
        seed_end = seed_end - seed_end % page_size;
        sum += try recursive_primes_p14(list, thread_count, seed_end, page_size);
    } else {
        seed_end = page_size;
        sum += sieve(list, seed_end - 1);
    }

    var threads: [32]std.Thread = undefined;

    // var slice_size = (max_prime + 1) / thread_count / 8;
    var slice_size = page_size;
    // slice_size = page_size + slice_size - slice_size % page_size;
    var start = seed_end;

    while (true) {
        var idx: usize = 0;
        while (idx < thread_count) : (idx += 1) {
            const end = min(start + slice_size, max_prime);
            // o.k. to call this with start == end
            threads[idx] = try std.Thread.spawn(.{}, primes_slice_p14, .{ list, seed_end, start, end, page_size });
            // primes_slice_p13(list, seed_end, start, end);
            start = end;
        }

        idx = 0;
        while (idx < thread_count) : (idx += 1) {
            threads[idx].join();
        }
        if (start == max_prime) {
            break;
        }
    }

    var i = seed_end;
    while (i < max_prime) : (i += 1) {
        if (list[i]) sum += 1;
    }

    return sum;
}

// Sieve, multithreaded
fn p14(max_prime: u64) !void {
    var thread_count: usize = 32;
    while (thread_count <= 32) : (thread_count *= 2) {
        var page_size: usize = 65536 * 2;
        while (page_size <= 65536 * 2) : (page_size *= 2) {
            timer = std.time.milliTimestamp();
            var list = try croc.alloc(bool, max_prime + 1);
            for (list) |_, i| {
                list[i] = true;
            }

            const sum = try recursive_primes_p14(list, thread_count, max_prime + 1, page_size);

            std.debug.print("P14, Time elapsed: {}, sum: {}, max_prime: {s}, thread_count: {}, page_size: {}\n", .{ time_diff(), sum, print_num(max_prime), thread_count, page_size });
        }
    }
}

fn primes_slice_p13(list: []bool, seed_end: usize, start: usize, end: usize) void {
    var i: usize = 2;
    var counter: usize = 0;
    while (i < seed_end) : (i += 1) {
        if (list[i]) {
            var j = (start + i - 1) / i * i;
            while (j < end) : (j += i) {
                list[j] = false;
            }
        }
    }
    i = start;
    while (i < end) : (i += 1) {
        if (list[i]) counter += 1;
    }
    // dbg("seed_end: {d}, start: {d}, end: {d}, counter: {d}\n", .{ seed_end, start, end, counter });
}

// max_prime is exclusive the wanted maximum prime number (other than the name suggests)
fn recursive_primes_p13(list: []bool, thread_count: usize, max_prime: usize, page_size: usize) std.Thread.SpawnError!usize {
    if (max_prime < page_size) {
        return sieve(list, max_prime - 1);
    }

    var seed_end: usize = undefined;

    // make sure primes up to sqrt(max_prime) are calculated
    // recursively call self if needed
    var sum: usize = 0;
    if (max_prime > page_size * page_size) {
        seed_end = (max_prime + 1) / thread_count / 8;
        seed_end = seed_end - seed_end % page_size;
        sum += try recursive_primes_p13(list, thread_count, seed_end, page_size);
    } else {
        seed_end = page_size;
        sum += sieve(list, seed_end - 1);
    }

    var threads: [32]std.Thread = undefined;

    var slice_size = (max_prime + 1) / thread_count / 8;
    slice_size = page_size + slice_size - slice_size % page_size;
    var start = seed_end;

    while (true) {
        var idx: usize = 0;
        while (idx < thread_count) : (idx += 1) {
            const end = min(start + slice_size, max_prime);
            // o.k. to call this with start == end
            threads[idx] = try std.Thread.spawn(.{}, primes_slice_p13, .{ list, seed_end, start, end });
            // primes_slice_p13(list, seed_end, start, end);
            start = end;
        }

        idx = 0;
        while (idx < thread_count) : (idx += 1) {
            threads[idx].join();
        }
        if (start == max_prime) {
            break;
        }
    }

    var i = seed_end;
    while (i < max_prime) : (i += 1) {
        if (list[i]) sum += 1;
    }

    return sum;
}

// Sieve, multithreaded
fn p13(max_prime: u64) !void {
    var thread_count: usize = 32;
    while (thread_count <= 32) : (thread_count += 4) {
        var page_size: usize = 8192;
        while (page_size <= 8192) : (page_size *= 2) {
            timer = std.time.milliTimestamp();
            var list = try croc.alloc(bool, max_prime + 1);
            for (list) |_, i| {
                list[i] = true;
            }

            const sum = try recursive_primes_p13(list, thread_count, max_prime + 1, page_size);

            std.debug.print("P13, Time elapsed: {}, sum: {}, max_prime: {s}, thread_count: {}, page_size: {}\n", .{ time_diff(), sum, print_num(max_prime), thread_count, page_size });
        }
    }
}

// returns the number of primes
fn sieve(list: []bool, max_prime: usize) usize {
    list[0] = false;
    list[1] = false;

    var i: usize = 2;
    var sum: usize = 0;
    while (i * i <= max_prime) : (i += 1) {
        if (list[i]) {
            sum += 1;
            var j = i + i;
            while (j <= max_prime) : (j += i) {
                list[j] = false;
            }
        }
    }
    // sum up the rest, save an "if" compared to the while above
    while (i < max_prime) : (i += 1) {
        if (list[i]) sum += 1;
    }

    return sum;
}

// Sieve of Eratosthenes
fn p10(max_prime: u64) !void {
    timer = std.time.milliTimestamp();
    var list = try croc.alloc(bool, max_prime + 1);
    for (list) |_, i| {
        list[i] = true;
    }

    const sum = sieve(list, max_prime);

    std.debug.print("P10: Time elapsed: {}, sum: {}, max_prime: {s}\n", .{ time_diff(), sum, print_num(max_prime) });
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

    std.debug.print("P9: Time elapsed: {}, sum: {}, max_prime: {s}\n", .{ time_diff(), sum, print_num(max_prime) });

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
    std.debug.print("P6: Time elapsed: {}, sum: {}, max_prime: {s}\n", .{ time_elapsed, sum, print_num(max_prime) });
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
    std.debug.print("P5: Time elapsed: {}, sum: {}, max_prime: {s}\n", .{ time_elapsed, sum, print_num(max_prime) });
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
    std.debug.print("P3: Time elapsed: {}, sum: {}, max_prime: {s}\n", .{ time_elapsed, sum, print_num(max_prime) });
}

fn p1(max_prime: u64) void {
    var time_start = std.time.milliTimestamp();

    var sum: u64 = 0;
    var i: u64 = 1;
    while (i < max_prime) : (i += 1) {
        sum += Primes.isPrime(i);
    }

    var time_elapsed = std.time.milliTimestamp() - time_start;
    std.debug.print("P1: Time elapsed: {}, sum: {}, max_prime: {s}\n", .{ time_elapsed, sum, print_num(max_prime) });
}

var line: std.ArrayList(u8) = undefined;
fn print_num(n: usize) ![]const u8 {
    try line.resize(0);
    if (n > 10_000_000_000) {
        try line.writer().print("{d}G", .{n / 1_000_000_000});
    } else if (n > 10_000_000) {
        try line.writer().print("{d}M", .{n / 1_000_000});
    } else if (n > 10_000) {
        try line.writer().print("{d}K", .{n / 1_000});
    } else {
        try line.writer().print("{d}", .{n});
    }
    return line.items;
}

pub fn main() anyerror!void {
    line = std.ArrayList(u8).init(croc);
    defer line.deinit();
    // const num = 3_000_000_000;
    // const num = 300_000_000;
    // const num = 30_000_000;
    const num = 3_000_000;
    // const num = 300;
    dbg("starting...\n", .{});
    try p15(num);
    try p13(num);
    try p10(num);
    if (num <= 3_000_000) {
        try p9(num);
        try p6(num);
        try p5(num);
        try p3(num);
        p1(num);
    }
}
