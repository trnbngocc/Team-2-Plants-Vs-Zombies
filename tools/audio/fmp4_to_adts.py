"""Extract AAC frames from a fragmented MP4 (DASH) into an ADTS .aac stream. Read-only on input."""
import struct, sys

def boxes(d, i, end):
    while i + 8 <= end:
        sz, typ = struct.unpack('>I4s', d[i:i+8]); hdr = 8
        if sz == 1: sz = struct.unpack('>Q', d[i+8:i+16])[0]; hdr = 16
        elif sz == 0: sz = end - i
        yield typ.decode('latin1'), i, i + hdr, i + sz
        i += sz

def find(d, path, i=0, end=None):
    end = len(d) if end is None else end
    for typ, s, b, e in boxes(d, i, end):
        if typ == path[0]:
            if len(path) == 1: return s, b, e
            r = find(d, path[1:], b + (8 if typ == 'stsd' else 0) + (4 if typ in ('meta',) else 0), e)
            if r: return r
    return None

def asc_from_esds(d):
    j = d.find(b'esds'); k = d.find(b'\x05', j + 12)   # DecoderSpecificInfo tag
    while d[k+1] & 0x80: k += 1
    n = d[k+1] & 0x7f
    return d[k+2:k+2+n]

def main(src, dst):
    d = open(src, 'rb').read()
    asc = asc_from_esds(d)
    aot = asc[0] >> 3; sfi = ((asc[0] & 7) << 1) | (asc[1] >> 7); ch = (asc[1] >> 3) & 15
    out = bytearray(); frames = 0; i = 0
    tops = list(boxes(d, 0, len(d)))
    for idx, (typ, s, b, e) in enumerate(tops):
        if typ != 'moof': continue
        sizes = []; data_off = 0; default_size = 0
        for t2, s2, b2, e2 in boxes(d, b, e):
            if t2 != 'traf': continue
            for t3, s3, b3, e3 in boxes(d, b2, e2):
                if t3 == 'tfhd':
                    fl = int.from_bytes(d[b3+1:b3+4], 'big'); p = b3 + 8
                    if fl & 1: p += 8
                    if fl & 2: p += 4
                    if fl & 8: p += 4
                    if fl & 0x10: default_size = struct.unpack('>I', d[p:p+4])[0]
                if t3 == 'trun':
                    fl = int.from_bytes(d[b3+1:b3+4], 'big'); n = struct.unpack('>I', d[b3+4:b3+8])[0]; p = b3 + 8
                    if fl & 1: data_off = struct.unpack('>i', d[p:p+4])[0]; p += 4
                    if fl & 4: p += 4
                    for _ in range(n):
                        if fl & 0x100: p += 4
                        if fl & 0x200: sizes.append(struct.unpack('>I', d[p:p+4])[0]); p += 4
                        else: sizes.append(default_size)
                        if fl & 0x400: p += 4
                        if fl & 0x800: p += 4
        p = s + data_off
        for sz in sizes:
            fl = sz + 7
            hdr = bytes([0xFF, 0xF1, ((aot - 1) << 6) | (sfi << 2) | (ch >> 2),
                         ((ch & 3) << 6) | (fl >> 11), (fl >> 3) & 0xFF, ((fl & 7) << 5) | 0x1F, 0xFC])
            out += hdr + d[p:p+sz]; p += sz; frames += 1
    open(dst, 'wb').write(out)
    sr = [96000,88200,64000,48000,44100,32000,24000,22050,16000,12000,11025,8000][sfi]
    print(f'{src.split(chr(92))[-1].split("/")[-1]}: AOT={aot} {sr}Hz ch={ch} frames={frames} ~{frames*1024/sr:.1f}s')

if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
