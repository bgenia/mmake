# C/C++ project plugins

## 42.mk
Configuration preset for ecole 42

### Usage
- `$(var) += $(call $.use_42)`

### Default compiler settings
```
CC=cc
CXX=c++
CFLAGS=-Wall -Wextra -Werror
CXXFLAGS=-Wall -Wextra -Werror -std=c++98
```

### Adding tasks
- re

  Rebuilds project

## 21.mk
Configuration preset for school 21

### Usage
- `$(var) += $(call $.use_21)`

  Uses s21 compilation preset

- `$(var) += $(call $.use_21_check)`

  Properly link check library for both mac and linux

- `$(var) += $(call $.use_21_tests)`

  Generates `test` and `valgrind` tasks for running tests on their own and under valgrind

### Default compiler settings
```
CC=gcc
CXX=g++
CFLAGS=-Wall -Wextra -Werror -std=c11
CXXFLAGS=-Wall -Wextra -Werror -std=c++17
```

### Adding tasks
- verter
  
  Runs verter in docker
- lint

  Runs clang-format --dry-run on project tree
- lint-fix

  Runs clang-format -i on project tree