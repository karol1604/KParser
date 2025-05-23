# Eigen
**Eigen** is a compiled, statically typed and partially lazy programming language. Its syntax is inspired by mathematical notation, aiming to make code somewhat read like a paper (not fully lol).

## Planned features
Here are some features I plan on adding to eigen.
- strong type system
- good pattern matching
- algebraic/product data types
- ranges (for example `1..10` or `1...10` for inclusive/exclusive ranges)
- nullable types (for example `?Int`)
- variadic functions
- partial lazy evaluation (perhaps a `lazy` keyword for stuff like expensive computations etc)
- list comprehensions with predicates, infinite lists, list cons (for example ``[2 * x | x <- [2..], x `mod` 3 == 1]``)
- good error handling and pretty error messages (current error handling is looking rough...)
- use llvm as a backend
- custom operators like in haskell?
- maybe allow binary functions as infix operators (for example `fn(x, y)` would be the equivalent to ``x `fn` y``)

## Notes
I don't even know how many times i've tried to build this... eh
But this time, i'll actuallt try to finish it to some degree!

Please ignore the error handling code. It's quite annoying to make good errors in zig and i'm still thinking about the good implementation here.

I'm also not sure about the `Checker` implementation. I've never written one before and the sheer amount of design decisions to make overwhelm me. I'm probably gonna iterate and refactor it a LOT of times.

## Bugs
- [ ] we are not properly assigning a type to a variable which is a function
- [ ] we still can't parse expressions like `1 == -1` bc of a hack in the `Parser`. We either parse them and allow expressions like `1 +- 1` or just don't parse them at all. Gotta think about this one
- this shit is prolly riddled with even more bugs tbh

## Todo
- [ ] Remove `Statement` as everything is an expression now
- [ ] Make some kind of `Diagnostic` struct or wtv for error handling bc now it's basically inexistent
- [ ] Think about types and how should they work
- [ ] This might be a stretch but i'd like to implement a simple symbolic engine

## Syntax (WIP)
This is the syntax I'd like this language to have. This is subject to change.

### Variable declaration
If no type is provided, the compiler infers it
```eigen
let x := 12;
let y : Int = 13;
```

### Function definitions
Function expressions are bound just like variables.
```eigen
let f : Int -> Int =
    λ n .
        let foo := n + 1;
        foo;
```
In this example, the variable `f` would be of type `(Int) -> Int`. You can also omit the braces if you return a single expression. For example
```eigen
let add : ℤ × ℤ -> ℤ = λ x y . x + y;

-- to call it
add(1, 2);
-- or
1 `add` 2;
-- or maybe... (prolly not lol)
add 1 2;
```
Here, the return type gets inferred. I'm not sure if this is a good idea tho. Maybe we should just require the return type to be specified? I don't know yet.

### Control flow
I'd like `if` to be an expression, so you can do stuff like
```eigen
let x := if (cond) then 1 else 2; -- if returns Int
let y := if (cond) then x + 1; -- if returns ?Int

let y : Int = if (cond) then x + 1; -- type error bc `y` is nullable so it should be ?Int
```

### Pattern matching
I'd like to have type safe pattern matching so the compiler should check if the cases are exhaustive. I'm really not so sure about this tho. Luckily, I there's A LOT of time till I need to implement this.
```eigen
let some_value : Int = some_function();
let x := cases (some_value) {
    1..10 -> 2,
    |val| 10...100 if val `mod` 10 == 0 -> 3,
    _ -> 4,
};
```
to be continued...
