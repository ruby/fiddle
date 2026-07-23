#include <fiddle.h>
#include <ruby/thread.h>

#include <stdbool.h>

#ifdef PRIsVALUE
# define RB_OBJ_CLASSNAME(obj) rb_obj_class(obj)
# define RB_OBJ_STRING(obj) (obj)
#else
# define PRIsVALUE "s"
# define RB_OBJ_CLASSNAME(obj) rb_obj_classname(obj)
# define RB_OBJ_STRING(obj) StringValueCStr(obj)
#endif

VALUE cFiddleFunction;

static ID id_ptr, id_abi, id_argument_types, id_return_type, id_is_variadic,
          id_need_gvl, id_name, id_closure, id_aref,
          id_last_error;
#if defined(_WIN32)
static ID id_win32_last_error, id_win32_last_socket_error;
#endif

#define MAX_ARGS (SIZE_MAX / (sizeof(void *) + sizeof(fiddle_generic)) - 1)

#define Check_Max_Args(name, len) \
    Check_Max_Args_(name, len, "")
#define Check_Max_Args_Long(name, len) \
    Check_Max_Args_(name, len, "l")
#define Check_Max_Args_(name, len, fmt) \
    do { \
        if ((size_t)(len) >= MAX_ARGS) { \
            rb_raise(rb_eTypeError, \
                     "%s is so large " \
                     "that it can cause integer overflow (%"fmt"d)", \
                     (name), (len)); \
        } \
    } while (0)

/* Call-path state, converted and validated once in #initialize.
 * Deliberately holds no VALUEs so the type needs no dmark/dcompact. */
typedef struct fiddle_function {
    ffi_cif cif;
    void (*fn)(void);
    int *argument_types;
    int n_argument_types;
    int return_type;
    ffi_abi abi;
    bool is_variadic;
    bool need_gvl;
} fiddle_function_t;

static void
deallocate(void *p)
{
    fiddle_function_t *func = p;
    if (func->cif.arg_types) xfree(func->cif.arg_types);
    if (func->argument_types) xfree(func->argument_types);
    xfree(func);
}

static size_t
function_memsize(const void *p)
{
    const fiddle_function_t *func = p;
    size_t size = 0;

    size += sizeof(*func);
    size += func->n_argument_types * sizeof(int);
#if !defined(FFI_NO_RAW_API) || !FFI_NO_RAW_API
    size += ffi_raw_size((ffi_cif *)&func->cif);
#endif

    return size;
}

const rb_data_type_t function_data_type = {
    .wrap_struct_name = "fiddle/function",
    .function = {
        .dmark = 0,
        .dfree = deallocate,
        .dsize = function_memsize
    },
    .flags = FIDDLE_DEFAULT_TYPED_DATA_FLAGS,
};

static VALUE
allocate(VALUE klass)
{
    fiddle_function_t *func;

    return TypedData_Make_Struct(klass, fiddle_function_t, &function_data_type, func);
}

VALUE
rb_fiddle_new_function(VALUE address, VALUE arg_types, VALUE ret_type)
{
    VALUE argv[3];

    argv[0] = address;
    argv[1] = arg_types;
    argv[2] = ret_type;

    return rb_class_new_instance(3, argv, cFiddleFunction);
}

static VALUE
normalize_argument_types(const char *name,
                         VALUE arg_types,
                         bool *is_variadic)
{
    VALUE normalized_arg_types;
    int i;
    int n_arg_types;
    *is_variadic = false;

    Check_Type(arg_types, T_ARRAY);
    n_arg_types = RARRAY_LENINT(arg_types);
    Check_Max_Args(name, n_arg_types);

    normalized_arg_types = rb_ary_new_capa(n_arg_types);
    for (i = 0; i < n_arg_types; i++) {
        VALUE arg_type = RARRAY_AREF(arg_types, i);
        int c_arg_type;
        arg_type = rb_fiddle_type_ensure(arg_type);
        c_arg_type = NUM2INT(arg_type);
        if (c_arg_type == TYPE_VARIADIC) {
            if (i != n_arg_types - 1) {
                rb_raise(rb_eArgError,
                         "Fiddle::TYPE_VARIADIC must be the last argument type: "
                         "%"PRIsVALUE,
                         arg_types);
            }
            *is_variadic = true;
            break;
        }
        else {
            (void)INT2FFI_TYPE(c_arg_type); /* raise */
        }
        rb_ary_push(normalized_arg_types, INT2FIX(c_arg_type));
    }

    /* freeze to prevent inconsistency at calling #to_int later */
    OBJ_FREEZE(normalized_arg_types);
    return normalized_arg_types;
}

