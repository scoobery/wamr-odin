package wasm_micro_runtime

import "base:builtin"
import "base:intrinsics"
import cdefs "core:c"
import c "core:c/libc"

when ODIN_OS == .Windows {

}
when ODIN_OS == .Linux {
	foreign import lib "lib/linux/libvmlib.a"
}

NativeSymbol :: struct {
	symbol:     cstring,
	func_ptr:   rawptr,
	signature:  cstring,
	/* attachment which can be retrieved in native API by
       calling wasm_runtime_get_function_attachment(exec_env) */
	attachment: rawptr,
}

/* Uninstantiated WASM module loaded from WASM binary file
   or AoT binary file*/
WASMModuleCommon :: struct {}
wasm_module_t :: ^WASMModuleCommon

wasm_import_export_kind_t :: enum {
	Func,
	Table,
	Memory,
	Global,
}

WASMFuncType :: struct {}
wasm_func_type_t :: ^WASMFuncType

WASMTableType :: struct {}
wasm_table_type_t :: ^WASMTableType

WASMGlobalType :: struct {}
wasm_global_type_t :: ^WASMGlobalType

WASMMemory :: struct {}
WASMMemoryType :: WASMMemory
wasm_memory_type_t :: ^WASMMemoryType

wasm_import_t :: struct {
	module_name: cstring,
	name:        cstring,
	kind:        wasm_import_export_kind_t,
	linked:      c.bool,
	u:           struct #raw_union {
		func_type:   wasm_func_type_t,
		table_type:  wasm_table_type_t,
		global_type: wasm_global_type_t,
		memory_type: wasm_memory_type_t,
	},
}

wasm_export_t :: struct {
	name: cstring,
	kind: wasm_import_export_kind_t,
	u:    struct #raw_union {
		func_type:   wasm_func_type_t,
		table_type:  wasm_table_type_t,
		global_type: wasm_global_type_t,
		memory_type: wasm_memory_type_t,
	},
}

/* Instantiated WASM module */
WASMModuleInstanceCommon :: struct {}
wasm_module_inst_t :: ^WASMModuleInstanceCommon

/* Function instance */
WASMFunctionInstanceCommon :: struct {}
wasm_function_inst_t :: ^WASMFunctionInstanceCommon

/* Memory instance */
WASMMemoryInstance :: struct {}
wasm_memory_inst_t :: ^WASMMemoryInstance

/* WASM section */
wasm_section_t :: struct {
	next:              ^wasm_section_t,
	/* section type */
	section_type:      c.int,
	/* section body, not include type and size */
	section_body:      [^]c.uint8_t,
	/* section body size */
	section_body_size: c.uint32_t,
}
aot_section_t :: wasm_section_t
wasm_section_list_t :: [^]wasm_section_t
aot_section_list_t :: [^]aot_section_t

/* Execution environment, e.g. stack info */
WASMExecEnv :: struct {}
wasm_exec_env_t :: ^WASMExecEnv

WASMSharedHeap :: struct {}
wasm_shared_heap_t :: ^WASMSharedHeap

/* Package Type */
package_type_t :: enum {
	Wasm_Module_Bytecode = 0,
	Wasm_Module_AoT,
	Package_Type_Unknown = 0xFFFF,
}

/* Memory allocator type */
mem_alloc_type_t :: enum {
	/* pool mode, allocate memory from user defined heap buffer */
	Alloc_With_Pool = 0,
	/* user allocator mode, allocate memory from user defined
       malloc function */
	Alloc_With_Allocator,
	/* system allocator mode, allocate memory from system allocator,
       or, platform's os_malloc function */
	Alloc_With_System_Allocator,
}

mem_alloc_usage_t :: enum {
	Alloc_For_Runtime,
	Alloc_For_LinearMemory,
}

/* Memory allocator option */
MemAllocOption :: struct {
	pool:      struct {
		heap_buf:  rawptr,
		heap_size: c.uint32_t,
	},
	allocator: struct {
		/* the function signature is varied when
        WASM_MEM_ALLOC_WITH_USER_DATA and
        WASM_MEM_ALLOC_WITH_USAGE are defined */
		malloc_func, realloc_func, free_func: rawptr,
		/* allocator user data, only used when
           WASM_MEM_ALLOC_WITH_USER_DATA is defined */
		user_data:                            rawptr,
	},
}

/* Memory pool info  */
mem_alloc_info_t :: struct {
	total_size, total_free_size, highmark_size: c.uint32_t,
}

/* Running mode of runtime and module instance*/
RunningMode :: enum {
	Mode_Interp = 1,
	Mode_Fast_JIT,
	Mode_LLVM_JIT,
	Mode_Multi_Tier_JIT,
}

/* WASM runtime initialize arguments */
RuntimeInitArgs :: struct {
	mem_alloc_type:                          mem_alloc_type_t,
	mem_alloc_option:                        MemAllocOption,
	native_module_name:                      cstring,
	native_symbols:                          [^]NativeSymbol,
	n_native_symbols:                        c.uint32_t,

	/* maximum thread number, only used when
       WASM_ENABLE_THREAD_MGR is defined */
	max_thread_num:                          c.uint32_t,

	/* Debug settings, only used when
       WASM_ENABLE_DEBUG_INTERP != 0 */
	ip_addr:                                 [128]c.char,
	unused:                                  c.int, /* was platform_port */
	instance_port:                           c.int,

	/* Fast JIT code cache size */
	fast_jit_code_cache_size:                c.uint32_t,

	/* Default GC heap size */
	gc_heap_size:                            c.uint32_t,

	/* Default running mode of the runtime */
	running_mode:                            RunningMode,

	/* LLVM JIT opt and size level */
	llvm_jit_opt_level, llvm_jit_size_level: c.uint32_t,

	/* Segue optimization flags for LLVM JIT */
	segue_flags:                             c.uint32_t,
	/**
     * If enabled
     * - llvm-jit will output a jitdump file for `perf inject`
     * - aot will output a perf-${pid}.map for `perf record`
     * - fast-jit. TBD
     * - multi-tier-jit. TBD
     * - interpreter. TBD
     */
	enable_linux_perf:                       c.bool,
}

LoadArgs :: struct {
	name:                 cstring,
	/* This option is only used by the Wasm C API (see wasm_c_api.h) */
	clone_wasm_binary:    bool,
	/* False by default, used by AOT/wasm loader only.
    If true, the AOT/wasm loader creates a copy of some module fields (e.g.
    const strings), making it possible to free the wasm binary buffer after
    loading. */
	wasm_binary_freeable: bool,

	/* false by default, if true, don't resolve the symbols yet. The
       wasm_runtime_load_ex has to be followed by a wasm_runtime_resolve_symbols
       call */
	no_resolve:           bool,
	/* TODO: more fields? */
}

/* WASM module instantiation arguments */
InstantiationArgs :: struct {
	default_stack_size, host_managed_heap_size, max_memory_pages: c.uint32_t,
}

wasm_valkind_t :: enum c.uint8_t {
	WASM_I32,
	WASM_I64,
	WASM_F32,
	WASM_F64,
	WASM_V128,
	WASM_EXTERNREF = 128,
	WASM_FUNCREF,
}

wasm_ref_t :: struct {}

wasm_val_t :: struct {
	kind:      wasm_valkind_t,
	_paddings: [7]c.uint8_t,
	of:        struct #raw_union {
		/* also represent a function index */
		i32:         c.int32_t,
		i64:         c.int64_t,
		float:       c.float,
		double:      c.double,
		/* represent a foreign object, aka externref in .wat */
		foreign_obj: c.uintptr_t,
		ref:         ^wasm_ref_t,
	},
}

/* Global instance*/
wasm_global_inst_t :: struct {
	kind:        wasm_valkind_t,
	is_mutable:  c.bool,
	global_data: rawptr,
}

/* Table instance*/
wasm_table_inst_t :: struct {
	elem_kind:          wasm_valkind_t,
	cur_size, max_size: c.uint32_t,
	/* represents the elements of the table, for internal use only */
	elems:              rawptr,
}

log_level_t :: enum {
	FATAL   = 0,
	ERROR   = 1,
	WARNING = 2,
	DEBUG   = 3,
	VERBOSE = 4,
}

SharedHeapInitArgs :: struct {
	size: c.uint32_t,
}

/**
 * Callback to load a module file into a buffer in multi-module feature
 */
module_reader :: #type proc "c" (
	module_type: package_type_t,
	module_name: cstring,
	p_buffer: ^[^]c.uint8_t,
	p_size: ^c.uint32_t,
) -> c.bool

/**
 * Callback to release the buffer loaded by module_reader callback
 */
module_destroyer :: #type proc "c" (buffer: [^]c.uint8_t, size: c.uint32_t)

/* wasm thread callback function type */
wasm_thread_callback_t :: #type proc "c" (_: wasm_exec_env_t, _: rawptr)
/* wasm thread type */
wasm_thread_t :: c.uintptr_t

