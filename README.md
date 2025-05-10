# KParser
I don't even know how many times i've tried to build this parser... eh
But this time, i'll actuallt try to finish it to some degree!

Please ignore the error handling code. It's quite annoying to make good errors in zig and i'm still thinking about the good implementation here.

## Bugs
- [FIXED] if the parser errors out, we directly return an error and we don't properly free the memory leading to memory leaks. Maybe we should use an arena allocator for this?
- [FIXED] we somehow parse expressions like `1)`
- this shit is prolly riddled with even more bugs tbh

## Todo
- [x] Pipe `Span` into `Expression` and `Statement`. For now, we literally ignore any position info LOL
- Make some kind of `Diagnostic` struct or wtv for error handling bc now it's basically inexistent
