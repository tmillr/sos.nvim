.PHONY: test perf

define run-test
nvim \
  --noplugin \
  -u tests/min_init.lua \
  -i NONE \
  -n \
  --headless \
  -c "PlenaryBustedDirectory $(or $(DIR),$1) {minimal_init = 'tests/min_init.lua'}"
@printf '\n\033[1mALL TESTS PASSED\033[0m\n'
endef

t test:
	@$(call run-test,tests)

perf:
	@$(call run-test,perf)
