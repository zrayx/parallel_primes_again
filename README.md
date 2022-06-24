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