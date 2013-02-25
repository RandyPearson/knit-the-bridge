* MS Office Constants
* (sometimes may need true = -1, false = 0 also)

* Revisions:
#DEFINE wdRevisionsViewFinal     0
#DEFINE wdRevisionsViewOriginal  1
* example: word.ActiveDocument.ActiveWindow.View.RevisionsView = wdRevisionsViewFinal
* note: the View flag ShowRevisionsAndComments also comes into play

* Save As document type formats:
#DEFINE wdFormatDocument                     0
#DEFINE wdFormatDocument97                   0
#DEFINE wdFormatDocumentDefault             16
#DEFINE wdFormatDOSText                      4
#DEFINE wdFormatDOSTextLineBreaks            5
#DEFINE wdFormatEncodedText                  7
#DEFINE wdFormatFilteredHTML                10
#DEFINE wdFormatFlatXML                     19
#DEFINE wdFormatFlatXMLMacroEnabled         20
#DEFINE wdFormatFlatXMLTemplate             21
#DEFINE wdFormatFlatXMLTemplateMacroEnabled 22
#DEFINE wdFormatHTML                         8
#DEFINE wdFormatPDF                         17
#DEFINE wdFormatRTF                          6
#DEFINE wdFormatTemplate                     1
#DEFINE wdFormatTemplate97                   1
#DEFINE wdFormatText                         2
#DEFINE wdFormatTextLineBreaks               3
#DEFINE wdFormatUnicodeText                  7
#DEFINE wdFormatWebArchive                   9
#DEFINE wdFormatXML                         11
#DEFINE wdFormatXMLDocument                 12
#DEFINE wdFormatXMLDocumentMacroEnabled     13
#DEFINE wdFormatXMLTemplate                 14
#DEFINE wdFormatXMLTemplateMacroEnabled     15
#DEFINE wdFormatXPS                         18

* wdFieldType - form field types. FormFields.Add( range, wdFieldType)
#define wdFieldFormTextInput 70
#define wdFieldFormCheckBox  71
#define wdFieldFormDropDown  83

#define wdFormatTemplate 1

* WdProtectionType : document.Protect(x)
#define wdNoProtection        -1 && use Unprotect() if protected
#define wdAllowOnlyFormFields  2
#define wdAllowOnlyReading     3

#DEFINE wdUndefined 9999999

* File paths
#DEFINE wdDocumentsPath 0
#DEFINE wdUserTemplatesPath 2
#DEFINE wdWorkGroupTemplatesPath 3

* Units for movement and selection
#DEFINE wdCharacter 1
#DEFINE wdWord 2
#DEFINE wdSentence 3
#DEFINE wdParagraph 4
#DEFINE wdLine 5
#DEFINE wdStory 6
#DEFINE wdScreen 7
#DEFINE wdSection 8
#DEFINE wdColumn 9
#DEFINE wdRow 10
#DEFINE wdWindow 11
#DEFINE wdCell 12
#DEFINE wdCharacterFormatting 13
#DEFINE wdParagraphFormatting 14
#DEFINE wdTable 15
#DEFINE wdItem 16

* Directions for collapse
#DEFINE wdCollapseStart 1
#DEFINE wdCollapseEnd 0

* Selection Status
#DEFINE wdNoSelection 0
#DEFINE wdSelectionIP 1
#DEFINE wdSelectionNormal 2

* Paragraph Alignment
#DEFINE wdAlignParagraphLeft 0
#DEFINE wdAlignParagraphCenter 1
#DEFINE wdAlignParagraphRight 2
#DEFINE wdAlignParagraphJustify 3

* Find and replace
#DEFINE wdFindStop 0
#DEFINE wdFindContinue 1
#DEFINE wdFindAsk 2

#DEFINE wdReplaceNone 0
#DEFINE wdReplaceOne 1
#DEFINE wdReplaceAll 2

* Line styles
#DEFINE wdLineStyleNone 0
#DEFINE wdLineStyleSingle 1
#DEFINE wdLineStyleDot 2
#DEFINE wdLineStyleDashDot 5
#DEFINE wdLineStyleDouble 7
#DEFINE wdLineStyleWavy 18

* Close and save
#DEFINE wdDoNotSaveChanges 0
#DEFINE wdSaveChanges -1
#DEFINE wdPromptToSaveChanges -2

* Styles
#DEFINE wdStyleTypeParagraph 1
#DEFINE wdStyleTypeCharacter 2

#DEFINE wdStyleNormal -1
#DEFINE wdHeading1 -2
#DEFINE wdHeading2 -3
#DEFINE wdHeading3 -4
#DEFINE wdHeading4 -5

