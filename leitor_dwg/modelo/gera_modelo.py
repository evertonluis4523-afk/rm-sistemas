"""Gera o modelo de desenho RM para o AutoCAD.

    python3 modelo/gera_modelo.py          (precisa do pacote ezdxf)

Saem dois arquivos, em centimetros (o 2D da RM):

  RM_MODELO.dxf   vazio: so as camadas e o bloco da ficha. No AutoCAD, abrir
                  e "Salvar como" .dwt (Modelo de desenho) uma vez; depois,
                  todo projeto novo comeca dele.
  RM_EXEMPLO.dxf  o mesmo modelo com uma tesoura de exemplo (dados ficticios)
                  desenhada do jeito certo. O Leitor DWG le este arquivo sem
                  nenhum aviso -- a bateria de testes confere.

As camadas sao o que o Leitor le, e a camada manda mais que a cor:
  RM-BANZO     banzos                         amarelo (2)
  RM-INTERNO   montantes e diagonais          vermelho (1)
  RM-QUADRO    retangulo em volta da estrutura verde (3)
  RM-SUPORTE   suporte de terca, chapa, detalhe -- nunca e peca   cinza (8)
  RM-TEXTO     fichas e anotacoes             branco (7)
  RM-COTA      cotas                          ciano (4)
"""
import os
import ezdxf
from ezdxf import units

AQUI = os.path.dirname(os.path.abspath(__file__))

CAMADAS = [
    ('RM-BANZO', 2, 'Banzos'),
    ('RM-INTERNO', 1, 'Montantes e diagonais'),
    ('RM-QUADRO', 3, 'Quadro em volta de cada estrutura'),
    ('RM-SUPORTE', 8, 'Suporte de terça, chapa, detalhe: nunca é peça'),
    ('RM-TEXTO', 7, 'Fichas e anotações'),
    ('RM-COTA', 4, 'Cotas'),
]

# a ficha: quatro campos, um por linha, dentro de uma moldura
LARG, LIN, ALT_TXT = 260.0, 20.0, 9.0
CAMPOS = [
    ('NOME', 'Nome da estrutura (ex.: TESOURA 01)', 'TESOURA 01'),
    ('BANZO', 'Perfil do banzo (ex.: U 40x100x40 #2,00)', 'U 40x100x40 #2,00'),
    ('INTERNO', 'Perfil interno (ex.: U 30x93x30 #2,00)', 'U 30x93x30 #2,00'),
    ('QTD', 'Quantidade de estruturas iguais', '1'),
]


def novo():
    doc = ezdxf.new('R2010', setup=True)
    doc.units = units.CM
    doc.header['$INSUNITS'] = 5
    doc.header['$MEASUREMENT'] = 1
    doc.header['$LUNITS'] = 2
    for nome, cor, desc in CAMADAS:
        lay = doc.layers.add(nome, color=cor)
        lay.description = desc
    blk = doc.blocks.new(name='FICHA_RM', base_point=(0, 0))
    altura = LIN * len(CAMPOS)
    # moldura e divisões na camada 0: herdam a camada do INSERT (RM-TEXTO)
    blk.add_lwpolyline([(0, 0), (LARG, 0), (LARG, -altura), (0, -altura)], close=True, dxfattribs={'layer': '0'})
    for i in range(1, len(CAMPOS)):
        blk.add_line((0, -LIN * i), (LARG, -LIN * i), dxfattribs={'layer': '0'})
    blk.add_line((70, 0), (70, -altura), dxfattribs={'layer': '0'})
    for i, (tag, prompt, _) in enumerate(CAMPOS):
        y = -LIN * i - LIN / 2 - ALT_TXT / 2
        blk.add_text(tag, height=ALT_TXT * 0.8, dxfattribs={'layer': '0', 'insert': (6, y)})
        blk.add_attdef(tag, insert=(78, y), height=ALT_TXT,
                       dxfattribs={'layer': '0', 'prompt': prompt, 'text': ''})
    return doc


def exemplo(doc):
    msp = doc.modelspace()
    ysup = lambda x: 40 + (x if x <= 600 else 1200 - x) * 110 / 600
    banzo = {'layer': 'RM-BANZO'}
    interno = {'layer': 'RM-INTERNO'}
    msp.add_line((0, 0), (1200, 0), dxfattribs=banzo)
    msp.add_line((0, 40), (600, 150), dxfattribs=banzo)
    msp.add_line((600, 150), (1200, 40), dxfattribs=banzo)
    for x in (0, 200, 400, 600, 800, 1000, 1200):
        msp.add_line((x, 0), (x, ysup(x)), dxfattribs=interno)
    for a, c in ((0, 200), (200, 400), (400, 600)):
        msp.add_line((a, ysup(a)), (c, 0), dxfattribs=interno)
    for a, c in ((600, 800), (800, 1000), (1000, 1200)):
        msp.add_line((a, 0), (c, ysup(c)), dxfattribs=interno)
    # suporte de terça sobre o banzo de cima: camada RM-SUPORTE
    import math
    for x in (200, 400, 800, 1000):
        y = ysup(x)
        ang = math.atan2(110, 600) * (1 if x < 600 else -1)
        c, s = math.cos(ang), math.sin(ang)
        pts = [(-4, -2), (4, -2), (4, 14), (-4, 14)]
        msp.add_lwpolyline([(x + px * c - py * s, y + px * s + py * c) for px, py in pts], close=True,
                           dxfattribs={'layer': 'RM-SUPORTE'})
    msp.add_lwpolyline([(-50, -60), (1250, -60), (1250, 330), (-50, 330)], close=True,
                       dxfattribs={'layer': 'RM-QUADRO'})
    ref = msp.add_blockref('FICHA_RM', (-30, 315), dxfattribs={'layer': 'RM-TEXTO'})
    ref.add_auto_attribs({tag: valor for tag, _, valor in CAMPOS})
    msp.add_text('EXEMPLO DO MODELO RM - dados ficticios. Apague e desenhe a sua estrutura.',
                 height=12, dxfattribs={'layer': 'RM-TEXTO', 'insert': (-50, -110)})


if __name__ == '__main__':
    novo().saveas(os.path.join(AQUI, 'RM_MODELO.dxf'))
    d = novo()
    exemplo(d)
    d.saveas(os.path.join(AQUI, 'RM_EXEMPLO.dxf'))
    print('ok: RM_MODELO.dxf e RM_EXEMPLO.dxf')
