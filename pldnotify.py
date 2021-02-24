#!/usr/bin/python3

import argparse
import requests
import rpm
from os import path

"""
RPM Spec parser
"""


class RPMSpec:
    def __init__(self, specfile):
        self._specfile = specfile
        self._header = None
        self._name = None
        self._version = None

    def get_spec_header(self):
        if not self._header:
            spec = rpm.spec(self._specfile)
            self._header = spec.sourceHeader
        return self._header

    # compare version against current package
    # using rpm.labelCompare function
    def compare(self, version):
        v1 = (None, version, '1')
        v2 = (None, self.version, '1')
        try:
            return rpm.labelCompare(v1, v2)
        except ValueError:
            return -1

    @property
    def name(self):
        if not self._name:
            if not self._header:
                self.get_spec_header()
            self._name = self._header[rpm.RPMTAG_NAME]
            if not self._name:
                raise ValueError("%s: spec with no name" % self._specfile)
        return self._name

    @property
    def version(self):
        if not self._version:
            if not self._header:
                self.get_spec_header()
            self._version = self._header[rpm.RPMTAG_VERSION]
            if not self._version:
                raise ValueError("%s: spec with no version" % self._specfile)
        return self._version


class AbstractChecker:
    pass


class CheckReleaseMonitoring(AbstractChecker):
    """
        Check for update from release-monitoring.org (Anitya).
        Raise ValueError or version from anitya project.
    """

    def find_latest(self, distro, spec):
        url = "https://release-monitoring.org/api/project/%s/%s" % (distro, spec.name)
        response = requests.get(url)
        data = response.json()
        if 'error' in data:
            error = data['error']
            if error == 'No package "%s" found in distro "%s"' % (spec.name, distro):
                res = self.find_alternatives(spec)
                if res is not None:
                    error = error + "\n" + res
            raise ValueError(error)

        return data['version']

    """
        Return alternatives found from Anitya
    """

    def find_alternatives(self, spec):
        url = "https://release-monitoring.org/api/projects/?pattern=%s" % spec.name
        data = requests.get(url).json()

        if data['total'] == 0:
            return None

        def format_project(project):
            url = 'https://release-monitoring.org/project/%d/' % project['id']

            return '"%s" (%s): %s' % (project['name'], project['homepage'], url)

        r = []
        for project in data['projects']:
            r.append(format_project(project))

        return "Possible matches:\n- %s" % ("\n- ".join(r))


"""
Class containing specific remote repositories,
i.e Anitya (release-monitoring.org), NPM (nodejs), etc ...
"""


class Checker:
    distro = 'pld-linux'
    checkers = [
        CheckReleaseMonitoring,
    ]

    def __init__(self, specfile, debug):
        self.debug = debug
        self.spec = RPMSpec(specfile)

        name = path.splitext(path.basename(specfile))[0]
        if self.spec.name != name:
            print("WARNING: name mismatch: %s!=%s" % (self.spec.name, name))

        print("%s: %s" % (self.spec.name, self.spec.version))

    def find_latest(self):
        current = None

        for name in self.checkers:
            checker = name()
            try:
                v = checker.find_latest(self.distro, self.spec)
            except ValueError as e:
                print("WARNING: skipping %s: %s" % (name, e))
                continue

            if self.debug:
                print("DEBUG: %s: %s" % (name, v))

            if self.spec.compare(v) <= 0:
                if self.debug:
                    print("DEBUG: skipping %s (is not newer)" % (v))
                continue

            current = v

        return current


def main():
    parser = argparse.ArgumentParser(description='PLD-Notify: project to monitor upstream releases')

    parser.add_argument('-d', '--debug',
                        action='store_true',
                        help='Enable debugging (default: %(default)s)')

    parser.add_argument('packages',
                        type=str, nargs='*',
                        help='Package to check')

    args = parser.parse_args()

    if not args.debug:
        rpm.setVerbosity(rpm.RPMLOG_ERR)

    i = 0
    n = len(args.packages)
    print("Checking %d packages" % n)
    for package in args.packages:
        i += 1
        print("[%d/%d] checking %s" % (i, n, package))
        try:
            checker = Checker(package, args.debug)
            ver = checker.find_latest()
        except Exception as e:
            print("ERROR: %s" % e)
            continue

        if ver:
            print("[%s] Found an update: %s" % (package, ver))
        else:
            print("[%s] No updates found" % (package))


if __name__ == '__main__':
    main()

# vi: encoding=utf-8 ts=8 sts=4 sw=4 et
