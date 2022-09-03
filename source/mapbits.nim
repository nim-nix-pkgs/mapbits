## A library to simplify mapping sub-byte portions of structures to/from int values,
## allowing every interaction to be done using int rather than char-sized values.
## This module should help simplify working with binary data, e.g. when parsing binary 
## data, or working with memory mapped files (`memfiles module<docs/memfiles.html>`_)
##
## Each portion of a byte is represented by an ``int`` value that is
## mapped to/from the portion of the byte.
##
## The mapping of bits within the byte is specified by a ``mask`` value, along with
## specifying the ``offset`` of the byte from the ``Base`` pointer to a data structure.
##
## Exception ``[OverflowError]`` is raised if trying to set a mapping to a value greater
## than can be represented by the number of mapped bits.
##
## Note: this module does NOT provide assistance for mapping bits across the byte
## boundary, only for mapping within a single byte.
##
## Example:
##
## .. code-block:: Nim
##  #=======  =======   ======================
##  #         bits:     7  6  5  4  3  2  1  0   
##  #-------  -------   ----------------------
##  #word 0:  byte 0:   y  y  y  y  x  x  w  w
##  #         byte 1:   z  z  z  z  z  z  a  a
##  #word 1:  byte 2:   b  c  c  c  c  c  c  d
##  #         byte 3:   e  e  f  f  f  g  g  g
##  #=======  =======   ======================
##
##  var 
##    val: int = 0x5aa5
##    updateBase(val.addr)
##    y = BitMap(Mask47, 0)   # byte 0  (Mask47 does the mapping to bits 7..4)
##    x = BitMap(Mask23, 0)
##    w = BitMap(Mask01, 0)
##    a = BitMap(Mask01, 1)   # byte 1
##    z = BitMap(Mask27, 1)
##    b = BitMap(Mask7,  2)   # byte 2  (Mask7 maps a SINGLE BIT, bit 7)
##    c = BitMap(Mask36, 2)
##    d = BitMap(Mask0,  2)
##    e = BitMap(Mask67, 3)   # byte 3
##    f = BitMap(Mask35, 3)
##    g = BitMap(Mask02, 3)
##
##  # Now just set/get integer values using variables y,x,w,....
##  echo "x is: ",x.toHex
##  y.set(14)  
##  #y.set(200)    this raises an exception
##
## Note: ``y`` (using ``Mask47``) specifies 4 bits are mapped to variable ``y``, so setting ``y`` to 
## an int value greater than 15 (0xf) raises an ``[OverflowError]`` exception

import macros, math, strutils
  
const   
  Mask0*   = 0x1                ## Bit 0 (LSB)
  Mask1*   = 0x2                ## Bit 1
  Mask2*   = 0x4                ## Bit 2
  Mask3*   = 0x8                ## Bit 3
  Mask4*   = 0x10               ## Bit 4
  Mask5*   = 0x20               ## Bit 5
  Mask6*   = 0x40               ## Bit 6
  Mask7*   = 0x80               ## Bit 7 (MSB)
  
  Mask01*  = 0x3                ## Bits 1..0
  Mask02*  = 0x7                ## Bits 2..0
  Mask03*  = 0xf                ## Bits 3..0
  Mask04*  = 0x1f               ## Bits 4..0
  Mask05*  = 0x3f               ## Bits 5..0
  Mask06*  = 0x7f               ## Bits 6..0
  Mask07*  = 0xff               ## Bits 7..0  (whole Byte)
  Mask12*  = Mask02 - 1         ## Bits 2..1
  Mask13*  = Mask03 - 1         ## Bits 3..1
  Mask14*  = Mask04 - 1         ## Bits 4..1
  Mask15*  = Mask05 - 1         ## Bits 5..1
  Mask16*  = Mask06 - 1         ## Bits 6..1
  Mask17*  = Mask07 - 1         ## Bits 7..1
  Mask23*  = Mask03 - 3         ## Bits 3..2
  Mask24*  = Mask04 - 3         ## Bits 4..2
  Mask25*  = Mask05 - 3         ## Bits 5..2
  Mask26*  = Mask06 - 3         ## Bits 6..2
  Mask27*  = Mask07 - 3         ## Bits 7..2
  Mask34*  = Mask04 - 7         ## Bits 4..3
  Mask35*  = Mask05 - 7         ## Bits 5..3
  Mask36*  = Mask06 - 7         ## Bits 6..3
  Mask37*  = Mask07 - 7         ## Bits 7..3
  Mask45*  = 0x30               ## Bits 5..4
  Mask46*  = 0x70               ## Bits 6..4
  Mask47*  = 0xf0               ## Bits 7..4
  Mask56*  = Mask06 - 0x1f      ## Bits 5..4
  Mask57*  = Mask07 - 0x1f      ## Bits 6..5
  Mask67*  = Mask07 - 0x3f      ## Bits 7..6
  
