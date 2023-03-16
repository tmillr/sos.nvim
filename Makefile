.PHONY: test perf

define run-test
nvim \
  --noplugin \
  -u tests/min_init.lua \
  -i NONE \
  -n \
  --headless \
  -c "PlenaryBustedDirectory $(or $(DIR),$1) {minimal_init = 'tests/min_init.lua'}"
@printf '\n%s\n' 'ALL TESTS PASSED'
endef

t test:
	@$(call run-test,tests)

perf:
	@$(call run-test,perf)
