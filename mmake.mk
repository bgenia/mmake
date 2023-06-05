# mmake/mmake, a gnu/make Makefile generator.
# This module provides core APIs only, use plugins to implement actual generators.

# MMPRAGMA
# A list of pragmas that control the behavior of mmake.
# You can add pragmas to this list by defining them on the MMPRAGMA variable before including this file.
# The following pragmas are supported:
# - no_make_44_check: disables the check for GNU Make v4.4 or newer, expect unstable behavior.
# - no_make_feature_check: disables the check for GNU Make features, expect unstable behavior.
# - no_make_version_check: disables the check for GNU Make version, expect unstable behavior.
# - no_make_checks: disables all checks for GNU Make, expect unstable behavior.

# Make 4.4 compatibility test, can be opted out by the no_make_44_check/no_make_checks pragmas.
# Turning this off is not recommended, expect unstable behavior.
ifneq ($(intcmp 1,1,<,=,>),=)
ifeq ($(filter no_make_44_check no_make_checks,$(MMPRAGMA)),)
$(error Your make installation is not compatible with GNU Make v4.4 or newer, update your installation or turn this check off (see mmake/mmake.mk).)
else
$(warning Your make installation is not compatible with GNU Make v4.4 or newer, expect unstable behavior.)
endif
endif

# Make configuration
.RECIPEPREFIX := >
#.NOTPARALLEL:
MAKEFLAGS += -j

# Include guard
ifndef __mmake
__mmake := 1

# mmake namespace
. = __mmake.

# mmake version
$.version := 0.3.0 @prototype

$(info Using $$.mmake v$($.version))


# Semver utility functions

## Get version number by index from a semver string
# (semver, index) -> (version_number)
$.semver.get = $(or $(word $2,$(subst ., ,$1)),0)

# Compare two semver strings
# (semver_expected, semver_actual) -> (comparison_result)
# comparison_result is one of the following:
# - <: semver_actual is less than semver_expected
# - =: semver_actual is equal to semver_expected
# - >: semver_actual is greater than semver_expected
# - ~: semver_actual is compatible with semver_expected (same major version and minor/patch versions are greater or equal to semver_expected)
$.semver.compare = $(intcmp $(call $.semver.get,$1,1),$(call $.semver.get,$2,1),>,$(intcmp $(call $.semver.get,$1,2),$(call $.semver.get,$2,2),~,$(intcmp $(call $.semver.get,$1,3),$(call $.semver.get,$2,3),~,=,<),<),<)

# Semver assertion functions

# Asserts that semver_expected is exactly equal to semver_actual
# (semver_expected, semver_actual, error_message) -> ()
$.semver.assert_exact = $(if $(filter-out =,$(call $.semver.compare,$1,$2)),$(error $3))

# Asserts that semver_expected is compatible with semver_actual
# (semver_expected, semver_actual, error_message) -> ()
$.semver.assert_compatible = $(if $(filter-out = ~,$(call $.semver.compare,$1,$2)),$(error $3))

# Asserts that semver_expected is less or equal to semver_actual
# (semver_expected, semver_actual, error_message) -> ()
$.semver.assert_minimum = $(if $(filter-out = ~ >,$(call $.semver.compare,$1,$2)),$(error $3))


# Make compatibility checks

# Make version checker, can be opted out by the no_make_version_check/no_make_checks pragmas.
# Turning this off is not recommended, expect unstable behavior.
# (semver_expected) -> ()
$.make.assert_version = $(if $(filter-out = ~ >,$(call $.semver.compare,$1,$(MAKE_VERSION))),\
	$(if $(filter no_make_version_check no_make_checks,$(MMPRAGMA)),\
		$(warning Your make installation is not compatible with GNU Make $1 or newer, expect unstable behavior.),\
		$(call $.semver.assert_minimum,$1,$(.VERSION),Your make installation is not compatible with GNU Make $1 or newer. Update your make installation or change the configuration.)\
	)\
)

# Make feature checker, can be opted out by the no_make_feature_check/no_make_checks pragmas.
# Turning this off is not recommended, expect unstable behavior.
# (feature_list) -> ()
$.make.assert_features = $(if $(filter-out $(.FEATURES),$1),\
	$(if $(filter no_make_feature_check no_make_checks,$(MMPRAGMA)),\
		$(warning Your make installation is missing some of the required features ($(filter-out $(.FEATURES),$1)) to run current mmake setup, expect unstable behavior.),\
		$(error Your make installation is missing some of the required features ($(filter-out $(.FEATURES),$1)) to run current mmake setup. Update your make installation or change the configuration.)\
	)\
)

