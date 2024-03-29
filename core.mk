# Make 4.4 compatibility test (version checker requires 4.4 to work)
ifneq ($(intcmp 1,1,<,=,>),=)
$(error Your Make installation is not compatible with mmake, please install GNU Make v4.4 or newer.)
endif

# Make configuration
.RECIPEPREFIX := >
.NOTPARALLEL:

# Include guard
ifndef __mmake
__mmake := 1

# Namespace alias
. := __mmake.

# Version
$.version := 0.2.1

# Make feature checker
# (feature_list) -> ()
$.assert_make_features = $(if $(filter-out $(.FEATURES),$1),$(error Your Make version is missing some of the required features ($(filter-out $(.FEATURES),$1)) to run current mmake setup. Please upgrade your make installation or change the configuration.))

# Semver checker
# (semver, version_index) -> version
$.semver_get = $(or $(word $2,$(subst ., ,$1)),0)

# (semver1, semver2) -> > | = | < | ~
# > : older version
# < : newer major version
# = : same version
# ~ : same major version, newer minor or patch version
$.semver_compare = $(intcmp $(call $.semver_get,$1,1),$(call $.semver_get,$2,1),<,$(intcmp $(call $.semver_get,$1,2),$(call $.semver_get,$2,2),~,$(intcmp $(call $.semver_get,$1,3),$(call $.semver_get,$2,3),~,=,>),>),>)

# (semver_expected, semver_current, error_message) -> ()
$.semver_assert_exact = $(if $(filter =,$(call $.semver_compare,$1,$2)),,$(error $3))
$.semver_assert_compatible = $(if $(filter = ~,$(call $.semver_compare,$1,$2)),,$(error $3))
$.semver_assert_minimum = $(if $(filter >,$(call $.semver_compare,$1,$2)),$(error $3))

# Make version checker
$.required_make_version := 4.4

$(call $.semver_assert_minimum,$($.required_make_version),$(MAKE_VERSION),Your Make version is not compatible with mmake. Please install GNU Make v$($.required_make_version) or newer.)

# Module glue
# Allows included makefiles to include mmake modules without specifying direct path
export MMAKE_CORE := $(abspath $(lastword $(MAKEFILE_LIST)))
export MMAKE_ROOT := $(dir $(MMAKE_CORE))

# General mmake configuration
# Generated makefile path
$.config.target_makefile := Makefile

# Utilities

# $.unspace is used to remove whitespace characters with special markers
# Right/left whitespace markers make $.unspace remove 1 space in specified direction
$.unspace.right := $.unspace.right_marker__
$.unspace.left := $.unspace.left_marker__
# Line marker makes $.unspace remove the folloing newline.
$.unspace.line := $.unspace.line_marker__
$.noline = $($.unspace.line)

define $.unspace.line.linebreak :=


endef

# (text) -> text
$.unspace = $(subst $($.unspace.line),,$(subst $($.unspace.line)$($.unspace.line.linebreak),,$(subst $($.unspace.left),,$(subst $() $($.unspace.left),,$(subst $($.unspace.right),,$(subst $($.unspace.right) ,,$1))))))

# Replaces all $ with $$
# (text) -> text
$.escape = $(subst $$,$$$$,$1)

# Strips defined content (e.g define $(call $.autostrip,my_text))
# (name) -> name
$.autostrip = $.autostrip/$1$(eval $1 = $$(strip $$(call $.autostrip/$1,$$1,$$2,$$3,$$4,$$5,$$6,$$7,$$8,$$9)))

# Alias for $($(var)) operation, can be used to increase readability
# (handle) -> $(handle)
$... = $($1)

# Temporaty value storage
# (name, value) -> value
$.t = $2$(eval $.t.$1 := $$()$(call $.escape,$2)$$())

# Entity API
# Entities are anonymous values that are passed by their handles.
# For each anonymous object a unique variable is created, it's name is used as a handle.
# A handle consists of namespace, data type and storage index: $.handle/<type>/<index>

# (type) -> variable_name
$.new_entity = $.handle/$1/$(words $($.entity/$1.index))$(eval $.entity/$1.list += $(words $($.entity/$1.index)))$(eval $.entity/$1.index += x)

