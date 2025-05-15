# KParser
I don't even know how many times i've tried to build this parser... eh
But this time, i'll actuallt try to finish it to some degree!

Please ignore the error handling code. It's quite annoying to make good errors in zig and i'm still thinking about the good implementation here.

I'm also not sure about the `Checker` implementation. I've never written one before and the sheer amount of design decisions to make overwhelm me. I'm probably gonna iterate and refactor it a LOT of times.

## Bugs
- [FIXED] if the parser errors out, we directly return an error and we don't properly free the memory leading to memory leaks. Maybe we should use an arena allocator for this?
- [FIXED] we somehow parse expressions like `1)`
- [ ] we still can't parse expressions like `1 == -1` bc of a hack in the `Parser`. We either parse them and allow expressions like `1 +- 1` or just don't parse them at all. Gotta think about this one
- this shit is prolly riddled with even more bugs tbh

## Todo
- [x] Pipe `Span` into `Expression` and `Statement`. For now, we literally ignore any position info LOL
- Make some kind of `Diagnostic` struct or wtv for error handling bc now it's basically inexistent

## Syntax (WIP)
This is the syntax I'd like this language to have. This is subject to change
```
-- vars
let x := 12;
let y: Int = 13;

-- functions
let f : Int -> (Int, Int)
f(n) = (n, 2*n);
```
