# mapbits
Access mapped portions of bytes as int variables

A library to simplify mapping sub-byte portions of structures to/from int values,
allowing every interaction to be done using int rather than char-sized values.
This module should help simplify working with binary data, e.g. when parsing binary 
data ( [parseFixed module](http://github.com/jlp765/parsefixed) ), or working with memory-mapped files ( [memfiles module] (http://nim-lang.org/docs/memfiles.html) )

Each portion of a byte is represented by an ``int`` value that is
mapped to/from the portion of the byte.

The mapping of bits within the byte is specified by a ``mask`` value, along with
specifying the ``offset`` of the byte from the ``Base`` pointer to a data structure.

Exception ``[OverflowError]`` is raised if trying to set a mapping to a value greater
than can be represented by the number of mapped bits.

Note: this module does NOT provide assistance for mapping bits across the byte
boundary, only for mapping within a single byte.

Example:

```nim
 #=======  =======   ======================
 #         bits:     7  6  5  4  3  2  1  0   
 #-------  -------   ----------------------
 #word 0:  byte 0:   y  y  y  y  x  x  w  w
 #         byte 1:   z  z  z  z  z  z  a  a
 #word 1:  byte 2:   b  c  c  c  c  c  c  d
 #         byte 3:   e  e  f  f  f  g  g  g
 #=======  =======   ======================

 var 
   val: int = 0x5aa5
   updateBase(val.addr)
   y = BitMap(Mask47, 0)   # byte 0  (Mask47 does the mapping to bits 7..4)
   x = BitMap(Mask23, 0)
   w = BitMap(Mask01, 0)
   a = BitMap(Mask01, 1)   # byte 1
   z = BitMap(Mask27, 1)
   b = BitMap(Mask7,  2)   # byte 2  (Mask7 maps a SINGLE BIT, bit 7)
   c = BitMap(Mask36, 2)
   d = BitMap(Mask0,  2)
   e = BitMap(Mask67, 3)   # byte 3
   f = BitMap(Mask35, 3)
   g = BitMap(Mask02, 3)
   
 # Now just set/get integer values using variables y,x,w,....
 echo "x is: ",x.toHex
 y.set(14)  
 #y.set(200)    this raises an exception
```

Note: ``y`` (using ``Mask47``) specifies 4 bits are mapped to variable ``y``, so setting ``y`` to 
an int value greater than 15 (0xf) raises an ``[OverflowError]`` exception
