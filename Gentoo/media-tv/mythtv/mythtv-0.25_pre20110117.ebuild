# Copyright 1999-2011 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header:$

EAPI=2
PYTHON_DEPEND="2"
MYTHTV_VERSION="v0.25pre-880-gd1e7906"
MYTHTV_BRANCH="master"
MYTHTV_REV="d1e7906677e6776455791a0cd43e00ca441b5947"
MYTHTV_SREV="d1e7906"

inherit flag-o-matic multilib eutils qt4 mythtv toolchain-funcs python

DESCRIPTION="Homebrew PVR project"
SLOT="0"
KEYWORDS="~amd64 ~x86 ~ppc"

IUSE_VIDEO_CARDS="video_cards_nvidia"
IUSE="altivec autostart dvb \
dvd bluray \
ieee1394 jack lcd lirc \
alsa jack \
debug profile \
perl python \
vdpau \
experimental \
${IUSE_VIDEO_CARDS} \
input_devices_joystick \
"

RDEPEND="
    >=net-misc/wget-1.12-r3
    >=media-libs/freetype-2.0
	>=media-sound/lame-3.93.1
	x11-libs/libX11
	x11-libs/libXext
	x11-libs/libXinerama
	x11-libs/libXv
	x11-libs/libXrandr
	x11-libs/libXxf86vm
	x11-libs/qt-core:4[qt3support]
	x11-libs/qt-gui:4[qt3support]
	x11-libs/qt-sql:4[qt3support,mysql]
	x11-libs/qt-opengl:4[qt3support]
	x11-libs/qt-webkit:4
	virtual/mysql
	virtual/opengl
	virtual/glu
	|| ( >=net-misc/wget-1.9.1 >=media-tv/xmltv-0.5.43 )
	alsa? ( >=media-libs/alsa-lib-0.9 )
	autostart? ( net-dialup/mingetty
				 x11-wm/evilwm
				 x11-apps/xset )
	dvb? ( media-libs/libdvb media-tv/linuxtv-dvb-headers )
	dvd? ( media-libs/libdvdcss )
	ieee1394? (	>=sys-libs/libraw1394-1.2.0
			    >=sys-libs/libavc1394-0.5.3
			    >=media-libs/libiec61883-1.0.0 )
	jack? ( media-sound/jack-audio-connection-kit )
	lcd? ( app-misc/lcdproc )
	lirc? ( app-misc/lirc )
	perl? ( dev-perl/DBD-mysql 
            dev-perl/Net-UPnP )
	python? ( dev-python/mysql-python
              dev-python/lxml )
    bluray? ( media-libs/libbluray )
    video_cards_nvidia? ( >=x11-drivers/nvidia-drivers-180.06 )
	"

DEPEND="${RDEPEND}
	x11-proto/xineramaproto
	x11-proto/xf86vidmodeproto
	x11-apps/xinit
	!x11-themes/mythtv-themes
	media-fonts/liberation-fonts
	"

MYTHTV_GROUPS="video,audio,tty,uucp"

pkg_setup() {
	python_set_active_version 2

	enewuser mythtv -1 /bin/bash /home/mythtv ${MYTHTV_GROUPS}
	usermod -a -G ${MYTHTV_GROUPS} mythtv
}

src_prepare() {
# upstream wants the revision number in their version.cpp
# since the subversion.eclass strips out the .svn directory
# svnversion in MythTV's build doesn't work
	sed -e "s/\${SOURCE_VERSION}/${MYTHTV_VERSION}/g" \
		-e "s/\${BRANCH}/${MYTHTV_BRANCH}/g" \
		-i "${S}"/version.sh


# Perl bits need to go into vender_perl and not site_perl
	sed -e "s:pure_install:pure_install INSTALLDIRS=vendor:" \
		-i "${S}"/bindings/perl/Makefile

	epatch "${FILESDIR}/fixLdconfSandbox.patch"
	epatch "${FILESDIR}/0001-Fix-the-use-of-datadirect-with-no-named-input-file.patch"

	if use experimental
	then
		epatch "${FILESDIR}/optimizeMFDBClearingBySource-3.patch"
		epatch "${FILESDIR}/jobQueueIgnoreDeletedRecgroup.patch"
		true;
	fi
}

