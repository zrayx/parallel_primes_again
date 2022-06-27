#!/bin/bash

clear
#zig build test > out 2>&1
#head -$((LINES-4)) out | cut -b-$COLUMNS
#rm out
prog=parallel_primes_again

ps -u $USER -eo comm | grep -wq $prog && {
    kill `ps -u $USER -eo comm,pid | awk '/'$prog'/ { print $2 }'`
}

#(cd lib/zdb/ && zig build test; echo -----------------------------------------)
#zig build test 2>&1 | cat

zig fmt build.zig src/*.zig
zig build run -Drelease-safe
#zig build run
#zig build test
echo --------------------------------------------------------------------------------

#echo --------------------------------------------------------------------------------
inotifywait --format %w -q -e close_write src/*.zig build.zig run.sh


exec ./run.sh