# (type) -> values
$.entity.get_all = $(foreach index,$($.entity/$1.list),$.handle/$1/$(index))

# Object API
# Object is a key-value store that can be used to represent complex data structures in make.
# Object is a list of properties, which are key-value pairs.
# Multiple properties can have the same key, they will behave as a single property with accumulated values (in order of definition).

# $.property is a key-value pair

# (handle) -> key
$.property.get_key = $($1.key)
# (handle, ...args) -> value
$.property.get_value = $(call $1.value,$2,$3,$4,$5,$6)

# (key, value, flavor?) -> handle
$.new_property = $(foreach handle,$(call $.new_entity,$.property),$(handle)$(eval $(handle).key := $$()$(call $.escape,$1)$$())$(eval $(handle).value $(or $3,=) $$()$(call $.escape,$2)$$()))
$.set = $(call $.new_property,$1,$2,$3)

# $.object is a list of $.properties

# (handle, key, ...args) -> value
$.object.get = $(call $.unspace,$(call $.unspace,$(foreach property,$($1),$(if $(filter $2,$(call $.property.get_key,$(property))),$(call $.property.get_value,$(property),$3,$4,$5,$6,$7) )$($.unspace.right)))$($.unspace.left))
$.object.get_joined = $(call $.unspace,$(foreach property,$($1),$(if $(filter $2,$(call $.property.get_key,$(property))),$(call $.property.get_value,$(property),$3,$4,$5,$6,$7))$($.unspace.right)))
$.get = $(call $.object.get,$1,$2,$3,$4,$5,$6,$7)
$.get! = $(call $.object.get_joined,$1,$2,$3,$4,$5,$6,$7)

# (handle, key) -> 1 | ``
$.object.has = $(if $(strip $(foreach property,$($1),$(if $(filter $2,$(call $.property.get_key,$(property))),x))),1)
$.has = $(call $.object.has,$1,$2)

# (properties) -> handle
$.new_object = $(foreach handle,$(call $.new_entity,$.object),$(handle)$(eval $(handle) := $1))

# $.to_string can be used with both $.objects and $.properties recursively, any other value will be returned as is
# (value) -> text
$.to_string = $(if $(1:$.handle/$.property/%=),$(if $(1:$.handle/$.object/%=),`$1`,$(call $.to_string.object,$1)),$(call $.to_string.property,$1))
$.to_string.object = { $(foreach property,$($1),$(call $.to_string,$(property))) }
$.to_string.property = [ $(call $.to_string,$(call $.property.get_key,$1)) = $(call $.to_string,$(call $.property.get_value,$1)) ]

# $.this is used as a context for macros, can be utilized for other cases

# (context)
$.define_context = $(eval $.this = $()$1$())

# (key, ...args)
$.this_get = $(call $.get,$($.this),$1,$2,$3,$4,$5,$6)
$.this_get! = $(call $.get!,$($.this),$1,$2,$3,$4,$5,$6)

# Shorthand $.this accessor, acts as $.this_get when a key is passed
# (key?, ...args)
$.@ = $(if $1,$(call $.this_get,$1,$2,$3,$4,$5,$6),$($.this))
$.@! = $(if $1,$(call $.this_get!,$1,$2,$3,$4,$5,$6),$($.this))

# Macro API
# Macros are used to store reusable make code. They can be assecced as text using $.macro.get or evaluated using $.macro.eval.
# Macros are implemented as $.objects, which means that you can add properties to them.

# $.macro object special properties
# - $.name - Macro name
# - $.context - Default context to eval macro with
# - $.source - Macro content
#
# $.macro object flags
# - autostrip - Strip macro content
# - no_final_newline - Not insert final newline

# Macro context can be acccesed using $.this variable and it's aliases.

define $.macro.linebreak :=


endef

$.macros := $(call $.new_object)

# (macro) -> ()
$.macro.register = $(eval $($.macros) += $(call $.set,$(call $.get,$1,$.name),$1))

# (macro, fallback_context) -> ()
$.macro.define_context = $(call $.define_context,$(or $(call $.get,$1,$.context),$2))

