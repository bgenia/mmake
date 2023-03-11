# MMake C/C++ plugin

# Make configuration
.RECIPEPREFIX := >
.NOTPARALLEL:

# MMake guard
ifndef __mmake
$(error This file is an mmake plugin, it is not intended for standalone usage. Please include mmake first.)
endif

# Include guard
ifndef __mmake_plugin_c_cxx
__mmake_plugin_c_cxx := 1

# Function naming guide:
# - new_* : Creates  entity
# - add_* : Creates properties for other entities
# - use_* : Applies a configuration preset to other entities

# Targets

# (name, sources, properties) -> handle
$.new_executable = $(call $.new_target,$(call $.set,type,executable) $(call $.set,name,$1) $(call $.set,sources,$2) $3)
$.new_static_library = $(call $.new_target,$(call $.set,type,static_library) $(call $.set,name,$1) $(call $.set,sources,$2) $3)

# Creates a copy if a target with a different name
# (target, name, properties) -> handle
$.new_variant = $(call $.new_target,$(foreach property,$($1),$(if $(findstring name,$(call $.property.get_key,$(property))),,$(property))) $(call $.set,name,$2) $3)

# Configuration

# Available languages: c, cxx
# (language) -> properties
$.use_language = $(call $.set,language,$(filter c cxx,$1))

# If set, the target will be built only when one of the specified build modes is currently enabled
# (mode) -> properites
$.add_build_type = $(call $.set,build_type,$1)

# (sources) -> properties
$.add_sources = $(call $.set,sources,$1)

# (directories) -> properties
$.add_include_directories = $(call $.set,CPPFLAGS,$(addprefix -I,$1))

# (directories) -> properties
$.add_link_directories = $(call $.set,LDFLAGS,$(addprefix -L,$1))

# (libraries) -> properties
$.add_linked_libraries = $(call $.set,LDLIBS,$1)

# Creates a dependency on a file built by make.
# Will attempt to call make each time before checking the file.
# (file, make_directory?, make_args)
$.add_make_dependency = $(call $.set,make_dependencies,$(call $.new_object,$(call $.set,target,$(strip $1)) $(call $.set,make_directory,$(strip $(or $2,$(dir $1)))) $(call $.set,make_args,$3)))

# (name)
$.add_dependency = $(call $.set,dependencies,$(call $.new_object,$(call $.set,target,$1)))

# (target)
$.add_target_dependency = $(call $.add_dependency,$(call $.get,$1,name))

# Configuration preset for building and linking a library from a makefile project
# (library_file, include_directories?, make_directory?, make_args?) -> properties
$.use_library_from_sources = $(call $.add_link_directories,$(dir $1)) $(call $.add_linked_libraries,$(addprefix -l:,$(notdir $1))) $(call $.add_include_directories,$2) $(call $.add_make_dependency,$1,$3,$4)

# Default configuration
## Plugin configuration
$.config.default_build_type := release
$.config.default_language := c
$.config.default_cc := cc
$.config.default_cxx := c++
$.config.default_source_root :=
$.config.default_build_root := build
$.config.default_cxx_extension := cpp

$.config.clean_target := clean
$.config.mostlyclean_target := mostlyclean

## Project configuration
$($.project) += $(call $.set,CPPFLAGS,-MMD)

# Template utilities
__c_cxx.current_language = $(or $(call $.@,language),$(or $(call $.get,$($.project),language),$($.config.default_language)))
__c_cxx.current_source_extension = $(if $(findstring cxx,$(__c_cxx.current_language)),$(or $(call $.@,cxx_extension),$(or $(call $.get,$($.project),cxx_extesion),$($.config.default_cxx_extension))),c)

# Templates

$.template.steps := init configure build deps util end

define $(call $.new_template,init)
# Make configuration
.RECIPEPREFIX := >

MAKEFLAGS += --no-print-directories --jobs

endef

define $(call $.new_template,configure)
# Build mode configuration
# Build mode can be passed from environment using BUILD variable
# Only targets which are allowed in the current build mode will be built.
DEFAULT_BUILD_TYPE := $(or $(call $.@,default_build_type),$($.config.default_build_type))
CURRENT_BUILD_TYPE := $$(or $$(BUILD_TYPE),$$(DEFAULT_BUILD_TYPE))

endef

define $(call $.new_macro,__c_cxx.configure_project/c,$(call $.set,no_final_newline))
CC = $(or $(call $.@,CC),$($.config.default_cc))
$(if $(call $.t,value,$(call $.@,CFLAGS)),CFLAGS = $($.t.value),$($.noline))
endef

