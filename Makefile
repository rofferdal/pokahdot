GODOT ?= godot
GDLINT := .venv/bin/gdlint
GDFORMAT := .venv/bin/gdformat
GUT_COMMAND := $(GODOT) --headless --path . -s addons/gut/gut_cmdln.gd
WEB_EXPORT_PATH := build/web/index.html
WEB_OUTPUT_DIR := $(dir $(WEB_EXPORT_PATH))

.PHONY: check profile-evolution-test web-release verify-web-release-output require-clean-worktree

check:
	$(MAKE) --no-print-directory profile-evolution-test
	$(GODOT) --headless --path . --import
	$(GDLINT) scripts tests my_test_node.gd
	$(GDFORMAT) --check scripts tests my_test_node.gd
	$(GUT_COMMAND)

profile-evolution-test:
	python3 -m unittest discover -s tests/profile_evolution -t . -v

require-clean-worktree:
	@test -z "$$(git status --porcelain)" || { \
		echo "Release build refused: commit or discard all working-tree changes first."; \
		git status --short; \
		exit 1; \
	}

web-release: require-clean-worktree
	$(MAKE) --no-print-directory check
	$(MAKE) --no-print-directory require-clean-worktree
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
	@! find $(WEB_OUTPUT_DIR) -type d \( -name addons -o -name tests \) -print -quit | grep -q . || { \
		echo "Release output must not include development addons or tests."; \
		exit 1; \
	}
	@! strings $(WEB_OUTPUT_DIR)index.pck | grep -Eq '(^|/)(addons|tests)/' || { \
		echo "Release game pack must not include development addons or tests."; \
		exit 1; \
	}
	@echo "Verified Web release output in $(WEB_OUTPUT_DIR)."