# Requirements for compatibility checks
$.requirements.make_version := 4.4.0
$.requirements.make_features :=

# Assert minimum make version
$(call $.make.assert_version,$($.make_version))

# Assert make features
$(call $.make.assert_features,$($.make_features))


# Core module path exports for glueing submodules together
export MMAKE_PATH := $(abspath $(lastword $(MAKEFILE_LIST)))
export MMAKE_ROOT := $(dir $(MMAKE_PATH))


# Entities
# Entities are anonymous values that are passed around by their handles.
# For each entity a unique variable is created, it's name is used as a handle.
# A handle consists of namespace, data type and storage index: $.entity/<type>/<index>

# Creates a new entity of the specified type.
# (type) -> (handle)
$.entity.create = $.entity/$1/$(words $($.entity/$1.index))$(eval $.entity/$1.list += $(words $($.entity/$1.index)))$(eval $.entity/$1.index += x)

# Gets all entities of the specified type.
# (type) -> (handle_list)
$.entity.get = $(foreach i,$($.entity/$1.list),$($.entity/$1/$i))


# String comparator
# Returns 1 if str1 and str2 are the same, otherwise returns nothing
# (str1, str2) -> (bool)
$.equals = $(and $(findstring $1,$2),$(findstring $2,$1),1)


# Functional programming
# These utilities are used to facilitate functional programming in makefiles.

# Identity function.
# (arg) -> (arg)
$.identity = $1

# Creates an anonymous $(call)able function.
# (body) -> (handle)
$.lambda = $(let e,$(call $.entity.create,$.lambda),$(eval $e = $()$1$())$e)

# Creates a named function using $(eval), can be used with meta constructs such as $.forward_argv.
# (name, body) -> ()
$.function = $(eval $1 = $()$2$())

# Creates a list of specified length.
# (length, current_) -> (list)
$.list = $(if $(and $(findstring $1,$(words $2)),$(findstring $(words $2),$1),1),$2,$(call $.list,$1,$2 x))

# Creates a list of numbers from $(start) of length $(length)/
# (start, length) -> (list)
$.slice = $(call $.range,$1,$(words $(call $.list,$1) $(call $.list,$2)))

# Creates a list of numbers for range [start; end).
# (start, end, current_) -> (list)
$.range = $(let v,$(or $3,$(call $.list,$1)),$(if $(call $.equals,$(words $v),$2),,$(strip $(words $v) $(call $.range,$1,$2,$v x))))

# Returns the first element of a list.
# (list) -> (value)
$.head = $(firstword $1)

# Returns the tail of a list.
# (list) -> (list)
$.tail = $(wordlist 2,$(words $1),$1)

# Returns the last element of a list.
# (list) -> (value)
$.last = $(lastword $1)

# Returns all but the last element of a list.
# (list) -> (list)
$.skip = $(wordlist 1,$(words $(call $.tail,$1)),$1)

# Applies a function to each element of a list.
# (list, function: (value) -> (value)) -> (list)
$.map = $(foreach e,$1,$(call $2,$e))

# Filters a list by applying a function to each element and returning only the elements for which the function returns true.
# (list, function: (value) -> (bool)) -> (list)
$.filter = $(foreach e,$1,$(if $(call $2,$e),$e))

# Folds a list by combining each element with the accumulator from right to left
# (list, function: (value, accumulator) -> (accumulator), accumulator) -> (accumulator)
$.fold = $(let h t,$1,$(if $h,$(call $2,$h,$(call $.fold,$t,$2,$3)),$3))

# Reduces a list by combining all elements one by one from right to left
# (list, function: (value, accumulator) -> (accumulator)) -> (accumulator)
$.reduce = $(call $.fold,$(call $.skip,$1),$2,$(call $.last,$1))

# Folds a list by combining each element with the accumulator from left to right.
# (list, function: (value, accumulator) -> (accumulator), accumulator) -> (accumulator)
$.fold_right = $(let h t,$1,$(if $h,$(call $.fold_right,$t,$2,$(call $2,$h,$3)),$3))

# Reduces a list by combining all elements one by one from left to right
# (list, function: (value, accumulator) -> (accumulator), initial_value?) -> (accumulator)
$.reduce_right = $(call $.fold_right,$(call $.tail,$1),$2,$(call $.head,$1))

