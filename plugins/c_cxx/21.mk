# School 21 C/C++ configuration preset

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

ifndef __mmake_plugin_c_cxx_21
__mmake_plugin_c_cxx_21 := 1

# c_cxx plugin configuration
$.config.mostlyclean_target := clean
$.config.clean_target := fclean

# Project/target configuration preset
define $(call $.autostrip,$.use_21) =
	$(call $.set,CC,gcc)
	$(call $.set,CXX,)
	$(call $.set,CFLAGS,-Wall -Wextra -Werror -std=c11)
	$(call $.set,CXXFLAGS,)
endef

# Norm-compliant re target
define $(call $.new_template,util)
re: fclean .WAIT all

endef

endif