--  Copyright (c) 2020 Maxim Reznik <reznikmm@gmail.com>
--
--  SPDX-License-Identifier: MIT
--  License-Filename: LICENSE
-------------------------------------------------------------

with Ada.Characters.Latin_1;
with Ada.Directories;
with Ada.Streams.Stream_IO;
with Ada.Unchecked_Deallocation;

with AWS.Client;
with AWS.Headers;
with AWS.Messages;
with AWS.Resources;
with AWS.Response;
with AWS.Utils;

with League.JSON.Documents;
with League.JSON.Objects;
with League.JSON.Values;

package body Skynet is

   -------------------
   -- Download_File --
   -------------------

   procedure Download_File
     (Path       : League.Strings.Universal_String;
      Skylink    : League.Strings.Universal_String;
      Portal_URL : League.Strings.Universal_String := +"https://siasky.net")
   is
      use type League.Strings.Universal_String;

      Hash : constant League.Strings.Universal_String :=
        Skylink.Tail_From (URI_Skynet_Prefix'Length);
      URL  : constant League.Strings.Universal_String :=
        Portal_URL & Hash;
      Response : constant AWS.Response.Data := AWS.Client.Get
        (URL.To_UTF_8_String,
         Follow_Redirection => True);
      Input  : AWS.Resources.File_Type;
      Output : Ada.Streams.Stream_IO.File_Type;
      Buffer : Ada.Streams.Stream_Element_Array (1 .. 1024);
      Last   : Ada.Streams.Stream_Element_Count;
   begin
      if AWS.Response.Status_Code (Response) not in AWS.Messages.Success then
         raise Program_Error with "request fails";
      end if;

      AWS.Response.Message_Body (Response, Input);
      Ada.Streams.Stream_IO.Create (Output, Name => Path.To_UTF_8_String);

      loop
         AWS.Resources.Read (Input, Buffer, Last);
         exit when Last in 0;
         Ada.Streams.Stream_IO.Write (Output, Buffer (1 .. Last));
      end loop;

      Ada.Streams.Stream_IO.Close (Output);
      AWS.Resources.Close (Input);
   end Download_File;

   -----------------
   -- Upload_File --
   -----------------

   procedure Upload_File
     (Path    : League.Strings.Universal_String;
      Skylink : out League.Strings.Universal_String;
      Options : Upload_Options := (others => <>))
   is
      use type Ada.Streams.Stream_Element_Count;

      type Simple_Stream (Size : Ada.Streams.Stream_Element_Count) is
        new Ada.Streams.Root_Stream_Type with
      record
         Last   : Ada.Streams.Stream_Element_Offset := 0;
         Buffer : Ada.Streams.Stream_Element_Array (1 .. Size);
      end record;

      procedure Read
        (Self : in out Simple_Stream;
         Item : out Ada.Streams.Stream_Element_Array;
         Last : out Ada.Streams.Stream_Element_Offset) is null;

      procedure Write
        (Self : in out Simple_Stream;
         Item : Ada.Streams.Stream_Element_Array);

      type Simple_Stream_Access is access all Simple_Stream;

      procedure Read_File
        (File_Name : String;
         Stream    : Simple_Stream_Access);

      procedure Free is new Ada.Unchecked_Deallocation
        (Simple_Stream, Simple_Stream_Access);

      ---------------
      -- Read_File --
      ---------------

      procedure Read_File
        (File_Name : String;
         Stream    : Simple_Stream_Access)
      is
         Input  : Ada.Streams.Stream_IO.File_Type;
         Buffer : Ada.Streams.Stream_Element_Array (1 .. 1024);
         Last   : Ada.Streams.Stream_Element_Count;
      begin
         Ada.Streams.Stream_IO.Open
           (Input, Ada.Streams.Stream_IO.In_File, File_Name);

         loop
            Ada.Streams.Stream_IO.Read (Input, Buffer, Last);
            exit when Last in 0;
            Stream.Write (Buffer (1 .. Last));
         end loop;

         Ada.Streams.Stream_IO.Close (Input);
      end Read_File;

      -----------
      -- Write --
      -----------

      procedure Write
        (Self : in out Simple_Stream;
         Item : Ada.Streams.Stream_Element_Array) is
      begin
         Self.Buffer (Self.Last + 1 .. Self.Last + Item'Length) := Item;
         Self.Last := Self.Last + Item'Length;
      end Write;

      Boundary_Size : constant := 32;

      File_Name : constant String := Path.To_UTF_8_String;
      Base_Name : constant String := Ada.Directories.Simple_Name (File_Name);
      CD        : constant String := AWS.Messages.Content_Disposition
        (Format   => "form-data",
         Name     => Options.Portal.File_Fieldname.To_UTF_8_String,
         Filename => Base_Name);

      File_Size : constant Ada.Directories.File_Size :=
        Ada.Directories.Size (File_Name);

      Buffer_Size : constant Ada.Streams.Stream_Element_Count :=
        2 + Boundary_Size + 2  --  --BOUNDARY<CRLF>
          + CD'Length + 2 + 2  --  Content_Disposition<CRLF><CRLF>
        + Ada.Streams.Stream_Element_Count (File_Size)
        + 2                           --  <CRLF>
        + 2 + Boundary_Size + 2 + 2;  --  --BOUNDARY--<CRLF>

      CRLF      : constant String :=
        (Ada.Characters.Latin_1.CR, Ada.Characters.Latin_1.LF);

      Boundary    : constant String := AWS.Utils.Random_String (Boundary_Size);
      Stream      : Simple_Stream_Access := new Simple_Stream (Buffer_Size);
      Response    : AWS.Response.Data;
      URL         : League.Strings.Universal_String;
      Document    : League.JSON.Documents.JSON_Document;
   begin
      URL.Append (Options.Portal.URL);
      URL.Append ("/");
      URL.Append (Options.Portal.Upload_Path);
      String'Write (Stream, "--");
      String'Write (Stream, Boundary);
      String'Write (Stream, CRLF);
      String'Write (Stream, CD);
      String'Write (Stream, CRLF);
      String'Write (Stream, CRLF);
      Read_File (File_Name, Stream);
      String'Write (Stream, CRLF);
      String'Write (Stream, "--");
      String'Write (Stream, Boundary);
      String'Write (Stream, "--");
      String'Write (Stream, CRLF);

      pragma Assert (Stream.Last = Stream.Size);

      Response := AWS.Client.Post
        (URL          => URL.To_UTF_8_String,
         Data         => Stream.Buffer,
         Content_Type => "multipart/form-data; boundary=" & Boundary);

      Free (Stream);

      if AWS.Response.Status_Code (Response) not in AWS.Messages.Success then
         raise Program_Error with "request fails";
      end if;

      Document := League.JSON.Documents.From_JSON
        (AWS.Response.Message_Body (Response));

      Skylink.Clear;
      Skylink.Append (URI_Skynet_Prefix);
      Skylink.Append (Document.To_JSON_Object.Value (+"skylink").To_String);
   end Upload_File;

end Skynet;
