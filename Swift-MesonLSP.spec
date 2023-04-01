%global debug_package %{nil}
%undefine _auto_set_build_flags

Name:           Swift-MesonLSP
Version:        0.0.1
Release:        1.5
Summary:        Meson language server
ExclusiveArch:  x86_64

License:        GPL
Source0:        https://github.com/JCWasmx86/Swift-MesonLSP/archive/refs/tags/v1.5.tar.gz

Requires:       bash
BuildRequires:  swift-lang
BuildRequires:  clang
BuildRequires:  git

%description
A meson language server

%prep
%setup -q -n Swift-MesonLSP-1.5


%build
git clone https://github.com/JCWasmx86/Swift-MesonLSP
cd Swift-MesonLSP
git checkout v1.5
swift build -c release --static-swift-stdlib -Xswiftc -g

%install
rm -rf $RPM_BUILD_ROOT
mkdir -p $RPM_BUILD_ROOT/%{_bindir}
cp Swift-MesonLSP/.build/release/Swift-MesonLSP $RPM_BUILD_ROOT/%{_bindir}

%files
%{_bindir}/Swift-MesonLSP

%changelog
* Sat Apr 1 2023 JCWasmx86 <JCWasmx86@t-online.de> - 0.0.1
- First version being packaged