src_configure() {
	local myconf="--prefix=/usr"
	myconf="${myconf} --mandir=/usr/share/man"
	myconf="${myconf} --libdir-name=$(get_libdir)"

	myconf="${myconf} --enable-pic"

	use alsa    || myconf="${myconf} --disable-audio-alsa"
	use altivec || myconf="${myconf} --disable-altivec"
	use jack    || myconf="${myconf} --disable-audio-jack"

	myconf="${myconf} $(use_enable dvb)"
	myconf="${myconf} $(use_enable ieee1394 firewire)"
	myconf="${myconf} $(use_enable lirc)"
	myconf="${myconf} --disable-directfb"
	myconf="${myconf} --dvb-path=/usr/include"
	myconf="${myconf} --enable-opengl-vsync"
	myconf="${myconf} --enable-xrandr"
	myconf="${myconf} --enable-xv"
	myconf="${myconf} --enable-x11"

	myconf="${myconf} --disable-xvmc"

	if use perl && use python
	then
		myconf="${myconf} --with-bindings=perl,python"
	elif use perl
	then
		myconf="${myconf} --without-bindings=python"
		myconf="${myconf} --with-bindings=perl"
	elif use python
	then
		myconf="${myconf} --without-bindings=perl"
		myconf="${myconf} --with-bindings=python"
	else
		myconf="${myconf} --without-bindings=perl,python"
	fi

	if use debug
	then
		myconf="${myconf} --compile-type=debug"
	elif use profile
	then
		myconf="${myconf} --compile-type=profile"
	else
		myconf="${myconf} --compile-type=release"
		myconf="${myconf} --enable-proc-opt"
	fi

	if use vdpau && use video_cards_nvidia
	then
		myconf="${myconf} --enable-vdpau"
	fi

	use input_devices_joystick || myconf="${myconf} --disable-joystick-menu"

	myconf="${myconf} --enable-symbol-visibility"

	hasq distcc ${FEATURES} || myconf="${myconf} --disable-distcc"
	hasq ccache ${FEATURES} || myconf="${myconf} --disable-ccache"

# let MythTV come up with our CFLAGS. Upstream will support this
	strip-flags
	CFLAGS=""
	CXXFLAGS=""

	chmod +x ./external/FFmpeg/version.sh

	einfo "Running ./configure ${myconf}"
	chmod +x ./configure
	./configure ${myconf} || die "configure died"
}

src_compile() {
	emake || die "emake failed"
}

src_install() {
	make INSTALL_ROOT="${D}" install || die "install failed"
	dodoc AUTHORS FAQ UPGRADING  README

	insinto /usr/share/mythtv/database
	doins database/*

	exeinto /usr/share/mythtv

	newinitd "${FILESDIR}"/mythbackend-0.18.2.rc mythbackend
	newconfd "${FILESDIR}"/mythbackend-0.18.2.conf mythbackend

	dodoc keys.txt docs/*.{txt,pdf}
	dohtml docs/*.html

	keepdir /etc/mythtv
	chown -R mythtv "${D}"/etc/mythtv
	keepdir /var/log/mythtv
	chown -R mythtv "${D}"/var/log/mythtv

	insinto /etc/logrotate.d
	newins "${FILESDIR}"/mythtv.logrotate.d mythtv

	insinto /usr/share/mythtv/contrib
	doins -r contrib/*

	dobin "${FILESDIR}"/runmythfe

	if use autostart
	then
		dodir /etc/env.d/
		echo 'CONFIG_PROTECT="/home/mythtv/"' > "${D}"/etc/env.d/95mythtv

		insinto /home/mythtv
		newins "${FILESDIR}"/bash_profile .bash_profile
		newins "${FILESDIR}"/xinitrc .xinitrc
	fi

	for file in `find ${D} -type f -name \*.py \
						-o -type f -name \*.sh \
						-o -type f -name \*.pl`;
	do
		chmod a+x $file;
	done
}

pkg_preinst() {
	export CONFIG_PROTECT="${CONFIG_PROTECT} ${ROOT}/home/mythtv/"
}

pkg_postinst() {
	elog "Want mythfrontend to start automatically?"
	elog "Set USE=autostart. Details can be found at:"
	elog "http://www.mythtv.org/wiki/Gentoo_Autostart"

	elog
	elog "To always have MythBackend running and available run the following:"
	elog "rc-update add mythbackend default"
	elog
	ewarn "Your recordings folder must be owned by the user 'mythtv' now"
	ewarn "chown -R mythtv /path/to/store"

	if use autostart
	then
		elog
		elog "Please add the following to your /etc/inittab file at the end of"
		elog "the TERMINALS section"
		elog "c8:2345:respawn:/sbin/mingetty --autologin mythtv tty8"
	fi

}

pkg_info() {
	"${ROOT}"/usr/bin/mythfrontend --version
}

pkg_config() {
	echo "Creating mythtv MySQL user and mythconverg database if it does not"
	echo "already exist. You will be prompted for your MySQL root password."
	"${ROOT}"/usr/bin/mysql -u root -p < "${ROOT}"/usr/share/mythtv/database/mc.sql
}

