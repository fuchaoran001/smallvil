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
          pname = "smallanvil";
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
            
            # 添加 EGL 和 OpenGL 支持
            pkgs.libglvnd
            pkgs.mesa
          ];

          # 指定构建 anvil 示例
          cargoBuildFlags = [ "--example" "smallvil" ];

          # 安装生成的二进制文件
          postInstall = ''
            mv $out/bin/smallanvil $out/bin/smallvil-compositor
          '';
          
          # 确保 libEGL 被正确链接
          preFixup = ''
            patchelf --add-needed libEGL.so.1 $out/bin/smallanvil-compositor
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
            
            # 添加 mesa 工具用于调试
            pkgs.mesa-demos
          ];

          buildInputs = [
            pkgs.libxkbcommon
            pkgs.libinput
            pkgs.libgbm
            pkgs.seatd
            pkgs.wayland
            pkgs.udev
            
            # 添加 EGL 和 OpenGL 支持
            pkgs.libglvnd
            pkgs.mesa
          ];

          # 设置国内 Rust 工具链镜像
          RUSTUP_DIST_SERVER = "https://rsproxy.cn";
          RUSTUP_UPDATE_ROOT = "https://rsproxy.cn/rustup";
          
          # 关键修复：确保所有运行时库可用
          LD_LIBRARY_PATH = "${pkgs.lib.makeLibraryPath [
            pkgs.libxkbcommon
            pkgs.libinput
            pkgs.libgbm
            pkgs.seatd
            pkgs.wayland
            pkgs.udev
            pkgs.libglvnd
            pkgs.mesa
          ]}";
          
          shellHook = ''
            echo "Smithay开发环境已激活 (使用国内镜像源)"
            
            # 创建安全的用户运行时目录
            export XDG_RUNTIME_DIR="/run/user/$(id -u)"
            if [ ! -d "$XDG_RUNTIME_DIR" ]; then
              echo "创建运行时目录: $XDG_RUNTIME_DIR"
              sudo mkdir -p "$XDG_RUNTIME_DIR"
              sudo chown $(id -u):$(id -g) "$XDG_RUNTIME_DIR"
              sudo chmod 0700 "$XDG_RUNTIME_DIR"
            fi
            
            # 设置 Wayland 显示名称
            export WAYLAND_DISPLAY="wayland-1"
            
            # 检查 EGL 支持
            echo "检查 EGL 支持:"
            if ${pkgs.mesa-demos}/bin/eglinfo; then
              echo "EGL 支持正常"
            else
              echo "警告: EGL 支持可能有问题"
              echo "尝试设置 LIBGL_DEBUG=verbose 获取更多信息"
            fi
            
            # 显示调试信息
            echo "环境变量:"
            echo "  WAYLAND_DISPLAY=$WAYLAND_DISPLAY"
            echo "  XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR"
            echo "  LD_LIBRARY_PATH=$LD_LIBRARY_PATH"
          '';
        };
      });
    };
}
