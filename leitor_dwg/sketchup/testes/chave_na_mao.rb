# Teste do chave na mao da extensao (roda sem o SketchUp, com um stub).
# Chamado por central_rm/ferramentas/testes/roda.js.
$LOAD_PATH.unshift File.join(__dir__, 'stub')
require_relative '../RM_Coberturas/main'
C = RM_Estruturas::Coberturas
def face(pts, n, root = 'G#1')
  c = [0, 1, 2].map { |k| pts.sum { |p| p[k] } / pts.size.to_f }
  # area do poligono (mm) pela projecao no plano mais "de frente" para a normal
  ax = n.map(&:abs).each_with_index.max[1]
  u, v = [[1, 2], [0, 2], [0, 1]][ax]
  a = 0.0
  pts.each_with_index { |p, i| q = pts[(i + 1) % pts.size]; a += p[u] * q[v] - q[u] * p[v] }
  { 'path' => root, 'name' => root, 'outer' => pts, 'holes' => [], 'normal' => n, 'material' => '',
    'area_m2' => a.abs / 2.0 / 1.0e6, '_root' => root, '_centroid' => c, '_centroid_z' => c[2], '_direct' => false }
end
piso = ->(x0, y0, x1, y1, z, n = [0, 0, 1]) { face([[x0, y0, z], [x1, y0, z], [x1, y1, z], [x0, y1, z]], n) }
parede = ->(x0, y0, x1, y1, h, n) { face([[x0, y0, 0], [x1, y1, 0], [x1, y1, h], [x0, y0, h]], n) }
# banheiro desenhado como caixa: piso e teto iguais -- conta uma vez so'
banheiro = [piso.(0, 0, 6300, 3000, 0), piso.(0, 0, 6300, 3000, 2800, [0, 0, -1])]
# forro: o teto (nivel mais alto) e' menor que o piso do ambiente
forro = [piso.(0, 0, 12000, 11000, 0), piso.(0, 0, 12000, 10000, 2800, [0, 0, -1])]
# divisoria de gesso com espessura: dois lados de 5 m x 2,80 m e as cabeceiras de 10 cm
gesso = [parede.(0, 0, 5000, 0, 2800, [0, -1, 0]), parede.(5000, 100, 0, 100, 2800, [0, 1, 0]),
         parede.(0, 0, 0, 100, 2800, [-1, 0, 0]), parede.(5000, 0, 5000, 100, 2800, [1, 0, 0])]
pav = [piso.(0, 0, 50000, 30000, 0)]
pay = C.chave_payload('Obra teste', [
  { 'servico' => 'pavilhao', 'nome' => 'Pavilhão', 'faces' => pav },
  { 'servico' => 'Banheiro', 'nome' => 'Banheiro masculino', 'faces' => banheiro },
  { 'servico' => 'Forro Modular', 'nome' => 'Escritório', 'faces' => forro },
  { 'servico' => 'Gesso', 'nome' => 'Divisória sala', 'faces' => gesso }])
por = ->(n) { (pay['servicos'].find { |s| s['servico'] == n } || {})['itens'] || [] }
puts JSON.generate(pay)
ok1 = pay['format'] == 'RM_CHAVE_NA_MAO' && pay['pavilhao'] && pay['pavilhao']['area_m2'] == 1500.0
puts ok1 ? 'OK A: pavilhao 1.500 m2 no formato do Orcamento' : 'FALHA A'
b = por.('Banheiro')[0] || {}
ok2 = b['area_m2'] == 18.9 && b['dims'] == '6,30 × 3,00 m' && b['nome'] == 'Banheiro masculino'
puts ok2 ? 'OK B: banheiro em caixa conta uma vez (18,90 m2, 6,30 x 3,00)' : 'FALHA B: ' + b.inspect
f = por.('Forro Modular')[0] || {}
ok3 = f['area_m2'] == 120.0
puts ok3 ? 'OK C: forro pelo nivel de cima (120 m2)' : 'FALHA C: ' + f.inspect
g = por.('Gesso')[0] || {}
ok4 = g['area_m2'] == 14.0 && g['dims'] == '5,00 m × 2,80 m' && pay['servicos'].find { |s| s['servico'] == 'Gesso' }['tipo'] == 'parede'
puts ok4 ? 'OK D: divisoria conta um lado e sem cabeceira (14 m2)' : 'FALHA D: ' + g.inspect
# esquadrias: pelo nome, pelo vidro, porta sem nome pela altura, marcadas e um falso achado (parede)
cands = [
  { 'nome' => 'Janela 4x1', 'larg' => 4002, 'alt' => 998, 'esp' => 60, 'vidro' => 0.8 },
  { 'nome' => 'Component#2', 'larg' => 3996, 'alt' => 1004, 'esp' => 55, 'vidro' => 0.9 },
  { 'nome' => 'Componente#3', 'larg' => 1000, 'alt' => 2100, 'esp' => 40, 'vidro' => 0.0 },
  { 'nome' => 'Porta alumínio', 'larg' => 1000, 'alt' => 2100, 'esp' => 40, 'vidro' => 0.0 },
  { 'nome' => 'Fachada', 'larg' => 5600, 'alt' => 5650, 'esp' => 80, 'vidro' => 0.0, 'marcado' => 'Portão' },
  { 'nome' => 'Parede', 'larg' => 12000, 'alt' => 3000, 'esp' => 150, 'vidro' => 0.0 },
  { 'nome' => 'Porta grossa', 'larg' => 1000, 'alt' => 2100, 'esp' => 600, 'vidro' => 0.0 }]
esq = C.chave_esquadrias(cands)
puts JSON.generate(esq)
j = esq.find { |e| e['tipo'] == 'Janela' } || {}
pt = esq.find { |e| e['tipo'] == 'Porta' } || {}
pg = esq.find { |e| e['tipo'] == 'Portão' } || {}
ok5 = j['qtd'] == 2 && j['larg_mm'] == 4000 && j['alt_mm'] == 1000 && pt['qtd'] == 2 && pt['larg_mm'] == 1000 && pt['alt_mm'] == 2100 &&
      pg['qtd'] == 1 && pg['origem'] == 'marcado' && esq.length == 3 && esq.sum { |e| e['qtd'] } == 5 &&
      j['nomes'] == ['Janela 4x1'] && pt['nomes'] == ['Porta alumínio']
puts ok5 ? 'OK E: esquadrias por nome, vidro, altura e marca; medida a 1 cm; parede e peca grossa nao entram; nome generico (Component#2) nao vai' : 'FALHA E: ' + esq.inspect
pay2 = C.chave_payload('Obra teste', [], esq)
ok6 = pay2['esquadrias'].length == esq.length && pay2['format'] == 'RM_CHAVE_NA_MAO'
puts ok6 ? 'OK F: esquadrias vao no arquivo do Orcamento' : 'FALHA F'
exit(ok1 && ok2 && ok3 && ok4 && ok5 && ok6 ? 0 : 1)
