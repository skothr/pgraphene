#!/usr/bin/make -f

EXEC ?= pgraph
CXX  ?= g++

# local paths
INC_DIR    = inc
SRC_DIR    = src
BUILD_DIR ?= build

# cuda config
CUDA_VERSION ?= 11.6
CUDA_ARCH    ?= sm_75
CUDA_ROOT    ?= /usr/local/cuda-$(CUDA_VERSION)
NVCC         := $(CUDA_ROOT)/bin/nvcc

# determine build type (debug/test/release)
BUILD := release
ifeq ($(filter debug,$(MAKECMDGOALS)),debug)
    BUILD := debug
    CXXFLAGS      := -O0 -DDEBUG -g
    CUDA_CXXFLAGS := -O0 -DDEBUG -g
else ifeq ($(filter test,$(MAKECMDGOALS)),test)
    BUILD := test
    CXXFLAGS      := -O2 -DNDEBUG -g -pg # -ftree-vectorize -mavx -flto
    CUDA_CXXFLAGS := -O2 -DNDEBUG -g -pg # -Xcompiler="-ftree-vectorize" -Xcompiler="-mavx"
else ifeq ($(filter release,$(MAKECMDGOALS)),release)
    BUILD := release
    CXXFLAGS      := -O3 -DNDEBUG -ftree-vectorize -mavx -flto
    CUDA_CXXFLAGS := -O3 -DNDEBUG -Xcompiler="-ftree-vectorize" -Xcompiler="-mavx" -Xptxas="-suppress-stack-size-warning"
endif
OBJ_DIR := $(BUILD_DIR)/$(BUILD)

# c++ flags
CPPFLAGS := -I$(INC_DIR) -I$(INC_DIR)/cuda -MMD -MP
CXXFLAGS += -std=c++2a -fext-numeric-literals
LDFLAGS  := 
LDLIBS   := -pthread -lstdc++fs
# CUDA flags
CUDA_CPPFLAGS := $(CPPFLAGS) -I$(CUDA_ROOT)/include
CUDA_CXXFLAGS += --std=c++17 -arch=$(CUDA_ARCH) --expt-relaxed-constexpr -use_fast_math
CUDA_LDFLAGS  := -L$(CUDA_ROOT)/lib64
CUDA_LDLIBS   := -lcuda -lcudart

# c++ source files
SOURCES = $(wildcard $(SRC_DIR)/*.cpp)
HEADERS = $(wildcard $(INC_DIR)/*.h*)
OBJS    = $(SOURCES:$(SRC_DIR)/%.cpp=$(OBJ_DIR)/%.cpp.o)
DEPS    = $(OBJS:%.o=%.d)
# cuda source files
CUDA_SOURCES = $(wildcard $(SRC_DIR)/cuda/*.cu)
CUDA_HEADERS = $(wildcard $(INC_DIR)/cuda/*.*h) # (*.h / *.cuh)
CUDA_OBJS    = $(CUDA_SOURCES:$(SRC_DIR)/cuda/%.cu=$(OBJ_DIR)/cuda/%.cu.o)
CUDA_DEPS    = $(CUDA_OBJS:%.o=%.d)


# targets
.PHONY: all clean check prep

all: release
debug test release: $(EXEC)
clean:
	@rm -rf $(EXEC) $(BUILD_DIR)

check: # print variable contents
	$(info )
	$(info BUILD:        $(BUILD))
	$(info OBJ_DIR:      $(OBJ_DIR))
	$(info )
	$(info SOURCES:      $(SOURCES))
	$(info HEADERS:      $(HEADERS))
	$(info OBJS:         $(OBJS))
	$(info DEPS:         $(DEPS))
	$(info )
	$(info CUDA_SOURCES: $(CUDA_SOURCES))
	$(info CUDA_HEADERS: $(CUDA_HEADERS))
	$(info CUDA_OBJS:    $(CUDA_OBJS))
	$(info CUDA_DEPS:    $(CUDA_DEPS))
	$(info )

# build directories
$(OBJ_DIR):
	mkdir -p $(OBJ_DIR)
$(OBJ_DIR)/cuda:
	mkdir -p $(OBJ_DIR)/cuda

# main executable
$(EXEC): $(OBJS) $(CUDA_OBJS)
	$(CXX) $(LDFLAGS) $(CUDA_LDFLAGS) $^ $(LDLIBS) $(CUDA_LDLIBS) -o $@

# [cpp --> cpp.o]
$(OBJ_DIR)/%.cpp.o: $(SRC_DIR)/%.cpp $(HEADERS) | $(OBJ_DIR)
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -c $< -o $@

# [cu --> cu.o]
$(OBJ_DIR)/cuda/%.cu.o: $(SRC_DIR)/cuda/%.cu $(CUDA_HEADERS) | $(OBJ_DIR)/cuda
	$(NVCC) $(CUDA_CPPFLAGS) $(CUDA_CXXFLAGS) -c $< -o $@

# clean build if Makefile has changed
-include Makefile.meta
Makefile.meta: Makefile
	@touch $@
	make clean

# include dependencies
-include $(DEPS)
-include $(CUDA_DEPS)
