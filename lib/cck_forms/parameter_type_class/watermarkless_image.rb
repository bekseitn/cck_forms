# Image without watermark. A subclass of Image.
#
class CckForms::ParameterTypeClass::WatermarklessImage < CckForms::ParameterTypeClass::Image
  def self.name
    'Картинка без водяного знака'
  end

  def self.additional_file_attributes
    {no_wm: '1'}
  end
end
