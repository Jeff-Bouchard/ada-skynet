--  Copyright (c) 2020 Maxim Reznik <reznikmm@gmail.com>
--
--  SPDX-License-Identifier: MIT
--  License-Filename: LICENSE
-------------------------------------------------------------

with League.Strings;

package Skynet is

   function "+"
     (Text : Wide_Wide_String) return League.Strings.Universal_String
        renames League.Strings.To_Universal_String;

   URI_Skynet_Prefix : constant Wide_Wide_String := "sia://";

   type Portal_Upload_Options is record
      URL         : League.Strings.Universal_String := +"https://siasky.net";
      Upload_Path : League.Strings.Universal_String := +"skynet/skyfile";

      File_Fieldname           : League.Strings.Universal_String := +"file";
      Directory_File_Fieldname : League.Strings.Universal_String := +"files[]";
   end record;

   type Upload_Options is record
      Portal          : Portal_Upload_Options;
      Custom_Filename : League.Strings.Universal_String;
   end record;

   procedure Upload_File
     (Path    : League.Strings.Universal_String;
      Skylink : out League.Strings.Universal_String;
      Options : Upload_Options := (others => <>))
       with Post => Skylink.Starts_With (URI_Skynet_Prefix);

   procedure Download_File
     (Path       : League.Strings.Universal_String;
      Skylink    : League.Strings.Universal_String;
      Portal_URL : League.Strings.Universal_String := +"https://siasky.net")
       with Pre => Skylink.Starts_With (URI_Skynet_Prefix);

end Skynet;
