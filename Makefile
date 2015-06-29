
include Makefile.config

TOOLCHAIN = $(HOST_ARCH)-4.9
TARGET_OCAML_ARCH = $(TARGET_ARCH)

ifeq ($(ABI),gnueabihf)
  HOST_ARCH = arm-linux-gnueabihf
  TARGET_ARCH = arm
  TARGET_MODEL = armv7
  TARGET_SYSTEM = linux_eabihf
else ifeq ($(ABI),armeabi-v7a)
  HOST_ARCH = arm-linux-androideabi
  TARGET_ARCH = arm
  TARGET_MODEL = armv7
  TARGET_SYSTEM = linux_eabihf
else ifeq ($(ABI),armeabi)
  HOST_ARCH = arm-linux-androideabi
  TARGET_ARCH = arm
  TARGET_MODEL = armv5te
  TARGET_SYSTEM = linux_eabi
else ifeq ($(ABI),x86)
  HOST_ARCH = i686-linux-android
  TOOLCHAIN = x86-4.8
  TARGET_ARCH = x86
  TARGET_OCAML_ARCH = i386
  TARGET_MODEL = default
  TARGET_SYSTEM = linux_elf
else
  $(error Unknown ABI: $(ABI))
endif

ifeq ($(ABI),gnueabihf)
  TARGET_CFLAGS = -march=armv7-a -mfpu=vfpv3-d16 -mhard-float -I/usr/arm-linux-gnueabihf/include
  TARGET_LDFLAGS = -march=armv7-a -Wl,--fix-cortex-a8 -Wl,--no-warn-mismatch
  TARGET_MATHLIB = -lm
else ifeq ($(ABI),armeabi-v7a)
  TARGET_CFLAGS = -march=armv7-a -mfpu=vfpv3-d16 -mhard-float
  TARGET_LDFLAGS = -march=armv7-a -Wl,--fix-cortex-a8 -Wl,--no-warn-mismatch
  TARGET_MATHLIB = -lm_hard
else
  TARGET_CFLAGS =
  TARGET_LDFLAGS =
  TARGET_MATHLIB = -lm
endif

SRC = ocaml-src

ARCH=$(shell uname | tr A-Z a-z)

CORE_OTHER_LIBS = unix str num dynlink
STDLIB=$(shell $(TARGET_BINDIR)/ocamlc -config | \
               sed -n 's/standard_library: \(.*\)/\1/p')

all: stamp-install

stamp-install: stamp-build
# Install the compiler
	cd $(SRC) && make install