# Joins a list with the specified separator
# (list, separator) -> (string)
$.join = $(call $.reduce,$1,$(call $.lambda,$$1$2$$2))

# Combines a list of functions of a single argument into a single function from left to right.
# Note that this function creates a wrapper lambda (a global entity) for each function in a list.
# (function_list) -> (arg) -> (value)
$.pipe = $(call $.reduce,$1,$(call $.lambda,$$(call $.lambda,$$$$(call $$2,$$$$(call $$1,$$$$1)))))

# Combines a list of functions of a single argument into a single function from right to left.
# Note that this function creates a wrapper lambda (a global entity) for each function in a list.
# (function_list) -> (arg) -> (value)
$.compose = $(call $.reduce_right,$1,$(call $.lambda,$$(call $.lambda,$$$$(call $$2,$$$$(call $$1,$$$$1)))))


# Function arguments

# Generates a list of available function argument variables.
# () -> (argument_list)
$.argv = $(strip $(let $.argv/i,$(or $($.argv/i),x),$(if $(findstring $(origin $(words $($.argv/i))),undefined),,$(words $($.argv/i)) $(let $.argv/i,$($.argv/i) x,$(call $.argv)))))

# Computes the number of arguments passed to a function, works for up to 100 arguments.
# () -> (uint)
$.argc = $(words $($.argv))

# Creates a string of all available function arguments separated by commas.
# Must be used as a variable $($.args) to work properly.
# () -> (arguments)
$.args = $(subst $.args.separator__,,$(subst $() $.args.separator__,$($.format.,),$(foreach a,$($.argv),$.args.separator__$($a))))

# Creates an argument forwarding list for use in forwarding lambdas.
# (first_index, count) -> (argument_list)
$.forward_argvn = $(call $.join,$(call $.map,$(call $.range,$1,$2),$(call $.lambda,$$$$($$1))),$($.format.,))
# (first_index, last_index)
$.forward_argv = $(call $.join,$(call $.map,$(call $.range,$1,$2),$(call $.lambda,$$$$($$1))),$($.format.,))


# Runtime configuration

# The path to the Makefile that is being generated
$.config.makefile := ./Makefile

$.config.template.steps := $()
$.config.template.scopes := $()

$.config.template.steps.default := begin
$.config.template.scopes.default := project


# Format markers are used to mark text for formatting.
# Right/left whitespace removal markers (removes excactly one whitespace character):
$.format.rtrim := $.format.rtrim_marker__
$.format.ltrim := $.format.ltrim_marker__

# Linebreak removal marker (removes excactly one linebreak character):
$.format.noline := $.format.noline_marker__

# Linebreak insertion marker:
$.format.linebreak := $.format.linebreak_marker__

# Dummy marker, simply gets removed from the string
# Can be used to escape leading whitespaces
$.format.dummy := $.format.dummy_marker__

# Linebreak character:
define $.format.\n :=


endef

# Comma character:
$.format., := ,

# Format marker handlers
# (string) -> (string)
define $.format.handlers :=
	$(call $.lambda,$$(subst $$($.format.rtrim),,$$(subst $$($.format.rtrim) ,,$$1)))
	$(call $.lambda,$$(subst $$($.format.ltrim),,$$(subst $$() $$($.format.ltrim),,$$1)))
	$(call $.lambda,$$(subst $$($.format.noline),,$$(subst $$($.format.noline)$$($.format.\n),,$$1)))
	$(call $.lambda,$$(subst $$($.format.linebreak),$$($.format.\n),$$1))
	$(call $.lambda,$$(subst $$($.format.dummy),,$$1))
endef

$.format.impl = $(call $.compose,$($.format.handlers))

# Format a string using the format markers
# (string) -> (formatted_string)
$.format = $(call $($.format.impl),$1)


# Escape a string for use in a Makefile.
# Replaces all dollar signs with $$.
$.escape = $(subst $$,$$$$,$1)


# Properties
# Properties are named values (key/value pairs) stored as entities.

# Creates a new property.
# The flavor is argument is optional and can be used to specify the property value flavor (e.g. simple, recursive, etc.). Default is simple.
# (key, value, flavor?) -> (handle)
$.property.create = $(let p,$(call $.entity.create,$.property),$(eval $p.key := $$()$(call $.escape,$1)$$())$(eval $p $(or $3,:=) $$()$(call $.escape,$2)$$())$p)

