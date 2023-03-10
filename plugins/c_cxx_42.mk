# Ecole 42 C/C++ configuration preset

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

ifndef __mmake_plugin_c_cxx_42
__mmake_plugin_c_cxx_42 := 1

# c_cxx plugin configuration
$.config.mostlyclean_target := clean
$.config.clean_target := fclean

# Project/target configuration preset
define $(call $.autostrip,$.use_42) =
	$(call $.set,CC,cc)
	$(call $.set,CXX,c++)
	$(call $.set,CFLAGS,-Wall -Wextra -Werror)
	$(call $.set,CXXFLAGS,-Wall -Wextra -Werror -std=c++98)
endef

# Norm-compliant re target
define $(call $.new_template,util)
re: fclean .WAIT all

endef

endif
