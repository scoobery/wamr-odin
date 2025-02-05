package wasm_micro_runtime_odin

import bnd "../"
import "core:mem"
import "core:strings"

WasmPointer :: distinct u64

Module :: bnd.wasm_module_t
ModuleInstance :: bnd.wasm_module_inst_t

ExecEnv :: bnd.wasm_exec_env_t

FunctionInstance :: bnd.wasm_function_inst_t

Value :: bnd.wasm_val_t

to_value :: proc {
	i32_value,
	i64_value,
	u32_value,
	u64_value,
	f32_value,
	f64_value,
}
i32_value :: proc(v: i32) -> Value {
	return Value{kind = .WASM_I32, of = {i32 = v}}
}
i64_value :: proc(v: i64) -> Value {
	return Value{kind = .WASM_I64, of = {i64 = v}}
}
u32_value :: proc(v: u32) -> Value {
	return Value{kind = .WASM_I32, of = {i32 = transmute(i32)u32(v)}}
}
u64_value :: proc(v: u64) -> Value {
	return Value{kind = .WASM_I64, of = {i64 = transmute(i64)u64(v)}}
}
f32_value :: proc(v: f32) -> Value {
	return Value{kind = .WASM_F32, of = {float = v}}
}
f64_value :: proc(v: f64) -> Value {
	return Value{kind = .WASM_F64, of = {double = v}}
}

from_value :: proc {
	value_i32,
}
value_i32 :: proc(v: Value) -> i32 {
	return v.of.i32
}
value_i64 :: proc(v: Value) -> i64 {
	return v.of.i64
}
value_f32 :: proc(v: Value) -> f32 {
	return v.of.float
}
value_f64 :: proc(v: Value) -> f64 {
	return v.of.double
}


@(private)
ErrorBuffer: [ErrorBufferCapacity]byte
ErrorBufferCapacity :: #config(ERR_BUFFER_CAPACITY, 128)

@(require_results)
get_error :: proc() -> string {
	return strings.string_from_null_terminated_ptr(&ErrorBuffer[0], len(ErrorBuffer))
}

// Initialize the WASM runtime environment.
// Returns true if success.
@(require_results)
init :: proc() -> bool {
	return bool(bnd.wasm_runtime_init())
}

// Destroy the WASM runtime environment.
destroy :: proc() {
	bnd.wasm_runtime_destroy()
}

// Load a WASM module from a specified byte slice. The slice can be WASM binary data when interpreter or JIT is
// enabled, or AOT binary data when AOT is enabled. If it is AOT binary data, it must be 4-byte aligned.
@(require_results)
load :: proc(buf: []byte) -> (Module, bool) {
	mod := bnd.wasm_runtime_load(&buf[0], u32(len(buf)), &ErrorBuffer[0], len(ErrorBuffer))
	return mod, mod != nil
}

// Unload a WASM module.
unload :: proc(mod: Module) {
	bnd.wasm_runtime_unload(mod)
}

@(require_results)
instantiate :: proc(mod: Module, stack_size, heap_size: u32) -> (ModuleInstance, bool) {
	inst := bnd.wasm_runtime_instantiate(mod, stack_size, heap_size, &ErrorBuffer[0], len(ErrorBuffer))
	return inst, inst != nil
}
deinstantiate :: proc(inst: ModuleInstance) {
	bnd.wasm_runtime_deinstantiate(inst)
}

@(require_results)
create_exec_env :: proc(inst: ModuleInstance, stack_size: u32) -> (ExecEnv, bool) {
	env := bnd.wasm_runtime_create_exec_env(inst, stack_size)
	return env, env != nil
}
destroy_exec_env :: proc(env: ExecEnv) {
	bnd.wasm_runtime_destroy_exec_env(env)
}

lookup_function :: proc(inst: ModuleInstance, name: string) -> (FunctionInstance, bool) {
	func := bnd.wasm_runtime_lookup_function(inst, strings.unsafe_string_to_cstring(name))
	return func, func != nil
}

call_wasm :: proc(
	env: ExecEnv,
	func: FunctionInstance,
	args: []Value,
	$RESULTCOUNT: uint,
) -> (
	[RESULTCOUNT]Value,
	bool,
) {
	_dummy_val: Value
	num_args := u32(len(args)) + 1
	arg_ptr: [^]Value = num_args > 1 ? &args[0] : &_dummy_val
	when RESULTCOUNT == 0 {
		func_ok := bnd.wasm_runtime_call_wasm_a(env, func, u32(RESULTCOUNT), &_dummy_val, num_args, arg_ptr)
		return {}, func_ok
	} else {
		results: [RESULTCOUNT]Value
		func_ok := bnd.wasm_runtime_call_wasm_a(env, func, u32(RESULTCOUNT), &results[0], num_args, arg_ptr)
		return results, func_ok
	}
}


module_malloc :: proc(inst: ModuleInstance, size: uint, backing: rawptr) -> (WasmPointer, bool) {
	ptr := bnd.wasm_runtime_module_malloc(inst, u64(size), backing)
	return WasmPointer(ptr), ptr != 0
}
module_free :: proc(inst: ModuleInstance, ptr: WasmPointer) {
	bnd.wasm_runtime_module_free(inst, u64(ptr))
}