# Converts a property to a string.
# (handle) -> (string)
$.property.stringify = [ $(call $.property.get_key,$1) = $(call $1) ]

# Gets the key of a property.
# (handle) -> (key)
$.property.get_key = $($1.key)

# Expands all "simple properties" in a string while remaining the normal ones.
# (string) -> properties
$.property.expand_simple = $(foreach s,$1,$(if $(findstring :,$s),$(let l,$(subst :, ,$s),$(call $.set,$(word 1,$l),$(word 2,$l))),$(if $(filter $.entity/$.property/%,$s),$s,$(call $.set,$s))))

# Shorthand for $.property.create
# (key, value, flavor?) -> (handle)
$.set = $($.property.create)

# Shorthand for $.property.expand_simple
$.props = $($.property.expand_simple)

# Objects
# Objects are lists of properties stored as entities.
# Multiple properties with the same key are treated as one property with a list of values.

# Creates a new object.
# Allows to specify a list of properties to add to the object.
# (props?) -> (handle)
$.object.create = $(let o,$(call $.entity.create,$.object),$(eval $o := $(or $(call $.props,$1),$$()))$o)

# Gets the value of the specified property.
# Supports passing up to 5 arguments to the property value if it is callable (recursive flavor).
# (object_handle, key, ...args) -> (value)
$.object.get = $(foreach p,$(foreach p,$($1),$(if $(call $.equals,$2,$(call $.property.get_key,$p)),$p)),$(call $p,$3,$4,$5,$6,$7))

# Checks if the specified property exists in the object.
# (object_handle, key) -> (bool)
$.object.has = $(firstword $(foreach p,$($1),$(if $(call $.equals,$2,$(call $.property.get_key,$p)),1)))

# Shorthands for $.object methods
# (props?) -> (handle)
$.new = $($.object.create)
# (object_handle, key, ...args) -> (value)
$.get = $($.object.get)
# (object_handle, key) -> (bool)
$.has = $($.object.has)


# Object/property stringification

# Recursively stringifies objects and properties in a value.
# As make stuggles with deep recursion, the recursion depth is limited by the depth argument as a number (Default is 2).
# The current_depth_ argument is used internally and should not be passed explicitly.
# (value, depth?, current_depth_) -> (string)
$.stringify = $(if $(call $.equals,$(or $2,2),$(words $3)),$1,$(if $(filter $.entity/$.property/%,$1),[ $(call $.property.get_key,$1) = $(call $.stringify,$($1),$2,$3 x) ],$(if $(filter $.entity/$.object/%,$1),{ $(words $($1)) $(foreach p,$($1),$(call $.stringify,$p,$2,$3 x)) },$(if $(filter $.entity/%,$1),<@$(1:$.entity/%=%): $(call $.stringify,$($1),$2,$3 x) >,$1))))


# Recursive context
# Context can be used to give a function information about current scope.

# Evaluates a recursive variable with the specified context
# Context is accessible via $.this and $.@ variables.
# Takes up to 5 arguments for callable variables.
# (name, context, ...args) -> (value)
$.call = $(let $.this,$2,$(call $1,$3,$4,$5,$6,$7))

# Shorthand for accessing current context object
# Works as $(call $.get,$($.this),key,...args) if the key argument was provided, otheriwise is equivalent to $($.this)
# (key?, ...args) -> (value)
$.@ = $(if $1,$(call $.get,$($.this),$1,$2,$3,$4,$5,$6),$($.this))


# Macros
# Macros are reusable pieces of make code. They can be used to define functions, templates, etc.
# Macros are stored as objects and registered in the $.macro.registry, from which they can be accessed by their name.

# Registry object
$.macro.registry := $()

# Registers a macro on the master macros object.
# (macro_handle) -> ()
$.macro.register = $(eval $.macro.registry += $(call $.set,$(call $.get,$1,name),$1))

# Macro modifiers
# Modifiers are used to modify the behavior of macros.

# A list of functions to modify macros (source, macro)@context -> (source)
$.macro.modifiers := $()