static VALUE
initialize(int argc, VALUE argv[], VALUE self)
{
    fiddle_function_t *func;
    VALUE ptr, arg_types, ret_type, abi, kwargs;
    VALUE name = Qnil;
    VALUE need_gvl = Qfalse;
    int c_ret_type;
    bool is_variadic = false;
    ffi_abi c_ffi_abi;
    void *cfunc;
    int i;

    rb_scan_args(argc, argv, "31:", &ptr, &arg_types, &ret_type, &abi, &kwargs);
    rb_ivar_set(self, id_closure, ptr);

    if (!NIL_P(kwargs)) {
        enum {
            kw_name,
            kw_need_gvl,
            kw_max_,
        };
        static ID kw[kw_max_];
        VALUE args[kw_max_];
        if (!kw[0]) {
            kw[kw_name] = rb_intern_const("name");
            kw[kw_need_gvl] = rb_intern_const("need_gvl");
        }
        rb_get_kwargs(kwargs, kw, 0, kw_max_, args);
        if (args[kw_name] != Qundef) {
            name = args[kw_name];
#ifdef HAVE_RB_STR_TO_INTERNED_STR
            if (RB_TYPE_P(name, RUBY_T_STRING)) {
              name = rb_str_to_interned_str(name);
            }
#endif
        }
        if (args[kw_need_gvl] != Qundef) {
            need_gvl = args[kw_need_gvl];
        }
    }
    rb_ivar_set(self, id_name, name);
    rb_ivar_set(self, id_need_gvl, need_gvl);

    ptr = rb_Integer(ptr);
    cfunc = NUM2PTR(ptr);
    PTR2NUM(cfunc);
    c_ffi_abi = NIL_P(abi) ? FFI_DEFAULT_ABI : NUM2INT(abi);
    abi = INT2FIX(c_ffi_abi);
    ret_type = rb_fiddle_type_ensure(ret_type);
    c_ret_type = NUM2INT(ret_type);
    (void)INT2FFI_TYPE(c_ret_type); /* raise */
    ret_type = INT2FIX(c_ret_type);

    arg_types = normalize_argument_types("argument types",
                                         arg_types,
                                         &is_variadic);
#ifndef HAVE_FFI_PREP_CIF_VAR
    if (is_variadic) {
        rb_raise(rb_eNotImpError,
                 "ffi_prep_cif_var() is required in libffi "
                 "for variadic arguments");
    }
#endif

    rb_ivar_set(self, id_ptr, ptr);
    rb_ivar_set(self, id_argument_types, arg_types);
    rb_ivar_set(self, id_return_type, ret_type);
    rb_ivar_set(self, id_abi, abi);
    rb_ivar_set(self, id_is_variadic, is_variadic ? Qtrue : Qfalse);

    TypedData_Get_Struct(self, fiddle_function_t, &function_data_type, func);
    func->fn = (void (*)(void))(VALUE)cfunc;
    func->abi = c_ffi_abi;
    func->return_type = c_ret_type;
    func->is_variadic = is_variadic;
    func->need_gvl = RTEST(need_gvl);

    /* allow re-initialization without leaking or double-freeing */
    if (func->argument_types) {
        xfree(func->argument_types);
        func->argument_types = NULL;
    }
    func->n_argument_types = RARRAY_LENINT(arg_types);
    func->argument_types = ALLOC_N(int, func->n_argument_types);
    for (i = 0; i < func->n_argument_types; i++) {
        func->argument_types[i] = FIX2INT(RARRAY_AREF(arg_types, i));
    }
    if (func->cif.arg_types) {
        xfree(func->cif.arg_types);
        func->cif.arg_types = NULL;
    }

    return self;
}

struct nogvl_ffi_call_args {
    ffi_cif *cif;
    void (*fn)(void);
    void **values;
    fiddle_generic retval;
};

static void *
nogvl_ffi_call(void *ptr)
{
    struct nogvl_ffi_call_args *args = ptr;

    ffi_call(args->cif, args->fn, &args->retval, args->values);

    return NULL;
}

