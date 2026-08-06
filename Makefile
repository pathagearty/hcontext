.PHONY: data test run verify

data:
	python3 data/generate.py

test:
	python3 -m unittest discover -s tests -v

run:
	python3 -m uvicorn backend.app:app --host 127.0.0.1 --port 8010

verify: data test
