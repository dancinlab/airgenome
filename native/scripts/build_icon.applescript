-- build_icon.applescript -- render the DNA emoji 🧬 to a 1024x1024 PNG.
--
-- Run via: osascript build_icon.applescript <output.png>
--
-- Apple Color Emoji drawn over a solid black background, then written
-- as PNG. The Makefile downsizes via sips and converts to .icns.
--
-- Uses drawAtPoint: instead of drawInRect: so the glyph is never clipped
-- by a layout rect; the point is computed from the glyph's measured
-- bounding box so the emoji is visually centered on the 1024 canvas.

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

    -- Font size 640pt → glyph ≈ 62% of canvas, leaving ample border so the
    -- macOS squircle mask doesn't clip strands and the icon reads cleanly
    -- in Dock/Finder thumbnails.
    set fontSize to 640
    set theFont to current application's NSFont's fontWithName:"Apple Color Emoji" |size|:fontSize
    set theAttrs to current application's NSDictionary's dictionaryWithObject:theFont forKey:(current application's NSFontAttributeName)
    set theStr to current application's NSAttributedString's alloc()'s initWithString:"🧬" attributes:theAttrs

    -- Measure the glyph's natural typographic size, then position the
    -- drawAtPoint: origin so the glyph's bounding box centers on the
    -- canvas. drawAtPoint: never clips, so descenders/ribbon ends are
    -- guaranteed to render in full.
    set glyphSize to theStr's |size|()
    set glyphW to width of glyphSize
    set glyphH to height of glyphSize
    set originX to (theSize - glyphW) / 2
    -- Apple Color Emoji typographic box (h=840 at 640pt) has more padding
    -- below the visible glyph than above; nudge y up so the visible glyph
    -- centers on the canvas rather than the typographic box centering.
    set originY to ((theSize - glyphH) / 2) + 10
    theStr's drawAtPoint:(current application's NSMakePoint(originX, originY))
    theImage's unlockFocus()

    set theTiff to theImage's TIFFRepresentation()
    set theRep to current application's NSBitmapImageRep's imageRepWithData:theTiff
    set theProps to current application's NSDictionary's dictionary()
    -- 4 = NSBitmapImageFileTypePNG
    set thePng to theRep's representationUsingType:4 |properties|:theProps

    thePng's writeToFile:outPath atomically:true
    return outPath
end run
