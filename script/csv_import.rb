# script to import transaction file for website
# data has double quote data that is breaking CSV read

#step -1 in an editior like excel do a find and replace
# replace " with /"

require File.expand_path('../../config/environment', __FILE__)

require 'csv'
data = CSV.read("/tmp/formalshirts-web-items.CSV", { encoding: "UTF-8", headers: true, header_converters: :symbol, converters: :all})

log_file_name = %Q{Item_create-#{Time.now.strftime("%m%d%y%I%M")}.log}
log_file =  %Q{#{Rails.root}/log/#{log_file_name}}
@logger = Logger.new(log_file)
@logger.info "Starting to create Items"
puts "Starting to create Items"

@products_created = 0
@variants_created = 0
@error_items = 0


hashed_data = data.map { |d| d.to_hash }


hashed_data.each do |rec|
  begin
    # get product sku for this item

    #find spree product
    @product = Spree::Product.find_by_sku(@product_sku)


  rescue Exception => e

  end

end

BEGIN{
  # functions section for script
  def get_product_sku(h = {})
    # passed a hash of the record and return a sku of its parts
    # SKU = %Q{#{group.strip}-#{season.strip}-#{style.strip "spaces are _" }}
    group = h[:group].strip
    season = h[:season].to_s.strip
    style = h[:style].strip.gsub(' ',"_")
    %Q{#{group}-#{season}-#{style}}
  end

  def get_or_create_spree_product(h = {})
    # Return product or create on the fly
    product_sku = get_product_sku(rec)
    product = Spree::Variant.find_by_sku_and_is_master(product_sku,true)
    if !product
      product = Spree::Product.new(
          name: ,
          description: ,
          available_on: Date.today()-1.day,
          shipping_category_id: 1 ,
          meta_description: p_meta,
          meta_keywords: ,
          price:         ,
          sku: product_sku
      )
    end
    product
  end

  def get_shirt_properties
    # Return array of shirt properties or create
    @shirtprops || create_shirt_properties
  end

  def create_shirt_properties
    @shirtprops = []
    ['Style' 'Shirt Type' 'Sleeve Type' 'Fit' 'Gender' 'Material'].each do |spn|
      spp = Spree::Property.find_by_name(spn)
      if !spp
        Spree::Property.create({name: spn,presentation: spn})
      end
      @shirtprops << spp
    end
  end

  
}

