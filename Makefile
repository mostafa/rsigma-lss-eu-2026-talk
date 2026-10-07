SHELL := /usr/bin/env bash

.PHONY: check record render replay vm vm-shell vm-snapshot vm-stop

check:
	shellcheck demo/*.sh demo/vm/*.sh demo/attack/*.sh
	bash -n demo/*.sh demo/vm/*.sh demo/attack/*.sh
	python3 -m py_compile demo/adapters/auditd/normalize.py demo/adapters/tetragon/normalize.py demo/attack/tcp_listener.py
	./demo/fetch-rsigma.sh
	demo/.state/bin/rsigma rule lint demo/rules
	demo/.state/bin/rsigma rule validate demo/rules
	./demo/run.sh --replay
	npx --yes @marp-team/marp-cli@4.5.1 deck/talk.md --theme deck/theme.css --allow-local-files --html --output /tmp/rsigma-lss-talk.html

render:
	npx --yes @marp-team/marp-cli@4.5.1 deck/talk.md --theme deck/theme.css --allow-local-files --html --output deck/talk.html
	npx --yes @marp-team/marp-cli@4.5.1 deck/talk.md --theme deck/theme.css --allow-local-files --pdf --output deck/talk.pdf

record:
	vhs recordings/live.tape

replay:
	./demo/run.sh --replay

vm:
	./demo/vm/launch.sh

vm-shell:
	multipass shell rsigma-lss

vm-snapshot:
	./demo/vm/snapshot.sh

vm-stop:
	multipass stop rsigma-lss
