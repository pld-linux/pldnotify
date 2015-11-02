Summary:	Tool to check for updates in RPM .spec files
Name:		pldnotify
Version:	4.8
Release:	1
License:	GPL
Group:		Applications/File
Source0:	%{name}.awk
Requires:	curl
Requires:	perl-base
Requires:	rpmbuild(macros) >= 1.539
Requires:	wget
Conflicts:	rpm-build-tools < 4.8
BuildArch:	noarch
BuildRoot:	%{tmpdir}/%{name}-%{version}-root-%(id -u -n)

%description
Tool to check for updates in RPM .spec files.

%prep
%setup -qcT
cp -p %{SOURCE0} pldnotify.awk

%install
rm -rf $RPM_BUILD_ROOT
install -d $RPM_BUILD_ROOT%{_bindir}
install -p pldnotify.awk $RPM_BUILD_ROOT%{_bindir}/pldnotify
ln -s pldnotify $RPM_BUILD_ROOT%{_bindir}/pldnotify.awk

%clean
rm -rf $RPM_BUILD_ROOT

%files
%defattr(644,root,root,755)
%attr(755,root,root) %{_bindir}/pldnotify*