type
  BitMapObj* = object  ## use the template ``BitMap()`` to create a variable of type ``BitMapObj``
    byteOffset*: int
    rshift: uint8
    andMask: uint8
    
  BaseType = ptr array[0..1_000_000, uint8]
  WBaseType = ptr array[0..1_000_000, uint16]
      
var
  Base: BaseType

template BitMap*(aMask, ByteOffs: untyped): untyped =
  BitMapObj(byteOffset: ByteOffs, rshift: getMaskShift(aMask), andMask: aMask)

proc initOffset*(bm: BitMapObj, byteOffs: int): BitMapObj =
  ## initialse a BitMap object by copying a variable with byteOffset (=0 ?), 
  ## and setting the byte offset to byteOffs
  result = bm
  result.byteOffset = byteOffs

proc initOffset*(bm: var BitMapObj, byteOffs: int) =
  ## initialse the byte offset of a BitMap object
  bm.byteOffset = byteOffs

proc updateBase*(newBase: BaseType) = 
  ## Set the [BaseType] ``Base`` address of ALL ``BitMapObj`` variables.
  ##
  ## ``byteOffset`` of ``BitMapObj`` is relative to ``newBase``
  Base = cast[BaseType](newBase)

proc updateBase*(newBase: pointer) = 
  ## Set the [pointer] ``Base`` address of ALL ``BitMapObj`` variables.
  ##
  ## ``byteOffset`` of ``BitMapObj`` is relative to ``newBase``
  Base = cast[BaseType](newBase)

proc updateBase*(newBase: ptr uint8) = 
  ## Set the [ptr uint8] ``Base`` address of ALL ``BitMapObj`` variables.
  ##
  ## ``byteOffset`` of ``BitMapObj`` is relative to ``newBase``
  Base = cast[BaseType](newBase)

proc getInPlace*(bm: BitMapObj): int {.inline.} = 
  ## retrieve the portion of the byte matching the andMask (unshifted)
  result = (Base[bm.byteOffset.uint8] and bm.andMask).int

proc get*(bm: BitMapObj): int {.inline.} = 
  ## retrieve the portion of the byte matching andMask, as a number (shifted right to the LSB)
  result = `shr`(bm.getInPlace, bm.rshift.int)

proc getMaskSize*(m: uint8): uint8 =
  ## return Mask shifted right so LSB is non-zero
  let m = m and 0xff
  for i in 0..7:
    result = `shr`(m, i.uint8).uint8
    if (result and 0x01) == 1: 
      return
  result = 0.uint8

proc getMaskShift*(m: uint8): uint8 =
  ## return number of right shifts for ``getMaskSize``
  var shft = 0.uint8
  let m = m and 0xff
  for i in 0..7:
    result = i.uint8
    shft = `shr`(m, result).uint8
    if (shft and 0x01) == 1: 
      return
  result = 0.uint8

proc set*(bm: var BitMapObj, val: int) =  
  ## sets the portion of the Base value matching the andMask to val
  ## Raises OverFlowError if val is greater than the mask size
  var ms = getMaskSize(bm.andMask).int
  if (val and ms) != val: 
    raise newException(OverflowError, "value (" &  $val & ") is greater than size of BitMap mask (" & $ms & ")")
  var x = `shl`(val.uint8, bm.rshift).uint8
  Base[bm.byteOffset] = (Base[bm.byteOffset] and not bm.andMask) + x

proc `$`*(bm: BitMapObj): string =
  ## return unsigned integer string representation of a ``BitMapObj`` 
  result = $get(bm)

proc toHex*(u: uint8; len: int = 2): string = u.BiggestInt.toHex(len)
  ## return the hexadecimal string representation of ``u`` (no leading ``0x``)

proc toHex*(u: uint16; len: int = 4): string = u.BiggestInt.toHex(len)
  ## return the hexadecimal string representation of ``u`` (no leading ``0x``)

proc toHex*(bm: BitMapObj): string = 
  ## return the hexadecimal string representation of ``bm`` (no leading ``0x``)
  result = toHex(bm.get,2)

proc `and`*(bm: BitMapObj, a: uint8): uint8 = 
  ## bit-wise ``and`` of a ``BitMapObj``
  result = bm.get.uint8 and a
proc `and`*(bm1, bm2: BitMapObj): uint8 = 
  ## bit-wise ``and`` of two ``BitMapObj`` variables
  result = bm1.get.uint8 and bm2.get.uint8

proc `or`*(bm: BitMapObj, a: uint8): uint8 = 
  ## bit-wise ``or`` of a ``BitMapObj``
  result = bm.get.uint8 or a
