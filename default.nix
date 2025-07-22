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
, makeWrapper
, seatd
, libdrm
}:

let
  # 创建完整的库路径
  libPath = lib.makeLibraryPath [
    libxkbcommon
    libinput
    udev
    wayland
    mesa
    libglvnd
    seatd
    libdrm
  ];
in

rustPlatform.buildRustPackage rec {
  pname = "smallvil";
  version = "0.1.0";
  
  src = ./.;
  
  cargoLock = {
    lockFile = ./Cargo.lock;
  };
  
  nativeBuildInputs = [ 
    pkg-config 
    makeWrapper
  ];
  
  buildInputs = [
    libxkbcommon
    libinput
    udev
    wayland
    mesa
    libglvnd
    seatd
    libdrm
  ];
  
  # 设置运行时环境
  postInstall = ''
    # 创建包装脚本
    wrapProgram $out/bin/smallanvil-compositor \
      --prefix LD_LIBRARY_PATH : "${libPath}" \
      --set WINIT_UNIX_BACKEND wayland \
      --set XDG_RUNTIME_DIR "/run/user/\$(id -u)" \
      --set RUST_BACKTRACE full
    
    # 创建简单的启动脚本
    cat > $out/bin/smallvil-start <<EOF
    #!/bin/sh
    # 确保运行时目录存在
    export XDG_RUNTIME_DIR="/run/user/\$(id -u)"
    mkdir -p "\$XDG_RUNTIME_DIR"
    chmod 0700 "\$XDG_RUNTIME_DIR"
    
    # 停止现有显示管理器
    if [ -z "\$NO_STOP_DISPLAY_MANAGER" ]; then
      sudo systemctl stop display-manager.service 2>/dev/null || true
    fi
    
    # 运行合成器
    exec $out/bin/smallanvil-compositor "\$@"
    EOF
    
    chmod +x $out/bin/smallvil-start
  '';
  
  meta = with lib; {
    description = "Small Wayland compositor";
    homepage = "https://github.com/fuchaoran001/smallvil";
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
