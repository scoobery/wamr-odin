# WAMR-odin
Bindings for the WASM Micro Runtime for the Odin Programming Language.

## Getting Started
1. Run `git submodule update --init --recursive` to pull the latest version of WAMR.
2. Run the build script for your respective system.
3. Import either the raw bindings from this package, or the `odin-wrapper` subpackage, and start using!

## Examples
If we have an example module such as this, built as a .wasm file with the options:  
`odin build wasm_module.odin -target:wasi_wasm32 -build-mode:lib`
```odin
package my_wasm_module

@(export)
hellope :: proc() {
	fmt.println("Hellope!")
}
```

We can import this compiled WASM module using WAMR and call our "hellope" function. Here's an example using the Odin wrapper package.
```odin
package app

import wamr "./wamr-odin/odin-wrapper"
import "core:fmt"
import "core:mem"
import "core:os"

STACK_SIZE :: mem.Megabyte
HEAP_SIZE :: 16 * mem.Megabyte

wasm_module_hellope :: proc(mod_bytes: []byte) -> bool {
	mod := wamr.load(mod_bytes) or_return
	defer wamr.unload(mod)

	inst := wamr.instantiate(mod, STACK_SIZE, HEAP_SIZE) or_return
	defer wamr.deinstantiate(inst)

	exec_env := wamr.create_exec_env(inst, STACK_SIZE) or_return
	defer wamr.destroy_exec_env(exec_env)

	func := wamr.lookup_function(mod_inst, "hellope") or_return

	results, func_ok := wamr.call_wasm(exec_env, func, {}, 0)
	return func_ok
}

main :: proc() {
	buffer, ok := os.read_entire_file("./wasm_module.wasm")
	defer delete(buffer)

	init_ok := wamr.init()
	defer wamr.destroy()

	if !wasm_module_hellope(buffer) {
		fmt.println(wamr.get_error())
	}
}
```

And here's an example of how to do it using the raw bindings.
```odin
package app

import wamr "./wamr-odin"
import "core:mem"
import "core:os"

STACK_SIZE :: mem.Megabyte
HEAP_SIZE :: 16 * mem.Megabyte

main :: proc() {
	error_buf: [128]u8

	buffer, ok := os.read_entire_file("./wasm_module.wasm")

	init_ok := wamr.wasm_runtime_init()
	defer wamr.wasm_runtime_destroy()

	mod := wamr.wasm_runtime_load(&buffer[0], u32(len(buffer)), &error_buf[0], 128)
	defer wamr.wasm_runtime_unload(mod)
	inst := wamr.wasm_runtime_instantiate(mod, STACK_SIZE, HEAP_SIZE, &error_buf[0], 128)
	defer wamr.wasm_runtime_deinstantiate(inst)
	exec_env := wamr.wasm_runtime_create_exec_env(inst, STACK_SIZE)
	defer wamr.wasm_runtime_destroy_exec_env(exec_env)

	func := wamr.wasm_runtime_lookup_function(mod_inst, "hellope")
	result: u32
	func_ok := wamr.wasm_runtime_call_wasm(exec_env, func, 0, &result)
}
```