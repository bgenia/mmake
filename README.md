# MMake

MMake (**m**ake **make**) is a makefile generator built entirely in make itself.

## Overview

MMake is based upon plugin architecture. The core module provides only basic configuration/codegen features.

Modules:

+ `mmake.mk` - Core module, provides configuration & codegen APIs
+ `plugins/`
  + (coming soon)

## Examples

Basic codegen example without plugins

`Makefile.mk`

```Makefile
.RECIPEPREFIX := >

include mmake/mmake.mk

# Configuration

# - Project configuration
$($.project) += $(call $.set,name,abobus)
$($.project) += $(call $.set,CC,clang)

# - First target
target1 := $(call $.new_target)

$(target1) += $(call $.set,name,foo)
$(target1) += $(call $.set,sources,foo.c)

# - Second target
target2 := $(call $.new_target)

$(target2) += $(call $.set,name,bar)
$(target2) += $(call $.set,sources,bar.c)

# Codegen

# - Project `init` step generator
define $(call $.new_generator,init)

.RECIPEPREFIX := >

$$(info building project $(call $.get,$($.this),name))

CC = $(call $.get,$($.this),CC)

endef

# - Target `build` step generator
define $(call $.new_generator,build,target)

$$(info building target $(call $.get,$($.this),name))

$(call $.get,$($.this),name): $(call $.get,$($.this),sources)
>   $$(CC) $$^ -o $$@

endef

# MMake entrypoint
$($.make)
```

Running mmake:

```sh
make -f Makefile.mk
```

Result:

`Makefile`

```Makefile
.RECIPEPREFIX := >

$(info building project abobus)

CC = clang


$(info building target foo)

foo: foo.c
>   $(CC) $^ -o $@


$(info building target bar)

bar: bar.c
>   $(CC) $^ -o $@
```
