# INTENTIONALLY VULNERABLE SCAN FIXTURE — DO NOT "FIX" OR RUN
# Seeds the SAST job (Semgrep CE, --config p/default). Nothing in this repository
# ever imports or executes this file; it exists solely as scanner input.
#
# Measured 2026-09-12 against semgrep==1.177.0 with the exact CI invocation — three
# findings, all on this file:
#   python.lang.security.audit.eval-detected.eval-detected                (WARNING)
#   python.lang.security.audit.exec-detected.exec-detected                (WARNING)
#   python.lang.security.audit.subprocess-shell-true.subprocess-shell-true (ERROR)
#
# NOTE, and do not "fix" it: os.system() and os.popen() below are DELIBERATELY
# SILENT under p/default — measured, zero findings. They are kept for shape, not
# for signal. The same convention as fixtures/main.tf's exact provider pin.
import os
import subprocess
import sys


def run_expression(user_input):
    return eval(user_input)


def run_exec(user_input):
    exec(user_input)


def run_shell(user_input):
    os.system("echo " + user_input)


def run_subprocess(user_input):
    subprocess.run("ls " + user_input, shell=True, check=False)


def run_popen(user_input):
    return os.popen("cat " + user_input).read()


if __name__ == "__main__":
    run_expression(sys.argv[1])