static VALUE
function_call(int argc, VALUE argv[], VALUE self)
{
    struct nogvl_ffi_call_args args = { 0 };
    fiddle_function_t *func;
    fiddle_generic *generic_args;
    int n_fixed_args = 0;
    int n_call_args = 0;
    int i;
    int i_call;
    int *call_arg_types;
    VALUE *converted_args;
    int n_converted_args = 0;
    VALUE alloc_buffer = 0;

    TypedData_Get_Struct(self, fiddle_function_t, &function_data_type, func);
    args.cif = &func->cif;

    n_fixed_args = func->n_argument_types;
    if (func->is_variadic) {
        if (argc < n_fixed_args) {
            rb_error_arity(argc, n_fixed_args, UNLIMITED_ARGUMENTS);
        }
        if (((argc - n_fixed_args) % 2) != 0) {
            rb_raise(rb_eArgError,
                     "variadic arguments must be type and value pairs: "
                     "%"PRIsVALUE,
                     rb_ary_new_from_values(argc, argv));
        }
        n_call_args = n_fixed_args + ((argc - n_fixed_args) / 2);
    }
    else {
        if (argc != n_fixed_args) {
            rb_error_arity(argc, n_fixed_args, n_fixed_args);
        }
        n_call_args = n_fixed_args;
    }
    Check_Max_Args("the number of arguments", n_call_args);

    generic_args = ALLOCV(alloc_buffer,
                          sizeof(fiddle_generic) * n_call_args +
                          sizeof(void *) * (n_call_args + 1) +
                          sizeof(VALUE) * n_call_args +
                          (func->is_variadic ? sizeof(int) * n_call_args : 0));
    args.values = (void **)((char *)generic_args +
                            sizeof(fiddle_generic) * n_call_args);
    /* GC-scanned (conservatively) as part of the ALLOCV buffer */
    converted_args = (VALUE *)((char *)args.values +
                               sizeof(void *) * (n_call_args + 1));
    MEMZERO(converted_args, VALUE, n_call_args);

    if (func->is_variadic) {
        call_arg_types = (int *)(converted_args + n_call_args);
        MEMCPY(call_arg_types, func->argument_types, int, n_fixed_args);
        for (i = n_fixed_args, i_call = n_fixed_args;
             i < argc;
             i += 2, i_call++) {
            VALUE arg_type = rb_fiddle_type_ensure(argv[i]);
            int c_arg_type = NUM2INT(arg_type);
            (void)INT2FFI_TYPE(c_arg_type); /* raise */
            call_arg_types[i_call] = c_arg_type;
        }

        /* Variadic calls may pass different types each call, so the
         * cif must always be re-prepared */
        if (func->cif.arg_types) {
            xfree(func->cif.arg_types);
            func->cif.arg_types = NULL;
        }
    }
    else {
        call_arg_types = func->argument_types;
    }

    if (!func->cif.arg_types) {
        ffi_type **ffi_arg_types;
        ffi_status result;

        ffi_arg_types = xcalloc(n_call_args + 1, sizeof(ffi_type *));
        for (i_call = 0; i_call < n_call_args; i_call++) {
            ffi_arg_types[i_call] = INT2FFI_TYPE(call_arg_types[i_call]);
        }
        ffi_arg_types[i_call] = NULL;

        if (func->is_variadic) {
#ifdef HAVE_FFI_PREP_CIF_VAR
            result = ffi_prep_cif_var(&func->cif,
                                      func->abi,
                                      n_fixed_args,
                                      n_call_args,
                                      INT2FFI_TYPE(func->return_type),
                                      ffi_arg_types);
#else
            /* This code is never used because ffi_prep_cif_var()
             * availability check is done in #initialize. */
            result = FFI_BAD_TYPEDEF;
#endif
        }
        else {
            result = ffi_prep_cif(&func->cif,
                                  func->abi,
                                  n_call_args,
                                  INT2FFI_TYPE(func->return_type),
                                  ffi_arg_types);
        }
        if (result != FFI_OK) {
            xfree(ffi_arg_types);
            func->cif.arg_types = NULL;
            rb_raise(rb_eRuntimeError, "error creating CIF %d", result);
        }
    }

    for (i = 0, i_call = 0;
         i < argc && i_call < n_call_args;
         i++, i_call++) {
        int c_arg_type = call_arg_types[i_call];
        VALUE original_src;
        VALUE src;
        if (i >= n_fixed_args) {
            i++;
        }
        src = argv[i];

        if (c_arg_type == TYPE_VOIDP) {
            if (NIL_P(src)) {
                generic_args[i_call].pointer = NULL;
            }
            else if (RB_TYPE_P(src, T_STRING)) {
                /* kept alive and pinned via converted_args */
                generic_args[i_call].pointer = RSTRING_PTR(src);
                converted_args[n_converted_args++] = src;
            }
            else {
                if (rb_cPointer != CLASS_OF(src)) {
                    src = rb_funcall(rb_cPointer, id_aref, 1, src);
                    converted_args[n_converted_args++] = src;
                }
                generic_args[i_call].pointer = rb_fiddle_ptr2cptr(src);
            }
        }
        else {
            original_src = src;
            VALUE2GENERIC(c_arg_type, src, &generic_args[i_call]);
            if (src != original_src) {
                converted_args[n_converted_args++] = src;
            }
        }
        args.values[i_call] = (void *)&generic_args[i_call];
    }
    args.values[i_call] = NULL;
    args.fn = func->fn;

    if (func->need_gvl) {
        ffi_call(args.cif, args.fn, &(args.retval), args.values);
    }
    else {
        (void)rb_thread_call_without_gvl(nogvl_ffi_call, &args, 0, 0);
    }

    {
        int errno_keep = errno;
#if defined(_WIN32)
        DWORD error = WSAGetLastError();
        int socket_error = WSAGetLastError();
        rb_thread_local_aset(rb_thread_current(), id_win32_last_error,
                             ULONG2NUM(error));
        rb_thread_local_aset(rb_thread_current(), id_win32_last_socket_error,
                             INT2NUM(socket_error));
#endif
        rb_thread_local_aset(rb_thread_current(), id_last_error,
                             INT2NUM(errno_keep));
    }

    ALLOCV_END(alloc_buffer);

    return GENERIC2VALUE(func->return_type, args.retval);
}

