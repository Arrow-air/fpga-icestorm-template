PACKAGE_NAME ?=
BUILD_IMAGE_NAME ?= ghcr.io/arrow-air/tools/arrow-icestorm
BUILD_IMAGE_TAG ?= latest

# 
# Update Environment Variables
# 
ENV_FILE := $(wildcard .env .env.repo)
ifeq ($(ENV_FILE),.env.repo)
$(warning Settings file '.env' missing: '$(ENV_FILE)' => installing .env as merge of .env.base + .env.repo!)
$(shell cat .env.base .env.repo > .env 2>/dev/null)
endif

ENV_KEYS=$(shell grep -Ehv '^\s*(\#.*)?\s*$$' .env.base .env.repo 2>/dev/null | cut -f1 -d= | sort)
$(foreach k, $(ENV_KEYS), $(eval $(shell sh -c "grep -q '^$(k)=' .env 2>/dev/null || (echo '*** NOTE: Adding missing .env key [$(k)] to your .env file!' 1>&2 ; grep -h '^$(k)=' .env.base .env.repo 2>/dev/null >> .env ; grep '^$(k)=' .env 1>&2)")))

-include $(ENV_FILE)

# 
# End of Update Environment Variables
# 

docker_run = docker run --rm \
	--user `id -u`:`id -g` \
	-w /home/$(USER)/project \
	$(ADDITIONAL_OPT) \
	-v $(shell pwd):/home/$(USER)/project \
	-t ${BUILD_IMAGE_NAME}:${BUILD_IMAGE_TAG} \
	$(1) $(2)

yosys: src/hdl/top.vhd build_tree
	@echo "Running yosys synthesis..."
	$(call docker_run,yosys -m ghdl -p "ghdl src/hdl/top.vhd -e ${PACKAGE_NAME}; \
		synth_ice40 -top ${PACKAGE_NAME} -json ./build/artifacts/syn/synth.json")

nextpnr: build/artifacts/syn/synth.json
	@$(echo "Running nextpnr...")
	$(call docker_run,nextpnr-ice40 --hx8k --package cb132 --json ./build/artifacts/syn/synth.json \
		--asc ./build/artifacts/pnr/${PACKAGE_NAME}.asc)

bitstream: ./build/artifacts/pnr/${PACKAGE_NAME}.asc
	@$(echo "Running icepack...")
	$(call docker_run,icepack ./build/artifacts/pnr/${PACKAGE_NAME}.asc ./build/artifacts/bitstream/${PACKAGE_NAME}.bin)

program: bitstream
	@$(echo "Running iceprog...")
	@$(call docker_run,iceprog ./build/artifacts/bitstream/${PACKAGE_NAME}.bin)

all: yosys nextpnr bitstream

clean:
	rm -rf build/

build_tree:
	mkdir -p build
	mkdir -p build/artifacts
	mkdir -p build/artifacts/syn/
	mkdir -p build/artifacts/pnr/
	mkdir -p build/artifacts/bitstream/
	mkdir -p build/logs/
