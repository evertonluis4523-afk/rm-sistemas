# Teste da extensão RM Cenas fora do SketchUp: um SketchUp de mentira com
# cenas, câmera e view, e a extensão de verdade carregada por cima.
# Imprime "OK <letra>" para cada verificação; o roda.js confere as letras.
require 'tmpdir'

# o require 'sketchup.rb' da extensão acha um arquivo vazio
STUB = Dir.mktmpdir
File.write(File.join(STUB, 'sketchup.rb'), '')
$LOAD_PATH.unshift(STUB)

def file_loaded?(_f) true end
def file_loaded(_f) end

module UI
  class Menu; def add_submenu(_n) self end; def add_item(*_a) end; def add_separator() end; end
  def self.menu(_n) Menu.new end
  # o relógio do SketchUp: o bloco só roda quando o SketchUp devolve o controle
  # Como no SketchUp: um aviso (janela) aberto dentro do bloco faz o relógio
  # disparar de novo, a não ser que ele já tenha sido parado (UI.stop_timer).
  @fila = []; @parados = []; @avisos = []; @ids = 0; @rodando = nil; @repetidas = 0
  def self.start_timer(_s, _r = false, &b) @ids += 1; @fila << [@ids, b]; @ids end
  def self.stop_timer(id) @parados << id end
  def self.messagebox(txt)
    @avisos << txt
    @repetidas += 1 if @rodando && !@parados.include?(@rodando[0])
    @fila << [@rodando[0], @rodando[1]] if @rodando && !@parados.include?(@rodando[0]) && @repetidas < 5
  end
  def self.avisos() @avisos end
  def self.fila() @fila end
  def self.roda_fila
    until @fila.empty?
      @rodando = @fila.shift
      @rodando[1].call
      @rodando = nil
    end
  end
end

module Sketchup
  def self.read_default(_s, _k, v) v end
  def self.write_default(*_a) end

  Camera = Struct.new(:nome, :aspect_ratio)

  class Page
    attr_reader :name, :camera
    attr_accessor :use_shadow_info, :use_rendering_options, :use_style, :estilo, :sol
    def initialize(nome, cam) @name = nome; @camera = cam; @use_shadow_info = true; @use_rendering_options = true; @use_style = true end
    def use_style?() @use_style end
    def use_shadow_info?() @use_shadow_info end
    def use_rendering_options?() @use_rendering_options end
    def use_camera?() true end
  end

  class Pages
    include Enumerable
    attr_reader :selected_page, :visitadas
    def initialize(lista) @lista = lista; @selected_page = lista[1]; @visitadas = [] end
    def each(&b) @lista.each(&b) end
    # como o SketchUp: entrar na cena reaplica o estilo e o sol guardados nela
    def selected_page=(p)
      @selected_page = p; @visitadas << p.name
      m = Sketchup.active_model
      m.rendering_options.merge!(p.estilo) if p.estilo && p.use_style?
      m.shadow_info.merge!(p.sol) if p.sol && p.use_shadow_info?
    end
    def to_a() @lista.dup end
  end

  class View
    attr_accessor :camera, :vpwidth, :vpheight, :gravadas, :falha_em, :durante
    def initialize() @camera = Camera.new('tela', 0.0); @vpwidth = 1400; @vpheight = 700; @gravadas = []; @durante = [] end
    def refresh() end
    def write_image(o)
      raise 'placa de vídeo' if @falha_em && @gravadas.size == @falha_em
      @durante << yield_estado.call if yield_estado
      @gravadas << o.merge(camera: @camera.nome)
      true
    end
    attr_accessor :yield_estado
  end

  class Model
    attr_reader :pages, :active_view, :options, :ops, :rendering_options, :shadow_info
    def initialize(pages)
      @pages = pages; @active_view = View.new; @options = { 'PageOptions' => { 'ShowTransition' => true } }; @ops = []
      # um SketchUp sem oclusão de ambiente (versão antiga): a chave não existe
      @rendering_options = { 'RenderMode' => 1, 'Texture' => false, 'EdgeDisplayMode' => 1, 'EdgeColorMode' => 0, 'DrawSilhouettes' => true, 'SilhouetteWidth' => 3,
                             'DrawDepthQue' => false, 'ExtendLines' => true, 'DrawLineEnds' => false, 'JitterEdges' => false, 'DrawBackEdges' => false,
                             'DrawHorizon' => true, 'DrawGround' => true, 'DisplayWatermarks' => false, 'MaterialTransparency' => true, 'BackgroundColor' => 'azulado' }
      @shadow_info = { 'DisplayShadows' => false, 'UseSunForAllShading' => false, 'Light' => 80, 'Dark' => 45, 'DisplayOnAllFaces' => true,
                       'DisplayOnGroundPlane' => true, 'EdgesCastShadows' => false, 'ShadowTime' => 'meio-dia' }
    end
    # o exportador do "Exportar > Gráfico 2D": grava pela view de mentira,
    # anotando que foi ele (export_falha: o exportador não dá conta)
    attr_accessor :export_falha
    def export(arquivo, o)
      return false if @export_falha
      @active_view.write_image(o.reject { |k, _| k == :show_summary }.merge(filename: arquivo, via: :exportador))
    end
    def start_operation(*_a) @ops << :inicio end
    def abort_operation() @ops << :desfeita end
    def path() '' end
  end

  class << self; attr_accessor :active_model; end
