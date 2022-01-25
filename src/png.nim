import streams
import std/strutils
import std/endians
import strformat
import os as os

# http://www.libpng.org/pub/png/spec/1.2/PNG-Chunks.html

const maxBlockSize = 100*1024

var width: uint = 0
var height: uint = 0
var colorType: uint = 0

type
  CustomRange = object
    low: uint
    high: uint
  BufferType = array[maxBlockSize, uint8]

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

proc readUInt32BE(buffer: BufferType, start: uint): uint32 =
  var raw: uint32
  var value: uint32
  copyMem(raw.addr, unsafeAddr buffer[start], 4)
  bigEndian32(addr value, addr raw)
  return value

proc readUInt16BE(buffer: BufferType, start: uint): uint32 =
  var raw: uint16
  var value: uint16
  copyMem(raw.addr, unsafeAddr buffer[start], 2)
  bigEndian16(addr value, addr raw)
  return value

proc printIHDR(buffer: BufferType) =
  let w = buffer.readUInt32BE(0)
  let h = buffer.readUInt32BE(4)
  width = (uint)w
  height = (uint)h
  let depth = buffer[8]
  let ctype = buffer[9]
  colorType = ctype
  let compression = buffer[10]
  let filter = buffer[11]
  let interlace = buffer[12]
  echo "---- IHDR ----"
  echo fmt"width {w} height {h}"
  echo fmt"depth {depth} color type {ctype}"
  echo fmt"compression {compression} filter {filter} interlace {interlace}"

proc printsRGB(buffer: BufferType) =
  let rgb = buffer[0]
  echo "---- sRGB ----"
  echo fmt"RGB {rgb}"

proc printgAMA(buffer: BufferType) =
  let g = buffer.readUInt32BE(0)
  let fg: float = float(g) * (1/2.2)
  echo "---- gAMA ----"
  echo fmt"GAMMA {fg:>9.3f} ({g})"

proc printpHYs(buffer: BufferType) =
  let ppux = buffer.readUInt32BE(0)
  let ppuy = buffer.readUInt32BE(4)
  let dimx: float = (float width)/(float ppux)*100
  let dimy: float = (float height)/(float ppuy)*100
  let unit = buffer[8]
  echo "---- pHYs ----"
  echo fmt"Pixel per unit x {ppux} ({dimx:>4.3f} cm x {dimy:>4.3f} cm)"
  echo fmt"Pixel per unit y {ppuy}"
  echo fmt"Unit {unit}"

proc printiCCP(buffer: BufferType) =
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

proc printtIME(buffer: BufferType) =
  let year = buffer.readUInt16BE(0)
  let month = buffer[2]
  let day = buffer[3]
  let hour = buffer[4]
  let min = buffer[5]
  let sec = buffer[6]

  echo "---- tIME ----"
  echo fmt"Last image modification: {year}/{month}/{day} {hour}:{min}:{sec}"

proc printtEXt(buffer: BufferType, size: uint) =
  var key: seq[char]
  var text: seq[char]
  var i: uint = 0

  while i < size and buffer[i] != 0:
    key.add char buffer[i]
    i+=1
  i+=1
  while i < size and buffer[i] != 0:
    text.add char buffer[i]
    i+=1
  echo "---- tEXt ----"
  echo fmt"{key.join}: {text.join}"

proc printbKGD(buffer: BufferType) =
  discard

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


    var buffer: BufferType
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
      of "tIME":
        printtIME(buffer)
      of "tEXt":
        printtEXt(buffer, size)
      of "bKGD":
        printbKGD(buffer)
      else:
        echo fmt"Type {btype} {size} bytes"

    if size == 0:
      break

    discard fs.readBytes(4)

when isMainModule:
  if os.paramCount() < 1:
    echo "Usage:: png <fname>"
    quit(0)
  readPng(os.paramStr(1))
