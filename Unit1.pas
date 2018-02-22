unit Unit1;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs,
  FMX.Objects;

type
  TTestForm = class(TForm)
    ImageCircle: TImage;
    Rectangle1: TRectangle;
    Rectangle2: TRectangle;
    Rectangle3: TRectangle;
    procedure FormShow(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  TestForm: TTestForm;

implementation

{$R *.fmx}

uses math;

type
  TOpacityMap = Array[0..4095] of PByteArray;

procedure CreateAntiAliasedCircleOpacityMap(var OpacityMap : TOpacityMap; srcWidth,srcHeight : Integer; CenterX, CenterY, Radius, LineWidth, Feather: single);
// original code found here :
// http://users.atw.hu/delphicikk/listaz.php?id=2372&oldal=15
{Create a circle opacity map. parts outside the circle will get alpha value 0, parts inside will get alpha value 255, and in the antialiased area (feather), the pixels will get values inbetween.

Parameters:

Bitmap:
The bitmap to draw on

Color:
The circle's fill color

CenterX, CenterY:
The center of the circle (float precision). Note that [0, 0] would be the center of the first pixel. To draw in the exact middle of a 100x100 bitmap, use CenterX = 49.5 and CenterY = 49.5

Radius:
The radius of the drawn circle in pixels (float precision)

LineWidth:
The line width of the drawn circle in pixels (float precision)

Feather:
The feather area. Use 1 pixel for a 1-pixel antialiased area. Pixel centers outside 'Radius + Feather / 2' become 0, pixel centers inside 'Radius - Feather/2' become 255. Using a value of 0 will yield a bilevel image. Note that Feather must be equal or smaller than LineWidth (or it will be adjusted internally)
}
var
  x, y                       : integer;
  LX, RX, LY, RY             : integer;
  Fact                       : integer;
  ROPF2, ROMF2, RIPF2, RIMF2 : single;
  OutRad, InRad              : single;
  SqY, SqDist                : single;
  sqX                        : array of single;
begin
  {Determine some helpful values (singles)}
  OutRad := Radius + LineWidth / 2;
  InRad  := Radius - LineWidth / 2;
  ROPF2  := sqr(OutRad + Feather / 2);
  ROMF2  := sqr(OutRad - Feather / 2);
  RIPF2  := sqr(InRad + Feather / 2);
  RIMF2  := sqr(InRad - Feather / 2);

  {Determine bounds:}
  LX     := Max(floor(CenterX - ROPF2), 0);
  RX     := Min(ceil(CenterX + ROPF2), srcWidth - 1);
  LY     := Max(floor(CenterY - ROPF2), 0);
  RY     := Min(ceil(CenterY + ROPF2), srcHeight - 1);

  {Checks}
  if Feather > LineWidth then Feather := LineWidth;

  {Optimization run: find squares of X first}
  SetLength(SqX, RX - LX + 1);
  for x := LX to RX do SqX[x - LX] := sqr(x - CenterX);

  {Loop through Y values to create opacity map}
  for y := LY to RY do
  begin
    GetMem(OpacityMap[y],srcWidth);
    //FillChar(OpacityMap[y]^,srcBitmap.Width,0);
    //P := Bitmap.Scanline[y];
    SqY := Sqr(y - CenterY);
    {Loop through X values}
    for x := LX to RX do
    begin
      {Determine squared distance from center for this pixel}
      SqDist := SqY + SqX[x - LX];
      {Now first check if we're completely inside (most often)}
      if SqDist < RIMF2 then
      begin
        {We're on the disk inside everything}
        OpacityMap[y][x] := 255;
      end
        else
      begin
        {Completely outside?}
        if SqDist < ROPF2 then
        begin
          {Inside outer line - feather?}
          if SqDist < ROMF2 then
          begin
            {Check if we're in inside feather area}
            if SqDist < RIPF2 then
            begin
              {We are in the feather area of inner line, now mix the color}
              //Fact := round(((sqrt(sqdist) - InRad) * 2 / Feather) * 127.5 + 127.5);
              //OpacityMap[y][x] := Max(0, Min(Fact, 255)); {just in case limit to [0, 255]}
              OpacityMap[y][x] := 255;
            end
              else
            begin
              {On the line}
              OpacityMap[y][x] := 255;
            end;
          end
            else
          begin
            {We are in the feather area of outer line, now mix the color}
            Fact := round(((OutRad - sqrt(sqdist)) * 2 / Feather) * 127.5 + 127.5);
            OpacityMap[y][x] := Max(0, Min(Fact, 255)); {just in case limit to [0, 255]}
          end;
        end
          else
        begin
          {Outside everything}
          OpacityMap[y][x] := 0;
        end;
      end;
    end;
  end;
end;



procedure DrawAntiAliasedCircle(srcBitmap: TBitmap; FillColor : TAlphaColor; CenterX, CenterY, Radius, LineWidth, Feather: single);
var
  FillR                      : Integer;
  FillG                      : Integer;
  FillB                      : Integer;
  FillRGB                    : Integer;
  OpacityMap                 : TOpacityMap;
  AlphaScanLine              : Array[0..4095] of TAlphaColor;
  bitmapData                 : FMX.Graphics.TBitmapData;
  tmpScanLine                : Pointer;
  X,Y                        : Integer;
  tmpMS                      : TMemoryStream;

begin
  {Initialization}
  FillR  := TAlphaColorRec(FillColor).R;
  FillG  := TAlphaColorRec(FillColor).G;
  FillB  := TAlphaColorRec(FillColor).B;

  CreateAntiAliasedCircleOpacityMap(OpacityMap, srcBitmap.Width, srcBitmap.Height, CenterX, CenterY, Radius, LineWidth, Feather);

  {create image based on opacity map and free memory}
  If srcBitmap.Map(TMapAccess.Write, bitmapData) then
  try
    FillRGB := (FillR shl 16)+(FillG shl 8)+FillB;

    for Y := 0 to srcBitmap.Height-1 do
    begin
      for X := 0 to srcBitmap.Width-1 do
        AlphaScanLine[X] := (OpacityMap[Y][X] shl 24)+FillRGB; // Opacity

      tmpScanLine := bitmapData.GetScanline(Y);
      AlphaColorToScanLine(@AlphaScanLine,tmpScanLine,srcBitmap.Width,srcBitmap.PixelFormat);
      FreeMem(OpacityMap[Y]);
    end;
  finally
    srcBitmap.Unmap(bitmapData);
  end;

  // Work-around fix
  tmpMS := TMemoryStream.Create;
  srcBitmap.SaveToStream(tmpMS);
  srcBitmap.LoadFromStream(tmpMS);
  tmpMS.Free;
end;


procedure TTestForm.FormShow(Sender: TObject);
begin
  ImageCircle.Bitmap.SetSize(Trunc(ImageCircle.Width),Trunc(ImageCircle.Height));
  DrawAntiAliasedCircle(ImageCircle.Bitmap,TAlphaColorRec.Red,(ImageCircle.Width/2)-0.5, (ImageCircle.Height/2)-0.5, (ImageCircle.Width / 2)-1, 1, 1);
end;

end.
