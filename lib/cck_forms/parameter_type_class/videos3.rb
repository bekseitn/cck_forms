class CckForms::ParameterTypeClass::VideoS3
  include CckForms::ParameterTypeClass::Base

  def build_form(form_builder, options)
    set_value_in_hash options

    file_input_id = form_builder_name_to_id form_builder, 'file_input'
    bucket_name_id = form_builder_name_to_id(form_builder, '[value]')

    form = form_builder.text_field :value, { class: 'form-control', name: form_builder.object_name + '[value]', id: bucket_name_id }.merge(options)
    form+= form_builder.file_field :value, { class: 'form-control', name: 'videofiles[file]', id: file_input_id }

    video = nil
    if options[:value].presence
      valid_video_ulr = options[:value].gsub('restoran-kz', '')
      video = %Q{
        <br>
        <div class="video-container" data-video-dir="https://video02.restoran.kz#{valid_video_ulr}/" data-posters-num="0">
          <img class="video-container__fallback-image" src="https://video02.restoran.kz#{valid_video_ulr}/640x360-00002.jpg" />
        </div>

        <link href="/assets/video-js.css" rel="stylesheet">
        <script src="/assets/video.js"></script>
        <script src="/assets/videojs-contrib-hls.js"></script>
      }
    end

    <<HTML
      <div>
        #{form}

        #{video if video}
      </div>

      <script type="text/javascript">
        var $fileInput = $("##{file_input_id}");
        var $bucketNameInput = $("##{bucket_name_id}");
        var $container = $fileInput.parent();
        var loaderClassName = 'js-video-loader';

        var showLoader = function() {
          $container.find('input').hide();
          $container.append('<div class='+ loaderClassName +'>загрузка видео ...</div>');
          $container.find('.video-container').remove();
        };
        var hideLoader = function() {
          $container.find('input').show();
          $container.find('.' + loaderClassName, '.video-container').remove();
        }

        $fileInput.fileupload({
          url: "#{self.admin_video_save_path}",
          add: function(e, data) {
            data.submit();
          },
          formData: function() {
            return $fileInput.serializeArray()
          },
          success: function(res) {
            hideLoader();
            if (res === 'false') {
              alert('Видео не загружено')
            } else {
              $bucketNameInput.val(res)
            }
          },
          error: function() {
            hideLoader();
            alert('Ошибка, видео не загружено')
          },
          start: function() {
            showLoader();
          },
        })

        $(function() {
          $('.video-container').videoContainer({
            video: {
              autoplay: false,
              muted: true,
              loop: false,
            },
          });
        });
      </script>
HTML
  end
end
