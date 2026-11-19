# frozen_string_literal: true

require 'sketchup.rb'
require 'json'
require 'time'

module RM_Estruturas
  module Coberturas
    FORMAT = 'RM_COBERTURA_SKETCHUP'.freeze
    CLOSURE_FORMAT = 'RM_FECHAMENTO_SKETCHUP'.freeze
    VERSION = 1
    # Vai em todo arquivo exportado: o Leitor avisa quando o arquivo veio de
    # uma versao antiga (que descartava parede interna sem dizer nada).
    EXTENSION_VERSION = '1.4.0'.freeze
    MM_PER_INCH = 25.4

    module_function

    def point_mm(point)
      [point.x.to_f * MM_PER_INCH, point.y.to_f * MM_PER_INCH, point.z.to_f * MM_PER_INCH]
    end

    def vector_array(vector)
      copy = vector.clone
      copy.normalize! if copy.length > 0.0
      [copy.x.to_f, copy.y.to_f, copy.z.to_f]
    end

    def entity_id(entity)
      entity.respond_to?(:persistent_id) ? entity.persistent_id : entity.entityID
    end

    def entity_name(entity)
      name = entity.respond_to?(:name) ? entity.name.to_s.strip : ''
      if name.empty? && entity.respond_to?(:definition)
        name = entity.definition.name.to_s.strip
      end
      name.empty? ? entity.typename : name
    end

    def face_hash(face, transform, path, direct, root)
      outer = face.outer_loop.vertices.map { |vertex| point_mm(vertex.position.transform(transform)) }
      holes = face.loops.reject(&:outer?).map do |loop|
        loop.vertices.map { |vertex| point_mm(vertex.position.transform(transform)) }
      end
      edges = face.loops.flat_map(&:edges).uniq.map do |edge|
        {
          'id' => entity_id(edge).to_s,
          'a' => point_mm(edge.start.position.transform(transform)),
          'b' => point_mm(edge.end.position.transform(transform)),
          'shared' => false
        }
      end
      material = face.material || face.back_material
      centroid_z = outer.sum { |point| point[2] } / [outer.length, 1].max.to_f
      centroid = [0, 1, 2].map do |axis|
        outer.sum { |point| point[axis] } / [outer.length, 1].max.to_f
      end
      {
        'id' => [path, entity_id(face)].reject { |value| value.to_s.empty? }.map(&:to_s).join('/'),
        'name' => path.empty? ? "Face #{entity_id(face)}" : path,
        'path' => path,
        'outer' => outer,
        'holes' => holes,
        'normal' => vector_array(face.normal.transform(transform)),
        'area_m2' => face.area(transform).to_f * 0.00064516,
        'material' => material ? material.display_name.to_s : '',
        'edges' => edges,
        '_direct' => direct,
        '_root' => root,
        '_centroid_z' => centroid_z,
        '_centroid' => centroid
      }
    end

    def walk(entity, transform, path, faces, visited, direct = false, root = '')
      return if entity.respond_to?(:hidden?) && entity.hidden?
      case entity
      when Sketchup::Face
        key = [entity_id(entity), transform.to_a.map { |n| n.round(8) }]
        return if visited[key]
        visited[key] = true
        faces << face_hash(entity, transform, path, direct, root)
      when Sketchup::Group, Sketchup::ComponentInstance
        current_name = entity_name(entity)
        child_path = [path, current_name].reject(&:empty?).join(' / ')
        child_transform = transform * entity.transformation
        entity.definition.entities.each do |child|
          walk(child, child_transform, child_path, faces, visited, false, root)
        end
      end
    end

    def roof_slope_percent(face)
      normal = face['normal']
      horizontal = Math.hypot(normal[0].to_f, normal[1].to_f)
      vertical = normal[2].to_f.abs
      vertical < 1.0e-8 ? Float::INFINITY : horizontal / vertical * 100.0
    end

    def filter_roof_faces(faces)
      direct, grouped = faces.partition { |face| face['_direct'] }
      selected = direct.select { |face| face['normal'][2].to_f.abs >= 0.015 && roof_slope_percent(face) <= 150.0 }

      grouped.group_by { |face| face['_root'] }.each_value do |items|
        candidates = items.select do |face|
          face['normal'][2].to_f > 0.015 && roof_slope_percent(face) <= 150.0 && face['area_m2'].to_f >= 0.10
        end
        if candidates.empty?
          candidates = items.select do |face|
            face['normal'][2].to_f.abs > 0.015 && roof_slope_percent(face) <= 150.0 && face['area_m2'].to_f >= 0.10
          end
          candidates = [candidates.max_by { |face| face['_centroid_z'].to_f }].compact
        end
        next if candidates.empty?
        max_area = candidates.map { |face| face['area_m2'].to_f }.max
        max_z = candidates.map { |face| face['_centroid_z'].to_f }.max
        min_z = candidates.map { |face| face['_centroid_z'].to_f }.min
        height_window = [1000.0, (max_z - min_z) * 0.40].max
        candidates.select! do |face|
          face['area_m2'].to_f >= [0.10, max_area * 0.02].max && face['_centroid_z'].to_f >= max_z - height_window
        end
        selected.concat(candidates)
      end

      selected = filter_roof_surface_pairs(selected)
      strip_private_fields(selected)
    end

    def strip_private_fields(faces)
      faces.each do |face|
        face.keys.grep(/^_/).each { |key| face.delete(key) }
      end
      faces
    end

    def closure_signature(face)
      # A assinatura usa as coordenadas globais, sem depender da ordem ou do
      # sentido dos vertices. Assim duas faces realmente coincidentes saem uma
      # vez, mas fachadas iguais em locais diferentes continuam separadas.
      face['outer'].map do |point|
        point.map { |value| (value.to_f * 10.0).round / 10.0 }
      end.sort.flatten.join('|')
    end

    def surface_cross(a, b)
      [a[1].to_f * b[2].to_f - a[2].to_f * b[1].to_f,
       a[2].to_f * b[0].to_f - a[0].to_f * b[2].to_f,
       a[0].to_f * b[1].to_f - a[1].to_f * b[0].to_f]
    end

    def surface_unit(vector)
      length = Math.sqrt(closure_dot(vector, vector))
      length > 1.0e-9 ? vector.map { |value| value.to_f / length } : [1.0, 0.0, 0.0]
    end

    def surface_bounds(face, axis)
      values = face['outer'].map { |point| closure_dot(point, axis) }
      [values.min, values.max]
    end

    def roof_surface_pair?(a, b)
      na = surface_unit(a['normal'])
      nb = surface_unit(b['normal'])
      return false if closure_dot(na, nb).abs < 0.995
      separation = closure_plane_separation(a, b)
      return false if separation < 2.0 || separation > 3000.0
      area_a = a['area_m2'].to_f
      area_b = b['area_m2'].to_f
      return false if [area_a, area_b].min / [area_a, area_b].max < 0.72
      reference = na[2].to_f.abs < 0.90 ? [0.0, 0.0, 1.0] : [1.0, 0.0, 0.0]
      u_axis = surface_unit(surface_cross(na, reference))
      v_axis = surface_unit(surface_cross(na, u_axis))
      closure_overlap_ratio(*surface_bounds(a, u_axis), *surface_bounds(b, u_axis)) >= 0.72 &&
        closure_overlap_ratio(*surface_bounds(a, v_axis), *surface_bounds(b, v_axis)) >= 0.72
    end

    def filter_roof_surface_pairs(faces)
      seen = {}
      unique = faces.select do |face|
        signature = closure_signature(face)
        next false if seen[signature]
        seen[signature] = true
      end
      removed_count = faces.length - unique.length
      unique.group_by { |face| face['_root'].to_s }.each_value do |group|
        removed = {}
        group.each_with_index do |face, i|
          next if removed[i]
          best = nil
          best_separation = Float::INFINITY
          ((i + 1)...group.length).each do |j|
            next if removed[j] || !roof_surface_pair?(face, group[j])
            separation = closure_plane_separation(face, group[j])
            if separation < best_separation
              best = j
              best_separation = separation
            end
          end
          next unless best
          loser = group[best]['_centroid_z'].to_f > face['_centroid_z'].to_f ? i : best
          removed[loser] = true
          removed_count += 1
        end
        group.each_with_index { |face, index| unique.delete(face) if removed[index] }
      end
      @roof_removed_pairs = removed_count
      unique
    end

    def filter_closure_faces(faces)
      vertical = faces.select do |face|
        normal = face['normal']
        normal[2].to_f.abs <= 0.35 && face['outer'].length >= 3 && face['area_m2'].to_f >= 0.10
      end

      seen = {}
      vertical.select! do |face|
        signature = closure_signature(face)
        next false if seen[signature]
        seen[signature] = true
      end

      # Uma parede com espessura tem duas faces verticais: a externa e a
      # interna. Ao selecionar o grupo inteiro ambas chegam aqui, separadas por
      # poucos centimetros, e dobrariam o pedido. Pareamos somente superficies
      # quase paralelas, proximas e com grande sobreposicao; a mais afastada do
      # centro do conjunto e mantida como face externa.
      removed_pairs = 0
      ignored = []
      vertical.group_by { |face| face['_root'].to_s }.each_value do |group|
        next if group.length < 2
        center = [0, 1, 2].map do |axis|
          group.sum { |face| face['_centroid'][axis].to_f } / group.length.to_f
        end
        removed = {}
        group.each_with_index do |face, i|
          next if removed[i]
          best = nil
          best_separation = Float::INFINITY
          ((i + 1)...group.length).each do |j|
            next if removed[j]
            other = group[j]
            next unless closure_wall_pair?(face, other)
            separation = closure_plane_separation(face, other)
            if separation < best_separation
              best = j
              best_separation = separation
            end
          end
          next unless best
          other = group[best]
          score_a = closure_exterior_score(face, center)
          score_b = closure_exterior_score(other, center)
          loser = score_b > score_a ? i : best
          winner = loser == i ? best : i
          removed[loser] = "lado de dentro de #{group[winner]['path']} (#{best_separation.round} mm)"
          removed_pairs += 1
        end
        group.each_with_index do |face, index|
          next unless removed[index]
          vertical.delete(face)
          ignored << face.merge('ignored_reason' => removed[index])
        end
      end
      @closure_removed_pairs = removed_pairs
      # NADA SOME CALADO: a face tomada como lado de dentro de outra parede
      # vai junto no arquivo, com o motivo. O Leitor mostra e traz de volta
      # com um clique se a regra errou (uma divisoria colada numa parede).
      @closure_ignored = strip_private_fields(ignored)
      strip_private_fields(vertical)
    end

    def closure_ignored
      @closure_ignored || []
    end

    def closure_payload(title, faces)
      {
        'format' => CLOSURE_FORMAT,
        'version' => VERSION,
        'extension_version' => EXTENSION_VERSION,
        'units' => 'mm',
        'model' => title,
        'sketchup_version' => (defined?(Sketchup) && Sketchup.respond_to?(:version) ? Sketchup.version : ''),
        'exported_at' => Time.now.iso8601,
        'faces' => faces,
        'ignored_faces' => closure_ignored
      }
    end

    def closure_dot(a, b)
      a[0].to_f * b[0].to_f + a[1].to_f * b[1].to_f + a[2].to_f * b[2].to_f
    end

    def closure_plane_separation(a, b)
      normal = a['normal']
      delta = [0, 1, 2].map { |axis| b['_centroid'][axis].to_f - a['_centroid'][axis].to_f }
      closure_dot(delta, normal).abs
    end

    def closure_overlap_ratio(a0, a1, b0, b1)
      overlap = [a1, b1].min - [a0, b0].max
      span = [a1 - a0, b1 - b0].min
      span > 1.0 ? [overlap, 0.0].max / span : 0.0
    end

    # As duas faces de uma parede moram no MESMO grupo e ficam a centimetros
    # uma da outra. Antes valia ate 3 m e entre grupos diferentes: a parede
    # divisoria 2 m para dentro da fachada, do mesmo tamanho, era tomada pelo
    # lado de dentro da fachada e saia do arquivo.
    CLOSURE_MAX_THICKNESS = 500.0

    def closure_wall_pair?(a, b)
      na = a['normal']
      nb = b['normal']
      return false if closure_dot(na, nb).abs < 0.995
      return false if a['path'].to_s != b['path'].to_s
      separation = closure_plane_separation(a, b)
      return false if separation < 2.0 || separation > CLOSURE_MAX_THICKNESS
      area_a = a['area_m2'].to_f
      area_b = b['area_m2'].to_f
      return false if [area_a, area_b].min / [area_a, area_b].max < 0.72

      # Projeta no eixo horizontal da propria parede e na vertical. Fachadas
      # opostas de um predio sao paralelas, mas ficam longe; retornos vizinhos
      # podem ficar perto, mas nao se sobrepoem nestes dois eixos.
      tangent = [-na[1].to_f, na[0].to_f, 0.0]
      bounds = [a, b].map do |face|
        along = face['outer'].map { |point| closure_dot(point, tangent) }
        height = face['outer'].map { |point| point[2].to_f }
        [along.min, along.max, height.min, height.max]
      end
      closure_overlap_ratio(bounds[0][0], bounds[0][1], bounds[1][0], bounds[1][1]) >= 0.72 &&
        closure_overlap_ratio(bounds[0][2], bounds[0][3], bounds[1][2], bounds[1][3]) >= 0.72
    end

    def closure_exterior_score(face, center)
      normal = face['normal']
      delta = [0, 1, 2].map { |axis| face['_centroid'][axis].to_f - center[axis].to_f }
      radial = closure_dot(delta, normal).abs
      material_bonus = face['material'].to_s.empty? ? 0.0 : 5.0
      radial + material_bonus
    end

    def edge_key(edge)
      points = [edge['a'], edge['b']].map do |point|
        point.map { |value| (value.to_f * 10.0).round / 10.0 }
      end
      points.sort.flatten.join('|')
    end

    def mark_shared_edges(faces)
      index = Hash.new { |hash, key| hash[key] = [] }
      faces.each_with_index do |face, face_index|
        face['edges'].each_with_index do |edge, edge_index|
          index[edge_key(edge)] << [face_index, edge_index]
        end
      end
      index.each_value do |uses|
        next unless uses.map(&:first).uniq.length > 1
        uses.each { |face_index, edge_index| faces[face_index]['edges'][edge_index]['shared'] = true }
      end
    end

    def safe_filename(value)
      text = value.to_s.encode('UTF-8', invalid: :replace, undef: :replace, replace: '')
      text = text.gsub(/[\\\/:*?"<>|]+/, '-').strip
      text.empty? ? 'Cobertura_RM' : text
    end

    def export_selected
      model = Sketchup.active_model
      selection = model.selection.to_a
      if selection.empty?
        UI.messagebox('Selecione as faces superiores da cobertura ou os grupos que as contêm.')
        return
      end

      base_transform = model.respond_to?(:edit_transform) ? model.edit_transform : Geom::Transformation.new
      faces = []
      visited = {}
      selection.each do |entity|
        direct = entity.is_a?(Sketchup::Face)
        root = direct ? 'Faces selecionadas' : "#{entity_name(entity)}##{entity_id(entity)}"
        walk(entity, base_transform, '', faces, visited, direct, root)
      end
      faces.select! { |face| face['outer'].length >= 3 }
      faces = filter_roof_faces(faces)

      if faces.empty?
        UI.messagebox('Nenhuma face de cobertura inclinada foi encontrada na seleção.')
        return
      end

      mark_shared_edges(faces)
      title = model.title.to_s.empty? ? 'Cobertura_RM' : model.title
      default_name = "#{safe_filename(title)}.rmcob"
      target = UI.savepanel('Exportar cobertura para o sistema RM', model.path.to_s.empty? ? nil : File.dirname(model.path), default_name)
      return unless target
      target += '.rmcob' unless File.extname(target).downcase == '.rmcob'

      payload = {
        'format' => FORMAT,
        'version' => VERSION,
        'units' => 'mm',
        'model' => title,
        'sketchup_version' => Sketchup.version,
        'exported_at' => Time.now.iso8601,
        'faces' => faces
      }
      File.open(target, 'wb') { |file| file.write(JSON.pretty_generate(payload)) }
      ignored = @roof_removed_pairs.to_i
      pair_note = ignored.positive? ? "\n#{ignored} face(s) inferior(es) duplicada(s) ignorada(s)" : ''
      UI.messagebox("Cobertura exportada com sucesso.\n\n#{faces.length} face(s) superior(es)#{pair_note}\n#{target}\n\nNo sistema RM, abra a aba Cobertura e clique em Importar SketchUp.")
    rescue StandardError => error
      UI.messagebox("Não foi possível exportar a cobertura.\n\n#{error.class}: #{error.message}")
      warn(error.full_message) if error.respond_to?(:full_message)
    end

    def export_selected_closure
      model = Sketchup.active_model
      selection = model.selection.to_a
      if selection.empty?
        UI.messagebox("Selecione as faces externas, o grupo ou o componente que contém o fechamento.")
        return
      end

      base_transform = model.respond_to?(:edit_transform) ? model.edit_transform : Geom::Transformation.new
      active_path = if model.respond_to?(:active_path) && model.active_path
                      model.active_path.map { |entity| entity_name(entity) }.reject(&:empty?).join(' / ')
                    else
                      ''
                    end
      faces = []
      visited = {}
      selection.each do |entity|
        direct = entity.is_a?(Sketchup::Face)
        root = direct ? 'Faces selecionadas' : "#{entity_name(entity)}##{entity_id(entity)}"
        walk(entity, base_transform, active_path, faces, visited, direct, root)
      end
      faces = filter_closure_faces(faces)

      if faces.empty?
        UI.messagebox('Nenhuma face vertical de fechamento foi encontrada na seleção. Selecione as superfícies externas, o grupo ou o componente das paredes.')
        return
      end

      title = model.title.to_s.empty? ? 'Fechamento_RM' : model.title
      default_name = "#{safe_filename(title)}.rmfecha"
      target = UI.savepanel('Exportar fechamento para o sistema RM', model.path.to_s.empty? ? nil : File.dirname(model.path), default_name)
      return unless target
      target += '.rmfecha' unless File.extname(target).downcase == '.rmfecha'

      payload = closure_payload(title, faces)
      File.open(target, 'wb') { |file| file.write(JSON.pretty_generate(payload)) }
      ignored = closure_ignored
      pair_note = if ignored.empty?
                    ''
                  else
                    nomes = ignored.map { |face| face['path'].to_s }.uniq.first(6).join(', ')
                    "\n#{ignored.length} face(s) tomada(s) como lado de dentro de outra parede: #{nomes}.\nElas vão no arquivo e voltam no sistema RM com um clique."
                  end
      UI.messagebox("Fechamento exportado com sucesso (RM Coberturas #{EXTENSION_VERSION}).\n\n#{faces.length} face(s) verticais#{pair_note}\n#{target}\n\nNo sistema RM, abra Fechamento vertical e selecione o arquivo .rmfecha.")
    rescue StandardError => error
      UI.messagebox("Não foi possível exportar o fechamento.\n\n#{error.class}: #{error.message}")
      warn(error.full_message) if error.respond_to?(:full_message)
    end

    # ================= CHAVE NA MAO =================
    # O orcamento chave na mao (sistema Orcamento RM) cobra hidraulica,
    # pintura, eletrica e piso pela area do pavilhao, e banheiro, forro e as
    # divisorias (gesso, granilite) pela medida de cada um. Os projetos nao
    # tem padrao de nome nem de tag: quem orca marca no modelo o que e' cada
    # coisa (o marcador fica gravado no proprio .skp) e exporta uma vez so'.
    #   - area  (pavilhao, banheiro, forro, piso): faces horizontais de UM
    #     nivel -- o mais baixo (piso) ou o mais alto (forro). Um ambiente
    #     desenhado como caixa (piso e teto) nao conta duas vezes.
    #   - parede (gesso, granilite): faces verticais, a parede com espessura
    #     conta um lado so' (mesma regra do fechamento) e a cabeceira estreita
    #     (a espessura da divisoria) nao entra.
    CHAVE_FORMAT = 'RM_CHAVE_NA_MAO'.freeze
    CHAVE_DICT = 'RM_CHAVE'.freeze
    CHAVE_SERVICOS = [
      ['Pavilhão (área total)', 'pavilhao', 'area', :baixo],
      ['Banheiro', 'Banheiro', 'area', :baixo],
      ['Forro modular', 'Forro Modular', 'area', :alto],
      ['Piso', 'Piso', 'area', :baixo],
      ['Divisórias de gesso', 'Gesso', 'parede', nil],
      ['Divisórias de granilite', 'Granilite', 'parede', nil]
    ].freeze
    CHAVE_CABECEIRA_MM = 250.0

    def chave_servico(chave)
      CHAVE_SERVICOS.find { |s| s[1] == chave }
    end

    def chave_fmt(valor, casas = 2)
      format("%.#{casas}f", valor.to_f).sub('.', ',')
    end

    def chave_extensao(faces, eixo)
      vals = faces.flat_map { |f| f['outer'].map { |p| p[eixo].to_f } }
      vals.empty? ? 0.0 : vals.max - vals.min
    end

    # area de um ambiente marcado: as faces horizontais do nivel pedido
    def chave_area(faces, nivel)
      horiz = faces.select { |f| f['normal'][2].to_f.abs >= 0.9 && f['outer'].length >= 3 }
      return nil if horiz.empty?
      niveis = horiz.group_by { |f| (f['_centroid_z'].to_f / 20.0).round }
      chave = nivel == :alto ? niveis.keys.max : niveis.keys.min
      sel = niveis[chave]
      area = sel.sum { |f| f['area_m2'].to_f }
      dims = "#{chave_fmt(chave_extensao(sel, 0) / 1000.0)} × #{chave_fmt(chave_extensao(sel, 1) / 1000.0)} m"
      { 'area_m2' => area.round(2), 'dims' => dims }
    end

    def chave_largura_horizontal(face)
      pts = face['outer']
      xs = pts.map { |p| p[0].to_f }
      ys = pts.map { |p| p[1].to_f }
      Math.hypot(xs.max - xs.min, ys.max - ys.min)
    end

    # area de divisorias: um lado de cada parede, sem as cabeceiras
    def chave_parede(faces)
      verticais = faces.reject { |f| f['normal'][2].to_f.abs > 0.35 || chave_largura_horizontal(f) < CHAVE_CABECEIRA_MM }
      return nil if verticais.empty?
      um_lado = filter_closure_faces(verticais.map { |f| f.merge('_root' => f['_root'] || 'chave') })
      return nil if um_lado.empty?
      area = um_lado.sum { |f| f['area_m2'].to_f }
      comp = um_lado.sum { |f| chave_largura_horizontal(f) } / 1000.0
      alt = um_lado.map { |f| f['outer'].map { |p| p[2].to_f }.max - f['outer'].map { |p| p[2].to_f }.min }.max.to_f / 1000.0
      { 'area_m2' => area.round(2), 'dims' => "#{chave_fmt(comp)} m × #{chave_fmt(alt)} m", 'comprimento_m' => comp.round(2), 'altura_m' => alt.round(2) }
    end

    # ---------- ESQUADRIAS ----------
    # O modelo tem as medidas certas das portas e janelas. Cada esquadria e'
    # um grupo/componente fino (a espessura do caixilho) em pe': a largura e'
    # a maior medida horizontal e a altura, a vertical. Vale o que estiver
    # marcado (Marcar como esquadria…) e, sem marca, o que se reconhece
    # sozinho: nome/tag com porta, janela, portao, basculante, maxim-ar...,
    # componente que recorta abertura na parede, ou painel com vidro. Marcar
    # "Nao e' esquadria" tira um falso achado. No Orcamento cada tipo e medida
    # vira uma linha da aba Esquadrias (com o preco do banco).
    CHAVE_ESQ_RE = /porta|janela|port[aã]o|basculante|maxi|vitr[oô]|esquadria|veneziana|window|door|pivotante|camar[aã]o/i
    CHAVE_VIDRO_RE = /vidro|glass|transl|cristal/i
    CHAVE_ESQ_TIPOS = %w[Janela Porta Portão Basculante Maxim-ar Outro].freeze
    CHAVE_NOME_GENERICO = /\A(component[ea]?|grupo|group|componentinstance|instance)\s*#?\s*\d*\z/i

    def chave_esq_tipo(nome, vidro, alt_mm)
      n = nome.to_s
      return 'Portão' if n =~ /port[aã]o/i
      return 'Basculante' if n =~ /basculante/i
      return 'Maxim-ar' if n =~ /maxi/i
      return 'Porta' if n =~ /porta|door|pivotante|camar[aã]o/i
      return 'Janela' if n =~ /janela|window|vitr|veneziana/i
      # sem nome que diga: porta vai do chao a mais de 1,90 m; janela tem vidro
      return 'Porta' if alt_mm >= 1900
      return 'Janela' if vidro
      'Esquadria'
    end

    # c: {nome, larg, alt, esp (mm), vidro (fracao da frente em vidro), marcado (tipo ou nil), auto (motivo)}
    def chave_esq_vale?(c)
      return true if c['marcado']
      # fina e do tamanho de uma esquadria (o portao de 5,65 x 5,60 m cabe; uma parede inteira, nao)
      c['esp'].to_f <= 400 && c['larg'].to_f.between?(300, 7000) && c['alt'].to_f.between?(300, 7000)
    end

    # junta por tipo e medida (arredondada a 1 cm): uma linha por peca igual
    def chave_esquadrias(cands)
      por = {}
      cands.each do |c|
        next unless chave_esq_vale?(c)
        tipo = c['marcado'] || chave_esq_tipo(c['nome'], c['vidro'].to_f >= 0.3, c['alt'].to_f)
        larg = (c['larg'].to_f / 10.0).round * 10
        alt = (c['alt'].to_f / 10.0).round * 10
        k = [tipo, larg, alt]
        por[k] ||= { 'tipo' => tipo, 'larg_mm' => larg, 'alt_mm' => alt, 'qtd' => 0, 'nomes' => [], 'origem' => c['marcado'] ? 'marcado' : 'automático' }
        por[k]['qtd'] += 1
        nome = c['nome'].to_s.strip
        # "Component#2", "Grupo", "ComponentInstance": nome que o SketchUp da' sozinho nao diz nada
        next if nome =~ CHAVE_NOME_GENERICO
        por[k]['nomes'] << nome unless nome.empty? || por[k]['nomes'].include?(nome) || por[k]['nomes'].length >= 4
      end
      por.values.sort_by { |e| [e['tipo'], -e['larg_mm'], -e['alt_mm']] }
    end

    # medida do grupo/componente no modelo (mm), pelas 8 quinas da definicao
    def chave_esq_medida(ent, transform)
      bb = ent.definition.bounds
      t = transform * ent.transformation
      pts = (0..7).map { |i| point_mm(bb.corner(i).transform(t)) }
      dx = pts.map { |p| p[0] }.max - pts.map { |p| p[0] }.min
      dy = pts.map { |p| p[1] }.max - pts.map { |p| p[1] }.min
      dz = pts.map { |p| p[2] }.max - pts.map { |p| p[2] }.min
      [[dx, dy].max, dz, [dx, dy].min]
    end

    def chave_esq_vidro(ent)
      faces = ent.definition.entities.grep(Sketchup::Face)
      tot = faces.sum { |f| f.area.to_f }
      return 0.0 if tot <= 0
      vid = faces.select { |f| [f.material, f.back_material].compact.any? { |m| m.display_name.to_s =~ CHAVE_VIDRO_RE } }.sum { |f| f.area.to_f }
      vid / tot * 2.0 # duas faces por vidro: a frente conta uma
    end

    def chave_esq_procura(entities, transform, saida)
      entities.each do |e|
        next if e.respond_to?(:hidden?) && e.hidden?
        next unless e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
        marca = e.get_attribute(CHAVE_DICT, 'servico')
        next if marca == 'nao_esquadria'
        nome = [e.name.to_s, e.definition.name.to_s, (e.layer ? e.layer.name.to_s : '')].reject(&:empty?).join(' ')
        corta = e.definition.respond_to?(:behavior) && e.definition.behavior.respond_to?(:cuts_opening?) && e.definition.behavior.cuts_opening?
        if marca == 'esquadria' || nome =~ CHAVE_ESQ_RE || corta
          larg, alt, esp = chave_esq_medida(e, transform)
          saida << { 'nome' => (e.get_attribute(CHAVE_DICT, 'nome') || entity_name(e)).to_s, 'larg' => larg, 'alt' => alt, 'esp' => esp,
                     'vidro' => chave_esq_vidro(e), 'marcado' => marca == 'esquadria' ? e.get_attribute(CHAVE_DICT, 'tipo') : nil }
          next
        end
        vidro = chave_esq_vidro(e)
        if vidro >= 0.3
          larg, alt, esp = chave_esq_medida(e, transform)
          if esp <= 400 && larg >= 300 && alt >= 300
            saida << { 'nome' => entity_name(e), 'larg' => larg, 'alt' => alt, 'esp' => esp, 'vidro' => vidro, 'marcado' => nil }
            next
          end
        end
        chave_esq_procura(e.definition.entities, transform * e.transformation, saida)
      end
    end

    def chave_marcar_esquadria
      model = Sketchup.active_model
      sel = model.selection.to_a.select { |e| e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance) }
      if sel.empty?
        UI.messagebox('Selecione as portas ou janelas (grupos ou componentes) antes de marcar.')
        return
      end
      resp = UI.inputbox(['Tipo', 'Nome (opcional)'], ['Janela', ''], [CHAVE_ESQ_TIPOS.join('|'), ''], 'Marcar como esquadria')
      return unless resp
      model.start_operation('Marcar esquadria', true)
      sel.each do |e|
        e.set_attribute(CHAVE_DICT, 'servico', 'esquadria')
        e.set_attribute(CHAVE_DICT, 'tipo', resp[0].to_s)
        e.set_attribute(CHAVE_DICT, 'nome', resp[1].to_s.strip.empty? ? entity_name(e) : resp[1].to_s)
      end
      model.commit_operation
      UI.messagebox("#{sel.length} esquadria(s) marcadas como #{resp[0]}.")
    end

    def chave_nao_esquadria
      model = Sketchup.active_model
      sel = model.selection.to_a.select { |e| e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance) }
      model.start_operation('Não é esquadria', true)
      sel.each { |e| e.set_attribute(CHAVE_DICT, 'servico', 'nao_esquadria') }
      model.commit_operation
      UI.messagebox("#{sel.length} item(ns) não entram mais como esquadria.")
    end

    # marcados: [{servico, nome, faces}] -> o arquivo que o Leitor DWG abre (aba Chave na mao)
    def chave_payload(title, marcados, esquadrias = [])
      pavilhao = 0.0
      por = {}
      marcados.each do |m|
        s = chave_servico(m['servico'])
        next unless s
        med = s[2] == 'parede' ? chave_parede(m['faces']) : chave_area(m['faces'], s[3])
        next unless med && med['area_m2'].to_f > 0
        if s[1] == 'pavilhao'
          pavilhao += med['area_m2'].to_f
          next
        end
        por[s[1]] ||= { 'servico' => s[1], 'tipo' => s[2], 'itens' => [] }
        por[s[1]]['itens'] << { 'nome' => m['nome'].to_s }.merge(med)
      end
      {
        'format' => CHAVE_FORMAT,
        'versao' => 1,
        'origem' => 'sketchup',
        'extension_version' => EXTENSION_VERSION,
        'arquivo' => title,
        'exported_at' => Time.now.iso8601,
        'pavilhao' => pavilhao > 0 ? { 'area_m2' => pavilhao.round(2), 'fonte' => 'SketchUp (marcado)' } : nil,
        'servicos' => por.values,
        'esquadrias' => esquadrias
      }
    end

    def chave_marcar(chave)
      model = Sketchup.active_model
      sel = model.selection.to_a.select { |e| e.is_a?(Sketchup::Face) || e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance) }
      if sel.empty?
        UI.messagebox('Selecione o piso, o forro ou as paredes (faces, grupos ou componentes) antes de marcar.')
        return
      end
      s = chave_servico(chave)
      padrao = sel.length == 1 && !sel[0].is_a?(Sketchup::Face) ? entity_name(sel[0]) : s[0]
      resp = UI.inputbox(['Nome (sai no orçamento)'], [padrao], "Marcar como #{s[0]}")
      return unless resp
      model.start_operation('Marcar chave na mão', true)
      sel.each do |e|
        e.set_attribute(CHAVE_DICT, 'servico', chave)
        e.set_attribute(CHAVE_DICT, 'nome', resp[0].to_s)
      end
      model.commit_operation
      UI.messagebox("#{sel.length} item(ns) marcados como #{s[0]}.")
    end

    def chave_desmarcar
      model = Sketchup.active_model
      model.start_operation('Desmarcar chave na mão', true)
      n = 0
      model.selection.each { |e| next unless e.respond_to?(:attribute_dictionary) && e.attribute_dictionary(CHAVE_DICT); e.attribute_dictionaries.delete(CHAVE_DICT); n += 1 }
      model.commit_operation
      UI.messagebox("#{n} item(ns) desmarcados.")
    end

    # percorre o modelo inteiro atras do que foi marcado (inclusive dentro de grupos)
    def chave_procura(entities, transform, saida)
      entities.each do |e|
        next if e.respond_to?(:hidden?) && e.hidden?
        servico = e.respond_to?(:get_attribute) ? e.get_attribute(CHAVE_DICT, 'servico') : nil
        servico = nil if %w[esquadria nao_esquadria].include?(servico)
        if servico
          faces = []
          walk(e, transform, '', faces, {}, e.is_a?(Sketchup::Face), "#{entity_name(e)}##{entity_id(e)}")
          saida << { 'servico' => servico, 'nome' => e.get_attribute(CHAVE_DICT, 'nome').to_s, 'faces' => faces }
        elsif e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
          chave_procura(e.definition.entities, transform * e.transformation, saida)
        end
      end
    end

    def chave_exportar
      model = Sketchup.active_model
      marcados = []
      chave_procura(model.entities, Geom::Transformation.new, marcados)
      # faces soltas com o mesmo servico e nome viram um item so' (o piso de
      # um banheiro desenhado em varias faces); grupo/componente e' um item
      juntos = {}
      lista = []
      marcados.each do |m|
        if m['faces'].all? { |f| f['_direct'] }
          k = [m['servico'], m['nome']]
          if juntos[k]
            juntos[k]['faces'].concat(m['faces'])
          else
            juntos[k] = m
            lista << m
          end
        else
          lista << m
        end
      end
      marcados = lista
      cands = []
      chave_esq_procura(model.entities, Geom::Transformation.new, cands)
      esquadrias = chave_esquadrias(cands)
      if marcados.empty? && esquadrias.empty?
        UI.messagebox("Nada marcado ainda.\n\nSelecione o piso de um banheiro, o forro ou as divisórias e use RM Coberturas › Chave na mão › Marcar como…")
        return
      end
      title = model.title.to_s.empty? ? 'Obra' : model.title
      payload = chave_payload(title, marcados, esquadrias)
      target = UI.savepanel('Exportar chave na mão para o Orçamento RM', model.path.to_s.empty? ? nil : File.dirname(model.path), "#{safe_filename(title)} - chave na mao.json")
      return unless target
      target += '.json' unless File.extname(target).downcase == '.json'
      File.open(target, 'wb') { |file| file.write(JSON.pretty_generate(payload)) }
      linhas = payload['servicos'].map { |s| "#{s['servico']}: #{chave_fmt(s['itens'].sum { |i| i['area_m2'].to_f })} m²" }
      linhas.unshift("Pavilhão: #{chave_fmt(payload['pavilhao']['area_m2'])} m²") if payload['pavilhao']
      esquadrias.each { |e| linhas << "#{e['qtd']} × #{e['tipo']} #{chave_fmt(e['larg_mm'] / 1000.0)} × #{chave_fmt(e['alt_mm'] / 1000.0)} m" }
      UI.messagebox("Chave na mão exportado (RM Coberturas #{EXTENSION_VERSION}).\n\n#{linhas.join("\n")}\n\n#{target}\n\nAbra este arquivo no Leitor DWG, aba Chave na mão (junto da planta, se quiser), confira e use Enviar para o Orçamento.")
    rescue StandardError => error
      UI.messagebox("Não foi possível exportar o chave na mão.\n\n#{error.class}: #{error.message}")
      warn(error.full_message) if error.respond_to?(:full_message)
    end

    def help
      UI.messagebox("RM COBERTURAS E FECHAMENTOS\n\nREGRA GERAL\nCada superfície é exportada uma única vez.\n\nCOBERTURA\nSelecione as faces ou os grupos do telhado. Quando houver face superior e inferior da mesma água, somente a superior será usada.\n\nFECHAMENTO\nSelecione as faces externas ou o grupo/componente do fechamento. Quando houver face externa e interna da mesma parede, somente a externa será usada. Grupos aninhados são percorridos automaticamente. Portas e janelas devem estar recortadas nas faces.\n\nCHAVE NA MÃO\nSelecione o piso de cada banheiro, o forro, o piso e as divisórias (faces, grupos ou componentes) e use Chave na mão › Marcar como…; marque também o piso do pavilhão inteiro. Portas e janelas são achadas sozinhas (pelo nome, pelo vidro ou por recortarem a parede), com a medida do modelo; se alguma não for achada, use Marcar seleção como esquadria…, e o que não for esquadria, Não é esquadria. O marcador fica salvo no modelo. No fim, Exportar chave na mão… e abra o arquivo no Leitor DWG, aba Chave na mão, que envia tudo para o Orçamento RM.\n\nO DWG continua disponível nos dois modos.")
    end

    unless file_loaded?(__FILE__)
      menu = begin
        UI.menu('Extensions')
      rescue StandardError
        UI.menu('Plugins')
      end
      submenu = menu.add_submenu('RM Coberturas')
      submenu.add_item('Exportar cobertura selecionada…') { export_selected }
      submenu.add_item('Exportar fechamento selecionado…') { export_selected_closure }
      chave = submenu.add_submenu('Chave na mão')
      CHAVE_SERVICOS.each { |s| chave.add_item("Marcar seleção como #{s[0]}…") { chave_marcar(s[1]) } }
      chave.add_separator
      chave.add_item('Marcar seleção como esquadria…') { chave_marcar_esquadria }
      chave.add_item('Não é esquadria (ignorar)') { chave_nao_esquadria }
      chave.add_separator
      chave.add_item('Desmarcar seleção') { chave_desmarcar }
      chave.add_separator
      chave.add_item('Exportar chave na mão…') { chave_exportar }
      submenu.add_separator
      submenu.add_item('Como usar') { help }
      file_loaded(__FILE__)
    end
  end
end
