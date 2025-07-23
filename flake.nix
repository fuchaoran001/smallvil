{
  description = "Smithay compositor with Anvil example";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    rust-overlay.url = "github:oxalica/rust-overlay";
  };

  outputs = { self, nixpkgs, rust-overlay }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forEachSystem = f: nixpkgs.lib.genAttrs systems (system: f {
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ rust-overlay.overlays.default ];
          config = {
            allowUnfree = true;
            # 添加国内镜像源
            substituters = [
              "https://mirror.sjtu.edu.cn/nix-channels/store"
              "https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store"
              "https://cache.nixos.org"
            ];
            trusted-public-keys = [
              "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
            ];
          };
        };
      });
    in {
      packages = forEachSystem ({ pkgs }: {
        default = pkgs.rustPlatform.buildRustPackage {
          pname = "smallvil";
          version = "0.1.0";
          src = ./.;

          cargoLock = {
            lockFile = ./Cargo.lock;
          };

          nativeBuildInputs = [ pkgs.pkg-config ];

          buildInputs = [
            pkgs.libxkbcommon
            pkgs.libinput
            pkgs.libgbm
            pkgs.seatd
            pkgs.wayland
            pkgs.udev
            pkgs.xwayland
            pkgs.libglvnd
            pkgs.mesa
            pkgs.libdrm
            pkgs.xorg.libX11
            pkgs.xorg.libXcursor
            pkgs.xorg.libXrandr
            pkgs.xorg.libXi
          ];

          buildPhase = ''
            cargo build --release
          '';

          installPhase = ''
            mkdir -p $out/bin
            cp target/release/smallvil $out/bin/smallvil-compositor.raw
            
            # 创建包装脚本自动设置环境
            cat > $out/bin/smallvil-compositor <<EOF
            #!${pkgs.bash}/bin/bash
            # 设置必要的库路径
            export LD_LIBRARY_PATH=${pkgs.lib.makeLibraryPath [
              pkgs.libglvnd
              pkgs.mesa
              pkgs.libdrm
              pkgs.xorg.libX11
              pkgs.xorg.libXcursor
              pkgs.xorg.libXrandr
              pkgs.xorg.libXi
              pkgs.wayland
            ]}:\$LD_LIBRARY_PATH
            
            # 设置 Wayland 环境
            export XDG_RUNTIME_DIR=/run/user/$(id -u)
            [ ! -d "\$XDG_RUNTIME_DIR" ] && mkdir -p "\$XDG_RUNTIME_DIR" && chmod 0700 "\$XDG_RUNTIME_DIR"
            
            # 运行实际的 compositor
            exec $out/bin/smallvil-compositor.raw "\$@"
            EOF
            
            chmod +x $out/bin/smallvil-compositor
          '';
        };
      });

      # ... devShells 部分保持不变 ...
    };
}