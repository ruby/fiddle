# News

## 1.1.1 - 2022-12-08

### Improvements

  * test: Improved glibc detection on alpha and ia64.
    [[GitHub#105](https://github.com/ruby/fiddle/pull/105)]
    [[Bug #18645](https://bugs.ruby-lang.org/issues/18645)]
    [Patch by John Paul Adrian Glaubitz]

  * Added support for linker script on Linux.
    [[GitHub#107](https://github.com/ruby/fiddle/issues/107)]
    [Reported by nicholas a. evans]

  * Freed `Fiddle::Closure` immediately.
    [[GitHub#109](https://github.com/ruby/fiddle/pull/109)]

  * Added `Fiddle::TYPE_UXXX` constants for unsigned types.
    [[GitHub#111](https://github.com/ruby/fiddle/pull/111)]

  * Added `Fiddle::Types` for type constants. We can still use
    `Fiddle::TYPE_XXX`.
    [[GitHub#112](https://github.com/ruby/fiddle/pull/112)]

  * Added `Fiddle::Handle.sym_defined?`.
    [[GitHub#108](https://github.com/ruby/fiddle/pull/108)]

  * Added `Fiddle::Closure.create` and `Fiddle::Closure.free`.
    [[GitHub#102](https://github.com/ruby/fiddle/issues/102)]
    [Reported by Vít Ondruch]

  * Added `--with-libffi-source-dir` build option and removed
    `--enable-bundled-libffi` build option.
    [[Bug #18571](https://bugs.ruby-lang.org/issues/18571)]

  * Added `Fiddle::Qtrue`, `Fiddle::Qfalse`, `Fiddle::Qnil` and
    `Fiddle::Qundef`.
    [[GitHub#115](https://github.com/ruby/fiddle/pull/115)]

### Fixes

  * Fixed a bug that `Fiddle::PackInfo::PACK_MAP` uses wrong pack
    template for unsigned types.
    [[GitHub#109](https://github.com/ruby/fiddle/pull/110)]

### Thanks

  * John Paul Adrian Glaubitz

  * Vít Ondruch

## 1.1.0 - 2021-10-23

### Improvements

  * Added `Fiddle::Struct.offsetof`.

  * Improved memory view availability detection.
    [GitHub#84][Reported by Jun Aruga]

  * Changed `Fiddle::Handle#to_i` value to wrapped pointer from
    internal handle data pointer. It's a backward incompatible change
    but the previous behavior was meaningless. No users must depend on
    the previous behavior. So this will not cause any backward
    incompatible problem.

  * Added `Fiddle::Handle#to_ptr`.

  * Added `Fiddle::Handle#file_name`.

### Thanks

  * Jun Aruga

## 1.0.9 - 2021-06-19

### Improvements

  * Added `Fiddle::Function#to_proc`.

  * Added `Fiddle::MemoryView#to_s`.
    [GitHub#74][Reported by dsisnero]

  * Added `Fiddle::MemoryView.export` and `Fiddle::MemoryView#release`.
    [GitHub#79][Reported by xtkoba]

### Fixes

  * Changed to use `GetLastError()` for `Fiddle.win32_last_error`.
    [Ruby#11579][Patch by cremno phobia]

### Thanks

  * cremno phobia

  * dsisnero

  * xtkoba

## 1.0.8 - 2021-04-19

### Improvements

  * Added support for `const` in C type.
    [GitHub#68][Reported by kojix2]

  * Added `Fiddle.win32_last_socket_error` and
    `Fiddle.win32_last_socket_error=`. They manage the last socket
    error on Windows. Users can't use `WSAGetLastError()` with Ruby
    3.0 or later because `rb_funcall()` resets the last socket error
    internally.
    [GitHub#72][Reported by Kentaro Hayashi]

### Fixes

  * Fixed wrong type aliases for 64-bit Windows in `Fiddle::Win32Types`.
    [GitHub#63][Patch by Orgad Shaneh]

### Thanks

  * Orgad Shaneh

  * kojix2

  * Kentaro Hayashi

## 1.0.7 - 2020-12-25

### Improvements

  * `Fiddle::Closure`: Added support for specifying a type as `Symbol`.

  * `Fiddle::Closure`: Added support for `const char *`.
    [GitHub#62][Reported by Cody Krieger]

### Thanks

  * Cody Krieger

## 1.0.6 - 2020-12-23

### Improvements

  * Modify Fiddle::MemoryView for the latest Ruby master branch.

## 1.0.5 - 2020-12-21

### Improvements

  * Added a workaround for build failure with macOS 10.15 and Homebrew.
    [GitHub#52][Reported by Yaroslav Berezovskiy]

### Thanks

  * Yaroslav Berezovskiy

## 1.0.4 - 2020-12-10

### Improvements

  * Experimentally support MemoryView feature in Ruby 3.0.
    [GitHub#54]

  * Add support for `intNN_t` and `uintNN_t`.

  * Add `:need_gvl` option in `Fiddle::Function#initialize`.
    [Reported by Alan Wu]

### Thanks

  * Alan Wu

## 1.0.3 - 2020-11-22

### Improvements

  * Added support for Fedora.
    [GitHub#49][Reported by Steve Fishman]

### Thanks

  * Steve Fishman

## 1.0.2 - 2020-11-18

### Fixes

  * Suppressed a compile time warning.

## 1.0.1 - 2020-11-17

### Improvements

  * Improved documentation.
    [GitHub#9][GitHub#33]
    [Patch by Olle Jonsson]
    [Patch by Chris Seaton]

  * Dropped deprecated taint support.
    [GitHub#21]
    [Patch by Jeremy Evans]

  * `Fiddle.malloc`: Changed to clear memory as all 0.
    [GitHub#24]
    [Patch by sinisterchipmunk]

  * `Fiddle::CStructEntity#[]`, `Fiddle::CStructEntity#[]=`: Added
    support for accessing struct data by offset and length.
    [GitHub#25]
    [Patch by sinisterchipmunk]

  * `Fiddle::Version`: Added.

  * `Fiddle::Pointer#call_free`, `Fiddle::Pointer#freed?`: Added.
    [GitHub#36]
    [Patch by Chris Seaton]

  * `Fiddle::Pointer#malloc`: Added support for freeing memory by block.
    [GitHub#38][GitHub#39]
    [Patch by Chris Seaton]

  * Added support for variadic arguments.
    [GitHub#39]
    [Reported by kojix2]

  * `Fiddle::TYPE_CONST_STRING`: Added.

  * `Fiddle::SIZEOF_CONST_STRING`: Added.

  * Added support for name such as `:size_t` to specify type.

  * `Fiddle::Pinned`: Added support for pinned object.
    [GitHub#44]

  * `Fiddle::Error`: Added as the root error class for Fiddle.

  * Added support for nested struct.
    [GitHub#27]
    [Patch by sinisterchipmunk]

  * `Fiddle::Importer::dlload`: Removed needless `rescue`.
    [GitHub#15]
    [Reported by Eneroth3]

### Thanks

  * Olle Jonsson

  * Jeremy Evans

  * sinisterchipmunk

  * Chris Seaton

  * kojix2

  * Eneroth3