# Default macro modifiers:
# - use:(function: (source, macro)@context -> (source)) : uses specified function as a modifier, can be declared multiple times for a list of functions
# - autostrip : $(strip)s macro source
# - noline : disables final linebreak insertion
# - if:(function: (source, macro)@context -> (boolean)) : replaces macro source with an empty string if the specified function returned an empty string
ifeq ($(filter no_default_macro_modifiers,$(MMPRAGMA)),)
	define $.macro.modifiers +=
		$(call $.lambda,$$(call $.fold_right,$$(call $.get,$$2,use),$$(call $.lambda,$$$$(call $$$$1,$$$$2,$$2)),$$1))
		$(call $.lambda,$$(if $$(call $.has,$$2,autostrip),$$(strip $$1),$$1))
		$(call $.lambda,$$(if $$(call $.has,$$2,noline),$$1,$$1$$($.format.\n)))
		$(call $.lambda,$$(if $$(call $.has,$$2,if),$$(if $$(call $$(call $.get,$$2,if),$$1,$$2),$$1),$$1))
	endef
endif

# Applies all the modifiers from $.macro.modifiers to macro source.
# (source, macro, context) -> (source)
$.macro.modify_source = $(call $.fold_right,$($.macro.modifiers),$(call $.lambda,$$(call $.call,$$1,$3,$$2,$2)),$1)

# Gets a macro by name.
# (name) -> (macro_handle)
$.macro.get_macro = $(strip $(foreach h,$($.macro.registry),$(if $(call $.equals,$(call $.get,$($h),name),$1),$($h))))

# Gets raw macro text.
# (name, context?, ...args) -> (text)
$.macro.get_raw = $(call $.format,$(foreach m,$(call $.macro.get_macro,$1),$(if $(call $.has,$m,noexpand),$(value $(call $.get,$m,source)),$(call $.call,$(call $.get,$m,source),$(or $2,$(call $.get,$m,context)),$3,$4,$5,$6,$7))$($.format.rtrim)))

# Gets modified macro text.
# (name, context?, ...args)
$.macro.get_text = $(call $.format,$(foreach m,$(call $.macro.get_macro,$1),$(let c,$(or $2,$(call $.get,$m,context)),$(call $.macro.modify_source,$(if $(call $.has,$m,noexpand),$(value $(call $.get,$m,source)),$(call $.call,$(call $.get,$m,source),$c,$3,$4,$5,$6,$7)),$m,$c))$($.format.rtrim)))

# Evaluates given macro as make code.
# (name, context?, ...args)
$.macro.eval = $(eval $(call $.macro.get_text,$1,$2,$3,$4,$5,$6,$7))

# Creates a new macro and returns it's source handle.
# (name, properties) -> (source_handle)
$.macro.create = $(let s,$(call $.set,source,$(call $.entity.create,$.macro_source)),$(let m,$(call $.new,$(call $.set,name,$1) $s $2),$(call $.macro.register,$m)$($s)))

# Shorthand for $.macro.eval
$.eval = $($.macro.eval)

# Shorthand for $.macro.create
$.macro = $($.macro.create)


# Configuration
# MMake provides 2 configuration primitives in a form of $.project and targets, which are stored as objects.
# The $.project object (notice that you don't need another $() to access it) represents the project-level configuration.
# There is only one such object.
# Target objects allow for target-specific configurations, they are created by the end user and automatically registered on the $.project.
# The list of all registered targets is available as $(call $.get,$.project,targets) or $($.project.targets).

# MMake also supports subprojects.
# A subproject is another mmake configuration in a separate makefile which will be built tougether with (before) the main project.
# The mmake installation used for the main project is shared across the subprojects by default, although each of them can choose to override it.
# Subprojects can have their own subprojects.

$.project := $()

$.project.targets = $(call $.get,$.project,targets)
$.project.subprojects = $(call $.get,$.project,subprojects)

# Adding subprojects
# (paths) -> (properties)

define $.add_subprojects =
$(strip
$(foreach p,$1,$(eval
$.mmake.make_all: $.subproject/$p

.PHONY: $.subproject/$p

$.subproject/$p:
>	$$(info Making subproject: $p)
>	$$(MAKE) -C $(dir $p) -f $(notdir $p)
))
$(call $.set,subprojects,$1)
)
endef

# Creates a new target and registers it on the project.
# Intended for use in a wrapper, therefore doesn't have a shorthand.
# (properties) -> (handle)
$.target.create = $(let h,$(call $.new,$1),$(eval $.project += $(call $.set,targets,$h))$h)


# Templates
# Templates are macros used to describe the generated makefile code. All macro features are supported.
# The template resolution process is called the compilation phase in mmake.
# During compilation phase, mmake will iterate over all defined compilation STEPS and collect templates for all specified SCOPES.
# Steps and scopes can be configured using their respective $.config variables.

