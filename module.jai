




#module_parameters(ORIGINAL_STRINGS := true,
                   //
                   // Will save a copy of the each string that's being hashed so you're
                   // able to retrieve the original string from the hash later. So all you 
                   // need to pass around then is the hash, but if you want to print it for
                   // debug purposes, you're able to get back the input that gave you that hash.
                   //
                   // Note that this also works with strings hashed at compile time! :) 
                   //

                   SERIALIZE_WITH_STRING := false,
                   //
                   // Will make osor_serialization replace the Hash_String type by one
                   // that includes the original string, so the serialized data will have it as well.
                   //
                   // Later when deserializing the hash, it will register it with that original string,
                   // meaning that when calling get_string() on it we should get the original string.
                   //
                   // See: github.com/osor-io/osor_serialization 
                   //

                   CUSTOM_HASH_STRING_PARSING := false,
                   //
                   // Includes custom parsing code for osor_parser to use when handling
                   // Hash_String types. This will make it so they appear as traditional
                   // literaly strings on the parsed/unparsed files/strings. So instead of
                   // having something like:
                   //
                   //     my_hash_string = { hash = 9732462322387836567 }
                   //
                   // You can have something like this:
                   //
                   //     my_hash_string = "My Hash String"
                   //
                   // And of course, if you have this in a file it's now possible to go edit
                   // it by hand, and have the parser calculate the string appropriately when
                   // it loads it.
                   //
                   // See: github.com/osor-io/osor_parser
                   //

                   USE_SHARED_EXCLUSIVE_LOCK := false,
                   //
                   // Makes it so we use a Shared_Exclusive_Lock instead of a traditional mutex when accessing
                   // the original string data. This allows concurrent reads of original strings (and therefore
                   // they have less contention). If this is not set, it'll use the traditional Mutex that is
                   // available on the language's libraries. 
                   //

                   MAX_COMPILE_TIME_STRINGS := 2048,
                   MAX_COMPILE_TIME_STRING_BYTES := 64*1024
                   //
                   // Both of these configure how many compile-time strings we're allowed to store so
                   // we can make the hash->string mapping available at run-time for compile-time hashing.
                   //
                   // This only applies if you have ORIGINAL_STRINGS set to true in the first place.
                   //
                   // Ideally we'd like to get rid of these, by figuring out a way of making them dynamic
                   // during compile-time and pack them into the executable's data segments somewhere. But
                   // at the time of writing this I don't think there's a way (without involving heavy
                   // metaprogramming which would make this module harder to use).
                   //
                   // So for now we'll have to use these, if you try to hash more strings that fit in here
                   // you'll get a compiler error so you can go bump them to whatever is needed.
                   //
);



Hash_String :: struct
{
    hash : u64 = 0;

    #if SERIALIZE_WITH_STRING
    {
        Replacement_Type :: struct
        {
            hash : u64 = 0;
            original_string : string;
        }
        serialization_replacement :: (hash_string : *Hash_String) -> Replacement_Type
        {
            result : Replacement_Type;
            result.hash = hash_string.hash;
            if hash_string.* != Hash_String.{}
            {
                #if ORIGINAL_STRINGS
                {
                    had_original_string := false;
                    result.original_string, had_original_string = get_string(hash_string.*); 
                    assert(had_original_string);
                }
                else
                {
                    assert(false, "Trying to serialize a Hash_String as a hash plus its original string but this build doesn't have the original strings");
                }
            }
            return result;
        }
        deserialization_replacement :: (hash_and_string : *Replacement_Type) -> Hash_String
        {
            result : Hash_String;
            result.hash = hash_and_string.hash;
            if result != Hash_String.{}
            {
                assert(result.hash == make_hash_string(hash_and_string.original_string).hash);
                #if ORIGINAL_STRINGS then save_original_string(result, hash_and_string.original_string);
            }
            return result;
        }
    }
}



operator == :: inline (a : Hash_String, b : Hash_String) -> bool { return a.hash == b.hash; }
operator != :: inline (a : Hash_String, b : Hash_String) -> bool { return a.hash != b.hash; }
compare_hash_strings :: inline (a : Hash_String, b : Hash_String) -> bool { return a == b; }



