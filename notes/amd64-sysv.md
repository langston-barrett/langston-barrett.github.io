# Amd64 System V ABI

## Function call sequence

### Registers

> The first six integer or pointer arguments are passed in registers RDI, RSI, RDX, RCX, R8, R9.

### Stack layout

On x86_64 with the SysV ABI, the stack grows \"downwards\" from high addresses to low. The end of the stack is initialized with the ELF auxiliary vector, and functions expect the following data to be available above their stack frame (i.e., just above the address in `rsp`), from high addresses to low:

- Padding (if necessary)
- Their stack-spilled arguments
- The return address

(The end of the stack-spilled argument list must be 16-byte aligned, which may necessitate the use of padding, depending on the number of spilled arguments and the layout of the caller's stack frame.)

The following diagram summarizes the stack frame layout:

```
High addresses

|---------------------|
| Caller's frame      |
|---------------------|
| Padding (if needed) |
|---------------------|
| Spilled argument n  |
|---------------------|
| ...                 |
|---------------------|
| Spilled argument 2  |
|---------------------|
| Spilled argument 1  |
|---------------------| <- %rsp + 8 (16-byte aligned)
| Return address      |
|---------------------| <- %rsp
| Callee's frame      |
|---------------------|

Low addresses
```

Helpful links:

- <https://eli.thegreenplace.net/2011/09/06/stack-frame-layout-on-x86-64>
- <https://wiki.osdev.org/System_V_ABI#x86-64>
- <https://refspecs.linuxfoundation.org/elf/x86_64-abi-0.99.pdf>
- <https://blog.nelhage.com/2010/10/amd64-and-va_arg/>:
