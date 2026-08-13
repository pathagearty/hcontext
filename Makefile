.PHONY: data test run verify supabase-test

data:
	python3 data/generate.py
	python3 data/generate_supabase_v1.py

test:
	python3 -m unittest discover -s tests -v

run:
	python3 -m uvicorn backend.app:app --host 127.0.0.1 --port 8010

supabase-test:
	supabase test db --local

verify: data
	python3 -m compileall -q backend data scripts tests
	node --check frontend/app.js
	python3 -m unittest discover -s tests -v
