# Include the nanopb provided Makefile rules.

include nanopb/extra/nanopb.mk

CC      = gcc
CFLAGS  = -Wall -O2 -I.
CFLAGS  += "-I$(NANOPB_DIR)"

# The proto file to be compiled (input "_I"), and output c file ("_O").
SCHEMA	= sensor
PROTO_I = $(SCHEMA).proto
PROTO_O = $(SCHEMA).pb

PCC		= /usr/bin/protoc
TMUX 	= /usr/bin/tmux

SRC     = protobuf_client.c
SRC    += $(PROTO_O).c
SRC    += $(NANOPB_DIR)/pb_encode.c  	# The nanopb encoder.
SRC    += $(NANOPB_DIR)/pb_decode.c  	# The nanopb decoder.
SRC    += $(NANOPB_DIR)/pb_common.c     # The nanopb common parts.
TARGET  = a.out

.PHONY: all proto proto-python clean dev

all: proto $(TARGET) dev

proto: $(PCC) proto-python

$(PROTO_O).c: $(PROTO_I) venv
	$(PCC) --plugin=protoc-gen-nanopb=./venv/bin/protoc-gen-nanopb --nanopb_out=. $<
	
proto-python: $(PROTO_I) venv
	$(PCC) --python_out=. $<

# Create the virtual environment and install dependencies.
venv: requirements.txt
	python3 -m venv $@
	./venv/bin/pip install -r requirements.txt

$(TARGET): $(SRC)
	$(CC) $(CFLAGS) -o $@ $^

# Using APT on Ubuntu.
$(PCC):
	sudo apt install protobuf-compiler protobuf-c-compiler libprotobuf-c-dev

clean:
	rm -f $(TARGET) $(PROTO_O).c $(PROTO_O).h

purge: clean
	rm -rf  venv/

dev: $(TMUX)
	$(TMUX) kill-session -t Protobuf 2>/dev/null || echo "Replacing running TMUX session."
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
