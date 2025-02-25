# Copyright 2025 EPFL
# SPDX-License-Identifier: Apache-2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Author: David Mallasén <david.mallasen@epfl.ch>
# Description: XIF coprocessor top-level makefile

MAKE = make

all: help

sim:
	fusesoc --cores-root . run --no-export --target=sim $(FUSESOC_FLAGS) --setup --build esl-epfl:ip:xif_copro:0.0.1 2>&1 | tee build_sim.log

sim-opt: sim
	$(MAKE) -C build/esl-epfl_ip_xif_copro_0.0.1/sim-modelsim opt

synth:
	fusesoc --cores-root . run --no-export --target=synth $(FUSESOC_FLAGS) --setup --build esl-epfl:ip:xif_copro:0.0.1 2>&1 | tee build_synth-pynq-z2.log

clean:
	rm -rf build

help:
	@echo "[WIP] See the Makefile for options"
