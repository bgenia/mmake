# MMake

MMake (**m**ake **make**) is a makefile generator built entirely in make itself.

## Overview

MMake is based upon plugin architecture. The core module provides only basic configuration/codegen features.

Modules:

+ `mmake.mk` - Core module, provides configuration & codegen APIs
+ `plugins/`
  + `c_cxx.mk` - Simple C/C++ plugin
    + `c_cxx_42.mk` - `c_cxx` plugin extension for Ecole 42 projects

## Examples

### Building C project with `c_cxx` plugin

`Makefile.mk`

```Makefile
include mmake/core.mk
include mmake/plugins/c_cxx.mk

program := $(call $.new_executable,program,$(wildcard src/*.c))

$(program) += $(call $.add_include_directories,include)
```

### Release/debug target variants

`Makefile.mk`

```Makefile
include mmake/core.mk
include mmake/plugins/c_cxx.mk

program := $(call $.new_executable,program,main.c)

# Common release & debug configuration ...

# Creates a new target variant, be careful to specify distinct properties only after this line
program_debug := $(call $.new_variant,$(program),program_debug)

$(program) += $(call $.add_build_type,release)
$(program) += $(call $.set,CFLAGS,-O2)

$(program_debug) += $(call $.add_build_type,debug)
$(program_debug) += $(call $.set,CFLAGS,-g)
```

```sh
make
make BUILD_TYPE=release
make BUILD_TYPE=debug
```

Another way is to use a separate object for common properties

`Makefile.mk`

```Makefile
include mmake/core.mk
include mmake/plugins/c_cxx.mk

program_common := $(call $.new_object)

$(program_common) += $(call $.add_sources,$(wildcard src/*.c))
$(program_common) += $(call $.add_include_directories,include)

program_release := $(call $.new_target,program_release,$(call $...,$(program_common)) $(call $.add_build_type,release))
program_debug := $(call $.new_target,program_debug,$(call $...,$(program_common)) $(call $.add_build_type,debug))

$(program_release) += $(call $.set,CFLAGS,-O2)

$(program_debug) += $(call $.set,CFLAGS,-g)
```
