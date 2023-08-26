# School 21 C/C++ gcoverage configuration preset

# Make configuration
.RECIPEPREFIX := >
.NOTPARALLEL:

# MMake guard
ifndef __mmake
$(error This file is an mmake plugin, it is not intended for standalone usage. Please include mmake first.)
endif

# C/C++ plugin guard
ifndef __mmake_plugin_c_cxx
$(error This file is a configuration preset for C/C++ plugin, it is not intended for standalone usage. Please include c_cxx plugin first.)
endif

ifndef __mmake_plugin_gcov_report
__mmake_plugin_gcov_report := 1

define $(call $.autostrip,$.use_gcov_report) =
	$(call $.add_linked_libraries,-lgcov)
	$(call $.set,CFLAGS,$(call $.get,$1,CFLAGS) --coverage)
	$(call $.set,gcov_target,$1)
	$(if $($2),$(call $.set,gcov_final,$2),)
endef

define $(call $.new_template,configure) =
TARGETS.CLEAN+=*.gcno *.gcda *.info *.gcov -r report
endef

define $(call $.new_macro,__gcov_report.gcov_template) =
gcov_report_$($.@):
> ./$($.@)
> lcov -o $($.@).info -c -d .
> genhtml -o report $($.@).info
endef

define $(call $.new_macro,__gcov_report.gcov_final_template) =
gcov_report: gcov_report_$(call $.get,$(call $.get,$($.@),gcov_target),name)
endef

define $(call $.new_macro,__gcov_report.__gcov_template) =
$(call $.macro.get,__gcov_report._gcov_template,$(call $.get,$(call $.get,$($.@),gcov_target),name))
endef

define $(call $.new_macro,__gcov_report._gcov_template) =
$(call $.macro.get,__gcov_report.gcov_template,$($.@))
$(if $(call $.has,$($.@),gcov_final),$(call $.macro.get,__gcov_report.gcov_final_template,$($.@)))
endef

define $(call $.new_template,util,target) =
$(if $(call $.has,$($.@),gcov_target),$(call $.macro.get,__gcov_report.__gcov_template,$($.@)),)
endef

endif
