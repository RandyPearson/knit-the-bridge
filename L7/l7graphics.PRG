* L7Graphics.PRG

#include L7GdiPlus.H

* Test mode
IF PROGRAM(-1) = 1
  * just like __Name__ = "__Main__" in Python
  SET PROCEDURE TO L7PageElement, L7Utils, L7HtmlLib, wwAPI, wwUtils ADDITIVE 
  CLEAR
  LOCAL ;
    loGrp as GpGraphics OF HOME() + "ffc/_gdiplus.vcx", ;
    loRect as GpRectangle OF HOME() + "ffc/_gdiplus.vcx", ;
    loPen as GpPen OF HOME() + "ffc/_gdiplus.vcx"
    
  loRect = NEWOBJECT("GpRectangle", HOME() + "ffc/_gdiplus.vcx")

  loPen = NEWOBJECT("GpPen", HOME() + "ffc/_gdiplus.vcx")
  
  loGrp = NEWOBJECT("GpGraphics", HOME() + "ffc/_gdiplus.vcx")

  loImg = NEWOBJECT("GpBitmap", HOME() + "ffc/_gdiplus.vcx")
  loImg.Create(300, 400)

  loGrp.CreateFromImage(loImg)
  loGrp.Clear(ForceAlpha(RGB(205,205,205)))

  loPen.Create(ForceAlpha(RGB(255,0,0)), 3, 2)
  loRect.Create(5, 5, 200, 20)
  loGrp.DrawRectangle(loPen, loRect)

  loPen.Create(ForceAlpha(RGB(205,0,0)), 3, 2)
  loRect.Create(5, 26, 200, 20)
  loGrp.DrawRectangle(loPen, loRect)

  lcFile = FORCEEXT("tmp_" + SYS(3), "png")
  loImg.SaveToFile(m.lcFile, "image/png")
  GoUrl(FULLPATH(m.lcFile))
ENDIF
RETURN 


* -------------------------------------------------------------------------------------- *
* duplicated as UDF (also method in L7Graphics classes) for convenience
FUNCTION ForceAlpha(tnRGB, tnAlpha)  && was named Fox something
  * defaults Alpha to 255
  LOCAL lnAlpha
  IF EMPTY(m.tnAlpha)
    lnAlpha = 0xFF000000
  ELSE 
    lnAlpha = 0x00000000
  ENDIF
  RETURN BITOR( m.lnAlpha ;
    , BITLSHIFT(BITAND(m.tnRGB,0xFF),16) ;
    , BITAND(m.tnRGB,0x0000FF00) ;
    , BITRSHIFT(BITAND(m.tnRGB,0x00FF0000),16) )
ENDFUNC

