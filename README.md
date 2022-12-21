# zig-gccjit
> Zig bindings for the gccjit library.

Please refer to the [official documentation](https://gcc.gnu.org/onlinedocs/jit/index.html) for any help.

This repository provides more idiomatic bindings for Zig. All functions are named similarly. However all
names have been expanded, and there are no shortened variants. For example there is `new_function_pointer_type`
instead of `new_function_ptr_type`.

All functions also guarantee that pointers won't be `null` as they instead return errors.

gccjit has a stable API, so these bindings will work forever, and don't need to be updated to use different
versions of the base library. However newer versions of these bindings **can** change function signatures.
These bindings will also work on older versions of the base library, albeit only the functions implemented
in that version.

## Adding library to your project
 
 Please refer to the `build.zig` file. Note that you **need** to link libc as well. Also you must ensure,
 that gccjit is present on the user's system. (Or is built and able to be linked statically.)

## Contributing

Contributions are welcome, the bindings are missing the official docstrings for example. Also more tests would
be benefficial.
