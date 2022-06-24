# parallel_primes_again

Compare Zig and Rust, see also my Rust implementation: https://github.com/zrayx/parallel_primes

At the moment I wouldn't be able to decide which to chose for a larger hobby project.

Zig pros:
* Legibility
  * The source code of the standard library is very readable
* Much easier to implement code
* More fun to code in, not as much fighting the language
* Embedded programming actually viable

Zig cons:
* Documentation
  * Still early work in progress
  * Being able to read the standard library and other people's code makes it much less of an issue
* Tool support
  * Couldn't get zls/debugging to work out of the box in vim or vs code.
* A hair slower than rust for very similar code
* Language not yet stable
* shadowing of variables not allowed: no local variable max if there is a global function called max
* no closures
* slow compile
* no for loop

Performance
===========
Turns out that Zig is about 15% slower than Rust. The algorithms P1-P9 are similarly implemented between Zig and Rust. P9 does a bit less of copying bytes around than P8, which makes in a few ms faster for primes up to 30M, but not enough to match the speed of Rust.

Zig:
```
P1: Time elapsed: 12396, sum: 1857860, max_prime: 30000000
P3: Time elapsed: 1922, sum: 1857863, max_prime: 30000000
P5: Time elapsed: 2038, sum: 1857859, max_prime: 30000000
P6: Time elapsed: 2257, sum: 1857859, max_prime: 30000000
P9: Time elapsed: 162, sum: 1857910, max_prime: 30000000
```
Rust (see https://github.com/zrayx/parallel_primes):
```
P1: Time elapsed: 10750, sum: 1857860, max: 30000000
P2: Time elapsed: 10688, sum: 1857859, max: 30000000
P3: Time elapsed: 1693, sum: 1857859, max: 30000000
P4: Time elapsed: 1694, sum: 1857859, max: 30000000
P5: Time elapsed: 1651, sum: 1857859, max: 30000000
P6: Time elapsed: 2921, sum: 1857859, max: 30000000
P7: Time elapsed: 187, sum: 1857866, max: 30000000
P8: Time elapsed: 149, sum: 1857863, threads: 16
P8: Time elapsed: 146, sum: 1857866, threads: 32
```
