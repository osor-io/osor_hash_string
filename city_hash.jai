


//
// This is a port of Google's 64-bit City Hash to the Jai programming language.
//
// No relevant changes have been made to the actual functionality, the intention
// being to just have a native implementation of it in the language.
//
//                                      - Ruben Osorio, 17/01/2021 
//
// Following is the original license, included as required:
//
// Copyright (c) 2011 Google, Inc.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//



city_hash_64 :: inline (bytes : []u8) -> u64 { return city_hash_64(bytes.data, cast(u64)bytes.count); }
city_hash_64 :: inline (s : string)   -> u64 { return city_hash_64(s.data, cast(u64)s.count); }
city_hash_64 :: (s : *u8, len : u64) -> u64 
{
    if len <= 32 
    {
        if len <= 16 
        {
            return hash_from_0_to_16(s, len);
        }
        else          
        {
            return hash_from_17_to_32(s, len);
        }
    }
    else if len <= 64
    {
        return hash_from_33_to_64(s, len);
    }

    x := fetch_64(s + len - 40);
    y := fetch_64(s + len - 16) + fetch_64(s + len - 56);
    z := city_hash_length_16(fetch_64(s + len - 48) + len, fetch_64(s + len - 24));
    v0, v1 := weak_hash_32_with_seeds(s + len - 64, len, z);
    w0, w1 := weak_hash_32_with_seeds(s + len - 32, y + k1, x);
    x = x * k1 + fetch_64(s);

    len = (len - 1) & ~(cast(u64)63);
    while true
    {
        x = rotate(x + y + v0 + fetch_64(s + 8), 37) * k1;
        y = rotate(y + v1 + fetch_64(s + 48), 42) * k1;
        x ^= w1;
        y += v0 + fetch_64(s + 40);
        z = rotate(z + w0, 33) * k1;
        v0, v1 = weak_hash_32_with_seeds(s, v1 * k1, x + w0);
        w0, w1 = weak_hash_32_with_seeds(s + 32, z + w1, y + fetch_64(s + 16));
        z, x = x, z;
        s += 64;
        len -= 64;
        if len == 0 break;
    }
    return city_hash_length_16(city_hash_length_16(v0, w0) + shift_mix(y) * k1 + z, city_hash_length_16(v1, w1) + x);
}    



#scope_file



k0 : u64 : 0xc3a5c85c97cb3127;
k1 : u64 : 0xb492b66fbe98f273;
k2 : u64 : 0x9ae16a3b2f90404f;

fetch_32 :: #bake_arguments fetch(T=u32); 
fetch_64 :: #bake_arguments fetch(T=u64); 
fetch :: inline ($T : Type, p : *void) -> T
{
    result : T = ---;
    memcpy(*result, p, size_of(type_of(result)));
    return result;
}

rotate :: inline (v : $T, $shift : int) -> T
{
    bit_count :: size_of(T) * 8;
    inverse_shift :: bit_count - shift;
    #assert(shift < bit_count);
    #if shift == 0 return v;
    else return (v >> shift) | (v << inverse_shift); 
}

shift_mix :: inline (v : u64) -> u64
{
    return v ^ (v >> 47);
}

city_hash_length_16 :: (u : u64, v :u64, mul : u64 = 0x9ddfea08eb382d69) -> u64 
{
    a : u64 = (u ^ v) * mul;
    a ^= (a >> 47);
    b : u64 = (v ^ a) * mul;
    b ^= (b >> 47);
    b *= mul;
    return b;
}

weak_hash_32_with_seeds :: (w : u64, x : u64, y : u64, z : u64, a : u64, b : u64) -> a : u64, b : u64 
{
    a += w;
    b = rotate(b + a + z, 21);
    c := a;
    a += x;
    a += y;
    b += rotate(a, 44);
    return (a + z), (b + c);
}

weak_hash_32_with_seeds :: (s : *u8, a : u64, b : u64) -> a : u64, b : u64
{
    a, b := weak_hash_32_with_seeds(fetch_64(s),
                                    fetch_64(s + 8),
                                    fetch_64(s + 16), 
                                    fetch_64(s + 24), 
                                    a, b);
    return a, b;
}

hash_from_0_to_16 :: (s : *u8, len : u64) -> u64
{
    if len >= 8 
    {
        mul : u64 = k2 + len * 2;
        a : u64 = fetch_64(s) + k2;
        b : u64 = fetch_64(s + len - 8);
        c : u64 = rotate(b, 37) * mul + a;
        d : u64 = (rotate(a, 25) + b) * mul;
        return city_hash_length_16(c, d, mul);
    }
    if len >= 4 
    {
        mul : u64 = k2 + len * 2;
        a : u64 = fetch_32(s);
        return city_hash_length_16(len + (a << 3), fetch_32(s + len - 4), mul);
    }
    if len > 0 
    {
        a : u8 = s[0];
        b : u8 = s[len >> 1];
        c : u8 = s[len - 1];
        y : u32 = (cast(u32)a)   + ((cast(u32)b) << 8);
        z : u32 = (cast(u32)len) + ((cast(u32)c) << 2);
        return shift_mix((y * k2) ^ (z * k0)) * k2;
    }
    return k2;
}

hash_from_17_to_32 :: (s : *u8, len : u64) -> u64
{
    mul : u64 = k2 + len * 2;
    a : u64 = fetch_64(s) * k1;
    b : u64 = fetch_64(s + 8);
    c : u64 = fetch_64(s + len - 8) * mul;
    d : u64 = fetch_64(s + len - 16) * k2;
    return city_hash_length_16(rotate(a + b, 43) + rotate(c, 30) + d, a + rotate(b + k2, 18) + c, mul);
}

hash_from_33_to_64 :: (s : *u8, len : u64) -> u64
{
    mul : u64 = k2 + len * 2;
    a : u64 = fetch_64(s) * k2;
    b : u64 = fetch_64(s + 8);
    c : u64 = fetch_64(s + len - 24);
    d : u64 = fetch_64(s + len - 32);
    e : u64 = fetch_64(s + 16) * k2;
    f : u64 = fetch_64(s + 24) * 9;
    g : u64 = fetch_64(s + len - 8);
    h : u64 = fetch_64(s + len - 16) * mul;
    u : u64 = rotate(a + g, 43) + (rotate(b, 30) + c) * 9;
    v : u64 = ((a + g) ^ d) + f + 1;
    w : u64 = byte_swap((u + v) * mul) + h;
    x : u64 = rotate(e + f, 42) + c;
    y : u64 = (byte_swap((v + w) * mul) + g) * mul;
    z : u64 = e + f + c;
    a = byte_swap((x + z) * mul + y) + b;
    b = shift_mix((z + a) * mul + d + h) * mul;
    return b + x;
}

byte_swap :: inline (input: $T) -> T
{
    result := input;

         #if size_of(T) == 1 then { /* Nothing, you have one byte bruh */ }
    else #if size_of(T) == 2 then #asm { bswap.w result; }
    else #if size_of(T) == 4 then #asm { bswap.d result; }
    else #if size_of(T) == 8 then #asm { bswap.q result; }
    else #assert(false);

    return result;
}