hash_to_32 :: inline (using s : Hash_String) -> u32 
{ 
    #assert(type_of(hash) == u64);
    return (cast,trunc(u32)hash) ^ (cast,trunc(u32)(hash >> 32));
}



make_hash_string :: inline ($$s : string) -> Hash_String
{
    #if is_constant(s)
    {
        result :: Hash_String.{ hash = #run city_hash_64(s) };
        #if ORIGINAL_STRINGS then #run save_original_string(result, s);
    }
    else
    {
        result := Hash_String.{ hash = city_hash_64(s) };
        #if ORIGINAL_STRINGS then save_original_string(result, s);
    }
    return result;
}



#if ORIGINAL_STRINGS
{
    get_string :: (hash_string : Hash_String) -> string, success : bool
    {
        init_if_needed();
        with_shared_lock(*original_string_lock);
        result, success := table_find(*hash_to_string_table, hash_string);
        if success then return result, true;
        return "<unavailable>", false;
    }
}



#if CUSTOM_HASH_STRING_PARSING
{
    #import "osor_parser";
    
    hash_string_parse :: (token : *Token, struct_info : *Type_Info_Struct, value_pointer : *void) -> parsed : bool, next_token : *Token, error : string
    {
        if struct_info == type_info(Hash_String) && token.type == .String
        {
            hash_string := make_hash_string(token.text);
            assert(struct_info.runtime_size == size_of(type_of(hash_string)));
            memcpy(value_pointer, *hash_string, size_of(type_of(hash_string)));
            token += 1;
            return true, token, "";
        }
        return false, null, "";
    }

    hash_string_unparse :: (builder : *String_Builder, struct_info : *Type_Info_Struct, value_pointer : *void) -> unparsed : bool, error : string
    {
        if ORIGINAL_STRINGS && struct_info == type_info(Hash_String)
        {
            hash_string := (cast(*Hash_String)value_pointer).*;
            original_string, found := get_string(hash_string);
            if found
            {
                append(builder, "\"");
                append(builder, original_string);
                append(builder, "\"");
                return true, "";
            }
            else
            {
                log("Trying to unparse a Hash_String but we couldn't find the original string to write", flags = .WARNING);
            }
        }
        return false, "";
    }
}



#scope_file



#load "city_hash.jai";



#if ORIGINAL_STRINGS
{
    #import "Basic";
    #import "Hash_Table";
    #import "Atomics";
    #import "Compiler";
    #if USE_SHARED_EXCLUSIVE_LOCK
    {
        #import "Shared_Exclusive_Lock";
        Lock_Type :: Shared_Exclusive_Lock;
        with_shared_lock :: (lock : *Lock_Type) #expand
        {
            lock_shared(lock);
            `defer unlock_shared(lock);
        }
        with_exclusive_lock :: (lock : *Lock_Type) #expand
        {
            lock_exclusive(lock);
            `defer unlock_exclusive(lock);
        }
    }
    else
    {
        #import "Thread";
        Lock_Type :: Mutex;
        with_shared_lock :: (mutex : *Lock_Type) #expand
        {
            lock(mutex);
            `defer unlock(mutex);
        }
        with_exclusive_lock :: (mutex : *Lock_Type) #expand
        {
            lock(mutex);
            `defer unlock(mutex);
        }
    }

    initialized := 0;
    original_string_lock : Lock_Type;
    hash_to_string_table : Table(Hash_String, string, hash_to_32, compare_hash_strings);
    last_node : *String_Data_Node;

    #no_reset compile_time_string_data : [MAX_COMPILE_TIME_STRING_BYTES]u8;
    #no_reset compile_time_string_data_count := 0;
    #no_reset compile_time_hashes_and_strings : [MAX_COMPILE_TIME_STRINGS] struct { hash : u64; offset : u32; count : u32; }; 
    #no_reset compile_time_hashes_and_strings_count := 0;

    ORIGINAL_STRING_NODE_SIZE :: 512 * 1024;
    String_Data_Node :: struct
    {
        data : [ORIGINAL_STRING_NODE_SIZE]u8;
        used := 0;
        previous_node : *String_Data_Node;
    }

    init_if_needed :: ()
    {
        if initialized > 0 then return;
        previous := atomic_add(*initialized, 1);
        if previous == 0
        {
            init(*original_string_lock); 
            if !#compile_time
            {
                for 0..compile_time_hashes_and_strings_count-1
                {
                    hash_and_offset := compile_time_hashes_and_strings[it];
                    the_string : string;
                    the_string.count = hash_and_offset.count;
                    the_string.data = compile_time_string_data.data + hash_and_offset.offset;
                    table_set(*hash_to_string_table, Hash_String.{hash_and_offset.hash}, the_string);
                }
            }
        }
        #asm { mfence; }
    }

    save_original_string :: (hash_string : Hash_String, $$s : string)
    {
        if s.count > ORIGINAL_STRING_NODE_SIZE then return;

        init_if_needed();

        {
            with_shared_lock(*original_string_lock);
            saved_string, found := table_find(*hash_to_string_table, hash_string);
            if found then return; // @@TODO: Could check for duplicates here and below
        }

        with_exclusive_lock(*original_string_lock);

        if #compile_time
        {
            //
            // @@NOTE: At compile-time, we also add the strings to a buffer that will
            // stay in memory until run-time.
            //
            // At run-time, this all the strings in this buffer will get added to the
            // table that maps hashes to strings. Which makes it so we can hash strings
            // at compile-time while still retrieving the original string at run-time.
            //

            #if is_constant(s) && false
            {
                //
                // @@TODO: This constant strings would ideally just be stored directly pointing to the constant
                // string on the data segment. Currently if we do this, the pointer on the string doesn't get
                // translated from a compile-time pointer to a run-time pointer at the end of compilation.
                //
                // So for the time being we just copy them to our buffer just like the non-constant strings
                // that get here at compile-time. However, if this eventually works we should store a pointer
                // to the constant string instead. Either with a different array for constant strings or with
                // with the same one we already have for the non-constant ones but with an enum for the type of 
                // string stored (constant/non-constant) and a union for the data of each type.
                //
                //                                                  - Ruben Osorio, 19/08/2023
                //
            }
            else
            {
                if (compile_time_string_data_count + s.count + 1) <= compile_time_string_data.count
                {
                    memcpy(*compile_time_string_data[compile_time_string_data_count], s.data, s.count);
                    compile_time_string_data[compile_time_string_data_count + s.count] = #char "\0";
                    if compile_time_hashes_and_strings_count + 1 <= compile_time_hashes_and_strings.count
                    {
                        compile_time_hashes_and_strings[compile_time_hashes_and_strings_count] = .{hash_string.hash, cast(u32)compile_time_string_data_count, cast(u32)s.count};
                        compile_time_hashes_and_strings_count += 1;
                    }
                    else
                    {
                        compiler_report(tprint("There's no room to store the all the compile-time Hash_Strings"));
                    }
                    compile_time_string_data_count += s.count + 1;
                }
                else
                {
                    compiler_report(tprint("There's no room to store the original string for all the compile-time Hash_Strings"));
                }
            }
        }

        saved_string, found := table_find(*hash_to_string_table, hash_string);
        if found then return; // @@TODO: Could check for duplicates here and above

        node := last_node;
        needed_room := s.count + 1;
        if node == null || (node.data.count - node.used) < needed_room
        {
            previous := node;
            node = New(String_Data_Node,, context.default_allocator);
            node.previous_node = previous;
        }
        node = node;

        copied_string : string;
        copied_string.data = node.data.data + node.used;
        copied_string.count = s.count;
        node.used += needed_room;

        memcpy(copied_string.data, s.data, s.count);
        (copied_string.data + copied_string.count).* = #char "\0";

        table_set(*hash_to_string_table, hash_string, copied_string);
    }
}
