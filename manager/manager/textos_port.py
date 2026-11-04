"""Blood Reborn Mod Manager: os textos do BB Port junto com os textos dos nossos mods.

O BB Port escreve, a cada abertura, camadas próprias ABAIXO dos mods (out/quit_text e out/rebirth: "Sair para a
Área de Trabalho", Configurações do PC, Renascer na Boneca), cada uma com o menu.msgbnd.dcx inteiro de cada idioma.
O lançador troca arquivo inteiro (o último dono vence), então um mod com menu.msgbnd.dcx apaga esses textos e o jogo
mostra os números (119001...). Este script monta, para cada idioma, o menu da camada de cima do port com as
entradas que os nossos mods mudam (a lista de ids vem do pacote ou do gerenciador), e grava numa pasta de
compatibilidade que o gerenciador põe no fim da ordem.

Roda com o Python do próprio port ("Bloodborne.exe --script textos_port.py --plano plano.json") e usa as funções de
texto do port (scripts/quit_menu.py): o mesmo formato que o port grava, sem copiar o código dele para cá.

plano.json: {"porto", "camada" (pasta msg da camada), "saida" (pasta da compatibilidade, vazia ou inexistente),
             "chave_ids", "resultado" (arquivo de resposta),
             "mods": [{"pasta", "msg" (pasta msg do mod), "ids": {"<FMG>": [ids]}}]}
Resposta: {"ok": true, "linguas": [...]} ou {"ok": false, "erro": "..."}; código 0 / 1.
Na pasta de saída fica blood_reborn_texts.json (as entradas usadas, por hash), que o gerenciador confere.
"""
import hashlib
import json
import sys
from pathlib import Path

REGISTRO = 'blood_reborn_texts.json'
FUNCOES = ('unpack_dcx', 'pack_dcx', 'bnd4_files', 'rebuild_bnd4', 'read_fmg', 'write_fmg')


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def arquivos(Q, archive):
    bnd = Q.unpack_dcx(archive)
    return bnd, {fid: bnd[off:off + ln] for _, off, ln, fid in Q.bnd4_files(bnd)}


def compor(Q, base_path, mods):
    """(bytes do menu novo, {pasta do mod: hash do menu dele}, esperado {fid: {id: texto}})"""
    archive = Path(base_path).read_bytes()
    bnd, base = arquivos(Q, archive)
    novos, usados, esperado = {}, {}, {}
    for pasta, menu, ids in mods:
        _, dele = arquivos(Q, Path(menu).read_bytes())
        usados[pasta] = sha(menu)
        for fid_txt, lista in ids.items():
            fid = int(fid_txt)
            if fid not in base or fid not in dele:
                continue
            textos = novos.get(fid)
            if textos is None:
                textos = Q.read_fmg(base[fid])
            origem = Q.read_fmg(dele[fid])
            for i in lista:
                if i in origem:
                    textos[i] = origem[i]
                    esperado.setdefault(fid, {})[i] = origem[i]
            novos[fid] = textos
    troca = {fid: Q.write_fmg(base[fid], textos) for fid, textos in novos.items()}
    return Q.pack_dcx(archive, Q.rebuild_bnd4(bnd, troca)), usados, esperado


def conferir(Q, base_path, saida, esperado):
    """o menu gravado: as entradas dos mods com o texto deles; todo o resto igual ao da camada do port"""
    _, base = arquivos(Q, Path(base_path).read_bytes())
    _, novo = arquivos(Q, Path(saida).read_bytes())
    if set(base) != set(novo):
        raise ValueError('%s: os FMGs mudaram' % saida)
    for fid, dados in base.items():
        if fid not in esperado:
            if novo[fid] != dados:
                raise ValueError('%s: FMG %d mudou sem ter entrada de mod' % (saida, fid))
            continue
        a, b = Q.read_fmg(dados), Q.read_fmg(novo[fid])
        for i in set(a) | set(b):
            quer = esperado[fid][i] if i in esperado[fid] else a.get(i)
            if b.get(i) != quer:
                raise ValueError('%s: FMG %d id %d ficou diferente' % (saida, fid, i))


def main():
    if len(sys.argv) != 3 or sys.argv[1] != '--plano':
        print('uso: textos_port.py --plano plano.json', file=sys.stderr)
        return 2
    plano = json.loads(Path(sys.argv[2]).read_text(encoding='utf-8'))
    resultado = Path(plano['resultado'])
    try:
        sys.path.insert(0, str(Path(plano['porto']) / 'scripts'))
        import quit_menu as Q
        faltam = [f for f in FUNCOES if not hasattr(Q, f)]
        if faltam:
            raise ValueError('o quit_menu.py deste BB Port não tem: ' + ', '.join(faltam))
        camada, saida = Path(plano['camada']), Path(plano['saida'])
        if saida.exists() and any(saida.iterdir()):
            raise ValueError('a pasta de saída não está vazia: %s' % saida)
        registro = {'schema': 1, 'camada': str(camada), 'chave_ids': plano.get('chave_ids', ''), 'linguas': {}}
        for pasta in sorted(p for p in camada.iterdir() if p.is_dir()):
            base = pasta / 'menu.msgbnd.dcx'
            if not base.is_file():
                continue
            mods = [(m['pasta'], Path(m['msg']) / pasta.name / 'menu.msgbnd.dcx', m['ids']) for m in plano['mods']]
            mods = [m for m in mods if m[1].is_file()]
            if not mods:
                continue
            dados, usados, esperado = compor(Q, base, mods)
            alvo = saida / 'dvdroot_ps4' / 'msg' / pasta.name / 'menu.msgbnd.dcx'
            alvo.parent.mkdir(parents=True, exist_ok=True)
            alvo.write_bytes(dados)
            conferir(Q, base, alvo, esperado)
            registro['linguas'][pasta.name] = {'camada': sha(base), 'mods': usados, 'saida': sha(alvo)}
        if not registro['linguas']:
            raise ValueError('nenhum idioma em comum entre a camada do port e os mods')
        saida.mkdir(parents=True, exist_ok=True)
        (saida / REGISTRO).write_text(json.dumps(registro, indent=1, ensure_ascii=False), encoding='utf-8')
        resultado.write_text(json.dumps({'ok': True, 'linguas': sorted(registro['linguas'])}), encoding='utf-8')
        return 0
    except Exception as erro:  # a resposta vai para o gerenciador, que mostra o erro
        resultado.write_text(json.dumps({'ok': False, 'erro': '%s: %s' % (type(erro).__name__, erro)}, ensure_ascii=False),
                             encoding='utf-8')
        return 1


if __name__ == '__main__':
    sys.exit(main())
