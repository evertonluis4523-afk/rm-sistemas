# Teste da regra de parede dupla da extensao (roda sem o SketchUp, com um stub).
# Chamado por central_rm/ferramentas/testes/roda.js.
$LOAD_PATH.unshift File.join(__dir__, 'stub')
require_relative '../RM_Coberturas/main'
C = RM_Estruturas::Coberturas
def f(path, pts, n, root='Galpao#1')
  c = [0,1,2].map { |k| pts.sum { |p| p[k] } / pts.size.to_f }
  { 'path' => path, 'name' => path, 'outer' => pts, 'holes' => [], 'normal' => n, 'material' => 'm',
    'area_m2' => 80.0, '_root' => root, '_centroid' => c, '_centroid_z' => c[2], '_direct' => false }
end
ret = ->(x0,y0,x1,y1,h){ [[x0,y0,0],[x1,y1,0],[x1,y1,h],[x0,y0,h]] }
# caso A: paredes com espessura (duas faces cada)
paredes_a = -> { [
  f('Galpao / Frente', ret.(0,0,16000,0,5000), [0,-1,0]),
  f('Galpao / Frente', ret.(16000,50,0,50,5000), [0,1,0]),          # lado de dentro da frente
  f('Galpao / Divisoria', ret.(0,2000,16000,2000,5000), [0,-1,0]),   # divisoria a 2 m
  f('Galpao / Divisoria', ret.(16000,2050,0,2050,5000), [0,1,0])] }  # o outro lado da divisoria
faces = paredes_a.call
# caso B: paredes desenhadas como uma face so (sem espessura)
faces_b = [
  f('Galpao / Frente', ret.(0,0,16000,0,5000), [0,-1,0]),
  f('Galpao / Divisoria', ret.(0,2000,16000,2000,5000), [0,-1,0])]
out = C.filter_closure_faces(faces)
paths = out.map { |x| x['path'] }
puts paths.inspect
ok1 = paths.count('Galpao / Frente') == 1 && paths.count('Galpao / Divisoria') == 1
puts ok1 ? 'OK A: frente 1 face, divisoria 1 face' : 'FALHA A'
pb = C.filter_closure_faces(faces_b).map { |x| x['path'] }
ok2 = pb.include?('Galpao / Divisoria') && pb.include?('Galpao / Frente')
puts ok2 ? 'OK B: divisoria sem espessura continua' : 'FALHA B: ' + pb.inspect
# caso C: nada some calado -- o lado de dentro descartado vai junto no
# arquivo, com o motivo, e o arquivo diz de qual versao da extensao veio
C.filter_closure_faces(paredes_a.call)
ign = C.respond_to?(:closure_ignored) ? C.closure_ignored : nil
ok3 = ign.is_a?(Array) && ign.length == 2 && ign.all? { |x| x['ignored_reason'].to_s.length > 5 && x.keys.grep(/^_/).empty? }
puts ok3 ? 'OK C: faces descartadas vao no arquivo com o motivo' : 'FALHA C: ' + ign.inspect[0, 300]
pay = C.respond_to?(:closure_payload) ? C.closure_payload('Galpao', out) : {}
ok4 = pay['extension_version'].to_s =~ /^\d+\.\d+\.\d+$/ && pay['ignored_faces'].is_a?(Array) && pay['ignored_faces'].length == 2 && pay['format'] == 'RM_FECHAMENTO_SKETCHUP'
puts ok4 ? 'OK D: arquivo com a versao da extensao e as faces descartadas' : 'FALHA D: ' + pay.keys.inspect
exit(ok1 && ok2 && ok3 && ok4 ? 0 : 1)
