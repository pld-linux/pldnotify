#!/usr/bin/python

import argparse
import requests
import rpm
import sys

"""
RPM Spec parser
"""
class RPMSpec:
    def __init__(self, specfile):
        self._specfile = specfile
        self._spec = None
        self._macros = None

    def getSpec(self):
        if not self._spec:
            ts = rpm.TransactionSet()
            self._spec = ts.parseSpec(self._specfile)

        return self._spec

    def macros(self):
        if not self._macros:
            s = self.getSpec()
            macros = {}
            for key, macro in s.macros().items():
                # skip functions
                if 'opts' in macro:
                    continue
                # skip unused macros
                if macro['used'] <= 0:
                    continue
                macros[key] = macro['body']
            self._macros = macros

        return self._macros

"""
Check for update from release-monitoring.org.
Raise ValueError or version from anitya project.
"""
def rmo_check(name):
    distro = "pld-linux"
    url = "https://release-monitoring.org/api/project/%s/%s" % (distro, name)
    response = requests.get(url)
    data = response.json()
    if 'error' in data:
        raise ValueError, data['error']

    return data['version']

def check_package(package):
    s = RPMSpec(package)
    macros = s.macros()
    name = macros['name']
    version = macros['version']
    print "%s: %s" % (name, version)
    ver = rmo_check(name)
    print "Anitya: %s" % ver

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
