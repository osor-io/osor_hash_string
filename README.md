# :knot: A Hash String module for Jai

A Hash-String module for the Jai programming language. You can check the code in [module.jai](module.jai) and examples of use in [example.jai](example.jai).

The idea behind this is to replace using strings with integers. These come as a result of hashing the original string. This is a well known technique that leverages the advantages that a constant-sized, small integer has over a string of arbitrary length such as faster comparisons, smaller storage, avoiding dynamic memory allocations, etc.

This is very common in the database world, asset management or in general in real-time applications. You can see good examples of other implementations [here by foonathan](https://github.com/foonathan/string_id) and [here by TheAllenChou](https://github.com/TheAllenChou/string-id).

## How To

If you want to be able to be able to map back your hash to the original string you should start by calling `hash_string_init`. This is tied to the module parameter `ORIGINAL_STRINGS = true`. This will even make strings that were hashed at compile-time available at run-time.
```
main :: ()
{
    hash_string_init();
    defer hash_string_init();
    /*...*/
}
```

Creating a `Hash_String` is as easy as calling `make_hash_string`. You can also call this at compile time if you want a constant.
```
name := make_hash_string("Alice");
NAME :: #run make_hash_string("Bob");
```

If you compiled with `ORIGINAL_STRINGS = true` you can retrieve back the string from a hash:
```
name := make_hash_string("Alice");
original_string := get_string(name);
assert(name == original_string);
```

That's pretty much the basics! There's more examples in [the example file](example.jai) and more options in the [module parameters](module.jai) in case you want to serialize these, parse them, configure how (or if) to save the original strings to access them based on the hash, etc.

One cool feature that the language allows us to do is that if it determines that the input to `make_hash_string` is constant, it'll be hashed at compile-time, so the call to `make_hash_string` that happens at runtime is essentially a no-op.

## License

I want people to be able to just use this without thinking about licensing, although give me a shout if you do use it and attribution is appreciated 😊. Replicating STB's (https://github.com/nothings/stb) licensing stuff where you can choose to use public domain or MIT.