* Mail merge
#DEFINE wdFormLetters 0
#DEFINE wdMailingLabels 1
#DEFINE wdEnvelopes 2

#DEFINE wdSendToNewDocument 0
#DEFINE wdSendToPrinter 1

* Paper Size
#DEFINE wdPaper11x17 1
#DEFINE wdPaperLetter 2
#DEFINE wdPaperLegal 4
#DEFINE wdPaperA4 7

* Paper Tray
#DEFINE wdPrinterDefaultBin 0
#DEFINE wdPrinterUpperBin 1
#DEFINE wdPrinterLowerBin 2
#DEFINE wdPrinterManualFeed 4
#DEFINE wdPrinterEnvelopeFeed 5
#DEFINE wdPrinterAutomaticSheetFeed 7

* Paper Orientation
#DEFINE wdOrientPortrait 0
#DEFINE wdOrientLandscape 1

* Vertical Alignment
#DEFINE wdAlignVerticalTop 0
#DEFINE wdAlignVerticalCenter 1
#DEFINE wdAlignVerticalJustify 2
#DEFINE wdAlignVerticalBottom 3

* Font underline
#DEFINE wdUnderlineNone 0
#DEFINE wdUnderlineSingle 1
#DEFINE wdUnderlineWords 2
#DEFINE wdUnderlineDouble 3
#DEFINE wdUnderlineDotted 4
#DEFINE wdUnderlineThick 6

* Line Spacing
#DEFINE wdLineSpaceSingle 0
#DEFINE wdLineSpace1pt5 1
#DEFINE wdLineSpaceDouble 2
#DEFINE wdLineSpaceAtLeast 3
#DEFINE wdLineSpaceExactly 4
#DEFINE wdLineSpaceMultiple 5

* Borders
#DEFINE wdBorderTop -1
#DEFINE wdBorderLeft -2
#DEFINE wdBorderBottom -3
#DEFINE wdBorderRight -4
#DEFINE wdBorderHorizontal -5
#DEFINE wdBorderVertical -6
#DEFINE wdBorderDiagonalDown -7
#DEFINE wdBorderDiagonalUp -8

* Line width for borders
#DEFINE wdLineWidth025pt 2
#DEFINE wdLineWidth050pt 4
#DEFINE wdLineWidth075pt 6
#DEFINE wdLineWidth100pt 8
#DEFINE wdLineWidth150pt 10
#DEFINE wdLineWidth225pt 18
#DEFINE wdLineWidth300pt 24
#DEFINE wdLineWidth450pt 36
#DEFINE wdLineWidth600pt 48

* Shading Textures
#DEFINE wdTextureNone 0
#DEFINE wdTexture5Percent 50
#DEFINE wdTexture10Percent 100
#DEFINE wdTextureSolid 1000
#DEFINE wdTextureHorizontal -7
#DEFINE wdTextureVertical -8
#DEFINE wdTextureDiagonalDown -9
#DEFINE wdTextureDiagonalUp -10

* Headers and Footers
#DEFINE wdHeaderFooterPrimary 1
#DEFINE wdHeaderFooterFirstPage 2
#DEFINE wdHeaderFooterEvenPages 3

* Page number alignment
#DEFINE wdAlignPageNumberLeft 0
#DEFINE wdAlignPageNumberCenter 1
#DEFINE wdAlignPageNumberRight 2
#DEFINE wdAlignPageNumberInside 3
#DEFINE wdAlignPageNumberOutside 4

* Page number styles
#DEFINE wdCaptionNumberStyleArabic 0
#DEFINE wdCaptionNumberStyleUppercaseRoman 1
#DEFINE wdCaptionNumberStyleLowercaseRoman 2
#DEFINE wdCaptionNumberStyleUppercaseLetter 3
#DEFINE wdCaptionNumberStyleLowercaseLetter 4

* Separator character for chapter-type page numbers
#DEFINE wdSeparatorHyphen 0
#DEFINE wdSeparatorPeriod 1
#DEFINE wdSeparatorColon 2
#DEFINE wdSeparatorEmDash 3
#DEFINE wdSeparatorEnDash 4

* List Galleries
#DEFINE wdBulletGallery 1
#DEFINE wdNumberGallery 2
#DEFINE wdOutlineNumberGallery 3

* List number styles
#DEFINE wdListNumberStyleArabic 0
#DEFINE wdListNumberStyleUppercaseRoman 1
#DEFINE wdListNumberStyleLowercaseRoman 2
#DEFINE wdListNumberStyleUppercaseLetter 3
#DEFINE wdListNumberStyleLowercaseLetter 4
#DEFINE wdListNumberStyleBullet 23

