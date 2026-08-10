{
  hostName,
  ...
}:
{
  networking = {
    inherit hostName;
    computerName = hostName;
  };

  system.defaults.smb.NetBIOSName = hostName;
}
