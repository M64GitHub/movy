let
  nixpkgs = builtins.fetchTarball {
    url = "https://github.com/nixos/nixpkgs/archive/6a08e6bb4e46ff7fcbb53d409b253f6bad8a28ce.tar.gz";
    sha256 = "0ixzzfdyrkm8mhfrgpdmq0bpfk5ypz63qnbxskj5xvfxvdca3ys3";
  };
  pkgs = import nixpkgs {};
in

pkgs.mkShell {
  buildInputs = with pkgs; [
    zig
    just
    pkg-config

    # For movy_video support
    ffmpeg
    SDL2
  ];
}
