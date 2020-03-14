--  Copyright (c) 2020 Maxim Reznik <reznikmm@gmail.com>
--
--  SPDX-License-Identifier: MIT
--  License-Filename: LICENSE
-------------------------------------------------------------

with Skynet;
with League.Strings;
with Ada.Wide_Wide_Text_IO;

procedure Skynet_Test is
   Options : Skynet.Upload_Options;
   Skylink : League.Strings.Universal_String;
begin
   Skynet.Upload_File
     (Path    => League.Strings.To_Universal_String ("/etc/hosts"),
      Skylink => Skylink,
      Options => Options);

   Ada.Wide_Wide_Text_IO.Put_Line (Skylink.To_Wide_Wide_String);

   Skynet.Download_File
     (Path    => League.Strings.To_Universal_String ("/tmp/hosts"),
      Skylink => Skylink);
end Skynet_Test;