end

load File.expand_path('../RM_Cenas/main.rb', __dir__)

def modelo(cenas)
  Sketchup.active_model = Sketchup::Model.new(Sketchup::Pages.new(cenas))
end

pasta = Dir.mktmpdir
cenas = [Sketchup::Page.new('Vista aérea', Sketchup::Camera.new('aerea', 16.0 / 9)),
         Sketchup::Page.new('Fachada: frontal/rua', Sketchup::Camera.new('frontal', 0.0)),
         Sketchup::Page.new('Interno', Sketchup::Camera.new('interno', 2.0))]
m = modelo(cenas)
v = m.active_view
v.yield_estado = -> { [m.options['PageOptions']['ShowTransition'], cenas.map(&:use_shadow_info?)] }
arqs = RM_Cenas.exportar(pasta, largura: 3000, suavizar: true, transparente: true, sombras_agora: true)

# A: uma imagem por cena, numerada, na ordem, nome sem caractere proibido
nomes = arqs.map { |a| File.basename(a) }
puts(nomes == ['01 - Vista aérea.png', '02 - Fachada_ frontal_rua.png', '03 - Interno.png'] && v.gravadas.map { |g| g[:camera] } == %w[aerea frontal interno] ? 'OK A' : "FALHA A #{nomes.inspect} #{v.gravadas.map { |g| g[:camera] }.inspect}")

# B: proporção da cena (16:9 e 2:1) ou da tela (2:1), na largura escolhida: sem faixas
tam = v.gravadas.map { |g| [g[:width], g[:height]] }
puts(tam == [[3000, 1688], [3000, 1500], [3000, 1500]] ? 'OK B' : "FALHA B #{tam.inspect}")

# C: fundo transparente, suavização como escolhida
puts(v.gravadas.all? { |g| g[:transparent] == true && g[:antialias] == true } ? 'OK C' : "FALHA C #{v.gravadas.inspect}")

# D: durante a exportação, sem transição e com as sombras de agora em todas
puts(v.durante.all? { |t, s| t == false && s.none? } ? 'OK D' : "FALHA D #{v.durante.inspect}")

# E: depois, tudo como estava: transição, sombras de cada cena, cena escolhida; a operação desfeita
ok = m.options['PageOptions']['ShowTransition'] == true && cenas.all?(&:use_shadow_info?) && m.pages.selected_page.name == 'Fachada: frontal/rua' && m.ops == %i[inicio desfeita]
puts(ok ? 'OK E' : "FALHA E #{[m.options, cenas.map(&:use_shadow_info?), m.pages.selected_page.name, m.ops].inspect}")

# F: sombras "de cada cena" e suavização/fundo desligados: não mexe nas sombras
cenas.each { |c| c.use_shadow_info = true }
m = modelo(cenas); v = m.active_view
v.yield_estado = -> { cenas.map(&:use_shadow_info?) }
RM_Cenas.exportar(pasta, largura: 1920, suavizar: false, transparente: false, sombras_agora: false)
puts(v.durante.all? { |s| s.all? } && v.gravadas.all? { |g| g[:antialias] == false && g[:transparent] == false && g[:width] == 1920 } ? 'OK F' : "FALHA F #{v.gravadas.inspect}")

