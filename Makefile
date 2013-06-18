COFFEE := $(wildcard *.coffee src/**/*.coffee)
JS := $(patsubst src%, lib%, $(COFFEE:.coffee=.js))

.PHONY: all clean prepublish test testem

all: $(JS)

$(JS): $(1)

%.js: %.coffee
	@$(eval input := $<)
	@$(eval output := $@)
	@mkdir -p `dirname $(output)`
	@coffee -pc $(input) > $(output)

lib/%.js: src/%.coffee
	@$(eval input := $<)
	@$(eval output := $@)
	@mkdir -p `dirname $(output)`
	@coffee -pc $(input) > $(output)

clean:
	@rm -f $(JS)

prepublish: clean all

test:
	@mocha --reporter spec test

tap:
	@testem ci

testem:
	@testem