# Put links to binaries in $TARGET_BINDIR
	rm -f $(TARGET_BINDIR)/$(HOST_ARCH)/ocamlbuild
	rm -f $(TARGET_BINDIR)/$(HOST_ARCH)/ocamlbuild.byte
	for i in $(TARGET_BINDIR)/$(HOST_ARCH)/*; do \
	  ln -sf $$i $(TARGET_BINDIR)/$(HOST_ARCH)-`basename $$i`; \
	done
# Install the target ocamlrun binary
	mkdir -p $(TARGET_PREFIX)/bin
	cd $(SRC) && \
	cp byterun/ocamlrun.target $(TARGET_PREFIX)/bin/ocamlrun
# Add a link to camlp4 libraries
	rm -rf $(TARGET_PREFIX)/lib/ocaml/camlp4
	ln -sf $(STDLIB)/camlp4 $(TARGET_PREFIX)/lib/ocaml/camlp4
	touch stamp-install

stamp-build: stamp-runtime
# Restore the ocamlrun binary for the local machine
	cd $(SRC) && cp byterun/ocamlrun.local byterun/ocamlrun
# Compile the libraries for target
	cd $(SRC) && make coreall opt-core otherlibraries otherlibrariesopt
	cd $(SRC) && make ocamltoolsopt
	touch stamp-build

stamp-runtime: stamp-prepare
# Recompile the runtime for target
	cd $(SRC) && make -C byterun all
# Save the ARM ocamlrun binary
	cd $(SRC) && cp byterun/ocamlrun byterun/ocamlrun.target
	touch stamp-runtime

stamp-prepare: stamp-core
# Update configuration files
	set -e; cd config; for f in *; do \
	  sed -e 's%TARGET_NDK%$(TARGET_NDK)%' \
	      -e 's%TARGET_PATH%$(TARGET_TOOLCHAIN_PATH)%g' \
	      -e 's%TARGET_PREFIX%$(TARGET_PREFIX)%g' \
	      -e 's%TARGET_BINDIR%$(TARGET_BINDIR)%g' \
	      -e 's%OCAML_SRC%$(OCAML_SRC)%g' \
	      -e 's%HOST_ARCH%$(HOST_ARCH)%g' \
	      -e 's%TARGET_CFLAGS%$(TARGET_CFLAGS)%g' \
	      -e 's%TARGET_LDFLAGS%$(TARGET_LDFLAGS)%g' \
	      -e 's%TARGET_MATHLIB%$(TARGET_MATHLIB)%g' \
	      -e 's%TARGET_ARCH%$(TARGET_ARCH)%g' \
	      -e 's%TARGET_OCAML_ARCH%$(TARGET_OCAML_ARCH)%g' \
	      -e 's%TARGET_MODEL%$(TARGET_MODEL)%g' \
	      -e 's%TARGET_SYSTEM%$(TARGET_SYSTEM)%g' \
	      -e 's%TARGET_PLATFORM%$(TARGET_PLATFORM)%g' \
	      $$f > ../$(SRC)/config/$$f; \
	done
# Apply patches
	set -e; for p in patches/*.txt; do \
	(cd $(SRC) && patch -p 0 < ../$$p); \
	done
# Save the ocamlrun binary for the local machine
	cd $(SRC) && cp byterun/ocamlrun byterun/ocamlrun.local
# Clean-up runtime and libraries
	cd $(SRC) && make -C byterun clean
	cd $(SRC) && make -C stdlib clean
	set -e; cd $(SRC) && \
	for i in $(CORE_OTHER_LIBS); do \
	  make -C otherlibs/$$i clean; \
	done
	touch stamp-prepare

stamp-core: stamp-configure
# Build the bytecode compiler and other core tools
	cd $(SRC) && \
	make OTHERLIBRARIES="$(CORE_OTHER_LIBS)" BNG_ASM_LEVEL=0 world
	touch stamp-core

stamp-configure: stamp-copy
# Configuration...
	cd $(SRC) && \
	./configure -prefix $(TARGET_PREFIX) \
		-bindir $(TARGET_BINDIR)/$(HOST_ARCH) \
	        -mandir $(shell pwd)/no-man \
		-cc "gcc -m32" -as "gcc -m32 -c" -aspp "gcc -m32 -c" \
		-no-pthread
	sed -i s/CAMLP4=camlp4/CAMLP4=/ $(SRC)/config/Makefile
	touch stamp-configure

stamp-copy:
# Copy the source code
	@if ! [ -d $(OCAML_SRC)/byterun ]; then \
	  echo Error: OCaml sources not found. Check OCAML_SRC variable.; \
	  exit 1; \
	fi
	@if ! [ -d $(TARGET_TOOLCHAIN_PATH) ]; then \
	  echo Error: Android NDK not found. Check TARGET_NDK variable.; \
	  exit 1; \
	fi
	@if ! [ -f $(TARGET_BINDIR)/ocamlc ]; then \
	  echo Error: $(TARGET_BINDIR)/ocamlc not found. \
	    Check TARGET_BINDIR variable.; \
	  exit 1; \
	fi
	cp -a $(OCAML_SRC) $(SRC)
	touch stamp-copy

clean:
	rm -rf $(SRC) stamp-*
