all: register_file

MODULES = ./register_file.v

SOURCES = ./register_file_tb.v

register_file: $(MODULES) $(SOURCES)
	iverilog -I ./ -s register_file_tb -o $@ $^

clean:
	rm -f register_file *.vcd