* -------------------------------------------------------------------------------------- *
DEFINE CLASS L7Pie AS custom

  *!* Much of L7Pie inspired by or directly from GPPie class and related article from 
  *!* Cesar Chalom. Per his writing:
  *!*  AUTHOR    : CESAR CHALOM  cchalom@hotmail.com
  *!*  REQUIREMENTS   : VFP9 - uses wrapper class _GDIPLUS.VCX
  *!*
  *!*  LICENSE :
  *!*  This class is free; use it on your own risk. 
  *!*  If you use this source code in a product, acknowledgment is not required
  *!*          but would be appreciated. 
  *!*  Nobody is authorized to sell the class unless specific permission is given by the author.

  *-- GDI+ GpImage object
  PROTECTED opieimg
  opieimg = 0
  *-- GDI+ GpGraphics object
  PROTECTED opiegraph
  opiegraph = 0
  *-- GDI+ GpImage object
  PROTECTED olegendimg
  olegendimg = 0
  *-- GDI+ GpGraphics object
  PROTECTED olegendgraph
  olegendgraph = 0
  *-- GDI+ GpImage object
  PROTECTED omainimg
  omainimg = 0
  *-- GDI+ GpGraphics object
  PROTECTED omaingraph
  omaingraph = 0
  *-- GDI+ GpSolidBrush object
  PROTECTED osolidbrush
  osolidbrush = 0
  *-- GDI+ GpHatchBrush object
  PROTECTED o3dbrush
  o3dbrush = 0
  *-- GDI+ GpHatchBrush object
  PROTECTED obwbrush
  obwbrush = 0
  *-- GDI+ GpPen object
  PROTECTED oborderpen
  oborderpen = 0
  *-- GDI+ GpFont object
  PROTECTED ofont
  ofont = 0
  *-- Width of Pie
  PROTECTED npiewidth
  npiewidth = 0
  *-- Height of Pie
  PROTECTED npieheight
  npieheight = 0
  *-- Sum of the field values
  PROTECTED ntotal
  ntotal = NULL  && was 0
  *-- Backcolor of the Images
  backcolor = (RGB(255,255,255))
  *-- Title Caption to show on top
  title = ""
  *-- Font to be used in title and legends
  fontname = "Verdana"
  *-- Font color to be used in Title (RGB)
  titlefontcolor = 0
  *-- Font size to be used in Title
  titlefontsize = 22
  *-- Font Style to be used in Title - B=bold, I=italic, U=underline, S=strikeout
  titlefontstyle = ""
  *-- Font color to be used as the backcolor of the Title
  titlebackcolor = (rgb(255,255,255))
  *-- .T. Allows exibition of legends
  legendshow = .T.
  *-- The legend position in the image created 1=TopLeft 2=BottomLeft 3=TopRight 4=BottomRight
  legendposition = 3
  *-- Width of the legend image
  PROTECTED legendwidth
  legendwidth = 180
  *-- Fore color of text legend (RGB)
  legendfontcolor = 0
  *-- Font size of text legend
  legendfontsize = 12
  *-- Font Style to be used in TextLegend - B=bold, I=italic, U=underline, S=strikeout
  legendfontstyle = ""
  *-- BackColor of legend (RGB)
  legendbackcolor = (RGB(255,255,255))
  *-- Width in pixels of legend border
  legendborder = 0
  *-- Border color of Legend Image
  legendbordercolor = 0
  *-- Width of shape border = 0=no shape
  legendshapeborder = 1
  *-- GDI+ GpColorObject
  PROTECTED oslicecolor
  oslicecolor = 0
  *-- ALIAS name of cursor of table containing information to draw the pie chart
  sourcealias = ""
  *-- Name of field from cursor "SourceAlias" that contains VALUE information
  pievaluefield = ""
  *-- Name of field from cursor "SourceAlias" that contains LEGEND information
  pielegendfield = ""
  *-- Name of field from cursor "SourceAlias" that contains DETACH information. If value = .T., slice will be detached.
  piedetachfield = ""
  *-- Name of field from cursor "SourceAlias" that contains COLOR to be used in slices and legends. If not passed, random colors will be used.
  piecolorfield = ""
  *-- Name of field from cursor "SourceAlias" that contains TEXT to be drawn INSIDE the slices.
  pieslicetextfield = ""
  *-- Border Color of pie slices
  piebordercolor = 0
  *-- Border Width in pixels of pie slices.
  piebordersize = 1
  *-- Height of  3D effect in pixels
  height3d = 30
  *-- Distance in pixels to Detach slices from the Pie.
  detachdistance = 30
  *-- 1=Plain Chart  2=3D Chart
  style = 1
  *-- .F. = default colored graphics  .T.=monochrome black and white graphics
  monochrome = .F.
  *-- Fore color of Slice text legend (RGB)
  pielegendfontcolor = 0
  *-- Font Size of Slice text legend (RGB)
  pielegendfontsize = 12
  *-- Font Style to be used in Slice TextLegend - B=bold, I=italic, U=underline, S=strikeout
  pielegendfontstyle = ""
  *-- BackColor of Slice egend (RGB)
  pielegendbackcolor = (RGB(255,255,255))
  *-- Distance in percentage from center if pie to draw the legend. <1=inside the slice   1=in the border of slice   >1=outside the slice
  pielegenddistance = 0.75
  *-- Width of Pie
  piewidth = 220
  *-- Height of Pie
  pieheight = 220
  *-- Style of Legend drawn inside slices 1=opaque 0=transparent
  pielegendstyle = 1
  *-- File Name containing Image created
  imagefile = NULL  && was ""
  *-- Name of field from cursor "SourceAlias" that contains information if this slice will appear or not in the chart. .T.=hides the slice.
  piehiddenfield = ""
  PROTECTED legendheight
  legendheight = 0
  *-- Logical, determines ithe use of gradient colors
  gradient = .F.
  *-- GDI+ GradientBrush Object
  PROTECTED ogradbrush
  ogradbrush = 0
  *-- Handle for GDI+ Path Gradient Brush
  PROTECTED gradbrushhandle
  gradbrushhandle = 0
  PROTECTED gradbrushpathhandle
  gradbrushpathhandle = 0
  gradientlevel = 5
  legendfield = ""
  Name = "L7Pie"

  DIMENSION aSliceColors[18] && used if no color field specified, or can be used to fill a structure
        aSliceColors[1] = RGB(180,180,224)
        aSliceColors[2] = RGB(224,224,0)
        aSliceColors[3] = RGB(200,244,200)
        aSliceColors[4] = RGB(224,200,200)
        aSliceColors[5] = RGB(233,163,201)
        aSliceColors[6] = RGB(240,200,240)
        aSliceColors[7] = RGB(0,190,0)
        aSliceColors[8] = RGB(224,160,60)
        aSliceColors[9] = RGB(100,180,180)
        aSliceColors[10] = RGB(190,0,0)
        aSliceColors[11] = RGB(128,128,128)
        aSliceColors[12] = RGB(224,128,128)
        aSliceColors[13] = RGB(0,0,190)
        aSliceColors[14] = RGB(155,114,77)
        aSliceColors[15] = RGB(200,200,200)
        aSliceColors[16] = RGB(200,200,0)
        aSliceColors[17] = RGB(0,128,64)
        aSliceColors[18] = RGB(221,0,110)

  * -------------------------------------------------------------------------------------- *
  PROTECTED PROCEDURE preparePieCursor
    LOCAL lcAlias, lcValue, lcLegend, lcDetach, lcColor, lcSliceText, lcSliceHidden
    WITH THIS
      lcAlias       = .SourceAlias
      lcValue       = .PieValueField
      lcLegend      = IIF(EMPTY(.PieLegendField), "SPACE(0)", .PieLegendField)
      lcDetach      = IIF(EMPTY(.PieDetachField), ".F.", .PieDetachField)
      lcColor       = IIF(EMPTY(.PieColorField) , "EVALUATE('00000000')", .PieColorField)
      lcSliceText   = IIF(EMPTY(.PieSliceTextField), ".F.", .PieSliceTextField)
      lcSliceHidden = IIF(EMPTY(.PieHiddenField), ".F.", .PieHiddenField)

      IF EMPTY(lcAlias) OR EMPTY(lcValue) OR ("CC" <> (VARTYPE(lcAlias) + VARTYPE(lcValue)))
        ERROR "Must specify properties SourceAlias and PieValueField"
        RETURN .F.
      ENDIF 

      SELECT &lcValue  AS nValue, ;
        &lcLegend AS cLegend, ;
        &lcDetach AS lDetach, ;
        &lcColor  AS nColor, ;
        &lcSliceText AS cSliceText, ;
        &lcSliceHidden AS lSliceHidden ;
        FROM &lcAlias ;
        INTO CURSOR PieCursor_ READWRITE 
      SELECT PieCursor_

      IF EMPTY(.PieColorField)
*!*          DIMENSION aColors(18)
*!*          aColors(1) = RGB(0,0,224)
*!*          aColors(2) = RGB(224,224,0)
*!*          aColors(3) = RGB(200,244,200)
*!*          aColors(4) = RGB(224,200,200)
*!*          aColors(5) = RGB(233,163,201)
*!*          aColors(6) = RGB(200,200,240)
*!*          aColors(7) = RGB(0,190,0)
*!*          aColors(8) = RGB(224,160,60)
*!*          aColors(9) = RGB(100,180,180)
*!*          aColors(10) = RGB(190,0,0)
*!*          aColors(11) = RGB(128,128,128)
*!*          aColors(12) = RGB(224,128,128)
*!*          aColors(13) = RGB(0,0,190)
*!*          aColors(14) = RGB(155,114,77)
*!*          aColors(15) = RGB(200,200,200)
*!*          aColors(16) = RGB(200,200,0)
*!*          aColors(17) = RGB(0,128,64)
*!*          aColors(18) = RGB(221,0,110)

