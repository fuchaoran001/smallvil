{ lib
, stdenv
, rustPlatform
, fetchFromGitHub
, pkg-config
, libxkbcommon
, libinput
, udev
, wayland
, mesa
, libglvnd
}:

rustPlatform.buildRustPackage rec {
  pname = "smallvil";
  version = "0.1.0";
  
  src = ./.;
  
  cargoLock = {
    lockFile = ./Cargo.lock;
  };
  
  nativeBuildInputs = [ pkg-config ];
  
  buildInputs = [
    libxkbcommon
    libinput
    udev
    wayland
    mesa
    libglvnd
  ];
  
  meta = with lib; {
    description = "Small Wayland compositor";
    homepage = "https://github.com/fuchaoran001/smallvil";
    license = licenses.mit;
  };
}