proc `or`*(bm1, bm2: BitMapObj, a: uint8): uint8 = 
  ## bit-wise ``or`` of two ``BitMapObj`` variables
  result = bm1.get.uint8 or bm2.get.uint8
  
proc `xor`*(bm: BitMapObj, a: uint8): uint8 = 
  result = bm.get.uint8 xor a
proc `xor`*(bm1, bm2: BitMapObj, a: uint8): uint8 = 
  ## bit-wise ``xor`` of two ``BitMapObj`` variables
  result = bm1.get.uint8 xor bm2.get.uint8
  
proc `not`*(bm: BitMapObj, a: uint8): uint8 = 
  ## bit-wise ``not`` of a ``BitMapObj`` variable
  result = not bm.get.uint8

proc bytes2Word*(bm2, bm1: BitMapObj): uint16 =
  ## return an unsigned int where bm1 has the 
  ## least significant bit (LSB) and bm2 has the MSB
  result = (`shl`(bm2.get.uint16, 8) and 0xffff) + bm1.get.uint16

proc bytes2Word*(u2, u1: uint8): uint16 =
  ## return an unsigned int where ``u1`` has the 
  ## least significant bit (LSB) and ``u2`` has the MSB
  result = `shl`(u2.uint16, 8).uint16 + u1.uint16

proc bytes2Word*(u2, u1: int): uint16 =
  ## return an unsigned int where ``u1`` has the 
  ## least significant bit (LSB) and ``u2`` has the MSB
  result = `shl`(u2, 8).uint16 + u1.uint16

proc getByte*(bOffs: int = 0): uint8 =
  ## return the unsigned int at the byte offset from ``Base``
  result = Base[bOffs]

proc getByte*(p: pointer; bOffs: int = 0): uint8 =
  ## return the unsigned int at the byte offset from pointer ``p``
  let b = cast[BaseType](p)
  result = b[bOffs]
  
proc getWord*(wOffs: int = 0): uint16 =
  ## return the unsigned int at the word offset from ``Base``
  var w = cast[WBaseType](Base)
  result = w[wOffs].uint16

proc getWord*(p: pointer; wOffs: int = 0): uint16 =
  ## return the unsigned int at the word offset from pointer ``p``
  let w = cast[WBaseType](p)
  result = w[wOffs].uint16

when isMainModule:
  var 
    val: array[2, uint16] = [0x5aa5.uint16, 0xa55b.uint16]
    Byte = BitMap(Mask07, 0)
    x =  BitMap(Mask23, 0)
  discard """  
    y =  BitMap(Mask47, 0)   # byte 0
    w =  BitMap(Mask01, 0)
    a =  BitMap(Mask01, 1)   # byte 1
    z =  BitMap(Mask27, 1)
    b =  BitMap(Mask7,  2)   # byte 2
    c =  BitMap(Mask36, 2)
    d =  BitMap(Mask0,  2)
    e =  BitMap(Mask67, 3)   # byte 3
    f =  BitMap(Mask35, 3)
    g =  BitMap(Mask02, 3)
    b2 = BitMap(Mask07, 1)
    zz = BitMap(Mask01, 1)
  """
  
  updateBase(val[0].addr)
  #doAssert(Byte.toHex == 
  doAssert(getMaskShift(Mask07) == 0)
  doAssert(getMaskShift(Mask13) == 1)
  doAssert(getMaskShift(Mask24) == 2)
  doAssert(getMaskShift(Mask36) == 3)
  doAssert(getMaskShift(Mask45) == 4)
  doAssert(getMaskShift(Mask56) == 5)
  doAssert(getMaskShift(Mask67) == 6)
  doAssert(getMaskShift(Mask7)  == 7)
  
  doAssert(BitMap(Mask27, 0) == BitMapObj(byteOffset: 0, rshift: 2, andMask: Mask27))
  doAssert(BitMap(Mask46, 15) == BitMapObj(byteOffset: 15, rshift: 4, andMask: Mask46))
  
  doAssert(Byte.toHex == "A5")
  doAssert((Byte and 0xf0) == 0xA0)
  doAssert((Byte xor 0x04) == 0xA1)
  
  doAssert(getWord(0) == 0x5AA5)
  doAssert(getWord(1) == 0xA55B)
  doAssert(Base.getWord(0) == 0x5AA5)
  doAssert(Base.getWord(1) == 0xA55B)

  doAssert(getByte(1) == 0x5A)
  doAssert(getByte(0) == 0xA5)
  doAssert(bytes2Word(getByte(1), getByte(0)) == getWord(0))
  doAssert(bytes2Word(getByte(3), getByte(2)) == getWord(1))


  doAssert(x.get == 1)
  x.set(0)
  doAssert(x.get == 0)
  x.set(3)
  doAssert(x.get == 3)
  doAssert(x.getInPlace == 12)
  
  