void
Init_fiddle_function(void)
{
    /*
     * Document-class: Fiddle::Function
     *
     * == Description
     *
     * A representation of a C function
     *
     * == Examples
     *
     * === 'strcpy'
     *
     *   @libc = Fiddle.dlopen "/lib/libc.so.6"
     *	    #=> #<Fiddle::Handle:0x00000001d7a8d8>
     *   f = Fiddle::Function.new(
     *     @libc['strcpy'],
     *     [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP],
     *     Fiddle::TYPE_VOIDP)
     *	    #=> #<Fiddle::Function:0x00000001d8ee00>
     *   buff = "000"
     *	    #=> "000"
     *   str = f.call(buff, "123")
     *	    #=> #<Fiddle::Pointer:0x00000001d0c380 ptr=0x000000018a21b8 size=0 free=0x00000000000000>
     *   str.to_s
     *   => "123"
     *
     * === ABI check
     *
     *   @libc = Fiddle.dlopen "/lib/libc.so.6"
     *	    #=> #<Fiddle::Handle:0x00000001d7a8d8>
     *   f = Fiddle::Function.new(@libc['strcpy'], [TYPE_VOIDP, TYPE_VOIDP], TYPE_VOIDP)
     *	    #=> #<Fiddle::Function:0x00000001d8ee00>
     *   f.abi == Fiddle::Function::DEFAULT
     *	    #=> true
     */
    id_ptr = rb_intern_const("@ptr");
    id_abi = rb_intern_const("@abi");
    id_argument_types = rb_intern_const("@argument_types");
    id_return_type = rb_intern_const("@return_type");
    id_is_variadic = rb_intern_const("@is_variadic");
    id_need_gvl = rb_intern_const("@need_gvl");
    id_name = rb_intern_const("@name");
    id_closure = rb_intern_const("@closure");
    id_aref = rb_intern_const("[]");
    id_last_error = rb_intern_const("__FIDDLE_LAST_ERROR__");
#if defined(_WIN32)
    id_win32_last_error = rb_intern_const("__FIDDLE_WIN32_LAST_ERROR__");
    id_win32_last_socket_error = rb_intern_const("__FIDDLE_WIN32_LAST_SOCKET_ERROR__");
#endif

    cFiddleFunction = rb_define_class_under(mFiddle, "Function", rb_cObject);

    /*
     * Document-const: DEFAULT
     *
     * Default ABI
     *
     */
    rb_define_const(cFiddleFunction, "DEFAULT", INT2NUM(FFI_DEFAULT_ABI));

#ifdef HAVE_CONST_FFI_STDCALL
    /*
     * Document-const: STDCALL
     *
     * FFI implementation of WIN32 stdcall convention
     *
     */
    rb_define_const(cFiddleFunction, "STDCALL", INT2NUM(FFI_STDCALL));
#endif

    rb_define_alloc_func(cFiddleFunction, allocate);

    /*
     * Document-method: call
     *
     * Calls the constructed Function, with +args+.
     * Caller must ensure the underlying function is called in a
     * thread-safe manner if running in a multi-threaded process.
     *
     * Note that it is not thread-safe to use this method to
     * directly or indirectly call many Ruby C-extension APIs unless
     * you don't pass +need_gvl: true+ to Fiddle::Function#new.
     *
     * For an example see Fiddle::Function
     *
     */
    rb_define_method(cFiddleFunction, "call", function_call, -1);

    /*
     * Document-method: new
     * call-seq: new(ptr,
     *               args,
     *               ret_type,
     *               abi = DEFAULT,
     *               name: nil,
     *               need_gvl: false)
     *
     * Constructs a Function object.
     * * +ptr+ is a referenced function, of a Fiddle::Handle
     * * +args+ is an Array of arguments, passed to the +ptr+ function
     * * +ret_type+ is the return type of the function
     * * +abi+ is the ABI of the function
     * * +name+ is the name of the function
     * * +need_gvl+ is whether GVL is needed to call the function
     *
     */
    rb_define_method(cFiddleFunction, "initialize", initialize, -1);
}
