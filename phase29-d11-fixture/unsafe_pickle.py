# INTENTIONALLY UNSAFE SCAN FIXTURE (Phase 29 D-11). DO NOT MERGE, "FIX" OR RUN.
# Nothing imports or executes this file; it exists only as Semgrep input.
# Expected Semgrep p/default finding: python.lang.security.deserialization.pickle.avoid-pickle
import pickle


def load_untrusted(data):
    return pickle.loads(data)
