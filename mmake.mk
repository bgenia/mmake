# MMake is a Makefile generator written in a Makefile.
# This file contains core functonality only and cannot serve as a complete build tool, everything else is provided by plugins.

# Make configuration

.RECIPEPREFIX := >

.NOTPARALLEL:

# Include guard

ifndef __mmake
__mmake := 1

# MMake alias

. := __mmake.

# MMake version

$.version := 0.1.0

$(info >> using mmake $($.version))

# GNU Make feature list
# Required features for mmake are marked with ! (for example: else-if!)
define $.feature_list :=
	archives
	check-symlink
	else-if
	extra-prereqs
	grouped-target
	guile
	jobserver
	jobserver-fifo
	load
	notintermediate
	oneshell
	order-only
	output-sync
	second-expansion
	shell-export
	shortest-stem
	target-specific
	undefine
endef

# *(feature_list) -> ()
define $.require_make_features.implementation =
	$.require_make_features.implementation.required = $$(patsubst %!,%,$$(filter %!,$(strip $1)))
	$.require_make_features.implementation.missing = $$(filter-out $$(.FEATURES),$$($.require_make_features.implementation.required))

	ifneq ($$($.require_make_features.implementation.missing),)
		$$(error Your Make version is missing some of the required features ($$($.require_make_features.implementation.missing)) to run this mmake setup, please upgrade to a newer version of GNU Make or change your configuration.)
	endif
endef

# (feature_list) -> ()
$.require_make_features = $(eval $(call $.require_make_features.implementation,$1))

$(call $.require_make_features,$($.feature_list))

# MMake configuration

$.target_makefile := ./Makefile

# Object API
# Object is a key-value store that can be used to store data in a Makefile,
# it abstracts away the details of how the data is stored and provides a simple API,
# allowing for easy manipulation of the data.
# Note that you aren't supposed to delete properties or objects, you can only add new ones.

# $.property is used to create a key-value pair, which can be stored in an $.object.

# (index) -> handle
$.property.encode = $.property/$1

# (handle) -> index
$.property.decode = $(patsubst $.property/%,%,$1)

# (handleOrIndex) -> storage_name
$.property.get_storage = $.property.store.$(call $.property.decode,$1)

# (handle) -> key
$.property.get_key = $($(call $.property.get_storage,$1).key)

# (handle) -> value
$.property.get_value = $($(call $.property.get_storage,$1).value)

# (handle) -> text
$.property.to_string = [$(call $.property.get_key,$1)=$(call $.property.get_value,$1)]

# *(key, value) -> ()
define $.new_property.implementation.define_property =
	$(call $.property.get_storage,$(words $($.property.index))).key = $$()$1$$()
	$(call $.property.get_storage,$(words $($.property.index))).value = $$()$2$$()
endef

# (key, value) -> handle
define $.new_property.implementation =
	$(eval $(call $.new_property.implementation.define_property,$1,$2))
	$(call $.property.encode,$(words $($.property.index)))
	$(eval $.property.index += x)
endef

# (key, value) -> handle
$.new_property = $(strip $(call $.new_property.implementation,$1,$2))

# (key, value) -> handle
$.set = $(call $.new_property,$1,$2)


# $.object is a key-value store that can be used to store data in properties.

# (index) -> handle
$.object.encode = $.object/$1

# (handle) -> index
$.object.decode = $(patsubst $.object/%,%,$1)

# TODO: Implement proper joining in $.get_raw so I can get rid of $.get
# (handle, key) -> value
$.object.get = $(strip $(foreach property,$($1),$(if $(filter $2,$(call $.property.get_key,$(property))),$(call $.property.get_value,$(property)))))
$.object.get_raw = $(call $.unspace,$(foreach property,$($1),$(call $.unspace.wrap,$(if $(filter $2,$(call $.property.get_key,$(property))),$(call $.property.get_value,$(property))))))

# (handle, key) -> value
$.get = $(call $.object.get,$1,$2)
$.get_raw = $(call $.object.get_raw,$1,$2)

# (handle, key) -> value
$.this_get = $(call $.get,$($.this),$1)
$.this_get_raw = $(call $.get_raw,$($.this),$1)

# (handle) -> text
$.object.to_string = {$(foreach property,$($1),$(call $.property.to_string,$(property)))}

# (properties) -> handle
define $.new_object.implementation =
	$(eval $(call $.object.encode,$(words $($.object.index))) = $1)
	$(call $.object.encode,$(words $($.object.index)))
	$(eval $.object.index += x)
endef

# (properties) -> handle
$.new_object = $(strip $(call $.new_object.implementation,$1))


# Utility functions

# (propertyOrObject) -> text
$.to_string = $(if $(1:$.property/%=),$(if $(1:$.object/%=),$1,$(call $.object.to_string,$1)),$(call $.property.to_string,$1))

