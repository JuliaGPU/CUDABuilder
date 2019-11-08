SHELL:=/bin/bash

VERSIONS := 9.0.176 9.2.148 10.0.130 10.1.243
TARGETS  := x86_64-linux-gnu x86_64-apple-darwin14 x86_64-w64-mingw32

EXT = tar.gz
PRODUCTS := $(foreach VERSION,$(VERSIONS),$(foreach TARGET,$(TARGETS),CUDA.v$(VERSION).$(TARGET).$(EXT)))

.PHONY: all
all: $(addprefix products/,$(PRODUCTS))

# access parts of a string separated by dots
word-dot = $(word $2,$(subst ., ,$1))

products:
	mkdir products

products/CUDA.v%.$(EXT): build_tarballs.jl | products
	BINARYBUILDER_AUTOMATIC_APPLE=true \
	julia --project $^ \
		  $(call word-dot,$*,4) \
	      --version=$(call word-dot,$*,1).$(call word-dot,$*,2) \
		  --verbose &> build/CUDA.v$*.log

.PHONY: clean
clean:
	$(RM) -r build

.PHONY: distclean
distclean: clean
	$(RM) -r products
