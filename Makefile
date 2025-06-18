CXX := g++
MKDIR := mkdir -p
RM := rm -rf
DATE := date +"%Y-%m-%d %H:%M:%S %Z"

SRC_DIR := src
INCLUDE_DIR := include
OBJ_DIR := obj
BUILD_DIR := bin
TEST_DIR := tests
DIST_DIR := dist

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

VERSION ?= $(shell git describe --tags --always --dirty 2>/dev/null || echo "dev")
ARCH ?= $(shell uname -m)
OS ?= $(shell uname -s)

ifeq ($(OS),Windows_NT)
    PLATFORM := windows
    BINARY_EXT := .exe
    ARCHIVE_EXT := .zip
    WINDRES := windres
    LDFLAGS += -lws2_32 -lcrypt32 -static
    CXXFLAGS += -DWIN32_LEAN_AND_MEAN -D_WIN32_WINNT=0x0601
else
    PLATFORM := unix
    BINARY_EXT := 
    ARCHIVE_EXT := .tar.gz
endif

RELEASE_NAME := hackatime-doctor-$(VERSION)-$(PLATFORM)-$(ARCH)
RELEASE_DIR := $(DIST_DIR)/$(RELEASE_NAME)
RELEASE_FILES := README.md LICENSE CHANGELOG.md install.sh uninstall.sh install.ps1 uninstall.ps1

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

windows-build:
	$(MAKE) CXX=x86_64-w64-mingw32-g++ \
		PLATFORM=windows \
		TARGET=$(BUILD_DIR)/hackatime-doctor.exe \
		LDFLAGS="-static -lssl -lcrypto -lws2_32 -lcrypt32" \
		CXXFLAGS="$(CXXFLAGS) -DWIN32_LEAN_AND_MEAN -D_WIN32_WINNT=0x0601" \
		all

macos-build:
	$(MAKE) CXX=o64-clang++ \
		PLATFORM=macos \
		TARGET=$(BUILD_DIR)/hackatime-doctor-macos \
		all

release: BUILD_TYPE=release
release: clean $(TARGET) package

package: package-$(PLATFORM)

package-windows: $(TARGET)
	@echo "Packaging Windows release..."
	@$(MKDIR) "$(RELEASE_DIR)"
	@cp "$(TARGET)$(BINARY_EXT)" "$(RELEASE_DIR)/"
	@for file in $(RELEASE_FILES); do \
		if [ -f "$$file" ]; then cp "$$file" "$(RELEASE_DIR)/"; fi; \
	done
	@echo "hackatime-doctor $(VERSION)" > "$(RELEASE_DIR)/VERSION"
	@echo "Built on: $$($(DATE))" >> "$(RELEASE_DIR)/VERSION"
	@echo "Platform: $(PLATFORM)-$(ARCH)" >> "$(RELEASE_DIR)/VERSION"
	@(cd "$(DIST_DIR)" && zip -r "$(RELEASE_NAME).zip" "$(RELEASE_NAME)")
	@echo "Created: $(DIST_DIR)/$(RELEASE_NAME).zip"

package-unix: $(TARGET)
	@echo "Packaging Unix release..."
	@$(MKDIR) "$(RELEASE_DIR)"
	@cp "$(TARGET)" "$(RELEASE_DIR)/"
	@for file in $(RELEASE_FILES); do \
		if [ -f "$$file" ]; then \
			cp "$$file" "$(RELEASE_DIR)/"; \
			[ "$${file##*.}" = "sh" ] && chmod +x "$(RELEASE_DIR)/$$file"; \
		fi; \
	done
	@echo "hackatime-doctor $(VERSION)" > "$(RELEASE_DIR)/VERSION"
	@echo "Built on: $$($(DATE))" >> "$(RELEASE_DIR)/VERSION"
	@echo "Platform: $(PLATFORM)-$(ARCH)" >> "$(RELEASE_DIR)/VERSION"
	@(cd "$(DIST_DIR)" && tar -czf "$(RELEASE_NAME).tar.gz" "$(RELEASE_NAME)")
	@echo "Created: $(DIST_DIR)/$(RELEASE_NAME).tar.gz"

release-all: release-linux release-windows release-macos

release-linux:
	@echo "Building Linux release..."
	@$(MAKE) BUILD_TYPE=release PLATFORM=linux ARCH=x86_64 clean $(TARGET) package-unix

release-windows:
	@echo "Building Windows release..."
	@$(MAKE) windows-build package-windows

release-macos:
	@echo "Building macOS release..."
	@if command -v o64-clang++ >/dev/null 2>&1; then \
		$(MAKE) macos-build package-unix; \
	else \
		echo "Error: osxcross not found. Install with: brew install osxcross"; \
		exit 1; \
	fi

install:
	@echo "Run platform-specific installer:"
	@echo "  Unix(Linux/Mac/WSL): ./install.sh"
	@echo "  Windows: ./install.ps1"

uninstall:
	@echo "Run platform-specific uninstaller:"
	@echo "  Unix(Linux/Mac/WSL): ./uninstall.sh"
	@echo "  Windows: ./uninstall.ps1"

format:
	find $(SRC_DIR) $(INCLUDE_DIR) -name '*.cpp' -o -name '*.h' | xargs clang-format -i

clean:
	$(RM) $(OBJ_DIR) $(BUILD_DIR)

clean-all: clean
	$(RM) $(DIST_DIR)

.PHONY: all test clean clean-all install uninstall format \
        release package package-windows package-unix \
        release-all release-linux release-windows release-macos \
        windows-build macos-build
