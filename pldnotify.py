#!/usr/bin/python

import argparse
import collections
import os
import rpm
import shlex
import subprocess
import sys

def check_package(package):
    print package

def main():
    parser = argparse.ArgumentParser(description='PLD-Notify: project to monitor upstream releases.')
    parser.add_argument('-d', '--debug',
        action='store_true',
        help='Enable debugging (default: %(default)s)')
    parser.add_argument('package',
        type=str,
        help='Package to check')
        
    args = parser.parse_args()
    check_package(args.package)

if __name__ == '__main__':
    main()

# vi: encoding=utf-8 ts=8 sts=4 sw=4 et
