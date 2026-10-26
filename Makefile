GODOT ?= godot
WEB_TEST_PYTHON ?= .venv/bin/python
WEB_TEST_OUTPUT ?= localtmp/web-input
WEB_LAN_PYTHON ?= python3
WEB_LAN_OUTPUT ?= localtmp/web-lan
WEB_LAN_BIND ?= 0.0.0.0
WEB_LAN_PORT ?= 8080
WEB_LAN_CA_PORT ?= 8081
WEB_LAN_ADDRESS ?=
GDLINT := .venv/bin/gdlint
GDFORMAT := .venv/bin/gdformat
GUT_COMMAND := $(GODOT) --headless --path . -s addons/gut/gut_cmdln.gd
WEB_EXPORT_PATH := build/web/index.html
WEB_OUTPUT_DIR := $(dir $(WEB_EXPORT_PATH))

.PHONY: check profile-evolution-test gui-visual-invariant-gate gui-phone-invariant-gate gui-ipad-invariant-gate gui-desktop-invariant-gate gui-current-invariant-gate release-candidate-gate gui-visual-capture gui-visual-capture-development gui-phone-capture-development gui-visual-capture-smoke web-release verify-web-release-output require-clean-worktree

check:
	$(MAKE) --no-print-directory profile-evolution-test
	$(MAKE) --no-print-directory web-lan-test
	$(GODOT) --headless --path . --import
	$(GDLINT) scripts tests my_test_node.gd
	$(GDFORMAT) --check scripts tests my_test_node.gd
	$(GUT_COMMAND)

profile-evolution-test:
	python3 -B -m unittest discover -s tests/profile_evolution -t . -v

.PHONY: web-lan-build web-lan-rebuild web-lan-test web-lan-serve web-lan-status web-lan-stop web-lan-network web-lan-tls web-lan-ca-serve
web-lan-build:
	$(WEB_LAN_PYTHON) tools/web-lan build --godot "$(GODOT)" --output "$(WEB_LAN_OUTPUT)"

web-lan-rebuild: web-lan-build

web-lan-serve:
	$(WEB_LAN_PYTHON) tools/web-lan serve --output "$(WEB_LAN_OUTPUT)" --bind "$(WEB_LAN_BIND)" --port "$(WEB_LAN_PORT)"

web-lan-status:
	$(WEB_LAN_PYTHON) tools/web-lan status --output "$(WEB_LAN_OUTPUT)"

web-lan-stop:
	$(WEB_LAN_PYTHON) tools/web-lan stop --output "$(WEB_LAN_OUTPUT)"

web-lan-network:
	$(WEB_LAN_PYTHON) tools/web-lan network

web-lan-tls:
	@test -n "$(WEB_LAN_ADDRESS)" || { echo "Set WEB_LAN_ADDRESS to the Wi-Fi IPv4 address shown by web-lan-network."; exit 1; }
	$(WEB_LAN_PYTHON) tools/web-lan tls-init --output "$(WEB_LAN_OUTPUT)" --address "$(WEB_LAN_ADDRESS)"

web-lan-ca-serve:
	$(WEB_LAN_PYTHON) -m http.server "$(WEB_LAN_CA_PORT)" --bind "$(WEB_LAN_BIND)" --directory "$(WEB_LAN_OUTPUT)/tls/public"

web-lan-test:
	$(WEB_LAN_PYTHON) -B -m unittest discover -s tests/web_lan -t . -v

.PHONY: web-input-test
web-input-test:
	$(WEB_TEST_PYTHON) tools/run_web_input_tests.py --godot "$(GODOT)" --output "$(WEB_TEST_OUTPUT)"

gui-visual-invariant-gate:
	$(GUT_COMMAND) -gconfig= -gtest=res://tests/manual/gui_invariant_matrix_runner.gd -gexit

