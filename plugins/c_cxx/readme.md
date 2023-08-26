# C/C++ project plugins

## 42.mk
Configuration preset for ecole 42

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