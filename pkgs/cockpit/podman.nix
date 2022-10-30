{ lib, stdenv, fetchzip, gettext, git }:

stdenv.mkDerivation rec {
  pname = "cockpit-podman";
  version = "54";

  src = fetchzip {
    url = "https://github.com/cockpit-project/cockpit-podman/releases/download/${version}/cockpit-podman-${version}.tar.xz";
    sha256 = "sha256-R+VnTrkOp0tt8LWrbXIQwTLla6+a9HnBtZL838LNyMY=";
  };

  nativeBuildInputs = [
    gettext
  ];

  prePatch = ''
      touch package-lock.json
  '';

  postPatch = ''
    substituteInPlace Makefile \
      --replace /usr/share $out/share
    touch pkg/lib/cockpit.js
    touch dist/manifest.json
    touch pkg/lib/cockpit-po-plugin.js
    touch package-lock.json
  '';


  dontBuild = true;

  meta = with lib; {
    description = "Cockpit UI for Podman";
    license = licenses.lgpl21;
    homepage = "https://github.com/cockpit-project/cockpit-podman";
    platforms = platforms.linux;
    maintainers = with maintainers; [ ];
  };
}