define $(call $.new_macro,__c_cxx.configure_project/cxx,$(call $.set,no_final_newline))
CXX = $(or $(call $.@,CC),$($.config.default_cxx))
$(if $(call $.t,value,$(call $.@,CXXFLAGS)),CXXFLAGS = $($.t.value),$($.noline))
endef

define $(call $.new_template,configure)
# Project configuration
$(call $.macro.get,__c_cxx.configure_project/$(__c_cxx.current_language),$($.@))
$(if $(call $.t,value,$(call $.@,CPPFLAGS)),CPPFLAGS = $($.t.value),$($.noline))
$(if $(call $.t,value,$(call $.@,LDFLAGS)),LDFLAGS = $($.t.value),$($.noline))
$(if $(call $.t,value,$(call $.@,LDLIBS)),LDLIBS = $($.t.value),$($.noline))

ARFLAGS = $(or $(call $.@,ARFLAGS),-crsv)

endef

define $(call $.new_macro,configure_c_target_,$(call $.set,no_final_newline))
$(if $(call $.t,value,$(call $.@,CC)),$(call $.@,name): CC = $($.t.value),$($.noline))
$(if $(call $.t,value,$(call $.@,CFLAGS)),$(call $.@,name): CFLAGS += $($.t.value),$($.noline))
endef

define $(call $.new_macro,configure_cxx_target_,$(call $.set,no_final_newline))
$(if $(call $.t,value,$(call $.@,CXX)),$(call $.@,name): CXX = $($.t.value),$($.noline))
$(if $(call $.t,value,$(call $.@,CXXFLAGS)),$(call $.@,name): CXXFLAGS += $($.t.value),$($.noline))
endef

define $(call $.new_template,configure,target)
# Target configuration: $(call $.@,name)
$(call $.@,name).SOURCE_ROOT := $(addsuffix /,$(patsubst %/,%,$(or $(call $.@,source_root),$($.config.default_source_root))))
$(call $.@,name).BUILD_ROOT := $(addsuffix /,$(patsubst %/,%,$(or $(call $.@,source_root),$($.config.default_build_root))))

$(call $.@,name).BUILD_DIRECTORY := $(addsuffix $$(CURRENT_BUILD_TYPE)/$(call $.@,name)/,$$($(call $.@,name).BUILD_ROOT))

$(call $.@,name).SOURCES := $(call $.@,sources)
$(call $.@,name).OBJECTS := $$($(call $.@,name).SOURCES:$$($(call $.@,name).SOURCE_ROOT)%.$(__c_cxx.current_source_extension)=$$($(call $.@,name).BUILD_DIRECTORY)%.o)

$(call $.@,name).OBJECT_DIRECTORIES = $$(sort $$(dir $$($(call $.@,name).OBJECTS)))

$(or $(call $.macro.get,configure_$(__c_cxx.current_language)_target_,$($.@)),$($.noline))
$(if $(call $.t,value,$(call $.@,CPPFLAGS)),$(call $.@,name): CPPFLAGS += $($.t.value),$($.noline))
$(if $(call $.t,value,$(call $.@,LDFLAGS)),$(call $.@,name): LDFLAGS += $($.t.value),$($.noline))
$(if $(call $.t,value,$(call $.@,LDLIBS)),$(call $.@,name): LDLIBS += $($.t.value),$($.noline))
$(if $(call $.t,value,$(call $.@,ARFLAGS)),$(call $.@,name): ARFLAGS += $($.t.value),$($.noline))

endef

define $(call $.new_template,configure,target)
TARGETS.BUILD += $(if $(call $.has,$($.@),build_type),$$(if $$(filter $(call $.@,build_type),$$(CURRENT_BUILD_TYPE)),$(call $.@,name)),$(call $.@,name))
TARGETS.CLEAN += $(if $(call $.has,$($.@),build_type),$$(if $$(BUILD_TYPE),$$(if $$(filter $(call $.@,build_type),$$(CURRENT_BUILD_TYPE)),$(call $.@,name)),$(call $.@,name)),$(call $.@,name))

DEPENDENCIES += $(_ $(call $.t,depfiles,$$($(call $.@,name).OBJECTS:%.o=%.d)))$(if $(call $.get,$(target),build_type),$$(if $$(filter $(call $.@,build_type),$$(CURRENT_BUILD_TYPE)),$($.t.depfiles)),$($.t.depfiles))

endef

define $(call $.new_template,build)
# Build project
.DEFAULT_GOAL := all
.PHONY: all
all: $$(TARGETS.BUILD)

endef

