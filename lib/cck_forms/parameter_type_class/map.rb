class CckForms::ParameterTypeClass::Map
  include CckForms::ParameterTypeClass::Base

  MAP_TYPE_GOOGLE = 'google'.freeze
  MAP_TYPE_YANDEX = 'yandex'.freeze
  DEFAULT_MAP_TYPE = MAP_TYPE_GOOGLE

  mattr_accessor :map_providers
  @@map_providers = [MAP_TYPE_YANDEX, MAP_TYPE_GOOGLE]

  mattr_accessor :google_maps_api_key

  def self.name
    'Точка на карте'
  end

  # Было базе: {latlon: [x, y], zoom: z}
  #
  # Стало в модели: {
  #   latitude: x,
  #   longitude: y,
  #   zoom: z
  # }
  def self.demongoize_value(value, parameter_type_class=nil)
    value = value.to_h
    value.stringify_keys!
    latlon = value['latlon'] || []

    latitude = value['latitude'] || latlon[0]
    longitude = value['longitude'] || latlon[1]
    type_of_map = value['type'] || DEFAULT_MAP_TYPE

    {
        'latitude' => latitude,
        'longitude' => longitude,
        'zoom' => value['zoom'].presence,
        'type' => type_of_map
    }
  end


  # Было в модели: {
  #   latitude: x,
  #   longitude: y,
  #   zoom: z
  # }
  #
  # Стало в базе: {latlon: [x, y], zoom: z}
  def mongoize
    value = self.value.is_a?(Hash) ? self.value : {}
    return {
        'latlon' => [value['latitude'].presence, value['longitude'].presence],
        'zoom' => value['zoom'].presence,
        'type' => value['type'].presence || DEFAULT_MAP_TYPE
    }
  end

  # Если переданы :width и :height, вызовет img_tag, иначе вернет пустую строку.
  def to_s(options = {})
    options ||= {}
    if options[:width].to_i > 0 and options[:height].to_i > 0
      return a_tag(to_s(options.except :link), options[:link]) if options[:link]
      return img_tag options[:width], options[:height]
    end

    ''
  end

  # Возвращает тэг IMG с картинкой карты и точкой на ней, если value не пустое (содержит координаты точки).
  # См. Google/Yandex Maps Static API.
  def img_tag(width, height, options = {})
    map_type = value['type']

    if value['latitude'].present? and value['longitude'].present?
      if map_type == MAP_TYPE_GOOGLE
        zoom_if_any = value['zoom'].present? ? "&zoom=#{value['zoom']}" : nil
        marker_size_if_any = options[:marker_size] ? "|size:#{options[:marker_size]}" : nil

        url = %Q(
          http://maps.googleapis.com/maps/api/staticmap?
            language=ru&
            size=#{width}x#{height}&
            maptype=roadmap&
            markers=color:red#{marker_size_if_any}|
            #{value['latitude']},#{value['longitude']}&
            sensor=false
            #{zoom_if_any}
        ).gsub(/\s+/, '')

      else # yandex
        zoom_if_any = value['zoom'].present? ? "&z=#{value['zoom']}" : nil
        marker_size = options[:marker_size] == :large ? 'l' : 'm'

        url = %Q(
          http://static-maps.yandex.ru/1.x/?
            l=map&
            size=#{width},#{height}&
            pt=#{value['longitude']},#{value['latitude']},pm2bl#{marker_size}&
            #{zoom_if_any}
        ).gsub(/\s+/, '')
      end
      %Q(<img src="#{url}" width="#{width}" height="#{height}" />).html_safe
    else
      ''
    end
  end

  # Возвращает тэг A со ссылкой на карту с маркером объекта.
  def a_tag(content, attrs)
    if attrs[:href] = url
      attrs_strings = []
      attrs.each_pair { |name, value| attrs_strings << sprintf('%s="%s"', name, value) }
      sprintf '<a %s>%s</a>', attrs_strings.join, content
    else
      ''
    end
  end

  # Возвращает урл на карту.
  def url
    if value['latitude'].present? and value['longitude'].present?
      if value['type'] == MAP_TYPE_GOOGLE
        sprintf(
          'http://maps.google.com/maps?%s&t=m&q=%s+%s',
          value['zoom'].present? ? 'z=' + value['zoom'] : '',
          value['latitude'],
          value['longitude']
        )
      else # yandex
        sprintf(
          'http://maps.yandex.ru/?l=map&text=%s&ll=%s%s',
          [value['latitude'], value['longitude']].join(','),
          [value['longitude'], value['latitude']].join(','),
          value['zoom'].present? ? '&z=' + value['zoom'] : nil
        )
      end
    end
  end

  # Построим форму для карты. Представляет собой 3 спрятанных поля latitude, longitude, zoom. Затем рядом ставится ДИВ,
  # на который вешается карта Гугла, и с помощью скриптов изменение полей привязывается к кликам на карте и изменению
  # масштаба.
  #
  # 1 клик на пустом месте ставит точку (пишем в поля), старая точка при этом удаляется. Клик на точке удаляет ее
  # (очищаем поля).
  #
  # Также, слушает событие change поля "город" (facility_page_cck_params_city_value), чтобы по известным названиям
  # городов отцентровать карту на выбранном городе.
  #
  # options:
  #
  #   value     - тек. значение, см. self.demongoize_value
  #   width     - ширина карты
  #   height    - высота карты
  #   latitude  - широта центра карты, если ничего не выбрано
  #   longitude - долгота центра карты, если ничего не выбрано
  #   zoom      - масштаб карты, если ничего не выбрано

  def build_form(form_builder, options)
    set_value_in_hash options

    options = {
        width: 550,
        height: 400,
        latitude: 47.757581,
        longitude: 67.298256,
        zoom: 5,
        value: {},
    }.merge options

    value = (options[:value].is_a? Hash) ? options[:value].stringify_keys : {}

    inputs = []
    id = ''

    form_builder.tap do |value_builder|
      id = form_builder_name_to_id value_builder
      inputs << value_builder.hidden_field(:latitude,  value: value['latitude'])
      inputs << value_builder.hidden_field(:longitude, value: value['longitude'])
      inputs << value_builder.hidden_field(:zoom,      value: value['zoom'])
      inputs << value_builder.hidden_field(:type,      value: value['type'])
    end

    city_id = id.clone
    city_id['map'] = 'city'
    city_id += '_value'

    cities_js = []
    city_class = if defined?(KazakhstanCities::City) then KazakhstanCities::City elsif defined?(City) then City end
    if city_class
      city_class.all.each do |city|
        cities_js.push [city.id, {lat: city.lat.to_f, lon: city.lon.to_f, zoom: city.zoom.to_i}]
      end
    end
    cities_js = Hash[cities_js].to_json

    allowed_maps = @@map_providers
    map_names = {'google' => 'Google', 'yandex' => 'Яндекс'}
    selected_map_type = value['type'].in?(allowed_maps) ? value['type'] : allowed_maps.first

    switchers = []
    switchers << %Q|<div class="btn-group cck-map-switchers #{'hide' if allowed_maps.count < 2}" style="margin-top: 5px;">|
    allowed_maps.map do |map|
      switchers << %Q|<a class="btn btn-default #{selected_map_type == map ? 'active' : nil}" href="#" data-map-type="#{map}">#{map_names[map]}</a>|
    end
    switchers << '</div>'

    map_html_containers = []
    allowed_maps.each do |map|
      map_html_containers.push %Q|<div id="#{id}_#{map}" data-id=#{id} class="map_widget" style="display: none; width: #{options[:width]}px; height: #{options[:height]}px"></div>|
    end

    api_key = @@google_maps_api_key.present? ? "&key=#{@@google_maps_api_key}" : nil

    %Q|
    <div class="map-canvas">
      #{inputs.join}

      <script>
      var mapsReady = {google: false, yandex: false, callback: null, on: function(callback) {
        this.callback = callback;
        this.fireIfReady();
      }, fireIfReady: function() {
        if(this.google && this.yandex && this.callback) { this.callback() }
      }}

      function googleMapReady() { mapsReady.google = true; mapsReady.fireIfReady() }
      function yandexMapReady() { mapsReady.yandex = true; mapsReady.fireIfReady() }

      function loadMapScripts() {
        var script;
        script = document.createElement('script');
        script.type = 'text/javascript';
        script.src = 'https://maps.googleapis.com/maps/api/js?v=3.exp&sensor=false&callback=googleMapReady#{api_key}';
        document.body.appendChild(script);

        script = document.createElement('script');
        script.type = 'text/javascript';
        script.src = 'https://api-maps.yandex.ru/2.0/?coordorder=longlat&load=package.full&wizard=constructor&lang=ru-RU&onload=yandexMapReady';
        document.body.appendChild(script);
      }

      window.onload = loadMapScripts;
      </script>

      <div data-map-data-source data-options='#{options.to_json}' data-id="#{id}" data-cities='#{cities_js}' data-cityid="#{city_id}" data-allowed-maps='#{allowed_maps.to_json}' style="width: #{options[:width]}px; height: #{options[:height]}px">
        #{map_html_containers.join}
      </div>

      #{switchers.join}
    </div>
    |
  end

  def to_diff_value(options = {})
    demongoize_value!
    img_tag(64, 64, marker_size: :small)
  end
end