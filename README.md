# KParser
I don't even know how many times i've tried to build this parser... eh
But this time, i'll actuallt try to finish it to some degree!

Please ignore the error handling code. It's quite annoying to make good errors in zig and i'm still thinking about the good implementation here.

## Bugs
- [FIXED] if the parser errors out, we directly return an error and we don't properly free the memory leading to memory leaks. Maybe we should use an arena allocator for this?
