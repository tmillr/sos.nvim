.PHONY: test

test:
	nvim \
	  --noplugin \
	  -u tests/min_init.lua \
	  -i NONE \
	  -n \
	  --headless \
	  -c "PlenaryBustedDirectory tests {minimal_init = 'tests/min_init.lua'}"