*!*          aColors(1) = RGB(0,0,255)
*!*          aColors(2) = RGB(255,255,0)
*!*          aColors(3) = RGB(0,255,64)
*!*          aColors(4) = RGB(255,0,0)
*!*          aColors(5) = RGB(255,0,255)
*!*          aColors(6) = RGB(0,0,160)
*!*          aColors(7) = RGB(0,190,0)
*!*          aColors(8) = RGB(255,160,60)
*!*          aColors(9) = RGB(100,180,180)
*!*          aColors(10) = RGB(190,0,0)
*!*          aColors(11) = RGB(128,128,128)
*!*          aColors(12) = RGB(255,128,128)
*!*          aColors(13) = RGB(0,0,190)
*!*          aColors(14) = RGB(155,114,77)
*!*          aColors(15) = RGB(200,200,200)
*!*          aColors(16) = RGB(200,200,0)
*!*          aColors(17) = RGB(0,128,64)
*!*          aColors(18) = RGB(221,0,110)

        SCAN
          ** REPLACE PieCursor_.nColor WITH aColors(RECNO())
          ** REPLACE PieCursor_.nColor WITH aColors(1 + MOD(RECNO(), 18))
          REPLACE PieCursor_.nColor WITH THIS.aSliceColors(1 + MOD(RECNO(), 18))
        ENDSCAN
      ENDIF
    ENDWITH
  ENDPROC  && preparePieCursor
  * -------------------------------------------------------------------------------------- *
  PROTECTED FUNCTION CalculateTotal
    IF ISNULL(THIS.nTotal)
      CALCULATE SUM(PieCursor_.nValue) TO THIS.nTotal  && subclass/fix later
    ENDIF 
  ENDPROC 

  * -------------------------------------------------------------------------------------- *
  PROCEDURE create
    WITH THIS
      IF .Gradient
        .declareGdip()
      ENDIF 
      IF .STYLE = 1 &&Plain
        .Height3D = 0
      ENDIF
      IF NOT .PreparePieCursor()
        This.Destroy
        RETURN .F.
      ENDIF
      .CreateGpObjects
      .CreatePie
      IF .LegendShow
        .CreateLegend
      ENDIF
      .CreateMainImg
    ENDWITH 
    RETURN
  ENDPROC  && create

  * -------------------------------------------------------------------------------------- *
  PROTECTED PROCEDURE createPie
    WITH THIS
      IF .STYLE = 1 && Plain (vs 3D)
        .Height3D = 0
      ENDIF

      .CalculateTotal()

      LOCAL lnStart, lnSweep, lnX, lnY, x1, y1, lnDetachAngle
      lnStart = 270 && Start angle

      lnX = 0 + .DetachDistance
      lnY = 0 + .DetachDistance
      .nPieWidth  = .PieWidth  - 1 - (2*.DetachDistance)
      .nPieHeight = .PieHeight - 1 - (2*.DetachDistance)

      * Draw the RIGHT side of the pie
      SCAN FOR m.lnStart < 450
        x1 = m.lnX
        y1 = m.lnY

        * Calculate Start point and Sweep
        lnSweep = PieCursor_.nValue / .nTotal * 360

        IF PieCursor_.lDetach = .T.
          lnDetachAngle = 360 - (lnStart + (lnSweep / 2))
          x1 = lnX + (COS(DTOR(lnDetachAngle)) * .DetachDistance)
          y1 = lnY - (SIN(DTOR(lnDetachAngle)) * .DetachDistance)
        ENDIF

        IF PieCursor_.lSliceHidden = .F.
          .DrawSlice(x1, y1, lnStart, lnSweep)
        ENDIF
        lnStart = lnStart + lnSweep
      ENDSCAN

      * Draw the LEFT side of the pie
      GO BOTTOM
      lnStart = 270
      DO WHILE lnStart > 90
        x1 = lnX
        y1 = lnY

        * Calculate Start point and Sweep
        lnSweep = (PieCursor_.nValue / .nTotal) * 360
        lnStart = lnStart - lnSweep

        IF PieCursor_.lDetach = .T.
          lnDetachAngle = 360 - (lnStart + (lnSweep / 2))
          x1 = lnX + (COS(DTOR(lnDetachAngle)) * .DetachDistance)
          y1 = lnY - (SIN(DTOR(lnDetachAngle)) * .DetachDistance)
        ENDIF

        IF PieCursor_.lSliceHidden = .F.
          .DrawSlice(x1, y1, lnStart, lnSweep)
        ENDIF
        SKIP -1
      ENDDO
      IF .Gradient
        GdipDeletePath(.GradbrushPathHandle) && Alter Drawing the slices, clear the Path Handle
      ENDIF
      .DrawLegendsonSlices()
    ENDWITH
    RETURN
  ENDPROC  && createPie

  * -------------------------------------------------------------------------------------- *
  PROTECTED PROCEDURE createLegend
    WITH THIS
      .oFont = NEWOBJECT('GpFont', HOME() + 'ffc/_gdiplus.vcx')
      .oFont.CREATE( .FontName ;  && font name
        , .LegendFontSize ;     && size in units below
        , .GetFontStyle(.LegendFontStyle) ; && fontStyle
        , GDIPLUS_Unit_Pixel)           && units

      * Measure the Height of one of the strings to calculate vertical space between legends
      LOCAL loStringSize as GpSize OF HOME() + 'ffc/_gdiplus.vcx'
      lostringsize = .oPieGraph.measurestringa(PieCursor_.cLegend, .oFont)

      LOCAL loGradBrush as GpBrush OF HOME() + 'ffc/_gdiplus.vcx'
      LOCAL lnFator, lnStringHeight, Y1

      lnFator = 1.35
      lnStringHeight = lostringsize.h * m.lnFator
      .LegendHeight = RECCOUNT() * m.lnStringHeight + 20

      .oLegendImg = NEWOBJECT("GpBitmap", HOME() + "ffc/_gdiplus.vcx")
      .oLegendImg.Create(.LegendWidth, .LegendHeight)
      .oLegendGraph = NEWOBJECT('GpGraphics', HOME() + "ffc/_gdiplus.vcx")
      .oLegendGraph.CreatefromImage(.oLegendImg)
      .oLegendGraph.CLEAR(.ForceAlpha(.LegendBackColor))

      LOCAL oMainBrush, lnGradBrush, lnPath, lnCenterColor, lnSurroundColor, lnCount
      LOCAL loTextPoint as GpPoint OF HOME() + 'ffc/_gdiplus.vcx'
      loTextPoint = NEWOBJECT("GpPoint", HOME() + 'ffc/_gdiplus.vcx')
      SCAN 
        y1 = lostringsize.h * m.lnFator * RECNO() - (lnStringHeight/2)

        IF PieCursor_.lSliceHidden = .T. && Don't draw Legends for hidden slices
          LOOP
        ENDIF

        * Create Point in which Text will be drawn
        lotextPoint.Create(35, m.y1)

        * Draw the Text
        .oSolidBrush.BrushColor = .ForceAlpha(.LegendFontColor)
        .oLegendGraph.drawstringa( PieCursor_.cLegend, .oFont, lotextPoint, , .oSolidBrush )

        * Draw legend rectangle
        IF .Monochrome
          * tnStyle, tvForeColor, tvBackColor
          .oBWBrush.CREATE(RECNO()*2, .ForceAlpha(0), 0xffffffff)
          .oLegendGraph.fillRectangle(.oBWBrush, 15, Y1, lostringsize.h, lostringsize.h)
        ELSE

          IF .Gradient
            lnCenterColor   = .ChangeColor(PieCursor_.nColor,.GradientLevel * 15)
            lnSurroundColor = PieCursor_.nColor

            * Assign GradientBrush colors
            lnGradBrush = 0 
            lnPath = 0 
            lnCount = 1
            GdipCreatePath(0, @lnPath) 
            GdipAddPathRectangle(m.lnPath, 15, y1, lostringsize.h, lostringsize.h) 
            GdipCreatePathGradientFromPath(m.lnPath, @lnGradBrush) 
            GdipSetPathGradientSurroundColorsWithCount(m.lnGradBrush, .ForceAlpha(m.lnSurroundColor), @lnCount)
            GdipSetPathGradientCenterColor(m.lnGradBrush, .ForceAlpha(m.lnCenterColor))
            * Assign Handle to GpBrush object
            loGradBrush = NEWOBJECT("GpBrush", HOME() + 'ffc/_gdiplus.vcx','' ) && Borrowed to use with Gradient Brush
            loGradBrush.Destroy()
            loGradBrush.SetHandle(m.lnGradBrush,.T.)
            .oLegendGraph.FillRectangle(loGradBrush, 15, Y1, lostringsize.h, lostringsize.h)
            GdipDeletePath(m.lnPath)
          ELSE
            * Draw the Normal Slice using the Solid Brush
            .oSolidBrush.BrushColor = .ForceAlpha(PieCursor_.nColor)
            .oLegendGraph.FillRectangle(.oSolidBrush, 15, Y1, lostringsize.h, lostringsize.h)
          ENDIF 
        ENDIF

        IF .LegendShapeBorder > 0
          .oBorderPen.Create(IIF( .Monochrome, .ForceAlpha(0), .ForceAlpha(.PieBorderColor)), .LegendShapeBorder)
          .oLegendGraph.DrawRectangle(.oBorderPen, 15, Y1, lostringsize.h, lostringsize.h)
        ENDIF 
      ENDSCAN

      IF .LegendBorder > 0
        .oBorderPen.Create(IIF( .Monochrome, .ForceAlpha(0), .ForceAlpha(.LegendBorderColor)), .LegendBorder)
        .oLegendGraph.DrawRectangle(.oBorderPen, 3, 3, .LegendWidth - 6, .LegendHeight - 7)
      ENDIF 
    ENDWITH 

    IF .Gradient
      RELEASE loGradBrush
      STORE .Null. TO loPathGradBrush
      IF m.lnPath != 0
        GdipDeletePath(m.lnPath)
      ENDIF 
    ENDIF
  ENDPROC && createLegend
  * -------------------------------------------------------------------------------------- *
  PROTECTED PROCEDURE createMainImg
    LOCAL lnTitleHeight, lnTitleWidth, lnFator, ;
      lnStringHeight, lnNewWidth, lnNewHeight, x1, y1

    WITH THIS
      lnTitleHeight = 0  && these stay 0 if no title
      lnTitleWidth  = 0

      IF NOT EMPTY(.Title)
        .oFont.CREATE( .FontName ;  && font name
          , .TitleFontSize ;           && size in units below
          , .GetFontStyle(.TitleFontStyle) ; && fontStyle
          , GDIPLUS_Unit_Pixel )      && units

        * Measure the Height of the Graphics Main Caption
        LOCAL loStringSize as GpSize OF HOME() + "ffc/_gdiplus.vcx"
        loStringSize = .oPieGraph.measureStringA(.Title, .oFont)
        lnTitleHeight = loStringSize.H
        lnTitleWidth  = loStringSize.W
      ENDIF

      lnFator = 1.5
      lnStringHeight = m.lnTitleHeight * m.lnFator
      lnNewWidth  = .PieWidth + 13 + IIF(.LegendShow, .LegendWidth + 12, 0)
      lnNewHeight = MAX(.PieHeight, .LegendHeight) + .Height3D + (m.lnTitleHeight * 2) + 10

      LOCAL loMainImg as GpBitmap OF HOME() + "ffc/_gdiplus.vcx"
      LOCAL loMainGraph as GpGraphics OF HOME() + "ffc/_gdiplus.vcx"
      loMainImg = NEWOBJECT("GpBitmap", HOME() + "ffc/_gdiplus.vcx")
      loMainImg.Create(m.lnNewWidth, m.lnNewHeight)
      loMainGraph = NEWOBJECT('GpGraphics', HOME() + "ffc/_gdiplus.vcx")
      loMainGraph.CreateFromImage(loMainImg)
      loMainGraph.Clear(0x33FFFFFF)  && .ForceAlpha(.BackColor))

      * Calculate Legend Positions: 1 = TopLeft   2 = bottLeft   3 = TopRight   4 = BottRight
      DO CASE 
      CASE .LegendPosition = 1 && TopLeft
        loMainGraph.DrawImageAt(.oPieImg, m.lnNewWidth - .PieWidth - 10, m.lnTitleHeight * 2)
        IF .LegendShow
          loMainGraph.DrawImageAt(.oLegendImg, 10, m.lnTitleHeight * 2)
        ENDIF 

      CASE .LegendPosition = 2 && BottomLeft
        loMainGraph.DrawImageAt(.oPieImg, m.lnNewWidth - .PieWidth - 10, m.lnTitleHeight * 2)
        IF .LegendShow
          loMainGraph.DrawImageAt(.oLegendImg, 10, m.lnNewHeight - .LegendHeight - 10)
        ENDIF 
      CASE .LegendPosition = 3 && TopRight
        loMainGraph.DrawImageAt(.oPieImg, 10, (m.lnTitleHeight * 2))
        IF .LegendShow
          loMainGraph.DrawImageAt(.oLegendImg, m.lnNewWidth - .LegendWidth - 10, m.lnTitleHeight * 2)
        ENDIF 
      CASE .LegendPosition = 4 && BottomRight
        loMainGraph.DrawImageAt(.oPieImg, 10, (m.lnTitleHeight * 2))
        IF .LegendShow
          loMainGraph.DrawImageAt(.oLegendImg, m.lnNewWidth - .LegendWidth - 10, m.lnNewHeight - .LegendHeight - 10)
        ENDIF 
      ENDCASE 

      * Drawing the title
      IF NOT EMPTY(.Title)
        * Create Rectangle in which text will be drawn
        x1 = (m.lnNewWidth - m.lnTitleWidth) / 2
        y1 = m.lnTitleHeight / 2

        LOCAL loTextRect as GpRectangle OF HOME() + 'ffc/_gdiplus.vcx'
        loTextRect = NEWOBJECT('GpRectangle', HOME() + 'ffc/_gdiplus.vcx','',;
          x1, y1, m.lnTitleWidth, m.lnTitleHeight )

        * Draw the Background Rectangle
        IF .TitleBackColor <> .BackColor AND NOT .Monochrome
          .oSolidBrush.BrushColor = .ForceAlpha(.TitleBackColor)
          loMainGraph.FillRectangle(.oSolidBrush, lotextRect)
        ENDIF 

        * Get a basic string format object, then set properties
        LOCAL loStringFormat as GpStringFormat OF HOME() + 'ffc/_gdiplus.vcx'
        loStringFormat = NEWOBJECT('GpStringFormat', HOME() + 'ffc/_gdiplus.vcx')
        loStringFormat.Create()
        loStringFormat.Alignment = GDIPLUS_STRINGALIGNMENT_Center
        loStringFormat.lineAlignment = GDIPLUS_STRINGALIGNMENT_Center

        * Draw the Title Text
        .oSolidBrush.BrushColor = IIF(.Monochrome, .ForceAlpha(0), .ForceAlpha(.TitleFontColor))
        loMainGraph.drawStringA(.Title, .oFont, lotextRect, loStringFormat, .oSolidBrush)
      ENDIF 

      IF ISNULL(.ImageFile)
        .ImageFile = "tmp" + SYS(2015) + ".PNG"
      ENDIF 
      loMainImg.SavetoFile(.ImageFile, "image/png")

    ENDWITH
    RETURN
  ENDPROC  && createMainImg
  * -------------------------------------------------------------------------------------- *
  FUNCTION ForceAlpha(tnRGB, tnAlpha)  && was named Fox something
    * defaults Alpha to 255
    LOCAL lnAlpha
    IF EMPTY(m.tnAlpha)
      lnAlpha = 0xFF000000
    ELSE 
      lnAlpha = 0x00000000
    ENDIF
    RETURN BITOR( m.lnAlpha ;
      , BITLSHIFT(BITAND(m.tnRGB,0xFF),16) ;
      , BITAND(m.tnRGB,0x0000FF00) ;
      , BITRSHIFT(BITAND(m.tnRGB,0x00FF0000),16) )
  ENDFUNC

  * -------------------------------------------------------------------------------------- *
  PROTECTED PROCEDURE drawSlice(tnX, tnY, tnStart, tnSweep)
    LOCAL oMainBrush, oBaseBrush, n, x, y

    WITH This
      * Prepare Brushes
      IF .Monochrome
        .oSliceColor.FoxRGB = .ForceAlpha(RGB(255,255,255)) && white
      ELSE
        .oSliceColor.FoxRGB = PieCursor_.nColor
      ENDIF

      .oSolidBrush.BrushColor = .oSliceColor
      .o3DBrush.CREATE(GDIPLUS_HatchStyle_50Percent, .oSliceColor, .ForceAlpha(0)) && tnStyle, tvForeColor, tvBackColor

      IF .Gradient AND NOT .Monochrome
        .Creategradientbrush(.ChangeColor(PieCursor_.nColor,.GradientLevel*20),PieCursor_.nColor) && Center, Surround 
        .oSolidBrush.BrushColor = This.MakeDarker(PieCursor_.nColor, 0.8)
        oMainBrush = .oGradBrush
        oBaseBrush = .oSolidBrush
      ELSE
        oMainBrush = .oSolidBrush
        oBaseBrush = .o3DBrush
      ENDIF 

      * Draw the 3D Slice using the Hatch Brush
      IF .STYLE = 2 && 3D
        tnY = tnY + .Height3D
        * Draw the contour of the 3D Slice
        .oPieGraph.FillPie(oBaseBrush , tnX, tnY, .nPieWidth, .nPieHeight, tnStart, tnSweep)
        .oPieGraph.DrawPie(.oBorderPen, tnX, tnY, .nPieWidth, .nPieHeight, tnStart, tnSweep)

        FOR N = 1 TO .Height3D
          tnY = tnY - 1
          * Draw the Normal Slice using the Solid Brush
          .oPieGraph.fillpie(oBaseBrush, tnX, tnY, .nPieWidth, .nPieHeight, tnStart, tnSweep) && draw the slice
          IF tnStart > 90
            .oPieGraph.drawarc(.oBorderPen, tnX, tnY, .nPieWidth, .nPieHeight, tnStart, 0.25)
          ENDIF 
          .oPieGraph.drawarc(.oBorderPen, tnX, tnY, .nPieWidth, .nPieHeight, tnStart + tnSweep - .25, 0.35)
        ENDFOR

        * Draw border line from ceter of pie
        x = (.nPieWidth / 2) + tnX
        y = (.nPieHeight / 2) + tnY
        .oPieGraph.DrawLine(.oBorderPen, X, Y, X, Y + .Height3D)
      ENDIF

      IF .Monochrome
        * tnStyle, tvForeColor, tvBackColor
        .oBWBrush.CREATE(RECNO()*2, .ForceAlpha(0), 0xffffffff)
        .oPieGraph.fillpie(.oBWBrush, tnX, tnY, .nPieWidth, .nPieHeight, tnStart, tnSweep) && draw the slice
      ELSE
        * Draw the Normal Slice using the Solid Brush
        .oPieGraph.fillpie(oMainBrush, tnX, tnY, .nPieWidth, .nPieHeight, tnStart, tnSweep)
      ENDIF

      IF tnStart > 90
        * Draw the Black contour of the slice using the Pen object
        .oPieGraph.drawpie(.oBorderPen, tnX, tnY, .nPieWidth, .nPieHeight, tnStart, tnSweep)
      ELSE
        .oPieGraph.drawarc(.oBorderPen, tnX, tnY, .nPieWidth, .nPieHeight, tnStart, tnSweep)
        .oPieGraph.drawpie(.oBorderPen, tnX, tnY, .nPieWidth, .nPieHeight, tnStart + tnSweep - 0.25, 0.25)
      ENDIF

    ENDWITH 
    RETURN
  ENDPROC

  * -------------------------------------------------------------------------------------- *
  PROTECTED PROCEDURE drawLegendsOnSlices
    LOCAL lnCenterX, lnCenterY, lnRadiusW, lnRadiusH, lnStart, lnSweep, lnAngle, ;
      x1, y1, lnChars, lnLines, lnWidth

    WITH This
      * Draw Legends over the slices
      * Create Font Object
      .oFont = NEWOBJECT('GpFont', HOME() + 'ffc/_gdiplus.vcx')
      .oFont.CREATE( .FontName ;  && font name
        , .PieLegendFontSize ;                 && size in units below
        , .GetFontStyle(.PieLegendFontStyle) ; && fontStyle
        , GDIPLUS_Unit_Pixel )      && units

      * Calculate positions
      lncenterx = (.nPieWidth / 2) + .DetachDistance
      lncentery = (.nPieHeight / 2) + .DetachDistance

      lnradiusW = (.nPieWidth / 2) * .PieLegendDistance
      lnradiusH = (.nPieHeight / 2) * .PieLegendDistance

      lnStart = 270

      LOCAL loStringsSize as GpSize OF HOME() + 'ffc/_gdiplus.vcx'
      LOCAL loTextRect as GpRectangle OF HOME() + 'ffc/_gdiplus.vcx'
      loTextRect = NEWOBJECT('GpRectangle', HOME() + 'ffc/_gdiplus.vcx')

      SCAN
        lnSweep = PieCursor_.nValue / .nTotal * 360
        IF NOT EMPTY(PieCursor_.cSliceText)
          lnangle = 360 - (lnStart + lnSweep / 2)
          lnangle = 360 - (lnStart + (lnSweep / 2))
          * If detached, need to compensate
          x1 = lncenterx + (COS(DTOR(lnangle)) * ((lnradiusW + lnradiusH) /2 + IIF(PieCursor_.lDetach,.DetachDistance,0)))
          y1 = lncentery - (SIN(DTOR(lnangle)) * (lnradiusH + IIF(PieCursor_.lDetach,.DetachDistance,0)))

          * Get measures from the string so that we can center correctly
          lnchars = 0
          lnlines = 0
          lostringsize = .oPieGraph.measurestringa(PieCursor_.cSliceText, .oFont, , , @lnchars, @lnlines)
          lnwidth = lostringsize.w
          .nPieHeight = lostringsize.h

          * Create Rectangle in which text will be drawn
          loTextrect.Create(x1 - (lnwidth/2) , y1 - (.nPieHeight/2), lostringsize.w, lostringsize.h)

          * Draw an empty White rectangle under the text
          IF .PieLegendStyle = 1 && 0 = transparent  1 = opaque
            .oSolidBrush.BrushColor = .ForceAlpha(.PieLegendBackColor) && Background Color
            .oPieGraph.fillrectangle(.oSolidBrush, lotextrect)
          ENDIF

          * Draw the Text
          .oSolidBrush.BrushColor = .ForceAlpha(.PieLegendFontColor) && Black
          .oPieGraph.drawstringa( PieCursor_.cSliceText, .oFont, lotextrect, , .oSolidBrush )
        ENDIF
        lnStart = m.lnStart + m.lnSweep
      ENDSCAN
    ENDWITH 
    RETURN
  ENDPROC

  * -------------------------------------------------------------------------------------- *
  PROTECTED PROCEDURE createGpObjects
    WITH This
      .oPieImg = NEWOBJECT("GpBitmap", HOME() + "ffc/_gdiplus.vcx")
      .oPieImg.Create(.PieWidth, .PieHeight + .Height3D)
      .oPieGraph = NEWOBJECT('GpGraphics', HOME() + "ffc/_gdiplus.vcx")
      .oPieGraph.CreatefromImage(.oPieImg)
      .oPieGraph.Clear(.ForceAlpha(.BACKCOLOR))

      * Create the drawing objects
      .oBorderPen = NEWOBJECT('GpPen', HOME() + 'ffc/_gdiplus.vcx','', .ForceAlpha(.PieBorderColor), .PieBorderSize )
      .oSolidBrush = NEWOBJECT('GpSolidBrush', HOME() + 'ffc/_gdiplus.vcx','' )
      .oSolidBrush.Create()
      .oSliceColor = NEWOBJECT('GpColor', HOME() + 'ffc/_gdiplus.vcx')
      .o3DBrush = NEWOBJECT('GpHatchBrush', HOME() + 'ffc/_gdiplus.vcx','' )
      .oBWBrush = NEWOBJECT('GpHatchBrush', HOME() + 'ffc/_gdiplus.vcx','' )
    ENDWITH 
    RETURN 
  ENDPROC

  * -------------------------------------------------------------------------------------- *
  PROTECTED PROCEDURE getFontStyle(tcFontStyle)
    LOCAL lnFontStyle
    lnFontStyle = GDIPLUS_FontStyle_Regular && 0
    tcFontStyle = UPPER(m.tcFontStyle)
    IF "B" $ m.tcFontStyle
      lnFontStyle = m.lnFontStyle + GDIPLUS_FontStyle_Bold  && 1
    ENDIF
    IF "I" $ tcFontStyle
      lnFontStyle = m.lnFontStyle + GDIPLUS_FontStyle_Italic && 2
    ENDIF
    IF "U" $ tcFontStyle
      lnFontStyle = m.lnFontStyle + GDIPLUS_FontStyle_Underline && 4
    ENDIF
    IF "S" $ tcFontStyle
      lnFontStyle = m.lnFontStyle + GDIPLUS_FontStyle_Strikeout && 8
    ENDIF
    RETURN m.lnFontStyle
  ENDPROC

