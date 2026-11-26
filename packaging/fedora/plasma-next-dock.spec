Name:           plasma-next-dock
Version:        0.9~preview1
Release:        1%{?dist}
Summary:        Customizable modular dock for KDE Plasma on Wayland
License:        GPL-2.0-or-later AND LGPL-2.0-or-later AND MIT-CMU
URL:            https://github.com/SarbaLabs/Plasma-Next-Dock
Source0:        %{name}-%{version}.tar.gz

BuildRequires:  cmake
BuildRequires:  gcc-c++
BuildRequires:  make
BuildRequires:  pkgconf-pkg-config
BuildRequires:  qt6-qtbase-devel
BuildRequires:  qt6-qtbase-private-devel
BuildRequires:  qt6-qtdeclarative-devel
BuildRequires:  qt6-qtshadertools-devel
BuildRequires:  qt6-qtsvg
BuildRequires:  layer-shell-qt-devel
BuildRequires:  plasma-wayland-protocols-devel
BuildRequires:  wayland-devel
BuildRequires:  plasma-workspace
BuildRequires:  plasma-desktop
BuildRequires:  plasma-pa
BuildRequires:  dbus-daemon
BuildRequires:  kf6-kirigami
BuildRequires:  kf6-qqc2-desktop-style
BuildRequires:  kpipewire
BuildRequires:  kf6-breeze-icons
BuildRequires:  kf6-kglobalaccel-devel
BuildRequires:  kf6-kwindowsystem-devel
BuildRequires:  kf6-ki18n-devel
BuildRequires:  kf6-kio-devel
BuildRequires:  kf6-solid-devel
BuildRequires:  kf6-kiconthemes-devel
BuildRequires:  kf6-kservice-devel
BuildRequires:  kf6-krunner-devel
BuildRequires:  kf6-knotifications-devel
BuildRequires:  plasma-activities-stats-devel
BuildRequires:  gettext
BuildRequires:  cmake-rpm-macros
BuildRequires:  kf6-kirigami-addons

Provides:       plasma-next-dock-module-api-1
Requires:       plasma-workspace
Requires:       plasma-desktop
Requires:       plasma-pa
Requires:       qt6-qtdeclarative
Requires:       qt6-qtsvg
Requires:       kf6-kirigami
Requires:       kf6-qqc2-desktop-style
Requires:       kpipewire
Requires:       kf6-breeze-icons
Recommends:     %{name}-module-unpinned
Recommends:     %{name}-module-folders
Recommends:     %{name}-module-trash
Recommends:     %{name}-module-usb
Recommends:     %{name}-module-appmenu

%description
Configure independent docks, pin applications and add optional modules.

%package module-unpinned
Summary:        Running applications module for Plasma Next Dock
Requires:       plasma-next-dock-module-api-1
BuildArch:      noarch

%description module-unpinned
Adds the optional Running applications module to the dock module catalog.

%package module-folders
Summary:        Folders module for Plasma Next Dock
Requires:       plasma-next-dock-module-api-1

%description module-folders
Adds the optional Folders module to the dock module catalog.

%package module-trash
Summary:        Trash module for Plasma Next Dock
Requires:       plasma-next-dock-module-api-1

%description module-trash
Adds the optional Trash module to the dock module catalog.

%package module-usb
Summary:        USB storage module for Plasma Next Dock
Requires:       plasma-next-dock-module-api-1

%description module-usb
Adds the optional USB storage module to the dock module catalog.

%package module-appmenu
Summary:        Applications menu module for Plasma Next Dock
Requires:       plasma-next-dock-module-api-1
Requires:       kf6-kirigami-addons, kf6-kconfig, kf6-kcoreaddons, kf6-kcmutils, kmenuedit

%description module-appmenu
Adds the optional Applications menu module to the dock module catalog.

%prep
%autosetup

%build
%cmake -DBUILD_TESTING=ON
%cmake_build

%install
%cmake_install
# QML resolves each native plugin relative to its module's qmldir.
for module in folders trash usb appmenu; do
    native=%{_datadir}/%{name}/modules/org.sarbalabs.$module/native
    dest=%{_libdir}/%{name}/$module
    install -d "%{buildroot}$dest"
    for plugin in "%{buildroot}$native"/*.so; do
        mv "$plugin" "%{buildroot}$dest/"
        ln -s "$dest/${plugin##*/}" "$plugin"
    done
done
%find_lang %{name}

%check
%ctest

%files -f %{name}.lang
%license LICENSE
%doc docs/licensing.md
%{_bindir}/%{name}
%{_datadir}/applications/org.sarbalabs.PlasmaNextDock.desktop
%{_datadir}/icons/hicolor/scalable/apps/org.sarbalabs.PlasmaNextDock.svg
%{_datadir}/plasma/plasmoids/org.sarbalabs.nextdock.launcherrelay/
%dir %{_datadir}/%{name}
%dir %{_datadir}/%{name}/modules
%dir %{_libdir}/%{name}
%{_datadir}/%{name}/org.sarbalabs.PlasmaNextDock.desktop

%files module-unpinned
%{_datadir}/%{name}/modules/org.sarbalabs.unpinned/

%files module-folders
%{_datadir}/%{name}/modules/org.sarbalabs.folders/
%{_libdir}/%{name}/folders/

%files module-trash
%{_datadir}/%{name}/modules/org.sarbalabs.trash/
%{_libdir}/%{name}/trash/

%files module-usb
%{_datadir}/%{name}/modules/org.sarbalabs.usb/
%{_libdir}/%{name}/usb/

%files module-appmenu
%{_datadir}/%{name}/modules/org.sarbalabs.appmenu/
%{_libdir}/%{name}/appmenu/
