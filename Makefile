CC      = gcc
CFLAGS  = -Wall -O2 -I.
LIBS    = -lprotobuf-c

SRC     = protobuf_client.c sensor.pb-c.c
TARGET  = a.out

.PHONY: all proto clean

all: proto $(TARGET)

proto:
	protoc --plugin=protoc-gen-c=$$(which protoc-gen-c) --c_out=. sensor.proto
	protoc --python_out=. sensor.proto

$(TARGET): $(SRC)
	$(CC) $(CFLAGS) -o $@ $^ $(LIBS)

clean:
	rm -f $(TARGET) sensor.pb-c.c sensor.pb-c.h sensor_pb*.py