define $(call $.new_macro,__c_cxx.build_target/executable/c,$(call $.set,no_final_newline))
>	$$(CC) $$(LDFLAGS) $$^ $$(LDLIBS) -o $$@
endef

define $(call $.new_macro,__c_cxx.build_target/executable/cxx,$(call $.set,no_final_newline))
>	$$(CXX) $$(LDFLAGS) $$^ $$(LDLIBS) -o $$@
endef

define $(call $.new_macro,__c_cxx.build_target/executable,$(call $.set,no_final_newline))
$(call $.macro.get,__c_cxx.build_target/executable/$(__c_cxx.current_language),$($.@))
endef

define $(call $.new_macro,__c_cxx.build_target/static_library,$(call $.set,no_final_newline))
>	$$(AR) $$(ARFLAGS) $$@ $$^
endef

define $(call $.new_macro,__c_cxx.build_objects/c,$(call $.set,no_final_newline))
>	$$(CC) -c $$(CFLAGS) $$(CPPFLAGS) $$< -o $$@
endef

define $(call $.new_macro,__c_cxx.build_objects/cxx,$(call $.set,no_final_newline))
>	$$(CXX) -c $$(CXXFLAGS) $$(CPPFLAGS) $$< -o $$@
endef

define $(call $.new_template,build,target)
# Build target: $(call $.@,name)
$(if $(or $(call $.has,$($.@),make_dependencies) $(call $.has,$($.@),dependencies)),$(call $.@,name): .EXTRA_PREREQS := $(foreach dependency,$(call $.@,make_dependencies),$(call $.get,$(dependency),target))$(foreach dependency,$(call $.@,dependencies),$(call $.get,$(dependency),target)),$($.noline))
$(call $.@,name): $$($(call $.@,name).OBJECTS)$(if $(findstring ./,$(dir $(call $.@,name))),, | $(dir $(call $.@,name)))
$(call $.macro.get,__c_cxx.build_target/$(call $.@,type),$($.@))

$$($(call $.@,name).BUILD_DIRECTORY)%.o: $$($(call $.@,name).SOURCE_ROOT)%.$(__c_cxx.current_source_extension) | $$($(call $.@,name).OBJECT_DIRECTORIES)
$(call $.macro.get,__c_cxx.build_objects/$(__c_cxx.current_language),$($.@))

$(if $(findstring ./,$(dir $(call $.@,name))),,$(dir $(call $.@,name)) )$$($(call $.@,name).OBJECT_DIRECTORIES):
>	mkdir -p $$@

endef

define $(call $.new_macro,__c_cxx.build_make_dependency)
$(call $.@,target): force-phony
>	$$(MAKE) -C $(call $.@,make_directory) $(call $.@,make_args)

endef

__c_cxx.make_dependency_targets = $(sort $(foreach target,$($.project.targets),$(foreach dependency,$(call $.get,$(target),make_dependencies),$(call $.get,$(dependency),target))))
__c_cxx.find_make_dependency_by_target = $(firstword $(foreach target,$($.project.targets),$(foreach dependency,$(call $.get,$(target),make_dependencies),$(if $(filter $1,$(call $.get,$(dependency),target)),$(dependency)))))

define $(call $.new_template,deps,,$(call $.set,no_final_newline))
$(_ $(call $.t,make_dependencies,$(foreach target,$(call $.@,$.targets),$(call $.get,$(target),make_dependencies))))$($.noline)
$(if $($.t.make_dependencies),# Build dependencies,$($.noline))
$(if $($.t.make_dependencies),.PHONY: force-phony,$($.noline))
$(if $($.t.make_dependencies),force-phony:;,$($.noline))

$(if $($.t.make_dependencies),$(call $.unspace,$(foreach dependency,$(__c_cxx.make_dependency_targets),$(call $.macro.get,__c_cxx.build_make_dependency,$(call __c_cxx.find_make_dependency_by_target,$(dependency)))$($.unspace.right))),$($.noline))
endef

define $(call $.new_template,util)
# Utility targets
.PHONY: $($.config.mostlyclean_target)
$($.config.mostlyclean_target):
ifndef BUILD_TYPE
>	$$(RM) -r $$(foreach target,$$(TARGETS.CLEAN),$$($$(target).BUILD_ROOT))
else
>	$$(RM) -r $$(foreach target,$$(TARGETS.CLEAN),$$($$(target).BUILD_DIRECTORY))
endif

.PHONY: $($.config.clean_target)
$($.config.clean_target): $($.config.mostlyclean_target)
>	$$(RM) $$(TARGETS.CLEAN)

endef

define $(call $.new_template,end,,)
-include $$(DEPENDENCIES)
endef

endif
