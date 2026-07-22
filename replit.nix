{pkgs}: {
  deps = [
    pkgs.lua52Packages.lua
    pkgs.luajitPackages.luarocks_bootstrap
    pkgs.cl-launch
    pkgs.love
    pkgs.unzip
  ];
}