# G: a placa de vídeo falha no meio: o modelo volta como estava mesmo assim
cenas.each { |c| c.use_shadow_info = true }
m = modelo(cenas); m.active_view.falha_em = 1
erro = begin; RM_Cenas.exportar(pasta, sombras_agora: true); nil; rescue => e; e.message; end
puts(erro == 'placa de vídeo' && m.options['PageOptions']['ShowTransition'] == true && cenas.all?(&:use_shadow_info?) && m.ops.last == :desfeita ? 'OK G' : "FALHA G #{[erro, m.options, m.ops].inspect}")

# H: modelo sem cenas: exporta a vista atual
m = modelo([])
arqs = RM_Cenas.exportar(pasta)
puts(arqs.map { |a| File.basename(a) } == ['01 - Vista atual.png'] ? 'OK H' : "FALHA H #{arqs.inspect}")

# J: "Qualidade máxima": durante a exportação, o acabamento da proposta em todas as cenas
cenas.each { |c| c.use_shadow_info = true; c.use_rendering_options = true }
m = modelo(cenas); v = m.active_view
ro0 = m.rendering_options.dup; si0 = m.shadow_info.dup
v.yield_estado = -> { [m.rendering_options.dup, m.shadow_info.dup, cenas.map(&:use_rendering_options?), cenas.map(&:use_shadow_info?)] }
RM_Cenas.exportar(pasta, qualidade_max: true)
ro, si, est, som = v.durante.first
ok = ro['Texture'] == true && ro['RenderMode'] == 2 && ro['EdgeColorMode'] == 1 && ro['SilhouetteWidth'] == 1 && ro['DrawGround'] == false && ro['DrawHorizon'] == false && ro['ExtendLines'] == false &&
     si['DisplayShadows'] == true && si['UseSunForAllShading'] == true && si['DisplayOnGroundPlane'] == false && si['ShadowTime'] == 'meio-dia' &&
     est.none? && som.none? && v.durante.size == 3 && v.durante.all? { |d| d[0] == ro }
puts(ok ? 'OK J' : "FALHA J #{v.durante.first.inspect}")

# K: depois, o estilo, o sol e as cenas exatamente como estavam; chave que a versão não tem não é criada
ok = m.rendering_options == ro0 && m.shadow_info == si0 && cenas.all?(&:use_rendering_options?) && cenas.all?(&:use_shadow_info?) && !m.rendering_options.key?('AmbientOcclusion')
puts(ok ? 'OK K' : "FALHA K #{[m.rendering_options, m.shadow_info].inspect}")

# L: versão nova do SketchUp, com oclusão de ambiente: liga durante e volta depois
m = modelo(cenas); m.rendering_options['AmbientOcclusion'] = false; v = m.active_view
v.yield_estado = -> { m.rendering_options['AmbientOcclusion'] }
RM_Cenas.exportar(pasta, qualidade_max: true)
puts(v.durante.all? { |a| a == true } && m.rendering_options['AmbientOcclusion'] == false ? 'OK L' : "FALHA L #{v.durante.inspect}")

# M: cenas guardadas com estilo de céu e chão e com o sol de noite (o caso da imagem escura):
# na qualidade máxima nenhuma delas volta; no fim, a tela como estava (mesmo o não salvo)
noite = [Sketchup::Page.new('Frontal', Sketchup::Camera.new('frontal', 16.0 / 9)), Sketchup::Page.new('Aérea', Sketchup::Camera.new('aerea', 16.0 / 9))]
noite.each { |p| p.estilo = { 'DrawHorizon' => true, 'DrawGround' => true, 'BackgroundColor' => 'azul-escuro' }; p.sol = { 'ShadowTime' => '20:30', 'DisplayShadows' => true } }
m = modelo(noite); v = m.active_view
m.shadow_info['ShadowTime'] = '08:30'   # o que a pessoa acertou na tela, sem salvar na cena
ro0 = m.rendering_options.dup; si0 = m.shadow_info.dup
v.yield_estado = -> { [m.rendering_options['DrawHorizon'], m.rendering_options['DrawGround'], m.shadow_info['ShadowTime'], noite.map(&:use_style?)] }
RM_Cenas.exportar(pasta, qualidade_max: true)
durante_ok = v.durante.size == 2 && v.durante.all? { |ceu, chao, hora, st| ceu == false && chao == false && hora == '08:30' && st.none? }
depois_ok = m.rendering_options == ro0 && m.shadow_info == si0 && noite.all?(&:use_style?) && noite.all?(&:use_shadow_info?)
puts(durante_ok && depois_ok ? 'OK M' : "FALHA M #{[v.durante, m.rendering_options, m.shadow_info].inspect}")

