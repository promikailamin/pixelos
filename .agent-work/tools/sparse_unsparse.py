import struct, sys, os

SPARSE_MAGIC = 0xED26FF3A
CHUNK_TYPE_RAW = 0xCAC1
CHUNK_TYPE_FILL = 0xCAC2
CHUNK_TYPE_DONT_CARE = 0xCAC3

def unsparse(infile, outfile):
    with open(infile, 'rb') as f:
        header = f.read(28)
        if len(header) < 28:
            print("file too short for sparse header"); return False
        magic, maj, min_, fhs, chs, bs, tb, tc, csum = struct.unpack('<IHHHHIIII', header)
        if magic != SPARSE_MAGIC:
            print("not a sparse image, magic=%x" % magic); return False
        print("sparse: block_size=%d total_blocks=%d total_chunks=%d chunk_header_size=%d" % (bs, tb, tc, chs))
        f.seek(fhs)
        out = open(outfile, 'wb')
        written = 0
        for i in range(tc):
            ch = f.read(chs)
            if len(ch) < chs:
                print("truncated chunk header at chunk", i); return False
            ctype, reserved, cblocks, csize = struct.unpack('<HHII', ch[:12])
            if ctype == CHUNK_TYPE_RAW:
                data = f.read(cblocks * bs)
                out.write(data)
                written += len(data)
            elif ctype == CHUNK_TYPE_FILL:
                fillchunk = f.read(4)
                fill = struct.unpack('<I', fillchunk)[0] if len(fillchunk) == 4 else 0
                out.write(bytes([fill & 0xFF]) * (cblocks * bs))
                written += cblocks * bs
            elif ctype == CHUNK_TYPE_DONT_CARE:
                out.write(b'\x00' * (cblocks * bs))
                written += cblocks * bs
            else:
                print("unknown chunk type %x at chunk %d" % (ctype, i)); return False
        out.close()
        print("unsparsed -> %d bytes (expected %d)" % (written, tb * bs))
        return True

if __name__ == '__main__':
    unsparse(sys.argv[1], sys.argv[2])
