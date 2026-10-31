CXX ?= g++
CXXFLAGS ?= -O3 -Wall -Wextra -std=c++17
SDK_PATH ?= $(HOME)/sdk

INCLUDES = -Isrc -I$(SDK_PATH)/sdk/include -I$(SDK_PATH)/sdk/src
LDFLAGS = -L$(SDK_PATH)/output/Linux/Release -lsl_lidar_sdk -lpthread

TARGET = lidar_bridge
SOURCES = src/main.cpp

all: $(TARGET)

$(TARGET): $(SOURCES)
	$(CXX) $(CXXFLAGS) $(INCLUDES) -o $@ $(SOURCES) $(LDFLAGS)

clean:
	rm -f $(TARGET)

.PHONY: all clean
