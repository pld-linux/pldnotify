Summary:	Tool to check for updates in RPM .spec files
Name:		pldnotify
Version:	4.8
Release:	2
License:	GPL
Group:		Applications/File
Source0:	%{name}.awk
Source1:	%{name}.py
Requires:	coreutils
Requires:	curl
Requires:	nodejs
Requires:	npm
Requires:	perl-HTML-Tree
Requires:	perl-base
Requires:	php-pear-PEAR
Requires:	python-requests
Requires:	python-rpm >= 5.4.15-26
Requires:	rpmbuild(macros) >= 1.539
Requires:	ruby-rubygems
Requires:	sed
Requires:	util-linux
Requires:	wget
Conflicts:	rpm-build-tools < 4.8
BuildArch:	noarch
BuildRoot:	%{tmpdir}/%{name}-%{version}-root-%(id -u -n)

%description
Tool to check for updates in RPM .spec files.

%prep
%setup -qcT
cp -p %{SOURCE0} .
cp -p %{SOURCE1} .

%install
rm -rf $RPM_BUILD_ROOT
install -d $RPM_BUILD_ROOT%{_bindir}
install -p pldnotify.awk $RPM_BUILD_ROOT%{_bindir}
install -p pldnotify.py $RPM_BUILD_ROOT%{_bindir}
ln -s pldnotify.awk $RPM_BUILD_ROOT%{_bindir}/pldnotify

%clean
rm -rf $RPM_BUILD_ROOT

%files
%defattr(644,root,root,755)
%attr(755,root,root) %{_bindir}/pldnotify.awk
%attr(755,root,root) %{_bindir}/pldnotify.py
%attr(755,root,root) %{_bindir}/pldnotify