# () -> handle
# (key) -> value
$.@ = $(if $1,$(call $.this_get,$1),$($.this))
$.@r = $(if $1,$(call $.this_get_raw,$1),$($.this))

$.unspace.right = $.unspace.right_separator__

# (text) -> text
$.unspace.wrap = $1$($.unspace.right)

# (text) -> text
$.unspace = $(subst $($.unspace.right),,$(subst $($.unspace.right) ,,$1))


# Macro API
# Macros are used to store reusable make code. They can be accessed as plain text using $.macro.get or evaluated using $.macro.invoke.
# Macros are implemented as $.objects, which means that you can add properties to them.

# Macro object special properties:
# - $.context - Default context to invoke macro with
# - $.source - Macro source code

define $.macro.linebreak :=


endef

$.macro.storage := $(call $.new_object)

# (macro) -> ()
$.macro.register = $(eval $($.macro.storage) += $(call $.set,$(call $.get_raw,$1,key),$1))

# (macro, context) -> ()
$.macro.use_context = $(eval $.this = $(or $2,$(call $.get_raw,$(macro),$.context)))

# (key, context) -> macro_text
$.macro.get = $(foreach macro,$(call $.get_raw,$($.macro.storage),$1),$(call $.macro.use_context,$(macro),$2)$($.macro.linebreak)$(call $.get_raw,$(macro),$.source)$($.macro.linebreak))

# (key, context) -> ()
$.macro.invoke = $(foreach macro,$(call $.get_raw,$($.macro.storage),$1),$(call $.macro.use_context,$(macro),$2)$($.macro.linebreak)$(eval $(call $.get_raw,$(macro),$.source)$($.macro.linebreak)))

# (key, context) -> ()
$.eval = $(call $.macro.invoke,$1,$2)

# (key, properties) -> handle
define $.new_macro.implementation =
	$(eval $.new_macro.implementation.current.source := $(call $.set,$.source))
	$(eval $.new_macro.implementation.current := $(call $.new_object,$($.new_macro.implementation.current.source) $(call $.set,key,$1) $2))
	$(call $.macro.register,$($.new_macro.implementation.current))
	$(call $.property.get_storage,$($.new_macro.implementation.current.source)).value
endef

# (key, properties) -> handle
$.new_macro = $(strip $(call $.new_macro.implementation,$1,$2))


# Configuration API
# Configuration API is what the end user interacts with, it provides simple configuration primitives for the project.
# The main configuration objects are $.project and targets.
# The $.project object represents project wide configuration. There can only be one such object, which is initialized automatically.
# The target objects represent configurations of individual targets. There can be multiple such objects, which are initialized by the user.

$.project := $(call $.new_object)

$.project.targets = $(call $.get,$($.project),targets)

# (properties) -> handle
define $.new_target.implementation =
	$(eval $.new_target.implementation.current := $(call $.new_object,$1))
	$(eval $($.project) += $(call $.set,targets,$($.new_target.implementation.current)))
	$($.new_target.implementation.current)
endef

# (properties) -> handle
$.new_target = $(strip $(call $.new_target.implementation,$1))


# Plugin API
# Plugin API privides simpler ways to create custom code generators and configuration presets.

# (step,context,properties) -> handle
$.new_generator = $(call $.new_macro,$.generate$(if $2,_$2):$1,$3)


# Codegen API
# Codegen API is used to generate Makefile code.

# Codegen steps (can be overwritten, though not recommended)
# Intended usage:
# - init: Make configuration
# - configure: Project configuration
# - build: Build rules
# - util: Utility rules
# - end: Finalization
define $.codegen.steps :=
	init
	configure
	build
	util
	end
endef


# (step) -> makefile_text
$.codegen.generate_project_step = $(call $.macro.get,$.generate:$1,$($.project))$(call $.macro.get,$.generate_project:$1,$($.project))

# (step, target) -> makefile_text
$.codegen.generate_target_step = $(call $.macro.get,$.generate_target:$1,$2)

# (step) -> makefile_text
$.codegen.generate_step = $(call $.codegen.generate_project_step,$1)$(foreach target,$($.project.targets),$(call $.codegen.generate_target_step,$1,$(target)))

$.codegen.generate = $(foreach step,$($.codegen.steps),$(call $.codegen.generate_step,$(step)))

$.codegen.write = $(file > $($.target_makefile),$($.codegen.generate))


# Main Entrypoint
# The $.make function performs actual makefile generation.
# It's designed to be called after the configuration code.

# () -> ()
define $.make.implementation =
	$($.codegen.write)
	$(info >> generated makefile: $($.target_makefile))
endef

# () -> ()
$.make = $(eval $($.make.implementation))

endif
