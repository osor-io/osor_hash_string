# :knot: A Hash String module for Jai

A Hash-String module for the Jai programming language. You can check the code in [module.jai](module.jai) and examples of use in [example.jai](example.jai).

The idea behind this is to replace using strings with integers. These come as a result of hashing the original string. This is a well known technique that leverages the advantages that a constant-sized, small integer has over a string of arbitrary length such as faster comparisons, smaller storage, avoiding dynamic memory allocations, etc.

This is very common in the database world, asset management or in general in real-time applications. You can see good examples of other implementations [here by foonathan](https://github.com/foonathan/string_id) and [here by TheAllenChou](https://github.com/TheAllenChou/string-id).

## License

I want people to be able to just use this without thinking about licensing, although give me a shout if you do use it and attribution is appreciated 😊. Replicating STB's (https://github.com/nothings/stb) licensing stuff where you can choose to use public domain or MIT.
