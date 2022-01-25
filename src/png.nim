import streams
import std/strutils
import std/endians
import strformat
import os as os

# http://www.libpng.org/pub/png/spec/1.2/PNG-Chunks.html

const maxBlockSize = 100*1024
var width: uint = 0
var height: uint = 0
type
  CustomRange = object
    low: uint
    high: uint

iterator items(range: CustomRange): uint =
  var i = range.low
  while i <= range.high:
    yield i
    inc i

proc readBytes(fs: FileStream, n: uint): seq[uint8] =
  for i in CustomRange(low: 0, high: n-1):
    result.add(fs.readUint8())

proc readBE32(fs: FileStream): uint32 =
  var data = fs.readUint32()
  var be: uint32
  bigEndian32(addr be, addr data)
  return be

proc readUInt32BE(buffer: array[maxBlockSize, uint8], start: uint): uint32 =
  var raw: uint32
  var value: uint32
  copyMem(raw.addr, unsafeAddr buffer[start], 4)
  bigEndian32(addr value, addr raw)
  return value

proc printIHDR(buffer: array[maxBlockSize, uint8]) =
  let w = buffer.readUInt32BE(0)
  let h = buffer.readUInt32BE(4)
  width = (uint)w
  height = (uint)h
  let depth = buffer[8]
  let ctype = buffer[9]
  let compression = buffer[10]
  let filter = buffer[11]
  let interlace = buffer[12]
  echo "---- IHDR ----"
  echo fmt"width {w} height {h}"
  echo fmt"depth {depth} color type {ctype}"
  echo fmt"compression {compression} filter {filter} interlace {interlace}"

proc printsRGB(buffer: array[maxBlockSize, uint8]) =
  let rgb = buffer[0]
  echo "---- sRGB ----"
  echo fmt"RGB {rgb}"

proc printgAMA(buffer: array[maxBlockSize, uint8]) =
  let g = buffer.readUInt32BE(0)
  let fg: float = float(g) * (1/2.2)
  echo "---- gAMA ----"
  echo fmt"GAMMA {fg:>9.3f} ({g})"

proc printpHYs(buffer: array[maxBlockSize, uint8]) =
  let ppux = buffer.readUInt32BE(0)
  let ppuy = buffer.readUInt32BE(4)
  let dimx: float = (float width)/(float ppux)*100
  let dimy: float = (float height)/(float ppuy)*100
  let unit = buffer[8]
  echo "---- pHYs ----"
  echo fmt"Pixel per unit x {ppux} ({dimx:>4.3f} cm x {dimy:>4.3f} cm)"
  echo fmt"Pixel per unit y {ppuy}"
  echo fmt"Unit {unit}"

proc printiCCP(buffer: array[maxBlockSize, uint8]) =
  var s: seq[char]
  for v in buffer:
    if v != 0:
      s.add chr(v)
    else:
      break
  let pname = s.join
  let cmethod = buffer[pname.len+1]
  echo "---- iCCP ----"
  echo fmt"Profile name: {pname}"
  echo fmt"Compression method: {cmethod}"


proc readPng(fname: string) =

  let fs = newFileStream(fname, fmRead)
  if fs.isNil:
    echo fmt"Error opening file <{fname}>"
    quit(-1)
  defer: fs.close

  discard fs.readBytes(8)

  while true:
    let size = fs.readBE32()
    let btype = fs.readStr(4)
    echo fmt"Type {btype} {size} bytes"

    var buffer: array[maxBlockSize, uint8]
    discard fs.readData(addr buffer, int size)


    case btype:
      of "IHDR":
        printIHDR(buffer)
      of "sRGB":
        printsRGB(buffer)
      of "gAMA":
        printgAMA(buffer)
      of "pHYs":
        printpHYs(buffer)
      of "iCCP":
        printiCCP(buffer)
      else:
        discard

    if size == 0:
      break

    discard fs.readBytes(4)

when isMainModule:
  if os.paramCount() < 1:
    echo "Usage:: png <fname>"
    quit(-2)
  readPng(os.paramStr(1))
