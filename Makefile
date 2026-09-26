.PHONY: setup check release-check stage

setup:
	npm ci --ignore-scripts --prefix scripts

check:
	bash scripts/check-release.sh

release-check:
	bash scripts/check-release.sh --live

stage:
	bash scripts/sync-tapper.sh
	bash scripts/stage-site.sh
