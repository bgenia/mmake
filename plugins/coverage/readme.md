## Examples

### Building target with `gcov_report` plugin

`Makefile.mk`

```Makefile
include mmake/core.mk
include mmake/plugins/c_cxx.mk
include mmake/plugins/coverage/gcov_report.mk

tests := $(call $.new_executable,test,$(wildcard tests/*.c))
$(tests) += $(call $.add_target_dependency,$(library)) # Some library dependency
$(tests) += $(call $.add_linked_libraries,-lcheck -lsubunit -lm $(call $.get,$(library),name))

tests_coverage := $(call $.new_variant,$(tests),tests_coverage)
# Any extra argument can be added to generate `gcov_report` task referred to `gcov_report_tests_coverage` in that case
$(tests_coverage) += $(call $.use_gcov_report,$(tests_coverage))
```

Generated gcov task for config above

```Makefile
gcov_report_tests_coverage:
> ./tests_coverage
> lcov -o tests_coverage.info -c -d .
> genhtml -o report tests_coverage.info
```

Generated gcov_report task for config above if extra argument specified

```Makefile
gcov_report: gcov_report_tests_coverage
```

## Adding this to cleanup list `*.gcno *.gcda *.info *.gcov -r report`