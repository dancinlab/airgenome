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

    -- Fill entire 1024x1024 canvas with solid black before drawing emoji.
    -- macOS applies the squircle mask automatically; corners are trimmed.
    -- NSRectFill is unreliable from AppleScript, so use bezier path fill.
    (current application's NSColor's blackColor())'s |set|()
    set bgRect to current application's NSMakeRect(0, 0, theSize, theSize)
    (current application's NSBezierPath's bezierPathWithRect:bgRect)'s fill()

    set theFont to current application's NSFont's fontWithName:"Apple Color Emoji" |size|:820
    set theAttrs to current application's NSDictionary's dictionaryWithObject:theFont forKey:(current application's NSFontAttributeName)
    set theStr to current application's NSAttributedString's alloc()'s initWithString:"🧬" attributes:theAttrs

    -- y origin = (1024-820)/2 = 102 centers the rect on both axes.
    -- Apple Color Emoji 🧬 has internal padding biasing visual center
    -- toward upper-left of glyph box; nudge y down (lower y in bottom-left
    -- coords) to compensate.
    theStr's drawInRect:(current application's NSMakeRect(102, 92, 820, 820))
    theImage's unlockFocus()

    set theTiff to theImage's TIFFRepresentation()
    set theRep to current application's NSBitmapImageRep's imageRepWithData:theTiff
    set theProps to current application's NSDictionary's dictionary()
    -- 4 = NSBitmapImageFileTypePNG
    set thePng to theRep's representationUsingType:4 |properties|:theProps

    thePng's writeToFile:outPath atomically:true
    return outPath
end run
