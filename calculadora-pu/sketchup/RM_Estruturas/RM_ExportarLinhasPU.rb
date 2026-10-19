# ============================================================
#  RM Estruturas Pré-Fabricadas
#  Exportar Linhas de Aplicação de PU → Viewer 3D
#
#  Gera as coordenadas 3D exatas de cada linha onde o PU
#  será aplicado, para visualização e validação no viewer.
#
#  Como usar:
#    Extensões → RM Estruturas PU → Exportar Linhas PU
#    No Controle de PU: Viewer 3D → Carregar *_linhasPU.json
#
#  O arquivo leva, além das linhas:
#    pecas  -- a caixa de cada peça lida (o 3D mostra o que foi lido)
#    camera -- a vista atual do SketchUp (o 3D abre igual)
# ============================================================
require 'json'

module RM_LinhasPU

  VERSAO = '1.1.0'

  INCHES_TO_M  = 0.0254
  ADJACENCIA_M = 0.50

  KEYWORDS   = %w[placa pilar viga].freeze
  EXT_ARQ    = %w[.dwg .dxf .obj .dae .skp .png .jpg .rvt].freeze
  SKIP_NOMES = %w[tesoura telhado escada porta janela vidro parafuso
                  chapa pino puxador fechadura alizar marco folha
                  niraj person people human car tree furniture].freeze

  def self.estrutural?(nome)
    n = nome.downcase
    KEYWORDS.any? { |k| n.include?(k) } &&
      !SKIP_NOMES.any? { |k| n.start_with?(k) } &&
      !EXT_ARQ.include?(File.extname(n))
  end

  # Mesma classificação do Exportar Medição PU: os dois arquivos têm de
  # chamar a mesma peça pelo mesmo tipo.
  def self.tipo(nome)
    n = nome.downcase
    return 'Pilar' if n.include?('pilar') || n.include?('coluna') || n.include?('poste')
    return 'Viga'  if n.include?('viga')  || n.include?('baldrame') || n.include?('travessa')
    'Placa'
  end

  def self.world_bounds(defn, world_t)
    bb = defn.bounds
    corners = (0..7).map { |i| world_t * bb.corner(i) }
    xs = corners.map(&:x); ys = corners.map(&:y); zs = corners.map(&:z)
    [xs.min, xs.max, ys.min, ys.max, zs.min, zs.max]
  end

  def self.merge_intervals(ivs)
    sorted = ivs.sort_by { |a, _| a }
    merged = [sorted.first.dup]
    sorted.drop(1).each do |iv|
      if iv[0] <= merged.last[1]
        merged.last[1] = [merged.last[1], iv[1]].max
      else
        merged << iv.dup
      end
    end
    merged
  end

  def self.coletar_tudo(entities, pilares, placas, vigas,
                        parent_t = Geom::Transformation.new)
    entities.each do |e|
      case e
      when Sketchup::ComponentInstance
        nome    = e.definition.name.strip
        world_t = parent_t * e.transformation
        if estrutural?(nome)
          t      = tipo(nome)
          bounds = world_bounds(e.definition, world_t)
          dx = (bounds[1]-bounds[0]).abs
          dy = (bounds[3]-bounds[2]).abs
          dz = (bounds[5]-bounds[4]).abs
          next if [dx,dy,dz].max < 1.0   # ignora peças tiny
          rec = { nome: nome.upcase, tipo: t, bounds: bounds }
          case t
          when 'Pilar' then pilares << rec
          when 'Viga'  then vigas   << rec
          else              placas  << rec
          end
        else
          coletar_tudo(e.definition.entities, pilares, placas, vigas, world_t)
        end
      when Sketchup::Group
        coletar_tudo(e.entities, pilares, placas, vigas,
                     parent_t * e.transformation)
      end
    end
  end

  # Converte polegadas → metros, 4 casas
  def self.m(v); (v * INCHES_TO_M).round(4); end
  def self.pt(x, y, z); [m(x), m(y), m(z)]; end

  # ── Gera linhas de PU em coordenadas reais ────────────────
  def self.gerar_linhas(pilares, placas, vigas)
    linhas = []; id = 0; adj = ADJACENCIA_M / INCHES_TO_M

    # ── PLACAS: linha horizontal na base (junta inferior) ────
    placas.each do |p|
      x0,x1,y0,y1,z0,z1 = p[:bounds]
      dx = (x1-x0).abs; dy = (y1-y0).abs
      z_base = z0   # base da placa = onde o PU é aplicado

      if dx >= dy   # placa estendida em X
        cy = (y0+y1)/2.0
        p1 = pt(x0, cy, z_base); p2 = pt(x1, cy, z_base)
        ml = (dx * INCHES_TO_M).round(3)
      else           # placa estendida em Y
        cx = (x0+x1)/2.0
        p1 = pt(cx, y0, z_base); p2 = pt(cx, y1, z_base)
        ml = (dy * INCHES_TO_M).round(3)
      end

      next if ml < 0.05
      linhas << { id: id+=1, nome: p[:nome], tipo: 'Placa',
                  pt1: p1, pt2: p2, ml: ml, app: 'ext_int', incluir: true }
    end

    # ── PILARES: segmentos verticais por face com placa ───────
    pilares.each do |pilar|
      px0,px1,py0,py1,pz0,pz1 = pilar[:bounds]
      pcx = (px0+px1)/2.0; pcy = (py0+py1)/2.0

      faces = { xp: [], xn: [], yp: [], yn: [] }
      placas.each do |pl|
        plx0,plx1,ply0,ply1,plz0,plz1 = pl[:bounds]
        x_gap = [plx0-px1, px0-plx1, 0].max
        y_gap = [ply0-py1, py0-ply1, 0].max
        next if x_gap > adj || y_gap > adj

        dx = (plx0+plx1)/2.0 - pcx
        dy = (ply0+ply1)/2.0 - pcy
        face = dx.abs >= dy.abs ? (dx>=0 ? :xp : :xn) : (dy>=0 ? :yp : :yn)

        z0 = [plz0,pz0].max; z1 = [plz1,pz1].min
        faces[face] << [z0,z1] if z1 > z0
      end

      # Sem placa encostada não leva PU: o pilar fica fora (regra da RM).
      next if faces.values.all?(&:empty?)

      faces.each do |face_sym, ivs|
        next if ivs.empty?
        merged = merge_intervals(ivs)

        # Posição no espaço da face do pilar
        case face_sym
        when :xp; fx=px1; fy=pcy
        when :xn; fx=px0; fy=pcy
        when :yp; fx=pcx; fy=py1
        when :yn; fx=pcx; fy=py0
        end

        merged.each do |zs, ze|
          ml = ((ze-zs)*INCHES_TO_M).round(3)
          next if ml < 0.05
          linhas << { id: id+=1,
                      nome: "#{pilar[:nome]} · face #{face_sym}",
                      tipo: 'Pilar',
                      pt1: pt(fx, fy, zs),
                      pt2: pt(fx, fy, ze),
                      ml: ml, app: 'ext_int', incluir: true }
        end
      end
    end

    # ── VIGAS: linha na face inferior (Line C) ─────────────
    # Só vigas com placas ABAIXO (intermediárias).
    # Vigas de base não geram linha — já coberta pela placa.
    vigas.each do |viga|
      vx0,vx1,vy0,vy1,vz0,vz1 = viga[:bounds]
      vwx = (vx1-vx0).abs; vwy = (vy1-vy0).abs
      along_x = vwx >= vwy
      viga_cz  = (vz0+vz1)/2.0

      covered = []
      placas.each do |pl|
        plx0,plx1,ply0,ply1,plz0,plz1 = pl[:bounds]
        z_gap = [plz0-vz1, vz0-plz1, 0].max
        next if z_gap > adj
        next if (plz0+plz1)/2.0 >= viga_cz   # placa acima → skip

        if along_x
          y_gap = [ply0-vy1, vy0-ply1, 0].max; next if y_gap > adj
          a0=[plx0,vx0].max; a1=[plx1,vx1].min; covered << [a0,a1] if a1>a0
        else
          x_gap = [plx0-vx1, vx0-plx1, 0].max; next if x_gap > adj
          a0=[ply0,vy0].max; a1=[ply1,vy1].min; covered << [a0,a1] if a1>a0
        end
      end
      next if covered.empty?

      z_line = vz0   # face inferior da viga
      merge_intervals(covered).each do |a0, a1|
        ml = ((a1-a0)*INCHES_TO_M).round(3)
        next if ml < 0.05
        if along_x
          vc = (vy0+vy1)/2.0
          linhas << { id: id+=1, nome: viga[:nome], tipo: 'Viga',
                      pt1: pt(a0,vc,z_line), pt2: pt(a1,vc,z_line),
                      ml: ml, app: 'ext_int', incluir: true }
        else
          vc = (vx0+vx1)/2.0
          linhas << { id: id+=1, nome: viga[:nome], tipo: 'Viga',
                      pt1: pt(vc,a0,z_line), pt2: pt(vc,a1,z_line),
                      ml: ml, app: 'ext_int', incluir: true }
        end
      end
    end

    linhas
  end

  # ── Onde gravar ────────────────────────────────────────────
  # Modelo ainda sem salvar não tem pasta: antes o arquivo ia para um lugar
  # qualquer. Agora pergunta.
  def self.caminho_saida(model, sufixo)
    base = model.path.to_s
    unless base.empty?
      return File.join(File.dirname(base), "#{File.basename(base, '.skp')}#{sufixo}")
    end
    UI.savepanel('Salvar linhas de PU', '', "Sem nome#{sufixo}")
  end

  def self.camera(model)
    c = model.active_view.camera
    v = ->(p) { [m(p.x), m(p.y), m(p.z)] }
    { eye: v.(c.eye), target: v.(c.target), up: [c.up.x, c.up.y, c.up.z].map { |x| x.to_f.round(4) },
      fov: c.fov.to_f.round(2), perspectiva: c.perspective? ? true : false }
  rescue StandardError
    nil
  end

  # ── Ponto de entrada ───────────────────────────────────────
  def self.exportar
    model   = Sketchup.active_model
    pilares = []; placas = []; vigas = []
    coletar_tudo(model.entities, pilares, placas, vigas)

    linhas = gerar_linhas(pilares, placas, vigas)

    if linhas.empty?
      UI.messagebox("Nenhuma linha de PU encontrada.\n\nVerifique os nomes dos componentes.")
      return
    end

    caminho = caminho_saida(model, '_linhasPU.json')
    return if caminho.nil? || caminho.to_s.empty?
    nome_arq  = File.basename(caminho)
    pasta     = File.dirname(caminho)
    nome_obra = File.basename(nome_arq, '_linhasPU.json').gsub(/[_\-]+/, ' ').strip

    pecas = (pilares + placas + vigas).map do |p|
      b = p[:bounds]
      { nome: p[:nome], tipo: p[:tipo], min: pt(b[0], b[2], b[4]), max: pt(b[1], b[3], b[5]) }
    end

    # JSON montado pela biblioteca, e não colando texto: aspas, barra
    # invertida ou acento no nome de uma peça quebravam o arquivo.
    dados = { obra: nome_obra, versao: VERSAO, gerado: Time.now.strftime('%Y-%m-%d %H:%M'),
              unidade: 'm', camera: camera(model), linhas: linhas, pecas: pecas }

    begin
      File.write(caminho, JSON.pretty_generate(dados), encoding: 'UTF-8')
    rescue => e
      UI.messagebox("Erro ao salvar:\n#{e.message}"); return
    end

    cnt = linhas.group_by { |l| l[:tipo] }.transform_values(&:count)
    ml1 = linhas.sum { |l| l[:ml] }

    UI.messagebox(
      "✓ Exportado!\n\n" \
      "Arquivo: #{nome_arq}\nPasta:   #{pasta}\n\n" \
      "#{linhas.size} linhas de PU:\n" \
      "  Pilares: #{cnt['Pilar']||0} segmentos\n" \
      "  Placas:  #{cnt['Placa']||0} linhas\n" \
      "  Vigas:   #{cnt['Viga']||0} linhas\n\n" \
      "ML total (1 lado): #{sprintf('%.2f', ml1)} m\n" \
      "ML total (ext+int): #{sprintf('%.2f', ml1*2)} m\n" \
      "\n" \
      "No Controle de PU: Viewer 3D → Carregar *_linhasPU.json."
    )
  end

end

RM_LinhasPU.exportar
