{
  description = "Smithay compositor with Anvil example";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
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
            # 国内镜像源配置
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
          
          nativeBuildInputs = [
            pkgs.pkg-config
            pkgs.makeWrapper
          ];
          
          buildInputs = [
            pkgs.cargo
            pkgs.rustc
          ] ++ (commonLibPath pkgs);
          
          # 配置 Rust 国内镜像源
          configurePhase = ''
            mkdir -p .cargo
            cat > .cargo/config.toml <<EOF
            [source.crates-io]
            replace-with = 'ustc'
            
            [source.ustc]
            registry = "https://mirrors.ustc.edu.cn/crates.io-index"
            
            [net]
            git-fetch-with-cli = true
            EOF
          '';
          
          buildPhase = ''
            # 设置国内镜像环境变量
            export CARGO_HOME=$(pwd)/.cargo
            export RUSTUP_DIST_SERVER="https://rsproxy.cn"
            export RUSTUP_UPDATE_ROOT="https://rsproxy.cn/rustup"
            
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
          
          # 设置国内 Rust 工具链镜像
          RUSTUP_DIST_SERVER = "https://rsproxy.cn";
          RUSTUP_UPDATE_ROOT = "https://rsproxy.cn/rustup";
          
          # 配置 Cargo 使用国内镜像
          shellHook = ''
            mkdir -p .cargo
            cat > .cargo/config.toml <<EOF
            [source.crates-io]
            replace-with = 'ustc'
            
            [source.ustc]
            registry = "https://mirrors.ustc.edu.cn/crates.io-index"
            
            [net]
            git-fetch-with-cli = true
            EOF
            
            export CARGO_HOME=$(pwd)/.cargo
            export XDG_RUNTIME_DIR="/run/user/$(id -u)"
            [ ! -d "$XDG_RUNTIME_DIR" ] && ( 
              sudo mkdir -p "$XDG_RUNTIME_DIR"
              sudo chown $(id -u):$(id -g) "$XDG_RUNTIME_DIR"
              sudo chmod 0700 "$XDG_RUNTIME_DIR"
            )
            echo "Smithay开发环境已激活 (使用国内镜像源)"
          '';
        };
      });
    };
}