# N: grava pelo exportador do "Exportar 2D" (o write_image saía escuro); ele falhando, o write_image
m = modelo(cenas); v = m.active_view
RM_Cenas.exportar(pasta)
pelo_exportador = v.gravadas.all? { |g| g[:via] == :exportador }
m = modelo(cenas); m.export_falha = true; v = m.active_view
RM_Cenas.exportar(pasta)
reserva = v.gravadas.size == 3 && v.gravadas.none? { |g| g[:via] == :exportador }
puts(pelo_exportador && reserva ? 'OK N' : "FALHA N #{[pelo_exportador, reserva].inspect}")

# O: com espera, a gravação só acontece depois de o SketchUp desenhar a cena (no relógio);
# no fim, o aviso recebe os arquivos e o modelo volta como estava
m = modelo(cenas); v = m.active_view
fim = nil
RM_Cenas.exportar(pasta, espera: 1.5, qualidade_max: true) { |arqs, erro| fim = [arqs.size, erro] }
antes_do_relogio = [v.gravadas.size, UI.fila.size, m.ops.dup]
UI.roda_fila
ok = antes_do_relogio == [0, 1, [:inicio]] && v.gravadas.size == 3 && fim == [3, nil] && m.ops == %i[inicio desfeita] && cenas.all?(&:use_style?)
puts(ok ? 'OK O' : "FALHA O #{[antes_do_relogio, v.gravadas.size, fim, m.ops].inspect}")

# P: "Só a vista atual": grava a tela sem trocar de cena nem mexer nas cenas
m = modelo(cenas); v = m.active_view
arqs = RM_Cenas.exportar(pasta, so_atual: true, qualidade_max: true)
ok = arqs.map { |a| File.basename(a) } == ['01 - Vista atual.png'] && m.pages.visitadas.empty? && v.gravadas.first[:camera] == 'tela' && cenas.all?(&:use_style?)
puts(ok ? 'OK P' : "FALHA P #{[arqs, m.pages.visitadas, v.gravadas].inspect}")

# Q: erro no meio, com espera: o aviso recebe o erro e o modelo volta como estava
cenas.each { |c| c.use_shadow_info = true }
m = modelo(cenas); m.active_view.falha_em = 1; m.export_falha = true
fim = nil
RM_Cenas.exportar(pasta, espera: 1.5, sombras_agora: true) { |arqs, erro| fim = [arqs.size, erro && erro.message] }
UI.roda_fila
puts(fim == [1, 'placa de vídeo'] && cenas.all?(&:use_shadow_info?) && m.ops.last == :desfeita ? 'OK Q' : "FALHA Q #{fim.inspect}")

# R: o aviso do fim (uma janela) não faz o relógio repetir: um aviso só, cada cena gravada uma vez
m = modelo(cenas); v = m.active_view
UI.avisos.clear
RM_Cenas.exportar(pasta, espera: 1.5) { |arqs, _erro| UI.messagebox("#{arqs.size} imagens") }
UI.roda_fila
puts(UI.avisos == ['3 imagens'] && v.gravadas.size == 3 ? 'OK R' : "FALHA R #{[UI.avisos, v.gravadas.size].inspect}")

# I: a versão do instalador e a da extensão são a mesma
inst = File.read(File.expand_path('../RM_Cenas.rb', __dir__), encoding: 'UTF-8')[/extension\.version = '([\d.]+)'/, 1]
puts(inst == RM_Cenas::EXTENSION_VERSION ? 'OK I' : "FALHA I #{inst} #{RM_Cenas::EXTENSION_VERSION}")
