%define APPKIT_VERSION		0.85
%define FOUNDATION_VERSION	0.85
%define SYSTEM_VERSION		0.85


Name:           nextspace-frameworks
Version:        0.85
Release:        0%{?dist}
Summary:        NextSpace core libraries.

Group:          Libraries/NextSpace
License:        GPLv2
URL:		http://www.github.com/trunkmaster/nextspace
Source0:	nextspace-frameworks-%{version}.tar.gz

Provides:	NXFoundation.so
Provides:	NXSystem.so
Provides:	NXAppKit.so
Provides:	SoundKit.so

BuildRequires:	nextspace-gnustep-devel
# NXFoundation
BuildRequires:	file-devel
# NXSystem
BuildRequires:	libudisks2-devel
BuildRequires:	dbus-devel
BuildRequires:	upower-devel
BuildRequires:	libXrandr-devel
BuildRequires:	libxkbfile-devel
BuildRequires:	libXcursor-devel
# SoundKit
BuildRequires:	pulseaudio-libs-devel >= 10.0

Requires:	nextspace-gnustep
# NXFoundation
Requires:	file-libs >= 5.11
# NXSystem
Requires:	udisks2
Requires:	libudisks2 >= 2.1.2
Requires:	dbus-libs >= 1.6.12
Requires:	upower >= 0.99.2
Requires:	glib2 >= 2.42.2
Requires:	libXrandr >= 1.4.2
Requires:	libxkbfile >= 1.0.9
Requires:	libXcursor >= 1.1.14
# SoundKit
Requires:	pulseaudio-libs >= 10.0


%description
NextSpace libraries.

%package devel
Summary:	NextSpace core libraries (NXSystem, NXFoundation, NXAppKit).
Requires:	%{name}%{?_isa} = %{version}-%{release}

%description devel
Header files for NextSpace core libraries (NXSystem, NXFoundation, NXAppKit, SoundKit).

%prep
%setup

#
# Build phase
#
%build
export CC=clang
export CXX=clang++
export GNUSTEP_MAKEFILES=/Developer/Makefiles
export PATH+=":/usr/NextSpace/bin"

export ADDITIONAL_INCLUDE_DIRS="-I../NXFoundation/derived_src -I../NXSystem/derived_src"

cd NXFoundation
make
cd ..

cd NXSystem
make
cd ..

cd NXAppKit
#export LDFLAGS="-L../NXFoundation-%{FOUNDATION_VERSION}/NXFoundation.framework -lNXFoundation"
make
cd ..

cd SoundKit
make
cd ..

#
# Build install phase
#
%install
export GNUSTEP_MAKEFILES=/Developer/Makefiles
export QA_SKIP_BUILD_ROOT=1

cd NXSystem
%{make_install}
cd ..

cd NXFoundation
%{make_install}
cd ..

cd NXAppKit
%{make_install}
cd ..

cd SoundKit
%{make_install}
cd ..

#
# Files
#
%files
#/Library/Images
/Library/Fonts
/usr/NextSpace/Frameworks
/usr/NextSpace/lib
/usr/NextSpace/Fonts
/usr/NextSpace/Images
/usr/NextSpace/Sounds

%files devel
/usr/NextSpace/include

#
# Package install
#
#%pre

%post
#ln -s /usr/NextSpace/Frameworks/NXAppKit.framework/Resources/Images /usr/NextSpace/Images
#ln -s /usr/NextSpace/Frameworks/NXAppKit.framework/Resources/Fonts /Library/Fonts
#ln -s /usr/NextSpace/Frameworks/NXAppKit.framework/Resources/Sounds /usr/NextSpace/Sounds
#ln -s /usr/NextSpace/Sounds/Bonk.snd /usr/NextSpace/Sounds/SystemBeep.snd

#%preun

%postun
rm /usr/NextSpace/Images
rm /Library/Fonts
rm /usr/NextSpace/Sounds

%changelog
* Fri May  3 2019 Sergii Stoian <stoyan255@gmail.com> - 0.85-0
- Build with nextspace-gnustep-1.26.0_0.25.0.
* Fri Mar 01 2019 Sergii Stoian <stoyan255@gmail.com> 0.7-0
- SoundKit was added.
- Sounds were added into NXAppKit framework.
* Fri Oct 21 2016 Sergii Stoian <stoyan255@gmail.com> 0.4-0
- Initial spec for CentOS 7.

