# Variables:
#     DIR:         path to dir or file to test (default: all of target's files/tests)
#     SEQ/SYNC:    if set, run tests sequentially (default: true for benchmarks, otherwise false)

.PHONY: test t fmt format perf bench checkfmt

# because ifdef considers empty vars unset...
ifneq "$(origin SEQ)" "undefined"
    SEQ ::= true
else ifneq "$(origin SYNC)" "undefined"
    SEQ ::= true
else
    SEQ ::= false
endif

define run-test
    nvim -v
    nvim \
      --noplugin \
      -u tests/min_init.lua \
      -i NONE \
      -n \
      --headless \
      -c "PlenaryBustedDirectory $(DIR) {sequential = $(SEQ), minimal_init = 'tests/min_init.lua'}"
    @printf '\n\033[1mALL TESTS PASSED\033[0m\n'
endef

t test: DIR ::= $(or $(DIR),tests)
t test:
	@$(run-test)

fmt format:
	stylua .

checkfmt:
	stylua -c .

perf bench: DIR ::= $(or $(DIR),perf)
perf bench: override SEQ ::= true
perf bench:
	@$(run-test)
