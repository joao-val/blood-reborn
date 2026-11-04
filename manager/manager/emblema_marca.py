"""Blood Reborn Mod Manager: o emblema da janela é a runa da Marca do Caçador, VERMELHA (pedido de 04/11/2026), tirada
do jogo da própria pessoa (nada do jogo vai no repositório).

Fonte: dvdroot_ps4/menu/menu_knowledge_00011.tpf.dcx (o ícone 11, a runa entalhada na pedra; BC7 400x400, PS4).
1. DCX (DFLT: zlib) -> TPF de PS4 -> a textura BC7;
2. desembaralha o nível 0 (blocos 4x4 em grupos de 8x8 na ordem de Morton; largura e altura acolchoadas para múltiplos
   de 32 pixels; o mesmo do SoulsFormats Headerizer.ReadPS4Images + DrSwizzler.PS4Deswizzle, conferido byte a byte com
   a exportação do fxrtex);
3. o Pillow (que vem no BB Port) abre o BC7;
4. recorta a runa da pedra e pinta de vermelho-sangue com contorno e brilho (as funções do marca_runa.py da
   finalização, onde a runa vermelha gira em cima da cabeça do finalizável).

Roda com o Python do port: "Bloodborne.exe --script emblema_marca.py --jogo <pasta do jogo> --saida <arquivo.png>".
Código 0 = gravou; 1 = não deu (a mensagem vai para o stderr)."""
import struct
import sys
import zlib
from pathlib import Path

ICONE = Path('dvdroot_ps4') / 'menu' / 'menu_knowledge_00011.tpf.dcx'
BC7 = 98
N = 256


# ---------------------------------------------------------------- textura
def tpf_textura(dados):
    """(largura, altura, formato DXGI, bytes) da 1ª textura de um TPF de PS4 (SoulsFormats TPF.Texture, plataforma 4)"""
    if dados[:4] != b'TPF\0':
        raise ValueError('não é um TPF')
    quantas, = struct.unpack_from('<i', dados, 8)
    if dados[0xC] != 4 or quantas < 1:
        raise ValueError('TPF que não é de PS4 ou vazio')
    off, tam = struct.unpack_from('<Ii', dados, 0x10)
    larg, alt = struct.unpack_from('<hh', dados, 0x10 + 12)
    dxgi, = struct.unpack_from('<i', dados, 0x10 + 32)
    return larg, alt, dxgi, dados[off:off + tam]


def morton(t, sx=8, sy=8):
    num1 = num2 = 1; x = y = 0
    while sx > 1 or sy > 1:
        if sx > 1:
            x += num2 * (t & 1); t >>= 1; num2 *= 2; sx >>= 1
        if sy > 1:
            y += num1 * (t & 1); t >>= 1; num1 *= 2; sy >>= 1
    return y * 8 + x