* List trailing character
#DEFINE wdTrailingTab 0
#DEFINE wdTrailingSpace 1
#DEFINE wdTrailingNone 2

* List number alignment
#DEFINE wdListLevelAlignLeft 0
#DEFINE wdListLevelAlignCenter 1
#DEFINE wdListLevelAlignRight 2

* Apply list template
#DEFINE wdListApplyToWholeList 0
#DEFINE wdListApplyToThisPointForward 1
#DEFINE wdListApplyToSelection 2

* List types
#DEFINE wdListNoNumbering 0
#DEFINE wdListNumOnly 1
#DEFINE wdListBullet 2
#DEFINE wdListSimpleNumbering 3
#DEFINE wdListOutlineNumbering 4
#DEFINE wdListMixedNumbering 5

* Print Range
#DEFINE wdPrintAllDocument 0 
#DEFINE wdPrintSelection 1
#DEFINE wdPrintCurrentPage 2
#DEFINE wdPrintFromTo 3
#DEFINE wdPrintRangeOfPages 4

* Section start types (wdSectionStart)
*   New Page, 2, is default for Add():
#DEFINE wdSectionContinuous 0
#DEFINE wdSectionEvenPage   3
#DEFINE wdSectionNewColumn  1
#DEFINE wdSectionNewPage    2
#DEFINE wdSectionOddPage    4

* Colors (wdColorIndex)
#DEFINE wdAuto        0
#DEFINE wdBlack       1
#DEFINE wdBlue        2
#DEFINE wdBrightGreen 4
#DEFINE wdByAuthor   -1
#DEFINE wdDarkBlue    9
#DEFINE wdDarkRed    13
#DEFINE wdDarkYellow 14
#DEFINE wdGray25     16
#DEFINE wdGray50     15
#DEFINE wdGreen      11
#DEFINE wdNoHighlight 0
#DEFINE wdPink        5
#DEFINE wdRed         6
#DEFINE wdTeal       10
#DEFINE wdTurquoise   3
#DEFINE wdViolet     12
#DEFINE wdWhite       8
#DEFINE wdYellow      7
* ... additional colors (wdColor):
#DEFINE wdColorDarkGreen   13056
#DEFINE wdColorBrown       13209
#DEFINE wdColorLightYellow 10092543

* Preferred Width type
#DEFINE wdPreferredWidthAuto    1
#DEFINE wdPreferredWidthPercent 2
#DEFINE wdPreferredWidthPoints  3

* Range Information Enumeration: range.Information(<member>)
*   added 10/15/2007 to get wdWithInTable
*
#DEFINE wdActiveEndAdjustedPageNumber  1  
#DEFINE wdActiveEndPageNumber  3  
#DEFINE wdActiveEndSectionNumber  2  
#DEFINE wdAtEndOfRowMarker  31  
#DEFINE wdCapsLock  21  
#DEFINE wdEndOfRangeColumnNumber  17  
#DEFINE wdEndOfRangeRowNumber  14  
#DEFINE wdFirstCharacterColumnNumber  9  
#DEFINE wdFirstCharacterLineNumber  10  
#DEFINE wdFrameIsSelected  11  
#DEFINE wdHeaderFooterType  33  
#DEFINE wdHorizontalPositionRelativeToPage  5  
#DEFINE wdHorizontalPositionRelativeToTextBoundary  7  
#DEFINE wdInClipboard  38  
#DEFINE wdInCommentPane  26  
#DEFINE wdInEndnote  36  
#DEFINE wdInFootnote  35  
#DEFINE wdInFootnoteEndnotePane  25  
#DEFINE wdInHeaderFooter  28  
#DEFINE wdInMasterDocument  34  
#DEFINE wdInWordMail  37  
#DEFINE wdMaximumNumberOfColumns  18  
#DEFINE wdMaximumNumberOfRows  15  
#DEFINE wdNumberOfPagesInDocument  4  
#DEFINE wdNumLock  22  
#DEFINE wdOverType  23  
#DEFINE wdReferenceOfType  32  
#DEFINE wdRevisionMarking  24  
#DEFINE wdSelectionMode  20  
#DEFINE wdStartOfRangeColumnNumber  16  
#DEFINE wdStartOfRangeRowNumber  13  
#DEFINE wdVerticalPositionRelativeToPage  6  
#DEFINE wdVerticalPositionRelativeToTextBoundary  8  
#DEFINE wdWithInTable 12  
#DEFINE wdZoomPercentage 19  
