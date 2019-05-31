#pragma once

#include <ruby.h>

#define RB_FIDDLE_BUFFER_VERSION 20190531

#define RB_FIDDLE_BUFFER_SIMPLE            0x0000
#define RB_FIDDLE_BUFFER_WRITABLE          0x0001
#define RB_FIDDLE_BUFFER_FORMAT            0x0004
#define RB_FIDDLE_BUFFER_MULTI_DIMENSIONAL 0x0008
#define RB_FIDDLE_BUFFER_STRIDES           (0x0010 | RB_FIDDLE_BUFFER_MULTI_DIMENSIONAL)
#define RB_FIDDLE_BUFFER_C_CONTIGUOUS      (0x0020 | RB_FIDDLE_BUFFER_STRIDES)
#define RB_FIDDLE_BUFFER_F_CONTIGUOUS      (0x0040 | RB_FIDDLE_BUFFER_STRIDES)
#define RB_FIDDLE_BUFFER_ANY_CONTIGUOUS    (0x0080 | RB_FIDDLE_BUFFER_STRIDES)
#define RB_FIDDLE_BUFFER_INDIRECT          (0x0100 | RB_FIDDLE_BUFFER_STRIDES)

typedef struct {
  void *buffer;     /** a pointer to the start of the buffer */
  ssize_t length;   /** the total bytes of the memory */
  int read_only;    /** 1 for readonly, 0 for writable */
  const char *format;  /** NULL-terminated format string */
  int n_dim;           /** the number of dimensions */
  ssize_t *shape;      /** the array of lengths for each dimension,
                           or NULL for ndim == 0 */
  ssize_t *strides;    /** the array of the number of bytes to skip to get
                           the next item in each dimension,
                           or NULL for ndim == 0 */
  ssize_t *sub_offset; /** offsets for each dimension if the buffrer is indirect */
  ssize_t item_size;   /** byte size of tan item */
  void *internal_data; /** the pointer to the internal data */
} rb_fiddle_buffer_t;

typedef int (* rb_fiddle_get_buffer_func_t)(VALUE obj,
                                            rb_fiddle_buffer_t *view,
                                            int view_spec);
typedef int (* rb_fiddle_release_buffer_func)(VALUE obj,
                                              rb_fiddle_buffer_t *view);

VALUE rb_fiddle_register_buffer_protocol(VALUE klass,
                                         rb_fiddle_get_buffer_func_t get_buffer_func,
                                         rb_fiddle_release_buffer_func_t release_buffer_func);

int rb_fiddle_respond_to_buffer_protocol(VALUE obj);
int rb_fiddle_obj_get_buffer(VALUE obj, rb_fiddle_buffer_t *view, int flags);
void rb_fiddle_obj_release_buffer(VALUE obj, rb_fiddle_buffer_t *view);
VALUE rb_fiddle_obj_get_memory_view(VALUE obj);
int rb_fiddle_is_memory_view(VALUE obj);
const rb_fiddle_buffer_t *rb_fiddle_memory_view_get_buffer(VALUE memory_view);

ssize_t rb_fiddle_format_item_size(const char *format);

int rb_fiddle_buffer_is_c_contiguous(const rb_fiddle_buffer_t *view);
int rb_fiddle_buffer_is_f_contiguous(const rb_fiddle_buffer_t *view);
int rb_fiddle_buffer_is_any_contiguous(const rb_fiddle_buffer_t *view);

void rb_fiddle_buffer_fill_c_contiguous_stride(int n_dim,
                                               const ssize_t *shape,
                                               ssize_t item_size,
                                               ssize_t *strides);
void rb_fiddle_buffer_fill_f_contiguous_stride(int n_dim,
                                               const ssize_t *shape,
                                               ssize_t item_size,
                                               ssize_t *strides);