# (macro, source)
$.macro.get_source.apply_flags = $(if $(call $.has,$1,autostrip),$(strip $2),$2)$(if $(call $.has,$1,no_final_newline),,$($.macro.linebreak))

# (macro, context, ...args)
$.macro.get_source = $(call $.macro.define_context,$1,$2)$(call $.macro.get_source.apply_flags,$1,$(call $.get,$(macro),$.source,$3,$4,$5,$6,$7))

# (name, context, ...args) -> text
$.macro.get = $(call $.unspace,$(foreach macro,$(call $.get,$($.macros),$1),$(call $.macro.get_source,$(macro),$2,$3,$4,$5,$6,$7)$($.unspace.right)))

# (name, context, ...args) -> ()
$.macro.eval = $(eval $(call $.macro.get,$1,$2,$3,$4,$5,$6,$7))
$.eval = $(call $.macro.eval,$1,$2,$3,$4,$5,$6,$7)

# (name, properties) -> source_handle
$.new_macro = $(foreach source,$(call $.set,$.source),$(foreach macro,$(call $.new_object,$(call $.set,$.name,$1) $(source) $2),$(call $.macro.register,$(macro))$(source).value))

# Configuration API
# MMake provides 2 configuration primitives ($.project and targets), which are stored as $.objects.
# The $.project object represents project level configuration. There can be only one $.project, which is initialized automatically.
# Target objects represent configurations for individual targets. Targets can be created using the $.new_target function by the user.
# Targets are registered on the $.project, the list of registered targets can be accessed with $.project.targets.

# MMake also supports subprojects. A subproject is an mmake makefile. MMake will run subproject makefiles and provide it's exports to them.

$.project := $(call $.new_object)

$.project.targets = $(call $.get,$($.project),$.targets)
$.project.subprojects = $(call $.get,$($.project),$.subprojects)

# (paths) -> properties
$.add_subprojects = $(call $.set,$.subprojects,$1)

# (properties) -> handle
$.new_target = $(foreach handle,$(call $.new_object,$1),$(handle)$(eval $($.project) += $(call $.set,$.targets,$(handle))))

# Template API
# Template API is used to generate make code.
# Users can define templates and bind them to different generation steps and contexts.
# MMake will walk through all templates and construct the target makefile.
# Templates are based on macros.

# (step, scope?, properties) -> source_handle
$.new_template = $(call $.new_macro,$.template/$1/$(or $2,project),$3)

# $.defer is used to defer execution until the generation phase.
# Useful when you need a complete configuration to make decisions (e.g conditional templates).
# Note that this will add another expansion step. You will have to escape make expressions that should be deferred.
$.defer = $(call $.new_macro,$.defer)

# Default build step list, can be modified
$.template.steps := init configure build util end

$.template.scopes := project target

# (step, scope) -> makefile_source
$.template.make_scoped_step = $(call $.template.make_scoped_step.$2,$1,$2)
$.template.make_scoped_step.project = $(call $.macro.get,$.template/$1/$2,$($.project))
$.template.make_scoped_step.target = $(call $.unspace,$(foreach target,$($.project.targets),$(call $.macro.get,$.template/$1/$2,$(target))$($.unspace.right)))

# (step) -> makefile_source
$.template.make_step = $(call $.unspace,$(foreach scope,$($.template.scopes),$(call $.template.make_scoped_step,$1,$(scope))$($.unspace.right)))

$.template = $(call $.unspace,$(foreach step,$($.template.steps),$(call $.template.make_step,$(step))$($.unspace.right)))

# Make API
# Main entrypoint & makefile generation

$.make.write_template = $(file > $($.config.target_makefile),$($.template))

$.make = $(call $.eval,$.defer)$($.make.write_template)
$.make_subprojects = $(foreach project,$($.project.subprojects),$(MAKE) -C $(dir $(project)) -f $(notdir $(project));)

.PHONY: $.make_subprojects
$.make_subprojects:
>	$(info Building subprojects : `$($.project.subprojects)`)
>	$($.make_subprojects)

.PHONY: $.make
$.make: $.make_subprojects
>	$(info Using mmake: v$($.version))
>	$(info $($.make))
>	$(info Generated makefile: $($.config.target_makefile))

.DEFAULT_GOAL := $.make

endif
