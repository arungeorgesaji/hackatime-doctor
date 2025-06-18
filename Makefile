CXX := g++
MKDIR := mkdir -p
RM := rm -rf

SRC_DIR := src
INCLUDE_DIR := include
OBJ_DIR := obj
BUILD_DIR := bin
TEST_DIR := tests

SRCS := $(wildcard $(SRC_DIR)/*.cpp)
MAIN_SRC := $(SRC_DIR)/main.cpp
CHECK_SRCS := $(filter-out $(MAIN_SRC), $(SRCS))

OBJS := $(patsubst $(SRC_DIR)/%.cpp,$(OBJ_DIR)/%.o,$(SRCS))
MAIN_OBJ := $(OBJ_DIR)/main.o
CHECK_OBJS := $(filter-out $(MAIN_OBJ), $(OBJS))

DEPS := $(OBJS:.o=.d)

TARGET := $(BUILD_DIR)/hackatime-doctor
TEST_TARGET := $(BUILD_DIR)/hackatime-tests

CXXFLAGS := -std=c++17 -Wall -Wextra -pedantic -I$(INCLUDE_DIR)
DEBUG_FLAGS := -g -O0
RELEASE_FLAGS := -O3 -DNDEBUG

LDFLAGS := -lssl -lcrypto
TEST_LDFLAGS := -lgtest -lgtest_main -lpthread

BUILD_TYPE ?= debug

ifeq ($(BUILD_TYPE),release)
    CXXFLAGS += $(RELEASE_FLAGS)
else
    CXXFLAGS += $(DEBUG_FLAGS)
endif

all: $(TARGET)

$(TARGET): $(OBJS)
	@$(MKDIR) $(@D)
	$(CXX) $(CXXFLAGS) $^ -o $@ $(LDFLAGS)

test: $(TEST_TARGET)
	@$(TEST_TARGET)  

$(TEST_TARGET): $(CHECK_OBJS) $(TEST_DIR)/tests.cpp
	@$(MKDIR) $(@D)
	$(CXX) $(CXXFLAGS) $^ -o $@ $(LDFLAGS) $(TEST_LDFLAGS)

$(OBJ_DIR)/%.o: $(SRC_DIR)/%.cpp
	@$(MKDIR) $(@D)
	$(CXX) $(CXXFLAGS) -MMD -MP -c $< -o $@

-include $(DEPS)

clean:
	$(RM) $(OBJ_DIR) $(BUILD_DIR)

PREFIX ?= /usr/local
BIN_DIR ?= $(PREFIX)/bin

install:
	@echo "Platform-specific installation instructions:"
	@echo ""
	@echo "For Linux/macOS:"
	@echo "  $$ chmod +x install.sh"
	@echo "  $$ ./install.sh [prefix]  # Default: /usr/local"
	@echo ""
	@echo "For Windows (Git Bash/MSYS2):"
	@echo "  $$ chmod +x install.sh"
	@echo "  $$ ./install.sh [install_dir]  # Default: /c/Program Files/hackatime-doctor"
	@echo ""
	@echo "For Windows (PowerShell):"
	@echo "  > Set-ExecutionPolicy RemoteSigned -Scope CurrentUser"
	@echo "  > .\install.ps1 -InstallDir \"C:\Program Files\hackatime-doctor\""
	@echo ""
	@echo "Note: On Windows, you may need administrator privileges"

uninstall:
	@echo "Platform-specific uninstallation instructions:"
	@echo ""
	@echo "For Linux/macOS:"
	@echo "  $$ ./uninstall.sh [prefix]  # Same as installation prefix"
	@echo ""
	@echo "For Windows (Git Bash/MSYS2):"
	@echo "  $$ ./uninstall.sh [install_dir]  # Same as installation directory"
	@echo ""
	@echo "For Windows (PowerShell):"
	@echo "  > .\uninstall.ps1 -InstallDir \"C:\Program Files\hackatime-doctor\""
	@echo ""
	@echo "Note: Remember to use the same path you used during installation"

format:
	find $(SRC_DIR) $(INCLUDE_DIR) -name '*.cpp' -o -name '*.h' | xargs clang-format -i

.PHONY: all clean install uninstall test format
