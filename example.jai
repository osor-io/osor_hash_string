#import "Basic";
#import "Random";
#import "Hash_Table";
#import,dir "../osor_hash_string"(ORIGINAL_STRINGS = true);



main :: ()
{
    hash_string_init();
    defer hash_string_init();

    //
    // The funcionality of this module is quite simple, and similar to
    // other Hash_String/String-ID implementations.
    //
    // See: - https://github.com/foonathan/string_id
    //      - https://github.com/TheAllenChou/string-id
    //
    // The idea is to compute the hash of a string, and then use that instead
    // of the actual string when working with it. Why would this be helpful?
    //
    // Because your string now takes a constant amount of space (and very little),
    // is trivially comparable, and can be used more directly in a variety 
    // of scenarios (hash table keys, names of things, etc).
    //
    // Plus after the string generation itself, after you hash it, you don't
    // have to worry about the lifetime of that memory, you can free it right
    // there and just use the hashed string forever.
    //
    // This might look fairly unimpressive at first, but the pros of being able
    // to use strings in any context that you'd use an integer on pop up incredibly
    // frequently once this is in your arsenal. And strings themselves tend to take
    // a back seat and used mostly for longer text, or text that needs visualized in
    // some way.
    //

    simple_hash();
    compile_time_hash();
    hash_table();
    switch_statements();
    string_memory();
}



simple_hash :: ()
{
    print_example_name("A simple hashed string");

	//
	// You can see here how we both hashed the string into an integer, and we later
	// retrieve that original string based only on the hash. This feature is turned
	// on by using the module parameter ORIGINAL_STRINGS. This keeps track of which
	// strings we hashed. And it's able to then map the hash back to the string if
	// necessary.
	//
	// Sometimes you might want to have access to the original strings for your own
	// purposes, then disable this access once the code is to be released for faster
	// execution and less memory usage.
	//
    alice := make_hash_string("Alice");
    print("Alice's name hashed is % (which is a %), which is the hash of string \"%\"\n", alice.hash, type_of(alice.hash), get_string(alice));
}



compile_time_hash :: ()
{
    print_example_name("Compile-Time Hashes");

    //
    // Here you can see how a string can be hashed at compile-time (notice the #run
    // directive). This means that at run-time, the hash is already there as an integer.
    //
    // Something not immediately obvious is that you're hashing the string at compile-time,
    // only having the hash at run-time, yet you can still retrieve the original string with
    // get_string() at run-time. This is because the module is able to store the strings it
    // worked with during compile-time execution and still read them at run-time.
    //
    HASH_FROM_COMPILE_TIME :: #run make_hash_string("My Compile-Time Hash String");
    print("We hashed % at compile-time, and we got the string \"%\" at run-time", HASH_FROM_COMPILE_TIME.hash, get_string(HASH_FROM_COMPILE_TIME));
}



hash_table :: ()
{
    print_example_name("In a hash table");

	Friend :: struct
	{
		amount_of_teslas_they_own := 0;
	}
	table : Table(Hash_String, Friend, hash_to_32, compare_hash_strings);

	ALICE  :: #run make_hash_string("Alice");
	BOB    :: #run make_hash_string("Bob");
	CLAIRE :: #run make_hash_string("Claire");

	table_set(*table, ALICE, .{});
	table_set(*table, BOB, .{42});
	table_set(*table, CLAIRE, .{});

	name := "Bob";
	print("How many teslas does % own? %\n", name, table_find_pointer(*table, make_hash_string(name)).*);
}



switch_statements :: ()
{
    print_example_name("Using it in switch statements as constants");
    name_we_want_to_find := "Claire";
    if make_hash_string(name_we_want_to_find).hash == 
    {
    	case #run make_hash_string("Alice").hash;  print("It was Alice!\n");
    	case #run make_hash_string("Bob").hash;    print("It was Bob!\n");
    	case #run make_hash_string("Claire").hash; print("It was Claire!\n");
    	case; print("It was someone else we don't know\n");
    }
}



string_memory :: ()
{
    print_example_name("String Memory");
	Monster :: struct
	{
		name : Hash_String;
		health := 100;
	}
	monsters : [..]Monster;

	make_new_monster :: (monsters : *[..]Monster)
	{
		//
		// Imagine that the name of the monster was a normal string type. But we
		// want to generate it dynamically here. You would need to either make the
		// name an array of bytes big enough to hold it, or you'd need to allocate it
		// onto the heap and remember to track it.
		//
		// This way we can use temporary memory to generate the name, hash it so it's
		// essentially a constant-sized integer, and store it on the monster. And you
		// don't really have to think about the lifetime of the name's memory or anything
		// along those lines.
		//
		name := tprint("Monster_%_%_%", random_get()%100, random_get()%100, random_get()%100);
		new : Monster;
		new.name = make_hash_string(name);
		new.health = 50 + cast(int)random_get()%51;
		array_add(monsters, new);
	}

	make_new_monster(*monsters);
	make_new_monster(*monsters);
	make_new_monster(*monsters);
	make_new_monster(*monsters);

	for monsters print("\"%\": %\n", get_string(it.name), it);

	//
	// Now we're going to remove a monster, if the name was a normal
	// string we'd need to remember to go deallocate it. But since it's
	// a hash, we're good to go.
	//
	array_unordered_remove_by_index(*monsters, 2);
}



#scope_file



print_example_name :: (name : string) #expand
{
    for 0..(8 + name.count)-1 print("#");
    print("\n### % ###\n", name);
    for 0..(8 + name.count)-1 print("#");
    print("\n");
    `defer print("\n\n\n");
}