def desembaralha_bc(dados, larg, alt, por_bloco=16):
    """nível 0 de uma textura BC de PS4 -> blocos em ordem de linha (largura x altura em pixels, sem o acolchoado)"""
    pl, pa = -(-larg // 32) * 32, -(-alt // 32) * 32           # acolchoado: 8 blocos de 4 pixels
    bl, ba = pl // 4, pa // 4
    if len(dados) < bl * ba * por_bloco:
        raise ValueError('textura menor que o esperado')
    saida = bytearray(bl * ba * por_bloco); i = 0
    ordem = [morton(t) for t in range(64)]
    for ty in range(-(-ba // 8)):
        for tx in range(-(-bl // 8)):
            for p in ordem:
                x, y = tx * 8 + p % 8, ty * 8 + p // 8
                if x < bl and y < ba:
                    d = (y * bl + x) * por_bloco
                    saida[d:d + por_bloco] = dados[i:i + por_bloco]
                i += por_bloco
    # recorta o acolchoado: só as linhas e colunas de blocos da imagem
    bw, bh = -(-larg // 4), -(-alt // 4)
    return b''.join(bytes(saida[(y * bl) * por_bloco:(y * bl + bw) * por_bloco]) for y in range(bh))


def dds_bc7(larg, alt, blocos):
    """cabeçalho DDS DX10 para o Pillow abrir (BC7_UNORM)"""
    cab = struct.pack('<4sIIIIIII44x', b'DDS ', 124, 0x1 | 0x2 | 0x4 | 0x1000 | 0x80000, alt, larg, len(blocos), 0, 1)
    cab += struct.pack('<II4sIIIII', 32, 0x4, b'DX10', 0, 0, 0, 0, 0)         # formato de pixel: só o FourCC DX10
    cab += struct.pack('<IIIII', 0x1000, 0, 0, 0, 0)                          # caps: textura
    cab += struct.pack('<IIIII', BC7, 3, 0, 1, 0)                             # DX10: BC7_UNORM, 2D, 1 elemento
    return cab + blocos


# ---------------------------------------------------------------- a runa (do marca_runa.py da finalização)
def pecas(m):
    W, H = m.size; px = m.load(); vis = bytearray(W * H); out = []
    for y0 in range(H):
        for x0 in range(W):
            if px[x0, y0] and not vis[y0 * W + x0]:
                st, p = [(x0, y0)], []; vis[y0 * W + x0] = 1
                while st:
                    x, y = st.pop(); p.append((x, y))
                    for dx in (-1, 0, 1):
                        for dy in (-1, 0, 1):
                            a, b = x + dx, y + dy
                            if 0 <= a < W and 0 <= b < H and px[a, b] and not vis[b * W + a]:
                                vis[b * W + a] = 1; st.append((a, b))
                out.append(p)
    return sorted(out, key=len, reverse=True)


def maior_peca(m, Image, minimo=0.03):
    """a maior peça + as peças com >= `minimo` dela cujo centro cai na caixa dela (a ponta de baixo sai separada)"""
    todas = pecas(m); melhor = todas[0]
    x0, x1 = min(p[0] for p in melhor), max(p[0] for p in melhor); y0, y1 = min(p[1] for p in melhor), max(p[1] for p in melhor)
    fica = [melhor] + [p for p in todas[1:] if len(p) >= minimo * len(melhor) and
                       x0 <= sum(q[0] for q in p) / len(p) <= x1 and y0 <= sum(q[1] for q in p) / len(p) <= y1 + 0.25 * (y1 - y0)]
    out = Image.new('L', m.size, 0); po = out.load()
    for p in fica:
        for x, y in p:
            po[x, y] = 255
    return out


def runa(im, Image, ImageChops, ImageDraw, ImageFilter, limiar=34, limiar_ponta=24):
    im = im.convert('L'); W, H = im.size
    fundo = im.filter(ImageFilter.GaussianBlur(18))
    escuro = ImageChops.subtract(fundo, im)
    circ = Image.new('L', (W, H), 0); ImageDraw.Draw(circ).ellipse([30, 30, W - 30, H - 30], fill=255)
    limpa = lambda lim: ImageChops.multiply(escuro.point(lambda v: 255 if v > lim else 0), circ).filter(
        ImageFilter.MinFilter(3)).filter(ImageFilter.MaxFilter(3))
    m = maior_peca(limpa(limiar), Image)
    px = m.load(); ys = [y for y in range(H) for x in range(W) if px[x, y]]; y0, y1 = min(ys), max(ys)
    topo = [x for y in range(y0, y0 + int(0.3 * (y1 - y0))) for x in range(W) if px[x, y]]
    xv = sorted(topo)[len(topo) // 2]
    for p in pecas(limpa(limiar_ponta)):
        cx = sum(q[0] for q in p) / len(p); ya = min(q[1] for q in p)
        if len(p) >= 100 and abs(cx - xv) <= 15 and y1 - 5 <= ya <= y1 + 40:
            for x, y in p:
                px[x, y] = 255
    m = m.filter(ImageFilter.MaxFilter(3))
    caixa = m.getbbox()
    lado = max(caixa[2] - caixa[0], caixa[3] - caixa[1]) + 40
    cx, cy = (caixa[0] + caixa[2]) // 2, (caixa[1] + caixa[3]) // 2
    m = m.crop((cx - lado // 2, cy - lado // 2, cx + lado // 2, cy + lado // 2)).resize((N, N), Image.LANCZOS)
    return m.filter(ImageFilter.GaussianBlur(0.8))


def pinta(mask, Image, ImageFilter, cor=(170, 10, 10), contorno=(25, 0, 0), brilho=(255, 40, 25), alfa_halo=0.9):
    borda = mask.filter(ImageFilter.MaxFilter(7))
    halo = borda.filter(ImageFilter.GaussianBlur(9))
    img = Image.new('RGBA', (N, N), brilho + (0,)); img.putalpha(halo.point(lambda a: int(a * alfa_halo)))
    cam = lambda c, a: Image.merge('RGBA', [Image.new('L', (N, N), v) for v in c] + [a])
    img = Image.alpha_composite(img, cam(contorno, borda))
    return Image.alpha_composite(img, cam(cor, mask))


# ---------------------------------------------------------------- principal
def gera(jogo, saida):
    import io
    from PIL import Image, ImageChops, ImageDraw, ImageFilter
    dcx = (Path(jogo) / ICONE).read_bytes()
    if dcx[:4] != b'DCX\0' or dcx[0x28:0x2C] != b'DFLT':
        raise ValueError('o ícone não é um DCX DFLT')
    larg, alt, dxgi, dados = tpf_textura(zlib.decompress(dcx[0x4C:]))
    if dxgi != BC7:
        raise ValueError('o ícone não é BC7 (%d)' % dxgi)
    im = Image.open(io.BytesIO(dds_bc7(larg, alt, desembaralha_bc(dados, larg, alt))))
    im.load()
    pinta(runa(im, Image, ImageChops, ImageDraw, ImageFilter), Image, ImageFilter).save(saida)


def main():
    a = sys.argv[1:]
    if len(a) != 4 or a[0] != '--jogo' or a[2] != '--saida':
        print('uso: emblema_marca.py --jogo <pasta do jogo> --saida <arquivo.png>', file=sys.stderr)
        return 2
    try:
        gera(a[1], a[3])
        return 0
    except Exception as erro:
        print('%s: %s' % (type(erro).__name__, erro), file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