# Creates a new template.
# (properties) -> (source_handle)
$.template.create = $(let p,$(call $.props,$1),$(call $.macro,$.template/$(or $(call $.get,p,on),$($.config.template.steps.default))/$(or $(call $.get,p,of),$($.config.template.scopes.default)),$p))

# All available STEPS and SCOPES including the builtin ones.
$.template.steps = begin $($.config.template.steps) end
$.template.scopes = project target $($.config.template.scopes)

# Shorthand for $.template.create
# (properties) -> (source_handle)
$.template = $($.template.create)

# Template resolvers for different compilation scopes.
# Resolvers for custom scopes can be defined in a similar manner.
# (step, scope) -> (source)
$.template.compile_scoped_step/project = $(call $.macro.get_text,$.template/$1/$2,$.project)
$.template.compile_scoped_step/target = $(call $.format,$(foreach t,$($.project.targets),$(call $.macro.get_text,$.template/$1/$2,$t)$($.format.rtrim)))

# Resolves templates for the specified scope.
# (step, scope) -> (source)
$.template.compile_scoped_step = $(call $.template.compile_scoped_step/$2,$1,$2)

# Resolves templates for the specified step.
# (step) -> (source)
$.template.compile_step = $(call $.format,$(foreach s,$($.template.scopes),$(call $.template.compile_scoped_step,$1,$s)$($.format.rtrim)))

# Compiles all defined templates into target makefile source.
# A fully custom template compiler can be assigned here.
# () -> (source)
$.template.compile = $(call $.format,$(foreach s,$($.template.steps),$(call $.template.compile_step,$s)$($.format.rtrim)))


# Hooks / Defer

# $.defer macros are used to defer the execution of make code until the compilation phase.
# For example, you can use this to register different templates depending on the configuration.
# $.defer is noexpand by default when used as a variable `$($.defer)`, but not when used as a function `$(call $.defer,...)`.
# (properties?) -> (source_handle)
$.defer = $(call $.macro,$.hook/compile,$(if $(and $(call $.equals,$.defer,$0),$(findstring automatic,$(origin 0))),$1,noexpand))

# Evaluates all defered macros
$.defer.eval = $(call $.macro.eval,$.hook/compile)


# MMake
# Main mmake functions.

# Writes the compiled template to the target makefile.
# () -> ()
$.mmake.write_template = $(file > $($.config.makefile),$(call $.template.compile))

# Runs deferred code and writes the compiled template to the target makefile.
# () -> ()
$.mmake.make_project = $(call $.defer.eval)$(call $.mmake.write_template)

# Main entrypoint

.PHONY: $.mmake.make_all
$.mmake.make_all: $.mmake.make_project

.PHONY: $.mmake.make_project
$.mmake.make_project:
>	$(info Making project$(let n,$(call $.get,$.project,name),$(if $n, [$n])))
>	$(info Configuration: {{ $(call $.stringify,$($.project),100) }})
>	$(_ $(call $.mmake.make_project))
>	$(info Generated makefile: $($.config.makefile))
>	@:

# Plugin loader
# $.using is a wrapper on top of `include` with support for mmake plugin structure / naming convention.
# It can search for plugins by their qualified names. A qualified name <word>{:<word>} is mapped to <word>{/<word>}/plugin.mk file.
#
# `include` example:
#
# > include $(MMAKE_ROOT)/plugins/foo/plugin.mk
# > include $(MMAKE_ROOT)/plugins/foo/bar/plugins.mk
#
# Plugin loader example:
#
# > $(call $.using,foo foo:bar)
#
# Other plugin search paths might be added by the end used.

# Plugin search paths
$.using.paths := $(MMAKE_ROOT)/plugins $(MMUPATHS)

# Searches for the specified plugin across known sarch paths
# (qualified_name) -> (path?)
$.using.search = $(firstword $(foreach p,$($.using.paths),$(abspath $(wildcard $p/$(subst :,/,$1)/plugin.mk))))

# Applies single plugin by it's qualified name
# (qualified_name) -> ()
$.using.apply_one = $(let p,$(call $.using.search,$1),$(if $(wildcard $p),$(eval include $p),$(error Plugin not found: $1)))

# Applies many plugins by their qualified names
# (qualified_names) -> ()
$.using.apply = $(foreach p,$1,$(call $.using.apply_one,$p))

# Shorthand for $.using.apply
# (qualified_names) -> ()
$.using = $($.using.apply)

endif
