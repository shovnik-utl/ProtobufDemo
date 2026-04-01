CC      = gcc
CFLAGS  = -Wall -O2 -I.
LIBS    = -lprotobuf-c

SRC     = protobuf_client.c sensor.pb-c.c
TARGET  = a.out

.PHONY: all proto clean

all: proto $(TARGET) dev

proto: proto-python proto-c

proto-c: sensor.proto
	protoc --plugin=protoc-gen-c=$(shell which protoc-gen-c) --c_out=. $^
	
proto-python: sensor.proto venv
	protoc --python_out=. $<
	. ./venv/bin/activate && test -f requirements.txt && pip install -r requirements.txt

venv:
	python3 -m venv $@

$(TARGET): $(SRC)
	$(CC) $(CFLAGS) -o $@ $^ $(LIBS)

.PHONY: clean dev

clean:
	rm -f $(TARGET) sensor.pb-c.c sensor.pb-c.h sensor_pb*.python

purge: clean
	rm -rf  venv/

dev:
	tmux new-session -d -s mysession \; \
		rename-window 'Server' \; \
		send-keys 'source venv/bin/activate && python3 protobuf_server.py' C-m \; \
		split-window -h \; \
		select-pane -t 1 \; \
		rename-window 'Client' \; \
		send-keys 'sleep 2 && ./a.out' C-m \; \
		select-pane -t 0 \; \
		attach-session -t mysession