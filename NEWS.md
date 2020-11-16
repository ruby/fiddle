# News

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
