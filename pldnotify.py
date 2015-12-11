#!/usr/bin/python

import argparse
import requests
import rpm
import sys
from os import path

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

    # compare version against current package
    # using rpm.labelCompare function
    def compare(self, version):
        v1 = (None, version, '1')
        v2 = (None, self.macros()['version'], '1')
        return rpm.labelCompare(v1, v2)

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
Class containing specific remote repositories,
i.e Anitya (release-monitoring.org), NPM (nodejs), etc ...

"""
class Checker:
    distro = 'pld-linux'
    checkers = ['anitya']

    def __init__(self, specfile):
        self.spec = RPMSpec(specfile)

        try:
            macros = self.spec.macros()
        except rpm.error, e:
            raise ValueError, e

        self.name = macros['name']
        self.version = macros['version']

        name = path.splitext(path.basename(specfile))[0]
        if self.name != name:
            print "WARNING: name mismatch: %s!=%s" % (self.name, name)

        print "%s: %s" % (self.name, self.version)

    def find_recent(self):
        current = None

        for fn in self.checkers:
            try:
                v = getattr(self, fn)()
            except ValueError, e:
                print "WARNING: skipping %s: %s" % (fn, e)
                continue

            print "DEBUG: %s: %s" % (fn, v)

            if self.spec.compare(v) <= 0:
                print "DEBUG: skipping %s (is not newer)" % (v)
                continue

            current = v

        return current

    """
        Check for update from release-monitoring.org (Anitya).
        Raise ValueError or version from anitya project.
    """
    def anitya(self):
        url = "https://release-monitoring.org/api/project/%s/%s" % (self.distro, self.name)
        response = requests.get(url)
        data = response.json()
        if 'error' in data:
            raise ValueError, data['error']

        return data['version']

def main():
    parser = argparse.ArgumentParser(description='PLD-Notify: project to monitor upstream releases.')
    parser.add_argument('-d', '--debug',
        action='store_true',
        help='Enable debugging (default: %(default)s)')
    parser.add_argument('package',
        type=str,
        help='Package to check')

    args = parser.parse_args()

    checker = Checker(args.package)
    ver = checker.find_recent()
    if ver:
        print "Found an update: %s" % ver
    else:
        print "No update for %s" % args.package

if __name__ == '__main__':
    main()

# vi: encoding=utf-8 ts=8 sts=4 sw=4 et