*!*    *-- Displays a Form and specifies if the Form is modal or modeless.
*!*    PROCEDURE show
*!*      LOCAL loForm as Form 
*!*      loForm = CREATEOBJECT("Form")
*!*      loForm.AddObject("imgPie","image")
*!*      loForm.BorderStyle = 0
*!*      loForm.ImgPie.Picture = This.ImageFile
*!*      loForm.ImgPie.Top  = 0
*!*      loForm.ImgPie.Left = 0
*!*      loForm.ImgPie.Visible = .T.
*!*      loForm.Width     = loForm.ImgPie.Width
*!*      loForm.Height    = loForm.ImgPie.Height
*!*      loForm.Caption   = This.Title
*!*      loForm.MaxButton = .F.
*!*      loForm.Show(1)
*!*      loForm = NULL 
*!*      RETURN
*!*    ENDPROC

  * -------------------------------------------------------------------------------------- *
  PROTECTED PROCEDURE makeDarker(tnRGB, tnPercent)
    * Assigns Alpha = 255
    RETURN BITOR( 0xFF000000 ;
      , BITLSHIFT(BITAND(m.tnRGB,0xFF * tnPercent),16) ;
      , BITAND(m.tnRGB,0x0000FF00 * tnPercent) ;
      , BITRSHIFT(BITAND(m.tnRGB,0x00FF0000 * tnPercent),16) )
  ENDPROC

  * -------------------------------------------------------------------------------------- *
  PROTECTED PROCEDURE changeColor(tnRGB, tnPoints)
    LOCAL lnRed, lnGreen, lnBlue
    lnRed   = BITAND(m.tnRGB, 0x000000FF)
    lnGreen = BITRSHIFT(BITAND(m.tnRGB, 0x0000FF00), 8)
    lnBlue  = BITRSHIFT(BITAND(m.tnRGB, 0x00FF0000), 16)

    IF m.tnPoints >= 0
      RETURN RGB( ;
        (MIN(255, m.lnRed   + m.tnPoints)), ;
        (MIN(255, m.lnGreen + m.tnPoints)), ;
        (MIN(255, m.lnBlue  + m.tnPoints)))
    ELSE
      RETURN RGB( ;
        (MAX(0, m.lnRed   + m.tnPoints)), ;
        (MAX(0, m.lnGreen + m.tnPoints)), ;
        (MAX(0, m.lnBlue  + m.tnPoints)))
    ENDIF 
  ENDPROC

  * -------------------------------------------------------------------------------------- *
  PROTECTED PROCEDURE declareGdip  && GDI+ DLL direct calls for gradient functions
    * Note: changed "GDIPLUS" to "GDIPLUS.DLL" in each line below; former caused error
    * if GDIPLUS was not in WinSysDir (or something like that). -rp
    DECLARE LONG GdipCreatePath ;
      IN GDIPLUS.DLL LONG brushmode, LONG @path
    DECLARE LONG GdipAddPathEllipse ;
      IN GDIPLUS.DLL LONG path, SINGLE x, SINGLE y, SINGLE nWidth, SINGLE Height 
    DECLARE LONG GdipAddPathRectangle ;
      IN GDIPLUS.DLL LONG path, SINGLE x, SINGLE y, SINGLE nWidth, SINGLE Height 
    DECLARE LONG GdipCreatePathGradientFromPath ;
      IN GDIPLUS.DLL LONG path, LONG @polyGradient
    DECLARE LONG GdipSetPathGradientCenterColor ;
      IN GDIPLUS.DLL LONG brush, LONG lColors
    DECLARE LONG GdipSetPathGradientSurroundColorsWithCount ;
      IN GDIPLUS.DLL LONG brush, LONG @argb, LONG @Count
    DECLARE LONG GdipDeletePath ;
      IN GDIPLUS.DLL LONG path
    RETURN   
  ENDPROC

  * -------------------------------------------------------------------------------------- *
  PROTECTED PROCEDURE createGradientBrush(tnCenter, tnSurround)
    LOCAL nCount, lnGradBrush, lnPath
    WITH This
      IF .GradBrushHandle = 0 && Create new Brush
        lnGradBrush = 0 
        lnPath = 0 

        GdipCreatePath(0, @lnPath) 
        GdipAddPathEllipse(m.lnPath, 0, 0, .PieWidth, .PieHeight) 
        GdipCreatePathGradientFromPath(m.lnPath, @lnGradBrush) 

        * Create object PathGradientBrush
        .oGradBrush = NEWOBJECT("GpBrush", HOME() + 'ffc/_gdiplus.vcx','' ) && Borrowed to use with Gradient Brush
        .oGradBrush.Destroy()
        .oGradBrush.SetHandle(m.lnGradBrush,.T.)

        .GradbrushPathHandle = m.lnPath && Store Path Handle in a property, so that 
            && Method Create Pie will be able to Release it after all slices are drawn
        .GradbrushHandle = m.lnGradBrush
      ENDIF

      * Assign GradientBrush colors
      nCount = 1
      GdipSetPathGradientSurroundColorsWithCount(.GradBrushHandle, .ForceAlpha(m.tnSurround), @nCount)
      GdipSetPathGradientCenterColor(.GradBrushHandle, .ForceAlpha(m.tnCenter))
    ENDWITH
    RETURN 
  ENDPROC

  * -------------------------------------------------------------------------------------- *
  PROCEDURE imagefile_assign(vNewVal)
    LOCAL lcCommand
    THIS.imagefile = m.vNewVal
    IF FILE(This.ImageFile)  && file exists from before, delete
      lcCommand = "CLEAR RESOURCES " + (This.ImageFile)
      &lcCommand
      DELETE FILE (This.ImageFile)
    ENDIF
    RETURN 
  ENDPROC

  * -------------------------------------------------------------------------------------- *
  PROCEDURE Destroy
    WITH This
      .oBorderPen = NULL
      .oSolidBrush = NULL
      .o3DBrush = NULL
      .oBWBrush = NULL
      .oSliceColor = NULL
      .oFont = NULL
      .oPieImg = NULL
      .oPieGraph = NULL
      .oLegendImg = NULL
      .oLegendGraph = NULL
      .oMainImg = NULL
      .oMainGraph = NULL

      * removed this--we want to retain image file once created
      *!*        IF FILE(This.ImageFile)
      *!*          LOCAL lcCommand
      *!*          lcCommand = "CLEAR RESOURCES " + (.ImageFile)
      *!*          &lcCommand
      *!*          DELETE FILE (.ImageFile)
      *!*        ENDIF

    ENDWITH 
    RETURN
  ENDPROC

    *!*    PROCEDURE Init
    *!*      LPARAMETERS tcTable, tcValueField, tcLegendField, tcColorField, ;
    *!*          tcDetachField, tcSliceTextField, tcCaption

    *!*      IF VARTYPE(m.tcTable) == "C"
    *!*        THIS.SourceAlias = m.tcTable
    *!*      ENDIF

    *!*      IF VARTYPE(m.tcValueField) == "C"
    *!*        THIS.PieValueField  = m.tcValueField
    *!*      ENDIF

    *!*      IF VARTYPE(m.tcLegendField) == "C"
    *!*        THIS.PieLegendField = m.tcLegendField
    *!*      ENDIF

    *!*      IF VARTYPE(m.tcDetachField) == "C"
    *!*        THIS.PieDetachField = m.tcDetachField
    *!*      ENDIF

    *!*      IF VARTYPE(m.tcColorField) == "C"
    *!*        THIS.PieColorField = m.tcColorField
    *!*      ENDIF

    *!*      IF VARTYPE(m.tcSliceTextField) == "C"
    *!*        THIS.PieSliceTextField = m.tcSliceTextField
    *!*      ENDIF

    *!*      IF VARTYPE(m.tcCaption) == "C"
    *!*        This.Title = m.tcCaption
    *!*      ENDIF

    *!*      * All parameters passed, so create automatically
    *!*      IF VARTYPE(m.tcTable) + VARTYPE(m.tcValueField) + VARTYPE(m.tcLegendField) == "CCC"
    *!*        This.Create
    *!*      ENDIF

    *!*      IF This.GradientLevel > 10 OR This.GradientLevel < 0
    *!*        This.GradientLevel = 5
    *!*      ENDIF 

    *!*      RETURN
    *!*    ENDPROC

