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
      
      # 共享的库路径定义
      commonLibPath = pkgs: with pkgs; [
        libglvnd
        mesa
        libdrm
        xorg.libX11
        xorg.libXcursor
        xorg.libXrandr
        xorg.libXi
        xorg.libXext
        wayland
        libxkbcommon
        libgbm
        libinput
        seatd
      ];
      
    in {
      packages = forEachSystem ({ pkgs }: {
        default = pkgs.stdenv.mkDerivation {
          pname = "smallvil";
          version = "0.1.0";
          src = ./.;
          
          buildInputs = [
            pkgs.rustc
            pkgs.cargo
            pkgs.pkg-config
            pkgs.makeWrapper
          ] ++ (commonLibPath pkgs);
          
          buildPhase = ''
            cargo build --release
          '';
          
          installPhase = ''
            mkdir -p $out/bin
            install -Dm755 target/release/smallvil $out/bin/smallvil.raw
            
            # 创建自动环境设置的包装器
            makeWrapper $out/bin/smallvil.raw $out/bin/smallvil \
              --prefix LD_LIBRARY_PATH : "${pkgs.lib.makeLibraryPath (commonLibPath pkgs)}" \
              --prefix PATH : "${pkgs.lib.makeBinPath [pkgs.xwayland]}" \
              --run 'export XDG_RUNTIME_DIR="/run/user/$(id -u)"'
          '';
        };
      });

      devShells = forEachSystem ({ pkgs }: {
        default = pkgs.mkShell {
          packages = [
            (pkgs.rust-bin.stable.latest.default.override {
              extensions = [ "rust-src" ];
            })
            pkgs.pkg-config
            pkgs.clippy
            pkgs.makeWrapper
          ];

          buildInputs = commonLibPath pkgs;
          
          RUSTUP_DIST_SERVER = "https://rsproxy.cn";
          RUSTUP_UPDATE_ROOT = "https://rsproxy.cn/rustup";
          
          LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath (commonLibPath pkgs);
          
          shellHook = ''
            echo "Smithay开发环境已激活"
            export XDG_RUNTIME_DIR="/run/user/$(id -u)"
            [ ! -d "$XDG_RUNTIME_DIR" ] && ( 
              sudo mkdir -p "$XDG_RUNTIME_DIR"
              sudo chown $(id -u):$(id -g) "$XDG_RUNTIME_DIR"
              sudo chmod 0700 "$XDG_RUNTIME_DIR"
            )
            export WAYLAND_DISPLAY="wayland-1"
          '';
        };
      });
    };
}