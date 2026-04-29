-- build_icon.applescript -- render the DNA emoji 🧬 to a 1024x1024 PNG.
--
-- Run via: osascript build_icon.applescript <output.png>
--
-- Apple Color Emoji at 820pt drawn over a transparent background, then
-- written as PNG. The Makefile downsizes via sips and converts to .icns
-- via iconutil.

use framework "Foundation"
use framework "AppKit"
use scripting additions

on run argv
    set outPath to item 1 of argv
    set theSize to 1024
    set theImage to current application's NSImage's alloc()'s initWithSize:(current application's NSMakeSize(theSize, theSize))
    theImage's lockFocus()

    set theFont to current application's NSFont's fontWithName:"Apple Color Emoji" |size|:820
    set theAttrs to current application's NSDictionary's dictionaryWithObject:theFont forKey:(current application's NSFontAttributeName)
    set theStr to current application's NSAttributedString's alloc()'s initWithString:"🧬" attributes:theAttrs

    theStr's drawInRect:(current application's NSMakeRect(102, 90, 820, 820))
    theImage's unlockFocus()

    set theTiff to theImage's TIFFRepresentation()
    set theRep to current application's NSBitmapImageRep's imageRepWithData:theTiff
    set theProps to current application's NSDictionary's dictionary()
    -- 4 = NSBitmapImageFileTypePNG
    set thePng to theRep's representationUsingType:4 |properties|:theProps

    thePng's writeToFile:outPath atomically:true
    return outPath
end run
