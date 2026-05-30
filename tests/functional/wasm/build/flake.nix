{
  outputs =
    { self }:
    let
      basic = import ./basic;
      depends-on-basic = import ./depends-on-basic { inherit basic; };

      allPackages = {
        inherit basic depends-on-basic;
      };
    in
    {
      packages.aarch64-darwin = allPackages;
      packages.x86_64-linux = allPackages;
      packages.aarch64-linux = allPackages;
    };
}
