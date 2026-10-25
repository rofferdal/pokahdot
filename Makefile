GODOT ?= godot
GDLINT := .venv/bin/gdlint
GDFORMAT := .venv/bin/gdformat
GUT_COMMAND := $(GODOT) --headless --path . -s addons/gut/gut_cmdln.gd
WEB_EXPORT_PATH := build/web/index.html
WEB_OUTPUT_DIR := $(dir $(WEB_EXPORT_PATH))

.PHONY: check profile-evolution-test gui-visual-invariant-gate gui-phone-invariant-gate gui-ipad-invariant-gate release-candidate-gate gui-visual-capture gui-visual-capture-development gui-phone-capture-development gui-visual-capture-smoke web-release verify-web-release-output require-clean-worktree

check:
	$(MAKE) --no-print-directory profile-evolution-test
	$(GODOT) --headless --path . --import
	$(GDLINT) scripts tests my_test_node.gd
	$(GDFORMAT) --check scripts tests my_test_node.gd
	$(GUT_COMMAND)

profile-evolution-test:
	python3 -B -m unittest discover -s tests/profile_evolution -t . -v

gui-visual-invariant-gate:
	$(GUT_COMMAND) -gconfig= -gtest=res://tests/manual/gui_invariant_matrix_runner.gd -gexit

gui-phone-invariant-gate:
	$(GUT_COMMAND) -gconfig= -gtest=res://tests/manual/gui_phone_invariant_matrix_runner.gd -gexit

gui-ipad-invariant-gate:
	$(GUT_COMMAND) -gconfig= -gtest=res://tests/manual/gui_ipad_invariant_matrix_runner.gd -gexit

release-candidate-gate:
	$(MAKE) --no-print-directory require-clean-worktree
	$(MAKE) --no-print-directory check
	$(MAKE) --no-print-directory gui-visual-invariant-gate
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
