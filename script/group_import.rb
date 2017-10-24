require File.expand_path('../../config/environment', __FILE__)

require 'csv'
data = CSV.read(ARGV[0], { encoding: "UTF-8", headers: true, header_converters: :symbol, converters: :all})

hashed_data = data.map { |d| d.to_hash }


hashed_data.each do |rec|
  ig = ImportGroup.find_by_group(rec[:grp])
  if ig
    ig.update_attributes(rec)
  else
    ig = ImportGroup.create(rec)
  end
end  