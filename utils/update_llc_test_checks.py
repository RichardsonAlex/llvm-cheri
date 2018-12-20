#!/usr/bin/env python2.7

"""A test case update script.

This script is a utility to update LLVM 'llc' based test cases with new
FileCheck patterns. It can either update all of the tests in the file or
a single test function.
"""

import argparse
import os         # Used to advertise this file's name ("autogenerated_note").
import string
import subprocess
import sys
import re

from UpdateTestChecks import asm, common

ADVERT = '; NOTE: Assertions have been autogenerated by '


def main():
  parser = argparse.ArgumentParser(description=__doc__)
  parser.add_argument('-v', '--verbose', action='store_true',
                      help='Show verbose output')
  parser.add_argument('--llc-binary', default='llc',
                      help='The "llc" binary to use to generate the test case')
  parser.add_argument(
      '--function', help='The function in the test file to update')
  parser.add_argument(
      '--extra_scrub', action='store_true',
      help='Always use additional regex to further reduce diffs between various subtargets')
  parser.add_argument(
      '--x86_scrub_rip', action='store_true', default=True,
      help='Use more regex for x86 matching to reduce diffs between various subtargets')
  parser.add_argument(
      '--no_x86_scrub_rip', action='store_false', dest='x86_scrub_rip')
  parser.add_argument('tests', nargs='+')
  args = parser.parse_args()

  autogenerated_note = (ADVERT + 'utils/' + os.path.basename(__file__))

  for test in args.tests:
    if args.verbose:
      print >>sys.stderr, 'Scanning for RUN lines in test file: %s' % (test,)
    with open(test) as f:
      input_lines = [l.rstrip() for l in f]

    triple_in_ir = None
    for l in input_lines:
      m = common.TRIPLE_IR_RE.match(l)
      if m:
        triple_in_ir = m.groups()[0]
        break

    raw_lines = [m.group(1)
                 for m in [common.RUN_LINE_RE.match(l) for l in input_lines] if m]
    run_lines = [raw_lines[0]] if len(raw_lines) > 0 else []
    for l in raw_lines[1:]:
      if run_lines[-1].endswith("\\"):
        run_lines[-1] = run_lines[-1].rstrip("\\") + " " + l
      else:
        run_lines.append(l)

    if args.verbose:
      print >>sys.stderr, 'Found %d RUN lines:' % (len(run_lines),)
      for l in run_lines:
        print >>sys.stderr, '  RUN: ' + l

    run_list = []
    for l in run_lines:
      commands = [cmd.strip() for cmd in l.split('|', 1)]
      llc_cmd = commands[0]
      if llc_cmd.startswith("%cheri"):
        llc_cmd = llc_cmd.replace("%cheri_purecap_llc", "llc -mtriple=cheri-unknown-freebsd -target-abi purecap -relocation-model pic -mcpu=cheri128 -mattr=+cheri128")
        llc_cmd = llc_cmd.replace("%cheri128_purecap_llc", "llc -mtriple=cheri-unknown-freebsd -target-abi purecap -relocation-model pic -mcpu=cheri128 -mattr=+cheri128")
        llc_cmd = llc_cmd.replace("%cheri256_purecap_llc", "llc -mtriple=cheri-unknown-freebsd -target-abi purecap -relocation-model pic -mcpu=cheri256 -mattr=+cheri256")
        llc_cmd = llc_cmd.replace("%cheri_llc", "llc -mtriple=cheri-unknown-freebsd -mcpu=cheri128 -mattr=+cheri128")
        llc_cmd = llc_cmd.replace("%cheri128_llc", "llc -mtriple=cheri-unknown-freebsd -mcpu=cheri128 -mattr=+cheri128")
        llc_cmd = llc_cmd.replace("%cheri256_llc", "llc -mtriple=cheri-unknown-freebsd -mcpu=cheri256 -mattr=+cheri256")

      triple_in_cmd = None
      m = common.TRIPLE_ARG_RE.search(llc_cmd)
      if m:
        triple_in_cmd = m.groups()[0]

      filecheck_cmd = ''
      if len(commands) > 1:
        filecheck_cmd = commands[1]
      if filecheck_cmd.startswith("%cheri_FileCheck"):
        filecheck_cmd = filecheck_cmd.replace("%cheri_FileCheck", "FileCheck '-D$CAP_SIZE=16'")
      if not llc_cmd.startswith('llc '):
        print >>sys.stderr, 'WARNING: Skipping non-llc RUN line: ' + l
        continue

      if not filecheck_cmd.startswith('FileCheck '):
        print >>sys.stderr, 'WARNING: Skipping non-FileChecked RUN line: ' + l
        continue

      llc_cmd_args = llc_cmd[len('llc'):].strip()
      llc_cmd_args = llc_cmd_args.replace('< %s', '').replace('%s', '').strip()

      check_prefixes = [item for m in common.CHECK_PREFIX_RE.finditer(filecheck_cmd)
                               for item in m.group(1).split(',')]
      if not check_prefixes:
        check_prefixes = ['CHECK']

      # FIXME: We should use multiple check prefixes to common check lines. For
      # now, we just ignore all but the last.
      run_list.append((check_prefixes, llc_cmd_args, triple_in_cmd))

    func_dict = {}
    for p in run_list:
      prefixes = p[0]
      for prefix in prefixes:
        func_dict.update({prefix: dict()})
    for prefixes, llc_args, triple_in_cmd in run_list:
      if args.verbose:
        print >>sys.stderr, 'Extracted LLC cmd: llc ' + llc_args
        print >>sys.stderr, 'Extracted FileCheck prefixes: ' + str(prefixes)

      raw_tool_output = common.invoke_tool(args.llc_binary, llc_args, test)
      if not (triple_in_cmd or triple_in_ir):
        print >>sys.stderr, "Cannot find a triple. Assume 'x86'"

      asm.build_function_body_dictionary_for_triple(args, raw_tool_output,
          triple_in_cmd or triple_in_ir or 'x86', prefixes, func_dict)

    is_in_function = False
    is_in_function_start = False
    func_name = None
    prefix_set = set([prefix for p in run_list for prefix in p[0]])
    if args.verbose:
      print >>sys.stderr, 'Rewriting FileCheck prefixes: %s' % (prefix_set,)
    output_lines = []
    output_lines.append(autogenerated_note)

    for input_line in input_lines:
      if is_in_function_start:
        if input_line == '':
          continue
        if input_line.lstrip().startswith(';'):
          m = common.CHECK_RE.match(input_line)
          if not m or m.group(1) not in prefix_set:
            output_lines.append(input_line)
            continue

        # Print out the various check lines here.
        asm.add_asm_checks(output_lines, ';', run_list, func_dict, func_name)
        is_in_function_start = False

      if is_in_function:
        if common.should_add_line_to_output(input_line, prefix_set):
          # This input line of the function body will go as-is into the output.
          output_lines.append(input_line)
        else:
          continue
        if input_line.strip() == '}':
          is_in_function = False
        continue

      # Discard any previous script advertising.
      if input_line.startswith(ADVERT):
        continue

      # If it's outside a function, it just gets copied to the output.
      output_lines.append(input_line)

      m = common.IR_FUNCTION_RE.match(input_line)
      if not m:
        continue
      func_name = m.group(1)
      if args.function is not None and func_name != args.function:
        # When filtering on a specific function, skip all others.
        continue
      is_in_function = is_in_function_start = True

    if args.verbose:
      print>>sys.stderr, 'Writing %d lines to %s...' % (len(output_lines), test)

    with open(test, 'wb') as f:
      f.writelines([l + '\n' for l in output_lines])


if __name__ == '__main__':
  main()
