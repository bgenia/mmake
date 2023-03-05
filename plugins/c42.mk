# MMake plugin for Ecole 42 C projects

# Make configuration

.RECIPEPREFIX := >

.NOTPARALLEL:

# MMake guard

ifndef __mmake
	$(error This is an mmake plugin, it is not indended for standalone usage. Please include mmake first.)
endif

# Include guard
ifndef __mmake_plugin_c42
__mmake_plugin_c42 := 1


# Project configuration
$($.project) += $(call $.set,CFLAGS,-Wall -Werror -Wextra)

# Target configuration
# (name, sources) -> handle
$.new_executable = $(call $.new_target,$(call $.set,type,executable) $(call $.set,name,$1) $(call $.set,sources,$2))
$.new_static_library = $(call $.new_target,$(call $.set,type,static_library) $(call $.set,name,$1) $(call $.set,sources,$2) $(call $.set,ARFLAGS,-rcs))

# (sources) -> properties
$.add_sources = $(call $.set,sources,$1)

# (directories) -> properties
$.add_include_directories = $(call $.set,CPPFLAGS,$(addprefix -I,$1))

# (directories) -> properties
$.add_link_directories = $(call $.set,LDFLAGS,$(addprefix -L,$1))

# (libraries) -> properties
$.link_libraries = $(call $.set,LDLIBS,$1)

# (file, make_directory?, make_args?) -> properties
$.add_make_depenency = $(call $.set,make_dependencies,$(call $.new_object,$(call $.set,target,$(strip $1)) $(call $.set,make_directory,$(strip $(or $2,$(dir $1)))) $(call $.set,make_args,$3)))

# (library_file, include_directories?, make_directory?, make_args?) -> properties
$.use_library_from_sources = $(call $.add_make_depenency,$1,$3,$4) $(call $.link_libraries,$1) $(call $.add_include_directories,$(or $2,$(dir $1)))

# Codegen
define $(call $.new_generator,init)
# Make configuration
.RECIPEPREFIX := >

MAKEFLAGS += --no-print-directories --jobs
endef

define $(call $.new_generator,configure)
# Project configuration
CC = $(or $(call $.@,CC),cc)

CFLAGS = $(call $.@,CFLAGS)
CPPFLAGS = $(call $.@,CPPFLAGS)

LDFLAGS = $(call $.@,LDFLAGS)
LDLIBS = $(call $.@,LDLIBS)

ARFLAGS = $(call $.@,ARFLAGS)
endef

define $(call $.new_generator,configure,target)
# Target configuration
$(if $(call $.@,CC),$(call $.@,name): CC = $(call $.@,CC))

$(call $.@,name): CFLAGS += $(call $.@,CFLAGS)
$(call $.@,name): CPPFLAGS += $(call $.@,CPPFLAGS)

$(call $.@,name): LDFLAGS += $(call $.@,LDFLAGS)
$(call $.@,name): LDLIBS += $(call $.@,LDLIBS)

$(call $.@,name): ARFLAGS += $(call $.@,ARFLAGS)

$(call $.@,name).SOURCE_ROOT := $(addsuffix /,$(patsubst %/,%,$(call $.@,source_root)))
$(call $.@,name).BUILD_ROOT := $(addsuffix /,$(patsubst %/,%,$(or $(call $.@,build_root),build)))

$(call $.@,name).SOURCES := $(call $.@,sources)
$(call $.@,name).OBJECTS := $$($(call $.@,name).SOURCES:$$($(call $.@,name).SOURCE_ROOT)%.c=$$($(call $.@,name).BUILD_ROOT)%.o)

$(call $.@,name).DEPENDENCIES := $$($(call $.@,name).OBJECTS:%.o=%.d)

DEPENDENCIES += $(call $.@,name).DEPENDENCIES

$(call $.@,name).OBJECT_DIRECTORIES = $$(sort $$(dir $$($(call $.@,name).OBJECTS)))
endef

define $(call $.new_generator,build)
# Build project
.DEFAULT_GOAL := all
.PHONY: all
all: $(foreach target,$(call $.@,targets),$(call $.get,$(target),name))
endef

define executable_recipe
$$(CC) $$(LDFLAGS) $$^ $$(LDLIBS) -o $$@
endef

define static_library_recipe
$$(AR) $$(ARFLAGS) $$@ $$^
endef

define $(call $.new_generator,build,target)
# Build target $(call $.@,name)
$(call $.@,name): .EXTRA_PREREQS := $(foreach dependency,$(call $.@,make_dependencies),$(call $.get,$(dependency),target))
$(call $.@,name): $$($(call $.@,name).OBJECTS)$(if $(findstring ./,$(dir $(call $.@,name))),, | $(dir $(call $.@,name)))
>	$($(call $.@,type)_recipe)

$$($(call $.@,name).BUILD_ROOT)%.o: $$($(call $.@,name).SOURCE_ROOT)%.c | $$($(call $.@,name).OBJECT_DIRECTORIES)
>	$$(CC) -c $$(CFLAGS) $$(CPPFLAGS) $$^ -o $$@

$(if $(findstring ./,$(dir $(call $.@,name))),,$(dir $(call $.@,name)) )$$($(call $.@,name).OBJECT_DIRECTORIES):
>	mkdir -p $$@
endef

define $(call $.new_macro,generate_make_dependency)
$(call $.@,target): force-phony
>	$$(MAKE) -C $(call $.@,make_directory) $(call $.@,make_args)
endef

define $(call $.new_generator,util)
PHONY: force-phony
force-phony:;

$(foreach dependency,$(foreach target,$(call $.@,targets),$(call $.get,$(target),make_dependencies)),$(call $.macro.get,generate_make_dependency,$(dependency)))
endef

define $(call $.new_generator,util)
# Utility rules
.PHONY: clean
clean:
>	$$(RM) $(foreach target,$(call $.@,targets),$$($(call $.get,$(target),name).OBJECTS))

.PHONY: fclean
fclean: clean
>	$$(RM) $(foreach target,$(call $.@,targets),$(call $.get,$(target),name))

re: fclean .WAIT all
endef

define $(call $.new_generator,end)
-include $$(DEPENDENCIES)
endef

endif