enlarge_memory_error_reason_t :: enum {
	INTERNAL_ERROR,
	MAX_SIZE_REACHED,
}

enlarge_memory_error_callback_t :: #type proc "c" (
	inc_page_count: c.uint32_t,
	current_memory_size: c.uint64_t,
	memory_index: c.uint32_t,
	failure_reason: enlarge_memory_error_reason_t,
	instance: wasm_module_inst_t,
	exec_env: wasm_exec_env_t,
	user_data: rawptr,
)

@(default_calling_convention = "c")
foreign lib {
	/**
    * Initialize the WASM runtime environment, and also initialize
    * the memory allocator with system allocator, which calls os_malloc
    * to allocate memory
    *
    * @return true if success, false otherwise
    */
	wasm_runtime_init :: proc() -> c.bool ---

	/**
	* Initialize the WASM runtime environment, WASM running mode,
	* and also initialize the memory allocator and register native symbols,
	* which are specified with init arguments
	*
	* @param init_args specifies the init arguments
	*
	* @return return true if success, false otherwise
	*/
	wasm_runtime_full_init :: proc(init_args: ^RuntimeInitArgs) -> c.bool ---

	/**
	* Set the log level. To be called after the runtime is initialized.
	*
	* @param level the log level to set
	*/
	wasm_runtime_set_log_level :: proc(level: log_level_t) ---

	/**
	* Query whether a certain running mode is supported for the runtime
	*
	* @param running_mode the running mode to query
	*
	* @return true if this running mode is supported, false otherwise
	*/
	wasm_runtime_is_running_mode_supported :: proc(running_mode: RunningMode) -> c.bool ---

	/**
	* Set the default running mode for the runtime. It is inherited
	* to set the running mode of a module instance when it is instantiated,
	* and can be changed by calling wasm_runtime_set_running_mode
	*
	* @param running_mode the running mode to set
	*
	* @return true if success, false otherwise
	*/
	wasm_runtime_set_default_running_mode :: proc(running_mode: RunningMode) -> c.bool ---

	/**
     * Destroy the WASM runtime environment.
     */
	wasm_runtime_destroy :: proc() ---

	/**
	* Allocate memory from runtime memory environment.
	*
	* @param size bytes need to allocate
	*
	* @return the pointer to memory allocated
	*/
	wasm_runtime_malloc :: proc(size: c.uint) -> rawptr ---

	/**
	* Reallocate memory from runtime memory environment
	*
	* @param ptr the original memory
	* @param size bytes need to reallocate
	*
	* @return the pointer to memory reallocated
	*/
	wasm_runtime_realloc :: proc(ptr: rawptr, size: c.uint) -> rawptr ---

	/*
	* Free memory to runtime memory environment.
	*/
	wasm_runtime_free :: proc(ptr: rawptr) ---

	/*
	* Get memory info, only pool mode is supported now.
	*/
	wasm_runtime_get_mem_alloc_info :: proc(mem_alloc_info: ^mem_alloc_info_t) -> c.bool ---

	/**
	* Get the package type of a buffer.
	*
	* @param buf the package buffer
	* @param size the package buffer size
	*
	* @return the package type, return Package_Type_Unknown if the type is unknown
	*/
	get_package_type :: proc(buf: [^]c.uint8_t, size: c.uint32_t) -> package_type_t ---

	/**
	* Get the package type of a buffer (same as get_package_type).
	*
	* @param buf the package buffer
	* @param size the package buffer size
	*
	* @return the package type, return Package_Type_Unknown if the type is unknown
	*/
	wasm_runtime_get_file_package_type :: proc(buf: [^]c.uint8_t, size: c.uint32_t) -> package_type_t ---

	/**
	* Get the package type of a module.
	*
	* @param module the module
	*
	* @return the package type, return Package_Type_Unknown if the type is
	* unknown
	*/
	wasm_runtime_get_module_package_type :: proc(module: wasm_module_t) -> package_type_t ---

	/**
	* Get the package version of a buffer.
	*
	* @param buf the package buffer
	* @param size the package buffer size
	*
	* @return the package version, return zero if the version is unknown
	*/
	wasm_runtime_get_file_package_version :: proc(buf: [^]c.uint8_t, size: c.uint32_t) -> c.uint32_t ---

	/**
	* Get the package version of a module
	*
	* @param module the module
	*
	* @return the package version, or zero if version is unknown
	*/
	wasm_runtime_get_module_package_version :: proc(module: wasm_module_t) -> c.uint32_t ---

	/**
	* Get the currently supported version of the package type
	*
	* @param package_type the package type
	*
	* @return the currently supported version, or zero if package type is unknown
	*/
	wasm_runtime_get_current_package_version :: proc(package_type: package_type_t) -> c.uint32_t ---

	/**
	* Check whether a file is an AOT XIP (Execution In Place) file
	*
	* @param buf the package buffer
	* @param size the package buffer size
	*
	* @return true if success, false otherwise
	*/
	wasm_runtime_is_xip_file :: proc(buf: [^]c.uint8_t, size: c.uint32_t) -> c.bool ---

	/**
	* Setup callbacks for reading and releasing a buffer about a module file
	*
	* @param reader a callback to read a module file into a buffer
	* @param destroyer a callback to release above buffer
	*/
	wasm_runtime_set_module_reader :: proc(reader: module_reader, destroyer: module_destroyer) ---

	/**
	* Give the "module" a name "module_name".
	* Can not assign a new name to a module if it already has a name
	*
	* @param module_name indicate a name
	* @param module the target module
	* @param error_buf output of the exception info
	* @param error_buf_size the size of the exception string
	*
	* @return true means success, false means failed
	*/
	wasm_runtime_register_module :: proc(module_name: cstring, module: wasm_module_t, error_buf: [^]c.char, error_buf_size: c.uint32_t) -> c.bool ---

	/**
	* Check if there is already a loaded module named module_name in the
	* runtime. Repeatedly loading a module with the same name is not allowed.
	*
	* @param module_name indicate a name
	*
	* @return return WASM module loaded, NULL if failed
	*/
	wasm_runtime_find_module_registered :: proc(module_name: cstring) -> wasm_module_t ---

	/**
    * Load a WASM module from a specified byte buffer. The byte buffer can be
    * WASM binary data when interpreter or JIT is enabled, or AOT binary data
    * when AOT is enabled. If it is AOT binary data, it must be 4-byte aligned.
    *
    * Note: In case of AOT XIP modules, the runtime doesn't make modifications
    * to the buffer. (Except the "Known issues" mentioned in doc/xip.md.)
    * Otherwise, the runtime can make modifications to the buffer for its
    * internal purposes. Thus, in general, it isn't safe to create multiple
    * modules from a single buffer.
    *
    * @param buf the byte buffer which contains the WASM/AOT binary data,
    *        note that the byte buffer must be writable since runtime may
    *        change its content for footprint and performance purpose, and
    *        it must be referenceable until wasm_runtime_unload is called
    * @param size the size of the buffer
    * @param error_buf output of the exception info
    * @param error_buf_size the size of the exception string
    *
    * @return return WASM module loaded, NULL if failed
    */
	wasm_runtime_load :: proc(buf: [^]c.uint8_t, size: c.uint32_t, error_buf: [^]c.char, error_buf_size: c.uint32_t) -> wasm_module_t ---

	/**
	* Load a WASM module with specified load argument.
	*/
	wasm_runtime_load_ex :: proc(buf: [^]c.uint8_t, size: c.uint32_t, args: ^LoadArgs, error_buf: [^]c.char, error_buf_size: c.uint32_t) -> wasm_module_t ---

	/**
	* Resolve symbols for a previously loaded WASM module. Only useful when the
	* module was loaded with LoadArgs::no_resolve set to true
	*/
	wasm_runtime_resolve_symbols :: proc(module: wasm_module_t) -> c.bool ---

	/**
	* Load a WASM module from a specified WASM or AOT section list.
	*
	* @param section_list the section list which contains each section data
	* @param is_aot whether the section list is AOT section list
	* @param error_buf output of the exception info
	* @param error_buf_size the size of the exception string
	*
	* @return return WASM module loaded, NULL if failed
	*/
	wasm_runtime_load_from_sections :: proc(section_list: wasm_section_list_t, is_aot: c.bool, error_buf: [^]c.char, error_buf_size: c.uint32_t) -> wasm_module_t ---

	/**
	* Unload a WASM module.
	*
	* @param module the module to be unloaded
	*/
	wasm_runtime_unload :: proc(module: wasm_module_t) ---

	/**
	* Set WASI parameters.
	*
	* While this API operates on a module, these parameters will be used
	* only when the module is instantiated. That is, you can consider these
	* as extra parameters for wasm_runtime_instantiate().
	*
	* @param module        The module to set WASI parameters.
	* @param dir_list      The list of directories to preopen. (real path)
	* @param dir_count     The number of elements in dir_list.
	* @param map_dir_list  The list of directories to preopen. (mapped path)
	*                      Format for each map entry: <guest-path>::<host-path>
	* @param map_dir_count The number of elements in map_dir_list.
	*                      If map_dir_count is smaller than dir_count,
	*                      mapped path is assumed to be same as the
	*                      corresponding real path for the rest of entries.
	* @param env           The list of environment variables.
	* @param env_count     The number of elements in env.
	* @param argv          The list of command line arguments.
	* @param argc          The number of elements in argv.
	* @param stdin_handle  The raw host handle to back WASI STDIN_FILENO.
	*                      If an invalid handle is specified (e.g. -1 on POSIX,
	*                      INVALID_HANDLE_VALUE on Windows), the platform default
	*                      for STDIN is used.
	* @param stdoutfd      The raw host handle to back WASI STDOUT_FILENO.
	*                      If an invalid handle is specified (e.g. -1 on POSIX,
	*                      INVALID_HANDLE_VALUE on Windows), the platform default
	*                      for STDOUT is used.
	* @param stderrfd      The raw host handle to back WASI STDERR_FILENO.
	*                      If an invalid handle is specified (e.g. -1 on POSIX,
	*                      INVALID_HANDLE_VALUE on Windows), the platform default
	*                      for STDERR is used.
	*/
	wasm_runtime_set_wasi_args_ex :: proc(module: wasm_module_t, dir_list: [^]cstring, dir_count: c.uint32_t, map_dir_list: [^]cstring, map_dir_count: c.uint32_t, env: [^]cstring, env_count: c.uint32_t, argv: [^]cstring, argc: c.int, stdinfd, stdoutfd, sterrfd: c.int64_t) ---

	/**
	* Set WASI parameters.
	*
	* Same as wasm_runtime_set_wasi_args_ex but with default stdio handles
	*/
	wasm_runtime_set_wasi_args :: proc(module: wasm_module_t, dir_list: [^]cstring, dir_count: c.uint32_t, map_dir_list: [^]cstring, map_dir_count: c.uint32_t, env: [^]cstring, env_count: c.uint32_t, argv: [^]cstring, argc: c.int) ---

	wasm_runtime_set_wasi_addr_pool :: proc(module: wasm_module_t, addr_pool: [^]cstring, addr_pool_size: c.uint32_t) ---

	wasm_runtime_set_wasi_ns_lookup_pool :: proc(module: wasm_module_t, ns_lookup_pool: [^]cstring, ns_lookup_pool_size: c.uint32_t) ---

	/**
	* Instantiate a WASM module.
	*
	* @param module the WASM module to instantiate
	* @param default_stack_size the default stack size of the module instance when
	*        the exec env's operation stack isn't created by user, e.g. API
	*        wasm_application_execute_main() and wasm_application_execute_func()
	*        create the operation stack internally with the stack size specified
	*        here. And API wasm_runtime_create_exec_env() creates the operation
	*        stack with stack size specified by its parameter, the stack size
	*        specified here is ignored.
	* @param host_managed_heap_size the default heap size of the module instance,
	*        a heap will be created besides the app memory space. Both wasm app
	*        and native function can allocate memory from the heap.
	* @param error_buf buffer to output the error info if failed
	* @param error_buf_size the size of the error buffer
	*
	* @return return the instantiated WASM module instance, NULL if failed
	*/
	wasm_runtime_instantiate :: proc(module: wasm_module_t, default_stack_size, host_managed_heap_size: c.uint32_t, error_buf: [^]c.char, error_buf_size: c.uint32_t) -> wasm_module_inst_t ---

	/**
	* Instantiate a WASM module, with specified instantiation arguments
	*
	* Same as wasm_runtime_instantiate, but it also allows overwriting maximum
	* memory
	*/
	wasm_runtime_instantiate_ex :: proc(module: wasm_module_t, args: ^InstantiationArgs, error_buf: [^]c.char, error_buf_size: c.uint32_t) -> wasm_module_inst_t ---

	/**
	* Set the running mode of a WASM module instance, override the
	* default running mode of the runtime. Note that it only makes sense when
	* the input is a wasm bytecode file: for the AOT file, runtime always runs
	* it with AOT engine, and this function always returns true.
	*
	* @param module_inst the WASM module instance to set running mode
	* @param running_mode the running mode to set
	*
	* @return true if success, false otherwise
	*/
	wasm_runtime_set_running_mode :: proc(module_inst: wasm_module_inst_t, running_mode: RunningMode) -> c.bool ---

	/**
	* Get the running mode of a WASM module instance, if no running mode
	* is explicitly set the default running mode of runtime will
	* be used and returned. Note that it only makes sense when the input is a
	* wasm bytecode file: for the AOT file, this function always returns 0.
	*
	* @param module_inst the WASM module instance to query for running mode
	*
	* @return the running mode this module instance currently use
	*/
	wasm_runtime_get_running_mode :: proc(module_inst: wasm_module_inst_t) -> RunningMode ---

	/**
	* Deinstantiate a WASM module instance, destroy the resources.
	*
	* @param module_inst the WASM module instance to destroy
	*/
	wasm_runtime_deinstantiate :: proc(module_inst: wasm_module_inst_t) ---

	/**
	* Get WASM module from WASM module instance
	*
	* @param module_inst the WASM module instance to retrieve
	*
	* @return the WASM module
	*/
	wasm_runtime_get_module :: proc(module_inst: wasm_module_inst_t) -> wasm_module_t ---

	wasm_runtime_is_wasi_mode :: proc(module_inst: wasm_module_inst_t) -> wasm_module_t ---

	wasm_runtime_lookup_wasi_start_function :: proc(module_inst: wasm_module_inst_t) -> wasm_function_inst_t ---

	/**
	* Get WASI exit code.
	*
	* After a WASI command completed its execution, an embedder can
	* call this function to get its exit code. (that is, the value given
	* to proc_exit.)
	*
	* @param module_inst the module instance
	*/
	wasm_runtime_get_wasi_exit_code :: proc(module_inst: wasm_module_inst_t) -> c.uint32_t ---

	/**
	* Lookup an exported function in the WASM module instance.
	*
	* @param module_inst the module instance
	* @param name the name of the function
	*
	* @return the function instance found, NULL if not found
	*/
	wasm_runtime_lookup_function :: proc(module_inst: wasm_module_inst_t, name: cstring) -> wasm_function_inst_t ---

	/**
	* Get parameter count of the function instance
	*
	* @param func_inst the function instance
	* @param module_inst the module instance the function instance belongs to
	*
	* @return the parameter count of the function instance
	*/
	wasm_func_get_param_count :: proc(func_inst: wasm_function_inst_t, module_inst: wasm_module_inst_t) -> c.uint32_t ---

	/**
	* Get result count of the function instance
	*
	* @param func_inst the function instance
	* @param module_inst the module instance the function instance belongs to
	*
	* @return the result count of the function instance
	*/
	wasm_func_get_result_count :: proc(func_inst: wasm_function_inst_t, module_inst: wasm_module_inst_t) -> c.uint32_t ---

	/**
	* Get parameter types of the function instance
	*
	* @param func_inst the function instance
	* @param module_inst the module instance the function instance belongs to
	* @param param_types the parameter types returned
	*/
	wasm_func_get_param_types :: proc(func_inst: wasm_function_inst_t, module_inst: wasm_module_inst_t, param_types: [^]wasm_valkind_t) ---

	/**
	* Get result types of the function instance
	*
	* @param func_inst the function instance
	* @param module_inst the module instance the function instance belongs to
	* @param result_types the result types returned
	*/
	wasm_func_get_result_types :: proc(func_inst: wasm_function_inst_t, module_inst: wasm_module_inst_t, result_types: [^]wasm_valkind_t) ---

	/**
	* Create execution environment for a WASM module instance.
	*
	* @param module_inst the module instance
	* @param stack_size the stack size to execute a WASM function
	*
	* @return the execution environment, NULL if failed, e.g. invalid
	*         stack size is passed
	*/
	wasm_runtime_create_exec_env :: proc(module_inst: wasm_module_inst_t, stack_size: c.uint32_t) -> wasm_exec_env_t ---

	/**
	* Destroy the execution environment.
	*
	* @param exec_env the execution environment to destroy
	*/
	wasm_runtime_destroy_exec_env :: proc(exec_env: wasm_exec_env_t) ---

	/**
	* Get the singleton execution environment for the instance.
	*
	* Note: The singleton execution environment is the execution
	* environment used internally by the runtime for the API functions
	* like wasm_application_execute_main, which don't take explicit
	* execution environment. It's associated to the corresponding
	* module instance and managed by the runtime. The API user should
	* not destroy it with wasm_runtime_destroy_exec_env.
	*
	* @param module_inst the module instance
	*
	* @return exec_env the execution environment to destroy
	*/
	wasm_runtime_get_exec_env_singleton :: proc(module_inst: wasm_module_inst_t) -> wasm_exec_env_t ---

	/**
	* Start debug instance based on given execution environment.
	* Note:
	*   The debug instance will be destroyed during destroying the
	*   execution environment, developers don't need to destroy it
	*   manually.
	*   If the cluster of this execution environment has already
	*   been bound to a debug instance, this function will return true
	*   directly.
	*   If developer spawns some exec_env by wasm_runtime_spawn_exec_env,
	*   don't need to call this function for every spawned exec_env as
	*   they are sharing the same cluster with the main exec_env.
	*
	* @param exec_env the execution environment to start debug instance
	* @param port     the port for the debug server to listen on.
	*                 0 means automatic assignment.
	*                 -1 means to use the global setting in RuntimeInitArgs.
	*
	* @return debug port if success, 0 otherwise.
	*/
	wasm_runtime_start_debug_instance_with_port :: proc(exec_env: wasm_exec_env_t, port: c.int32_t) -> c.uint32_t ---

	/**
	* Same as wasm_runtime_start_debug_instance_with_port(env, -1).
	*/
	wasm_runtime_start_debug_instance :: proc(exec_env: wasm_exec_env_t) -> c.uint32_t ---

	/**
	* Initialize the thread environment.
	* Note:
	*   If developer creates a child thread by himself to call the
	*   the wasm function in that thread, he should call this API
	*   firstly before calling the wasm function and then call
	*   wasm_runtime_destroy_thread_env() after calling the wasm
	*   function. If the thread is created from the runtime API,
	*   it is unnecessary to call these two APIs.
	*
	* @return true if success, false otherwise
	*/
	wasm_runtime_init_thread_env :: proc() -> c.bool ---

	/**
	* Destroy the thread environment
	*/
	wasm_runtime_destroy_thread_env :: proc() ---

	/**
	* Whether the thread environment is initialized
	*/
	wasm_runtime_thread_env_inited :: proc() -> c.bool ---

	/**
	* Get WASM module instance from execution environment
	*
	* @param exec_env the execution environment to retrieve
	*
	* @return the WASM module instance
	*/
	wasm_runtime_get_module_inst :: proc(exec_env: wasm_exec_env_t) -> wasm_module_inst_t ---

	/**
	* Set WASM module instance of execution environment
	* Caution:
	*   normally the module instance is bound with the execution
	*   environment one by one, if multiple module instances want
	*   to share to the same execution environment, developer should
	*   be responsible for the backup and restore of module instance
	*
	* @param exec_env the execution environment
	* @param module_inst the WASM module instance to set
	*/
	wasm_runtime_set_module_inst :: proc(exec_env: wasm_exec_env_t, module_inst: wasm_module_inst_t) ---

	/**
	* @brief Lookup a memory instance by name
	*
	* @param module_inst The module instance
	* @param name The name of the memory instance
	*
	* @return The memory instance if found, NULL otherwise
	*/
	wasm_runtime_lookup_memory :: proc(module_inst: wasm_module_inst_t, name: cstring) -> wasm_memory_inst_t ---

	/**
	* @brief Get the default memory instance
	*
	* @param module_inst The module instance
	*
	* @return The memory instance if found, NULL otherwise
	*/
	wasm_runtime_get_default_memory :: proc(module_inst: wasm_module_inst_t) -> wasm_memory_inst_t ---

	/**
	* @brief Get a memory instance by index
	*
	* @param module_inst The module instance
	* @param index The index of the memory instance
	*
	* @return The memory instance if found, NULL otherwise
	*/
	wasm_runtime_get_memory :: proc(module_inst: wasm_module_inst_t, index: c.uint32_t) -> wasm_memory_inst_t ---

	/**
	* @brief Get the current number of pages for a memory instance
	*
	* @param memory_inst The memory instance
	*
	* @return The current number of pages
	*/
	wasm_memory_get_cur_page_count :: proc(memory_inst: wasm_memory_inst_t) -> c.uint64_t ---

	/**
	* @brief Get the maximum number of pages for a memory instance
	*
	* @param memory_inst The memory instance
	*
	* @return The maximum number of pages
	*/
	wasm_memory_get_max_page_count :: proc(memory_inst: wasm_memory_inst_t) -> c.uint64_t ---

	/**
	* @brief Get the number of bytes per page for a memory instance
	*
	* @param memory_inst The memory instance
	*
	* @return The number of bytes per page
	*/
	wasm_memory_get_bytes_per_page :: proc(memory_inst: wasm_memory_inst_t) -> c.uint64_t ---

	/**
	* @brief Get the shared status for a memory instance
	*
	* @param memory_inst The memory instance
	*
	* @return True if shared, false otherwise
	*/
	wasm_memory_get_shared :: proc(memory_inst: wasm_memory_inst_t) -> c.bool ---

	/**
	* @brief Get the base address for a memory instance
	*
	* @param memory_inst The memory instance
	*
	* @return The base address on success, false otherwise
	*/
	wasm_memory_get_base_address :: proc(memory_inst: wasm_memory_inst_t) -> rawptr ---

	/**
	* @brief Enlarge a memory instance by a number of pages
	*
	* @param memory_inst The memory instance
	* @param inc_page_count The number of pages to add
	*
	* @return True if successful, false otherwise
	*/
	wasm_memory_enlarge :: proc(memory_inst: wasm_memory_inst_t, inc_page_count: c.uint64_t) -> c.bool ---

	/**
	* Call the given WASM function of a WASM module instance with
	* arguments (bytecode and AoT).
	*
	* @param exec_env the execution environment to call the function,
	*   which must be created from wasm_create_exec_env()
	* @param function the function to call
	* @param argc total cell number that the function parameters occupy,
	*   a cell is a slot of the uint32 array argv[], e.g. i32/f32 argument
	*   occupies one cell, i64/f64 argument occupies two cells, note that
	*   it might be different from the parameter number of the function
	* @param argv the arguments. If the function has return value,
	*   the first (or first two in case 64-bit return value) element of
	*   argv stores the return value of the called WASM function after this
	*   function returns.
	*
	* @return true if success, false otherwise and exception will be thrown,
	*   the caller can call wasm_runtime_get_exception to get the exception
	*   info.
	*/
	wasm_runtime_call_wasm :: proc(exec_env: wasm_exec_env_t, function: wasm_function_inst_t, argc: c.uint32_t, argv: [^]c.uint32_t) -> c.bool ---

	/**
	* Call the given WASM function of a WASM module instance with
	* provided results space and arguments (bytecode and AoT).
	*
	* @param exec_env the execution environment to call the function,
	*   which must be created from wasm_create_exec_env()
	* @param function the function to call
	* @param num_results the number of results
	* @param results the pre-alloced pointer to get the results
	* @param num_args the number of arguments
	* @param args the arguments
	*
	* @return true if success, false otherwise and exception will be thrown,
	*   the caller can call wasm_runtime_get_exception to get the exception
	*   info.
	*/
	wasm_runtime_call_wasm_a :: proc(exec_env: wasm_exec_env_t, function: wasm_function_inst_t, num_results: c.uint32_t, results: [^]wasm_val_t, num_args: c.uint32_t, args: [^]wasm_val_t) -> c.bool ---

	/**
	* Call the given WASM function of a WASM module instance with
	* provided results space and variant arguments (bytecode and AoT).
	*
	* @param exec_env the execution environment to call the function,
	*   which must be created from wasm_create_exec_env()
	* @param function the function to call
	* @param num_results the number of results
	* @param results the pre-alloced pointer to get the results
	* @param num_args the number of arguments
	* @param ... the variant arguments
	*
	* @return true if success, false otherwise and exception will be thrown,
	*   the caller can call wasm_runtime_get_exception to get the exception
	*   info.
	*/
	wasm_runtime_call_wasm_v :: proc(exec_env: wasm_exec_env_t, function: wasm_function_inst_t, num_results: c.uint32_t, results: [^]wasm_val_t, num_args: c.uint32_t, #c_vararg args: ..any) -> c.bool ---

	/**
	* Call a function reference of a given WASM runtime instance with
	* arguments.
	*
	* Note: this can be used to call a function which is not exported
	* by the module explicitly. You might consider it as an abstraction
	* violation.
	*
	* @param exec_env the execution environment to call the function
	*   which must be created from wasm_create_exec_env()
	* @param element_index the function reference index, usually
	*   provided by the caller of a registered native function
	* @param argc the number of arguments
	* @param argv the arguments.  If the function method has return value,
	*   the first (or first two in case 64-bit return value) element of
	*   argv stores the return value of the called WASM function after this
	*   function returns.
	*
	* @return true if success, false otherwise and exception will be thrown,
	*   the caller can call wasm_runtime_get_exception to get exception info.
	*/
	wasm_runtime_call_indirect :: proc(exec_env: wasm_exec_env_t, element_index: c.uint32_t, argc: c.uint32_t, argv: [^]c.uint32_t) -> c.bool ---

	/**
	* Find the unique main function from a WASM module instance
	* and execute that function.
	*
	* @param module_inst the WASM module instance
	* @param argc the number of arguments
	* @param argv the arguments array, if the main function has return value,
	*   *(int*)argv stores the return value of the called main function after
	*   this function returns.
	*
	* @return true if the main function is called, false otherwise and exception
	*   will be thrown, the caller can call wasm_runtime_get_exception to get
	*   the exception info.
	*/
	wasm_application_execute_main :: proc(module_inst: wasm_module_inst_t, argc: c.int32_t, argv: [^]cstring) -> c.bool ---

	/**
	* Find the specified function from a WASM module instance and execute
	* that function.
	*
	* @param module_inst the WASM module instance
	* @param name the name of the function to execute.
	*  to indicate the module name via: $module_name$function_name
	*  or just a function name: function_name
	* @param argc the number of arguments
	* @param argv the arguments array
	*
	* @return true if the specified function is called, false otherwise and
	*   exception will be thrown, the caller can call wasm_runtime_get_exception
	*   to get the exception info.
	*/
	wasm_application_execute_func :: proc(module_inst: wasm_module_inst_t, name: cstring, argc: c.int32_t, argv: [^]cstring) -> bool ---

	/**
	* Get exception info of the WASM module instance.
	*
	* @param module_inst the WASM module instance
	*
	* @return the exception string
	*/
	wasm_runtime_get_exception :: proc(module_inst: wasm_module_inst_t) -> cstring ---

	/**
	* Set exception info of the WASM module instance.
	*
	* @param module_inst the WASM module instance
	*
	* @param exception the exception string
	*/
	wasm_runtime_set_exception :: proc(module_inst: wasm_module_inst_t, exception: cstring) ---

	/**
	* Clear exception info of the WASM module instance.
	*
	* @param module_inst the WASM module instance
	*/
	wasm_runtime_clear_exception :: proc(module_inst: wasm_module_inst_t) ---

	/**
	* Terminate the WASM module instance.
	*
	* This function causes the module instance fail as if it raised a trap.
	*
	* This is intended to be used in situations like:
	*
	*  - A thread is executing the WASM module instance
	*    (eg. it's in the middle of `wasm_application_execute_main`)
	*
	*  - Another thread has a copy of `wasm_module_inst_t` of
	*    the module instance and wants to terminate it asynchronously.
	*
	* @param module_inst the WASM module instance
	*/
	wasm_runtime_terminate :: proc(module_inst: wasm_module_inst_t) ---

	/**
	* Set custom data to WASM module instance.
	* Note:
	*  If WAMR_BUILD_LIB_PTHREAD is enabled, this API
	*  will spread the custom data to all threads
	*
	* @param module_inst the WASM module instance
	* @param custom_data the custom data to be set
	*/
	wasm_runtime_set_custom_data :: proc(module_inst: wasm_module_inst_t, custom_data: rawptr) ---

	/**
	* Get the custom data within a WASM module instance.
	*
	* @param module_inst the WASM module instance
	*
	* @return the custom data (NULL if not set yet)
	*/
	wasm_runtime_get_custom_data :: proc(module_inst: wasm_module_inst_t) -> rawptr ---

	/**
	* Set the memory bounds checks flag of a WASM module instance.
	*
	* @param module_inst the WASM module instance
	* @param enable the flag to enable/disable the memory bounds checks
	*/
	wasm_runtime_set_bounds_checks :: proc(module_inst: wasm_module_inst_t, enable: c.bool) ---

	/**
	* Check if the memory bounds checks flag is enabled for a WASM module instance.
	*
	* @param module_inst the WASM module instance
	* @return true if the memory bounds checks flag is enabled, false otherwise
	*/
	wasm_runtime_is_bounds_checks_enabled :: proc(module_inst: wasm_module_inst_t) -> c.bool ---

	/**
	* Allocate memory from the heap of WASM module instance
	*
	* Note: wasm_runtime_module_malloc can call heap functions inside
	* the module instance and thus cause a memory growth.
	* This API needs to be used very carefully when you have a native
	* pointers to the module instance memory obtained with
	* wasm_runtime_addr_app_to_native or similar APIs.
	*
	* @param module_inst the WASM module instance which contains heap
	* @param size the size bytes to allocate
	* @param p_native_addr return native address of the allocated memory
	*        if it is not NULL, and return NULL if memory malloc failed
	*
	* @return the allocated memory address, which is a relative offset to the
	*         base address of the module instance's memory space. Note that
	*         it is not an absolute address.
	*         Return non-zero if success, zero if failed.
	*/
	wasm_runtime_module_malloc :: proc(module_inst: wasm_module_inst_t, size: c.uint64_t, p_native_addr: rawptr) -> c.uint64_t ---

	/**
	* Free memory to the heap of WASM module instance
	*
	* @param module_inst the WASM module instance which contains heap
	* @param ptr the pointer to free
	*/
	wasm_runtime_module_free :: proc(module_inst: wasm_module_inst_t, ptr: c.uint64_t) ---

	/**
	* Allocate memory from the heap of WASM module instance and initialize
	* the memory with src
	*
	* @param module_inst the WASM module instance which contains heap
	* @param src the source data to copy
	* @param size the size of the source data
	*
	* @return the allocated memory address, which is a relative offset to the
	*         base address of the module instance's memory space. Note that
	*         it is not an absolute address.
	*         Return non-zero if success, zero if failed.
	*/
	wasm_runtime_module_dup_data :: proc(module_inst: wasm_module_inst_t, src: [^]c.char, size: c.uint64_t) -> c.uint64_t ---

	/**
	* Validate the app address, check whether it belongs to WASM module
	* instance's address space, or in its heap space or memory space.
	*
	* @param module_inst the WASM module instance
	* @param app_offset the app address to validate, which is a relative address
	* @param size the size bytes of the app address
	*
	* @return true if success, false otherwise. If failed, an exception will
	*         be thrown.
	*/
	wasm_runtime_validate_app_addr :: proc(module_inst: wasm_module_inst_t, app_offset, size: c.uint64_t) -> c.bool ---

	/**
	* Similar to wasm_runtime_validate_app_addr(), except that the size parameter
	* is not provided. This function validates the app string address, check
	* whether it belongs to WASM module instance's address space, or in its heap
	* space or memory space. Moreover, it checks whether it is the offset of a
	* string that is end with '\0'.
	*
	* Note: The validation result, especially the NUL termination check,
	* is not reliable for a module instance with multiple threads because
	* other threads can modify the heap behind us.
	*
	* @param module_inst the WASM module instance
	* @param app_str_offset the app address of the string to validate, which is a
	*        relative address
	*
	* @return true if success, false otherwise. If failed, an exception will
	*         be thrown.
	*/
	wasm_runtime_validate_app_str_addr :: proc(module_inst: wasm_module_inst_t, app_offset_str: c.uint64_t) -> c.bool ---

	/**
	* Validate the native address, check whether it belongs to WASM module
	* instance's address space, or in its heap space or memory space.
	*
	* @param module_inst the WASM module instance
	* @param native_ptr the native address to validate, which is an absolute
	*        address
	* @param size the size bytes of the app address
	*
	* @return true if success, false otherwise. If failed, an exception will
	*         be thrown.
	*/
	wasm_runtime_validate_native_addr :: proc(module_inst: wasm_module_inst_t, native_ptr: rawptr, size: c.uint64_t) -> c.bool ---

	/**
	* Convert app address (relative address) to native address (absolute address)
	*
	* Note that native addresses to module instance memory can be invalidated
	* on a memory growth. (Except shared memory, whose native addresses are
	* stable.)
	*
	* @param module_inst the WASM module instance
	* @param app_offset the app address
	*
	* @return the native address converted
	*/
	wasm_runtime_addr_app_to_native :: proc(module_inst: wasm_module_inst_t, app_offset: c.uint64_t) -> rawptr ---

	/**
	* Convert native address (absolute address) to app address (relative address)
	*
	* @param module_inst the WASM module instance
	* @param native_ptr the native address
	*
	* @return the app address converted
	*/
	wasm_runtime_addr_native_to_app :: proc(module_inst: wasm_module_inst_t, native_ptr: rawptr) -> c.uint64_t ---

	/**
	* Get the app address range (relative address) that a app address belongs to
	*
	* @param module_inst the WASM module instance
	* @param app_offset the app address to retrieve
	* @param p_app_start_offset buffer to output the app start offset if not NULL
	* @param p_app_end_offset buffer to output the app end offset if not NULL
	*
	* @return true if success, false otherwise.
	*/
	wasm_runtime_get_app_addr_range :: proc(module_inst: wasm_module_inst_t, app_offset: c.uint64_t, p_app_start_offset, p_app_end_offset: [^]c.uint64_t) -> c.bool ---

	/**
	* Get the native address range (absolute address) that a native address
	* belongs to
	*
	* @param module_inst the WASM module instance
	* @param native_ptr the native address to retrieve
	* @param p_native_start_addr buffer to output the native start address
	*        if not NULL
	* @param p_native_end_addr buffer to output the native end address
	*        if not NULL
	*
	* @return true if success, false otherwise.
	*/
	wasm_runtime_get_native_addr_range :: proc(module_inst: wasm_module_inst_t, native_ptr: [^]c.uint8_t, p_native_start_addr, p_native_end_addr: ^[^]c.uint8_t) -> c.bool ---

	/**
	* Get the number of import items for a WASM module
	*
	* @param module the WASM module
	*
	* @return the number of imports (zero for none), or -1 for failure
	*/
	wasm_runtime_get_import_count :: proc(module: wasm_module_t) -> c.int32_t ---

	/**
	* Get information about a specific WASM module import
	*
	* @param module the WASM module
	* @param import_index the desired import index
	* @param import_type the location to store information about the import
	*/
	wasm_runtime_get_import_type :: proc(module: wasm_module_t, import_index: c.int32_t, import_type: ^wasm_import_t) ---

	/**
	* Get the number of export items for a WASM module
	*
	* @param module the WASM module
	*
	* @return the number of exports (zero for none), or -1 for failure
	*/
	wasm_runtime_get_export_count :: proc(module: wasm_module_t) -> c.int32_t ---

	/**
	* Get information about a specific WASM module export
	*
	* @param module the WASM module
	* @param export_index the desired export index
	* @param export_type the location to store information about the export
	*/
	wasm_runtime_get_export_type :: proc(module: wasm_module_t, export_index: c.int32_t, export_type: ^wasm_export_t) ---

	/**
	* Get the number of parameters for a function type
	*
	* @param func_type the function type
	*
	* @return the number of parameters for the function type
	*/
	wasm_func_type_get_param_count :: proc(func_type: wasm_func_type_t) -> c.uint32_t ---

	/**
	* Get the kind of a parameter for a function type
	*
	* @param func_type the function type
	* @param param_index the index of the parameter to get
	*
	* @return the kind of the parameter if successful, -1 otherwise
	*/
	wasm_func_type_get_param_valkind :: proc(func_type: wasm_func_type_t, param_index: c.uint32_t) -> wasm_valkind_t ---

	/**
	* Get the number of results for a function type
	*
	* @param func_type the function type
	*
	* @return the number of results for the function type
	*/
	wasm_func_type_get_result_count :: proc(func_type: wasm_func_type_t) -> c.uint32_t ---

	/**
	* Get the kind of a result for a function type
	*
	* @param func_type the function type
	* @param result_index the index of the result to get
	*
	* @return the kind of the result if successful, -1 otherwise
	*/
	wasm_func_type_get_result_valkind :: proc(func_type: wasm_func_type_t, result_index: c.uint32_t) -> wasm_valkind_t ---

	/**
	* Get the kind for a global type
	*
	* @param global_type the global type
	*
	* @return the kind of the global
	*/
	wasm_global_type_get_valkind :: proc(global_type: wasm_global_type_t) -> wasm_valkind_t ---

	/**
	* Get the mutability for a global type
	*
	* @param global_type the global type
	*
	* @return true if mutable, false otherwise
	*/
	wasm_global_type_get_mutable :: proc(global_type: wasm_global_type_t) -> c.bool ---

	/**
	* Get the shared setting for a memory type
	*
	* @param memory_type the memory type
	*
	* @return true if shared, false otherwise
	*/
	wasm_memory_type_get_shared :: proc(memory_type: wasm_memory_type_t) -> c.bool ---

	/**
	* Get the initial page count for a memory type
	*
	* @param memory_type the memory type
	*
	* @return the initial memory page count
	*/
	wasm_memory_type_get_init_page_count :: proc(memory_type: wasm_memory_type_t) -> c.uint32_t ---

	/**
	* Get the maximum page count for a memory type
	*
	* @param memory_type the memory type
	*
	* @return the maximum memory page count
	*/
	wasm_memory_type_get_max_page_count :: proc(memory_type: wasm_memory_type_t) -> c.uint32_t ---

	/**
	* Get the element kind for a table type
	*
	* @param table_type the table type
	*
	* @return the element kind
	*/
	wasm_table_type_get_elem_kind :: proc(table_type: wasm_table_type_t) -> wasm_valkind_t ---

	/**
	* Get the sharing setting for a table type
	*
	* @param table_type the table type
	*
	* @return true if shared, false otherwise
	*/
	wasm_table_type_get_shared :: proc(table_type: wasm_table_type_t) -> c.bool ---

	/**
	* Get the initial size for a table type
	*
	* @param table_type the table type
	*
	* @return the initial table size
	*/
	wasm_table_type_get_init_size :: proc(table_type: wasm_table_type_t) -> c.uint32_t ---

	/**
	* Get the maximum size for a table type
	*
	* @param table_type the table type
	*
	* @return the maximum table size
	*/
	wasm_table_type_get_max_size :: proc(table_type: wasm_table_type_t) -> c.uint32_t ---

	/**
	* Register native functions with same module name
	*
	* Note: The array `native_symbols` should not be read-only because the
	* library can modify it in-place.
	*
	* Note: After successful call of this function, the array `native_symbols`
	* is owned by the library.
	*
	* @param module_name the module name of the native functions
	* @param native_symbols specifies an array of NativeSymbol structures which
	*        contain the names, function pointers and signatures
	*        Note: WASM runtime will not allocate memory to clone the data, so
	*              user must ensure the array can be used forever
	*        Meanings of letters in function signature:
	*          'i': the parameter is i32 type
	*          'I': the parameter is i64 type
	*          'f': the parameter is f32 type
	*          'F': the parameter is f64 type
	*          'r': the parameter is externref type, it should be a uintptr_t
	*               in host
	*          '*': the parameter is a pointer (i32 in WASM), and runtime will
	*               auto check its boundary before calling the native function.
	*               If it is followed by '~', the checked length of the pointer
	*               is gotten from the following parameter, if not, the checked
	*               length of the pointer is 1.
	*          '~': the parameter is the pointer's length with i32 type, and must
	*               follow after '*'
	*          '$': the parameter is a string (i32 in WASM), and runtime will
	*               auto check its boundary before calling the native function
	* @param n_native_symbols specifies the number of native symbols in the array
	*
	* @return true if success, false otherwise
	*/
	wasm_runtime_register_natives :: proc(module_name: cstring, native_symbols: [^]NativeSymbol, n_native_symbols: c.uint32_t) -> c.bool ---

	/**
	* Register native functions with same module name, similar to
	*   wasm_runtime_register_natives, the difference is that runtime passes raw
	* arguments to native API, which means that the native API should be defined as
	*   void foo(wasm_exec_env_t exec_env, uint64 *args);
	* and native API should extract arguments one by one from args array with macro
	*   native_raw_get_arg
	* and write the return value back to args[0] with macro
	*   native_raw_return_type and native_raw_set_return
	*/
	wasm_runtime_register_natives_raw :: proc(module_name: cstring, native_symbols: [^]NativeSymbol, n_native_symbols: c.uint32_t) -> c.bool ---

	/**
	* Undo wasm_runtime_register_natives or wasm_runtime_register_natives_raw
	*
	* @param module_name    Should be the same as the corresponding
	*                       wasm_runtime_register_natives.
	*                       (Same in term of strcmp.)
	*
	* @param native_symbols Should be the same as the corresponding
	*                       wasm_runtime_register_natives.
	*                       (Same in term of pointer comparison.)
	*
	* @return true if success, false otherwise
	*/
	wasm_runtime_unregister_natives :: proc(module_name: cstring, native_symbols: [^]NativeSymbol) -> c.bool ---

	/**
	* Get an export global instance
	*
	* @param module_inst the module instance
	* @param name the export global name
	* @param global_inst location to store the global instance
	*
	* @return true if success, false otherwise
	*
	*/
	wasm_runtime_get_export_global_inst :: proc(module_inst: wasm_module_inst_t, name: cstring, global_inst: ^wasm_global_inst_t) -> c.bool ---

	/**
	* Get an export table instance
	*
	* @param module_inst the module instance
	* @param name the export table name
	* @param table_inst location to store the table instance
	*
	* @return true if success, false otherwise
	*
	*/
	wasm_runtime_get_export_table_inst :: proc(module_inst: wasm_module_inst_t, name: cstring, table_inst: ^wasm_table_inst_t) -> c.bool ---

	/**
	* Get a function instance from a table.
	*
	* @param module_inst the module instance
	* @param table_inst the table instance
	* @param idx the index in the table
	*
	* @return the function instance if successful, NULL otherwise
	*/
	wasm_table_get_func_inst :: proc(module_inst: wasm_module_inst_t, table_inst: ^wasm_table_inst_t, idx: c.uint32_t) -> wasm_function_inst_t ---

	/**
	* Get attachment of native function from execution environment
	*
	* @param exec_env the execution environment to retrieve
	*
	* @return the attachment of native function
	*/
	wasm_runtime_get_function_attachment :: proc(exec_env: wasm_exec_env_t) -> rawptr ---

	/**
	* Set user data to execution environment.
	*
	* @param exec_env the execution environment
	* @param user_data the user data to be set
	*/
	wasm_runtime_set_user_data :: proc(exec_env: wasm_exec_env_t, user_data: rawptr) ---

	/**
	* Get the user data within execution environment.
	*
	* @param exec_env the execution environment
	*
	* @return the user data (NULL if not set yet)
	*/
	wasm_runtime_get_user_data :: proc(exec_env: wasm_exec_env_t) -> rawptr ---

	/**
	* Set native stack boundary to execution environment, if it is set,
	* it will be used instead of getting the boundary with the platform
	* layer API when calling wasm functions. This is useful for some
	* fiber cases.
	*
	* Note: unlike setting the boundary by runtime, this API doesn't add
	* the WASM_STACK_GUARD_SIZE(see comments in core/config.h) to the
	* exec_env's native_stack_boundary to reserve bytes to the native
	* thread stack boundary, which is used to throw native stack overflow
	* exception if the guard boundary is reached. Developer should ensure
	* that enough guard bytes are kept.
	*
	* @param exec_env the execution environment
	* @param native_stack_boundary the user data to be set
	*/
	wasm_runtime_set_native_stack_boundary :: proc(exec_env: wasm_exec_env_t, native_stack_boundary: [^]c.uint8_t) ---

	/**
	* Dump runtime memory consumption, including:
	*     Exec env memory consumption
	*     WASM module memory consumption
	*     WASM module instance memory consumption
	*     stack and app heap used info
	*
	* @param exec_env the execution environment
	*/
	wasm_runtime_dump_mem_consumption :: proc(exec_env: wasm_exec_env_t) ---

	/**
	* Dump runtime performance profiler data of each function
	*
	* @param module_inst the WASM module instance to profile
	*/
	wasm_runtime_dump_perf_profiling :: proc(module_inst: wasm_module_inst_t) ---

	/**
	* Return total wasm functions' execution time in ms
	*
	* @param module_inst the WASM module instance to profile
	*/
	wasm_runtime_sum_wasm_exec_time :: proc(module_inst: wasm_module_inst_t) -> c.double ---

	/**
	* Return execution time in ms of a given wasm function with
	* func_name. If the function is not found, return 0.
	*
	* @param module_inst the WASM module instance to profile
	* @param func_name could be an export name or a name in the
	*                  name section
	*/
	wasm_runtime_get_wasm_func_exec_time :: proc(module_inst: wasm_module_inst_t, func_name: cstring) -> c.double ---

	/**
	* Set the max thread num per cluster.
	*
	* @param num maximum thread num
	*/
	wasm_runtime_set_max_thread_num :: proc(num: c.uint32_t) ---

	/**
	* Spawn a new exec_env, the spawned exec_env
	*   can be used in other threads
	*
	* @param num the original exec_env
	*
	* @return the spawned exec_env if success, NULL otherwise
	*/
	wasm_runtime_spawn_exec_env :: proc(exec_env: wasm_exec_env_t) -> wasm_exec_env_t ---

	/**
	* Destroy the spawned exec_env
	*
	* @param exec_env the spawned exec_env
	*/
	wasm_runtime_destroy_spawned_exec_env :: proc(exec_env: wasm_exec_env_t) ---

	/**
	* Spawn a thread from the given exec_env
	*
	* @param exec_env the original exec_env
	* @param tid thread id to be returned to the caller
	* @param callback the callback function provided by the user
	* @param arg the arguments passed to the callback
	*
	* @return 0 if success, -1 otherwise
	*/
	wasm_runtime_spawn_thread :: proc(exec_env: wasm_exec_env_t, tid: ^wasm_thread_t, callback: wasm_thread_callback_t, arg: rawptr) -> c.int32_t ---

	/**
	* Wait a spawned thread to terminate
	*
	* @param tid thread id
	* @param retval if not NULL, output the return value of the thread
	*
	* @return 0 if success, error number otherwise
	*/
	wasm_runtime_join_thread :: proc(tid: wasm_thread_t, retval: ^rawptr) -> c.int32_t ---

	/**
	* Map external object to an internal externref index: if the index
	*   has been created, return it, otherwise create the index.
	*
	* @param module_inst the WASM module instance that the extern object
	*        belongs to
	* @param extern_obj the external object to be mapped
	* @param p_externref_idx return externref index of the external object
	*
	* @return true if success, false otherwise
	*/
	wasm_externref_obj2ref :: proc(module_inst: wasm_module_inst_t, extern_obj: rawptr, p_externref_idx: ^c.uint32_t) -> c.bool ---

	/**
	* Delete external object registered by `wasm_externref_obj2ref`.
	*
	* @param module_inst the WASM module instance that the extern object
	*        belongs to
	* @param extern_obj the external object to be deleted
	*
	* @return true if success, false otherwise
	*/
	wasm_externref_objdel :: proc(module_inst: wasm_module_inst_t, extern_obj: rawptr) -> c.bool ---

	/**
	* Set cleanup callback to release external object.
	*
	* @param module_inst the WASM module instance that the extern object
	*        belongs to
	* @param extern_obj the external object to which to set the
	*        `extern_obj_cleanup` cleanup callback.
	* @param extern_obj_cleanup a callback to release `extern_obj`
	*
	* @return true if success, false otherwise
	*/
	wasm_externref_set_cleanup :: proc(module_inst: wasm_module_inst_t, extern_obj: rawptr, extern_object_cleanup: proc "c" (_: rawptr)) -> c.bool ---

	/**
	* Retrieve the external object from an internal externref index
	*
	* @param externref_idx the externref index to retrieve
	* @param p_extern_obj return the mapped external object of
	*        the externref index
	*
	* @return true if success, false otherwise
	*/
	wasm_externref_ref2obj :: proc(externref_idx: c.uint32_t, p_extern_obj: ^rawptr) -> c.bool ---

	/**
	* Retain an extern object which is mapped to the internal externref
	*   so that the object won't be cleaned during extern object reclaim
	*   if it isn't used.
	*
	* @param externref_idx the externref index of an external object
	*        to retain
	* @return true if success, false otherwise
	*/
	wasm_externref_retain :: proc(externref_idx: c.uint32_t) -> c.bool ---

	/**
	* Dump the call stack to stdout
	*
	* @param exec_env the execution environment
	*/
	wasm_runtime_dump_call_stack :: proc(exec_env: wasm_exec_env_t) ---

	/**
	* Get the size required to store the call stack contents, including
	* the space for terminating null byte ('\0')
	*
	* @param exec_env the execution environment
	*
	* @return size required to store the contents, 0 means error
	*/
	wasm_runtime_get_call_stack_buf_size :: proc(exec_env: wasm_exec_env_t) -> c.uint32_t ---

	/**
	* Dump the call stack to buffer.
	*
	* @note this function is not thread-safe, please only use this API
	*       when the exec_env is not executing
	*
	* @param exec_env the execution environment
	* @param buf buffer to store the dumped content
	* @param len length of the buffer
	*
	* @return bytes dumped to the buffer, including the terminating null
	*         byte ('\0'), 0 means error and data in buf may be invalid
	*/
	wasm_runtime_dump_call_stack_to_buf :: proc(exec_env: wasm_exec_env_t, buf: [^]c.char, len: c.uint32_t) -> c.uint32_t ---

	/**
	* Get the size required to store the LLVM PGO profile data
	*
	* @param module_inst the WASM module instance
	*
	* @return size required to store the contents, 0 means error
	*/
	wasm_runtime_get_pgo_prof_data_size :: proc(module_inst: wasm_module_inst_t) -> c.uint32_t ---

	/**
	* Dump the LLVM PGO profile data to buffer
	*
	* @param module_inst the WASM module instance
	* @param buf buffer to store the dumped content
	* @param len length of the buffer
	*
	* @return bytes dumped to the buffer, 0 means error and data in buf
	*         may be invalid
	*/
	wasm_runtime_dump_pgo_prof_data_to_buf :: proc(module_inst: wasm_module_inst_t, buf: [^]c.char, len: c.uint32_t) -> c.uint32_t ---

	/**
	* Get a custom section by name
	*
	* @param module_comm the module to find
	* @param name name of the custom section
	* @param len return the length of the content if found
	*
	* @return Custom section content (not including the name length
	*         and name string) if found, NULL otherwise
	*/
	wasm_runtime_get_custom_section :: proc(module_comm: wasm_module_t, name: cstring, len: ^c.uint32_t) -> [^]c.uint8_t ---

	/**
	* Get WAMR semantic version
	*/
	wasm_runtime_get_version :: proc(major, minor, patch: ^c.uint32_t) ---

	/**
	* Check whether an import func `(import <module_name> <func_name> (func ...))`
	* is linked or not with runtime registered native functions
	*/
	wasm_runtime_is_import_func_linked :: proc(module_name, func_name: cstring) -> c.bool ---

	/**
	* Check whether an import global `(import <module_name> <global_name>
	* (global ...))` is linked or not with runtime registered native globals
	*/
	wasm_runtime_is_import_global_linked :: proc(module_name, global_name: cstring) -> c.bool ---

	/**
	* Enlarge the memory region for a module instance
	*
	* @param module_inst the module instance
	* @param inc_page_count the number of pages to add
	*
	* @return true if success, false otherwise
	*/
	wasm_runtime_enlarge_memory :: proc(module_inst: wasm_module_inst_t, inc_page_count: c.uint64_t) -> c.bool ---

	/**
	* Setup callback invoked when memory.grow fails
	*/
	wasm_runtime_set_enlarge_mem_error_callback :: proc(callback: enlarge_memory_error_callback_t, user_data: rawptr) ---

	/*
	* module instance context APIs
	*   wasm_runtime_create_context_key
	*   wasm_runtime_destroy_context_key
	*   wasm_runtime_set_context
	*   wasm_runtime_set_context_spread
	*   wasm_runtime_get_context
	*
	* This set of APIs is intended to be used by an embedder which provides
	* extra sets of native functions, which need per module instance state
	* and are maintained outside of the WAMR tree.
	*
	* It's modelled after the pthread specific API.
	*
	* wasm_runtime_set_context_spread is similar to
	* wasm_runtime_set_context, except that
	* wasm_runtime_set_context_spread applies the change
	* to all threads in the cluster.
	* It's an undefined behavior if multiple threads in a cluster call
	* wasm_runtime_set_context_spread on the same key
	* simultaneously. It's a caller's responsibility to perform necessary
	* serialization if necessary. For example:
	*
	* if (wasm_runtime_get_context(inst, key) == NULL) {
	*     newctx = alloc_and_init(...);
	*     lock(some_lock);
	*     if (wasm_runtime_get_context(inst, key) == NULL) {
	*         // this thread won the race
	*         wasm_runtime_set_context_spread(inst, key, newctx);
	*         newctx = NULL;
	*     }
	*     unlock(some_lock);
	*     if (newctx != NULL) {
	*         // this thread lost the race, free it
	*         cleanup_and_free(newctx);
	*     }
	* }
	*
	* Note: dynamic key create/destroy while instances are live is not
	* implemented as of writing this.
	* it's caller's responsibility to ensure destroying all module instances
	* before calling wasm_runtime_create_context_key or
	* wasm_runtime_destroy_context_key.
	* otherwise, it's an undefined behavior.
	*
	* Note about threads:
	* - When spawning a thread, the contexts (the pointers given to
	*   wasm_runtime_set_context) are copied from the parent
	*   instance.
	* - The destructor is called only on the main instance.
	*/
	wasm_runtime_create_context_key :: proc(dtor: #type proc "c" (inst: wasm_module_inst_t, ctx: rawptr)) -> rawptr ---

	wasm_runtime_destroy_context_key :: proc(key: rawptr) ---

	wasm_runtime_set_context :: proc(inst: wasm_module_inst_t, key, ctx: rawptr) ---

	wasm_runtime_set_context_spread :: proc(inst: wasm_module_inst_t, key, ctx: rawptr) ---

	wasm_runtime_get_context :: proc(inst: wasm_module_inst_t, key: rawptr) -> rawptr ---

	/*
	* wasm_runtime_begin_blocking_op/wasm_runtime_end_blocking_op
	*
	* These APIs are intended to be used by the implementations of
	* host functions. It wraps an operation which possibly blocks for long
	* to prepare for async termination.
	*
	* For simplicity, we recommend to wrap only the very minimum piece of
	* the code with this. Ideally, just a single system call.
	*
	* eg.
	*
	*   if (!wasm_runtime_begin_blocking_op(exec_env)) {
	*       return EINTR;
	*   }
	*   ret = possibly_blocking_op();
	*   wasm_runtime_end_blocking_op(exec_env);
	*   return ret;
	*
	* If threading support (WASM_ENABLE_THREAD_MGR) is not enabled,
	* these functions are no-op.
	*
	* If the underlying platform support (OS_ENABLE_WAKEUP_BLOCKING_OP) is
	* not available, these functions are no-op. In that case, the runtime
	* might not terminate a blocking thread in a timely manner.
	*
	* If the underlying platform support is available, it's used to wake up
	* the thread for async termination. The expectation here is that a
	* `os_wakeup_blocking_op` call makes the blocking operation
	* (`possibly_blocking_op` in the above example) return in a timely manner.
	*
	* The actual wake up mechanism used by `os_wakeup_blocking_op` is
	* platform-dependent. It might impose some platform-dependent restrictions
	* on the implementation of the blocking operation.
	*
	* For example, on POSIX-like platforms, a signal (by default SIGUSR1) is
	* used. The signal delivery configurations (eg. signal handler, signal mask,
	* etc) for the signal are set up by the runtime. You can change the signal
	* to use for this purpose by calling os_set_signal_number_for_blocking_op
	* before the runtime initialization.
	*/
	wasm_runtime_begin_blocking_op :: proc(exec_env: wasm_exec_env_t) -> c.bool ---

	wasm_runtime_end_blocking_op :: proc(exec_env: wasm_exec_env_t) ---

	wasm_runtime_set_module_name :: proc(module: wasm_module_t, name: cstring, error_buf: [^]c.char, error_buf_size: c.uint32_t) -> c.bool ---

	/* return the most recently set module name or "" if never set before */
	wasm_runtime_get_module_name :: proc(module: wasm_module_t) -> cstring ---

	/*
	* wasm_runtime_detect_native_stack_overflow
	*
	* Detect native stack shortage.
	* Ensure that the calling thread still has a reasonable amount of
	* native stack (WASM_STACK_GUARD_SIZE bytes) available.
	*
	* If enough stack is left, this function returns true.
	* Otherwise, this function raises a "native stack overflow" trap and
	* returns false.
	*
	* Note: please do not expect a very strict detection. it's a good idea
	* to give some margins. wasm_runtime_detect_native_stack_overflow itself
	* requires a small amount of stack to run.
	*/
	wasm_runtime_detect_native_stack_overflow :: proc(exec_env: wasm_exec_env_t) -> c.bool ---

	/*
	* wasm_runtime_detect_native_stack_overflow_size
	*
	* Similar to wasm_runtime_detect_native_stack_overflow,
	* but use the caller-specified size instead of WASM_STACK_GUARD_SIZE.
	*
	* An expected usage:
	* ```c
	* __attribute__((noinline))  // inlining can break the stack check
	* void stack_hog(void)
	* {
	*     // consume a lot of stack here
	* }
	*
	* void
	* stack_hog_wrapper(exec_env) {
	*     // the amount of stack stack_hog would consume,
	*     // plus a small margin
	*     uint32_t size = 10000000;
	*
	*     if (!wasm_runtime_detect_native_stack_overflow_size(exec_env, size)) {
	*         // wasm_runtime_detect_native_stack_overflow_size has raised
	*         // a trap.
	*         return;
	*     }
	*     stack_hog();
	* }
	* ```
	*/
	wasm_runtime_detect_native_stack_overflow_size :: proc(exec_env: wasm_exec_env_t, required_size: c.uint32_t) -> c.bool ---

	/**
	* Query whether the wasm binary buffer used to create the module can be freed
	*
	* @param module the target module
	* @return true if the wasm binary buffer can be freed
	*/
	wasm_runtime_is_underlying_binary_freeable :: proc(module: wasm_module_t) -> c.bool ---

	/**
	* Create a shared heap
	*
	* @param init_args the initialization arguments
	* @return the shared heap created
	*/
	wasm_runtime_create_shared_heap :: proc(init_args: ^SharedHeapInitArgs) -> wasm_shared_heap_t ---

	/**
	* Attach a shared heap to a module instance
	*
	* @param module_inst the module instance
	* @param shared_heap the shared heap
	* @return true if success, false if failed
	*/
	wasm_runtime_attach_shared_heap :: proc(module_inst: wasm_module_inst_t, shared_heap: wasm_shared_heap_t) -> c.bool ---

	/**
	* Detach a shared heap from a module instance
	*
	* @param module_inst the module instance
	*/
	wasm_runtime_detach_shared_heap :: proc(module_inst: wasm_module_inst_t) ---

	/**
	* Allocate memory from a shared heap
	*
	* @param module_inst the module instance
	* @param size required memory size
	* @param p_native_addr native address of allocated memory
	*
	* @return return the allocated memory address, which re-uses part of the wasm
	* address space and is in the range of [UINT32 - shared_heap_size + 1, UINT32]
	* (when the wasm memory is 32-bit) or [UINT64 - shared_heap_size + 1, UINT64]
	* (when the wasm memory is 64-bit). Note that it is not an absolute address.
	*         Return non-zero if success, zero if failed.
	*/
	wasm_runtime_shared_heap_malloc :: proc(module_inst: wasm_module_inst_t, size: c.uint64_t, p_native_addr: ^rawptr) -> c.uint64_t ---

	/**
	* Free the memory allocated from shared heap
	*
	* @param module_inst the module instance
	* @param ptr the offset in wasm app
	*/
	wasm_runtime_shared_heap_free :: proc(module_inst: wasm_module_inst_t, ptr: c.uint64_t) ---
}