gui-phone-invariant-gate:
	$(GUT_COMMAND) -gconfig= -gtest=res://tests/manual/gui_phone_invariant_matrix_runner.gd -gexit

gui-ipad-invariant-gate:
	$(GUT_COMMAND) -gconfig= -gtest=res://tests/manual/gui_ipad_invariant_matrix_runner.gd -gexit

gui-desktop-invariant-gate:
	$(GUT_COMMAND) -gconfig= -gtest=res://tests/manual/gui_desktop_invariant_matrix_runner.gd -gexit

gui-current-invariant-gate:
	$(MAKE) --no-print-directory gui-visual-invariant-gate
	$(MAKE) --no-print-directory gui-phone-invariant-gate
	$(MAKE) --no-print-directory gui-ipad-invariant-gate
	$(MAKE) --no-print-directory gui-desktop-invariant-gate

release-candidate-gate:
	$(MAKE) --no-print-directory require-clean-worktree
	$(MAKE) --no-print-directory check
	$(MAKE) --no-print-directory gui-current-invariant-gate
	$(MAKE) --no-print-directory require-clean-worktree

gui-visual-capture: release-candidate-gate
	$(GODOT) --path . --rendering-method gl_compatibility --rendering-driver opengl3 --audio-driver Dummy --script tests/visual/gui_visual_capture_runner.gd -- --full-m3

gui-visual-capture-development:
	$(GODOT) --path . --rendering-method gl_compatibility --rendering-driver opengl3 --audio-driver Dummy --script tests/visual/gui_visual_capture_runner.gd -- --full-m3 --development

gui-phone-capture-development:
	$(GODOT) --path . --rendering-method gl_compatibility --rendering-driver opengl3 --audio-driver Dummy --script tests/visual/gui_visual_capture_runner.gd -- --full-phone --development

gui-visual-capture-smoke:
	$(GODOT) --path . --rendering-method gl_compatibility --rendering-driver opengl3 --audio-driver Dummy --script tests/visual/gui_visual_capture_runner.gd -- --viewport desktop_1280x720 --state human-turn-preflop --player-count 6 --development

require-clean-worktree:
	@test -z "$$(git status --porcelain)" || { \
		echo "Release build refused: commit or discard all working-tree changes first."; \
		git status --short; \
		exit 1; \
	}

web-release: release-candidate-gate
	mkdir -p $(WEB_OUTPUT_DIR)
	$(GODOT) --headless --path . --export-release "Web" $(WEB_EXPORT_PATH)
	$(MAKE) --no-print-directory verify-web-release-output

verify-web-release-output:
	@test -f $(WEB_EXPORT_PATH) || { echo "Missing $(WEB_EXPORT_PATH)."; exit 1; }
	@for file in $$(grep -oE '(src|href)="[^"]+"' $(WEB_EXPORT_PATH) | sed -E 's/^[a-z]+="([^"]+)"/\1/' | grep -Ev '^(https?:|//|#|data:)' || true); do \
		test -f "$(WEB_OUTPUT_DIR)$$file" || { echo "Missing HTML-referenced release file: $$file"; exit 1; }; \
	done
	@for extension in js wasm pck; do \
		find $(WEB_OUTPUT_DIR) -maxdepth 1 -type f -name "*.$$extension" -print -quit | grep -q . || { \
			echo "Missing exported Web *.$$extension payload."; \
			exit 1; \
		}; \
	done
	@! find $(WEB_OUTPUT_DIR) -type d \( -name addons -o -name tests -o -name localtmp -o -name artifacts \) -print -quit | grep -q . || { \
		echo "Release output must not include development-only directories."; \
		exit 1; \
	}
	@! strings $(WEB_OUTPUT_DIR)index.pck | grep -Eq '(^|/)(addons|tests|localtmp|artifacts)/' || { \
		echo "Release game pack must not include development-only directories."; \
		exit 1; \
	}
	@echo "Verified Web release output in $(WEB_OUTPUT_DIR)."
