CC      = gcc
CFLAGS  = -Wall -O2 -I.
LIBS    = -lprotobuf-c
PCC		= /usr/bin/protoc
TMUX 	= /usr/bin/tmux

SRC     = protobuf_client.c sensor.pb-c.c
TARGET  = a.out

.PHONY: all proto clean dev

all: proto $(TARGET) dev

proto: $(PCC) proto-python proto-c

proto-c: sensor.proto
	$(PCC) --plugin=protoc-gen-c=$(shell which protoc-gen-c) --c_out=. $^
	
proto-python: sensor.proto venv
	$(PCC) --python_out=. $<
	. ./venv/bin/activate && test -f requirements.txt && pip install -r requirements.txt

venv:
	python3 -m venv $@

$(TARGET): $(SRC)
	$(CC) $(CFLAGS) -o $@ $^ $(LIBS)

# Using APT on Ubuntu.
$(PCC):
	sudo apt install protobuf-compiler protobuf-c-compiler libprotobuf-c-dev

clean:
	rm -f $(TARGET) sensor.pb-c.c sensor.pb-c.h sensor_pb*.python

purge: clean
	rm -rf  venv/

dev: $(TMUX)
	$(TMUX) new-session -d -s Protobuf \; \
		rename-window 'Main' \; \
		select-pane -T 'Server' \; \
		send-keys 'source venv/bin/activate && python3 protobuf_server.py' C-m \; \
		split-window -h \; \
		select-pane -t 1 \; \
		select-pane -T 'Client 1' \; \
		send-keys 'sleep 2 && ./a.out' C-m \; \
		split-window -v \; \
		select-pane -t 2 \; \
		select-pane -T 'Client 2' \; \
		send-keys 'sleep 1 && ./a.out 1>&2' C-m \; \
		select-pane -t 0 \; \
		attach-session -t Protobuf

$(TMUX):
	sudo apt install tmux
