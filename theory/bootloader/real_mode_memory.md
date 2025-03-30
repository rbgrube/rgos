# Real mode memory addressing

In 16 bit real mode, since registores can hold no more than 2 bytes, memory locations are addres with a 2 byte segment pounter and a 2 byte offset pointer. `segment:offset`

Each memory segment points to a section of memoery, and is shifted left by 16 bits in order to derive its linear memory adress. The offset value is the offset of the memory location from this segment.

`(Segment * 16) + Offset = Real address`

For example, the segment offset pointer `0x07C0:0000` translates to the absolute memory adress `0x7c00`, and `0x1000:0x0050` to `0x10050`
