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
                # skip unused macros, except name and version
                if macro['used'] <= 0 and (key not in ['name', 'version']):
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
            raise ValueError, "%s: %s" % (specfile, e.message)

        try:
            self.name = macros['name']
            self.version = macros['version']
        except Exception, e:
            raise ValueError, "%s: macro error: %s" % (specfile, e.message)

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
            error = data['error']
            if error == 'No package "%s" found in distro "%s"' % (self.name, self.distro):
                res = self.anitya_alternatives()
                if res != None:
                    error = error + ", " + res
            raise ValueError, error

        return data['version']

    """
        Return alternatives found from Anitya
    """
    def anitya_alternatives(self):
        url = "https://release-monitoring.org/api/projects/?pattern=%s" % self.name
        data = requests.get(url).json()

        if data['total'] == 0:
            return None

        def format_project(project):
            return '"%s" (%s)' % (project['name'], project['homepage'])

        r = []
        for project in data['projects']:
            r.append(format_project(project))

        return "Do you need to map %s?" % (", ".join(r))

def main():
    parser = argparse.ArgumentParser(description='PLD-Notify: project to monitor upstream releases')

    parser.add_argument('-d', '--debug',
        action='store_true',
        help='Enable debugging (default: %(default)s)')

    parser.add_argument('packages',
        type=str, nargs='*',
        help='Package to check')

    args = parser.parse_args()

    i = 0
    n = len(args.packages)
    print "Checking %d packages" % n
    for package in args.packages:
        i += 1
        print "[%d/%d] checking %s" % (i, n, package)
        try:
            checker = Checker(package)
            ver = checker.find_recent()
        except Exception, e:
            print "ERROR: %s" % e
            continue

        if ver:
            print "[%s] Found an update: %s" % (package, ver)
        else:
            print "[%s] No updates found" % (package)

if __name__ == '__main__':
    main()

# vi: encoding=utf-8 ts=8 sts=4 sw=4 et
