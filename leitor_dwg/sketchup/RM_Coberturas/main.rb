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
    EXTENSION_VERSION = '1.2.6'.freeze
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

    def help
      UI.messagebox("RM COBERTURAS E FECHAMENTOS\n\nREGRA GERAL\nCada superfície é exportada uma única vez.\n\nCOBERTURA\nSelecione as faces ou os grupos do telhado. Quando houver face superior e inferior da mesma água, somente a superior será usada.\n\nFECHAMENTO\nSelecione as faces externas ou o grupo/componente do fechamento. Quando houver face externa e interna da mesma parede, somente a externa será usada. Grupos aninhados são percorridos automaticamente. Portas e janelas devem estar recortadas nas faces.\n\nO DWG continua disponível nos dois modos.")
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
      submenu.add_separator
      submenu.add_item('Como usar') { help }
      file_loaded(__FILE__)
    end
  end
end