ENDDEFINE  && L7Pie

*** ===================================================== ***
define class L7ImageInfo as Custom
  cPath = null
  cFileName = 0
  nWidth = 0
  nHeight = 0 
  nResolution = 0
  * --------------------------------------------
  function GetInfo
    local llOK, lnW, lnH, lnRes
    store 0 to lnW, lnH, lnRes
    llOK = GetImageInfo(addbs(this.cPath) + this.cFileName, @lnW, @lnH, @lnRes)
    if m.llOK
      this.nWidth = m.lnW
      this.nHeight = m.lnH
      this.nResolution = m.lnRes
    else
      error "GetImageInfo failed"
    endif
    return     
  endfunc && GetInfo 
  * --------------------------------------------
  function RotateImage(tnFlipType, tcNewFile, tcAltPath)
    * rotates current file _or_ creates a new rotated file
    * returns an object for the rotated file 
    local loImg
    if empty(m.tcNewFile)
      loImg = this
    else
      loImg = createobject(this.Class) && rotate works on existing file, so first make a copy
      loImg.cFileName = m.tcNewFile
      loImg.cPath = evl(m.tcAltPath, this.cPath)
      copy file (addbs(this.cPath) + this.cFileName) to (addbs(loImg.cPath) + loImg.cFileName)
    endif
    RotateImage(addbs(loImg.cPath) + loImg.cFileName, m.tnFlipType)
    return m.loImg
  endfunc && RotateImage
  * --------------------------------------------
  function CreateThumbnail(tnW, tnH, tcNewFile, tcAltPath)
    * if H and W both specified, allows default behavior based on larged dimension
    * otherwise forces the passed dimension to rule, by calculating 
    local lnW, lnH, lnRatio, loImg
    if this.nWidth = 0
      this.GetInfo()
    endif
    lnRatio = this.nWidth / this.nHeight 
    do case
    case empty(m.tnW) && new width not specified--base on height
      lnH = m.tnH
      lnW = int(m.tnH * m.lnRatio)
    case empty(m.tnH) && new height not specified--base on width
      lnW = m.tnW
      lnH = int(m.tnW / m.lnRatio)
    otherwise
      lnH = m.tnH
      lnW = m.tnW
    endcase

    loImg = createobject(this.Class) 
    loImg.cFileName = m.tcNewFile
    loImg.cPath = evl(m.tcAltPath, this.cPath)
    CreateThumbnail( ;
      addbs(this.cPath) + this.cFileName, ;
      addbs(loImg.cPath) + loImg.cFileName, ;
      m.lnW, m.lnH )
    loImg.GetInfo() && so we return an object with its actual values
    return m.loImg
  endfunc && CreateThumbnail 
  * --------------------------------------------

enddefine && L7ImageInfo 

* end: L7Graphics






