# frozen_string_literal: true

# script to import transaction file for website
# data has double quote data that is breaking CSV read

# step -1 in an editior like excel do a find and replace
# replace " with /"

require File.expand_path('../../config/environment', __FILE__)

if ARGV[1] && ARGV[1] == 'delete_all'
  puts 'Deleting existing data...'
  Spree::Order.destroy_all
  Spree::Product.destroy_all
  Spree::Product.unscoped.delete_all
  Spree::Variant.unscoped.delete_all
  Spree::OptionValueVariant.unscoped.delete_all
  Spree::Property.delete_all
  Spree::ProductProperty.delete_all

  Spree::Price.delete_all
  Spree::Taxon.destroy_all
  Spree::Taxonomy.destroy_all
  puts 'Done deleting.'
end

if Rails.env == 'staging'
  @local_site_path = '/tmp/images/'
else
  @local_site_path = '/home/louie/shirt/images/'
  # @local_site_path = "/home/louie/Dropbox/DEV/Artistic/sitesucker/www.artisticribbon.com/"
end

require 'csv'
data = CSV.read(ARGV[0], encoding: 'UTF-8', headers: true, header_converters: :symbol, converters: :all)

log_file_name = %(Item_create-#{Time.now.strftime('%m%d%y%I%M')}.log)
log_file = %(#{Rails.root}/log/#{log_file_name})
@logger = Logger.new(log_file)

log_event('Starting to create Items')

@products_created = 0
@products_updated = 0
@variants_created = 0
@error_items = 0

# taxcode
@taxcode = Spree::TaxCategory.find_by_tax_code('exempt')

if @taxcode.nil?
  Spree::TaxCategory.create(name: 'Tax Exempt',
                            is_default: true,
                            tax_code: 'exempt')
end
# setup property hash
setup_properties_hash
# setup options
setup_product_options

hashed_data = data.map(&:to_hash)

hashed_data.each do |rec|
  begin
    @rec_hash = rec

    @action = 'Updated'

    # find spree product
    @product = get_or_create_spree_product(@rec_hash)

    if !@product&.discontinue_on.nil? && @product.discontinue_on < Time.now.to_date
      @action = 'Discontinued, skipped'
    elsif @product
      @product.properties = []
      @product.save

      create_product_taxon(@product, @rec_hash)

      create_and_populate_product_properties(@product, @rec_hash)

      # add options
      @options.each do |o|
        @product.option_types << o unless @product.option_types.include?(o)
      end

      @product.save!

      create_variants(@product, @rec_hash)

      @product.save!
    end

    log_event("#{@action} sku: #{@rec_hash[:sku]}")
  rescue StandardError => e
    log_event("Error: #{e} sku: #{@rec_hash[:sku]}")
  end
end

log_event("finished import: #{@products_created} items created | #{@products_updated} items changed | #{@error_items} not imported")

BEGIN {
  # functions section for script

  def log_event(log_message)
    # little method to log messages and output to screen
    @logger.info log_message
    puts log_message
  end

  def get_or_create_spree_product(h = {})
    # Return product or create on the fly
    p_meta = h[:descrip]
    p_key = "#{h[:sku]} #{h[:style_name]} #{h[:group_name]}"

    psku = %(#{h[:group].strip}-#{h[:season].to_s.strip}-#{h[:style_name].strip}_#{h[:color_code]})

    product_sku = psku.tr(' ', '_')

    product = nil
    variant = Spree::Variant.find_by_sku(h[:sku])
    if variant
      product = variant.product
    else
      variant = Spree::Variant.find_by_sku(product_sku)
      product = variant.product if variant
    end

    if product.nil?

      if h[:group_name][h[:style_name]]
        title = %(#{h[:color_name].strip} #{h[:group_name].strip}).titleize
      else
        title = %(#{h[:style_name].strip} #{h[:color_name].strip} #{h[:group_name].strip}).titleize
      end

      @ig = ImportGroup.find_by_group(h[:group])
      desc = h[:descrip]
      if @ig
        desc = %(#{@ig.desc}\n\n)
        desc += %(Colors:#{@ig.colors})
      end

      discontinue_on = begin
                         Date.parse(h[:discontinue].to_s)
                       rescue
                         nil
                       end

      if discontinue_on.nil? || discontinue_on > Time.now.to_date
        @action = 'Created'
        product = Spree::Product.new(
          name: title,
          description: desc,
          available_on: Date.today - 1.day,
          shipping_category_id: 1,
          meta_title: title,
          meta_description: p_meta,
          meta_keywords: p_key,
          price: h[:std_price],
          sku: product_sku,
          discontinue_on: discontinue_on
        )
        @products_created += 1
      else
        @products_updated += 1
      end
    end

    #     if product.images.empty?
    #       begin
    #         src_image = %Q{#{@local_site_path}/#{h[:isbn].to_s.strip}.jpg}
    #         if File.file?(src_image)
    #           product.images <<  Spree::Image.create!(:attachment => File.open(src_image))
    #           product.save!
    #         else
    #           log_event( "Could not find image #{src_image}")
    #         end
    #       rescue Exception => e
    #         log_event( "#{e.to_s} error loading image id #{h[:isbn]}")
    #       end
    #     end

    product
  end

  def create_product_taxon(product, h = {})
    # at the moment the taxon is the group with the
    # taxonomie as the group also
    group = h[:group_name].strip.titleize
    tgender = h[:gender_name].strip
    gender = ''
    color = h[:color_name].strip.titleize
    gender = case tgender
             when /women/i
               'Ladies'
             when /mens/i
               'Mens'
             else
               tgender
             end

    this_product_group_taxonomy = Spree::Taxonomy.find_by_name(group)
    if this_product_group_taxonomy.nil?
      this_product_group_taxonomy = Spree::Taxonomy.create(
        name: group
      )
    end

    this_product_group_taxon = Spree::Taxon.find_by_taxonomy_id_and_name(this_product_group_taxonomy.id, group)

    if this_product_group_taxon
      desc = ''
      if @ig && h[:group] == @ig.group
        desc = @ig.desc
      else
        @ig = ImportGroup.find_by_group(h[:group])
        desc = @ig.desc if @ig
      end
      unless this_product_group_taxon.description == desc
        this_product_group_taxon.update_attribute(:description, desc)
      end
    end

    this_product_gender_taxon = Spree::Taxon.find_by_taxonomy_id_and_name(this_product_group_taxonomy.id, gender)
    if this_product_gender_taxon.nil?
      this_product_gender_taxon = Spree::Taxon.create(
        name: gender,
        taxonomy_id: this_product_group_taxonomy.id,
        parent_id: this_product_group_taxon.id
      )
    end

    unless product.taxons.include?(this_product_gender_taxon)
      product.taxons << this_product_gender_taxon
    end

    this_product_color_taxon = Spree::Taxon.find_by_parent_id_and_name(this_product_gender_taxon.id, color)
    if this_product_color_taxon.nil?
      this_product_color_taxon = Spree::Taxon.create(
        name: color,
        taxonomy_id: this_product_group_taxonomy.id,
        parent_id: this_product_gender_taxon.id
      )
    end

    unless product.taxons.include?(this_product_color_taxon)
      product.taxons << this_product_color_taxon
    end

    product.save
  end

  def create_and_populate_product_properties(product, rec_hash)
    # little method to create properties based on property
    # hash and data contained in passed hash record
    @properties_hash.each do |_k, v|
      val_from_rec = nil
      if v.last.blank?
        # web_group_value
        if @ig &&  rec_hash[:group] == @ig.group
          val_from_rec = @ig.var2
        else
          @ig = ImportGroup.find_by_group(rec_hash[:group])
          val_from_rec = @ig.var2 if @ig
        end
      else
        val_from_rec = rec_hash[v.last.to_sym]
      end

      next unless val_from_rec && !val_from_rec.to_s.strip.empty?
      val_array = []

      val_array << val_from_rec

      val_array.each do |r_v|
        next if r_v.to_s == '0'
        product.properties << v.first
        product.save

        propval = Spree::ProductProperty.where(product_id: product.id, property_id: v.first.id).last

        if propval.nil?
          propval = Spree::ProductProperty.create(
            product_id: product.id,
            property_id: v.first.id,
            value: r_v
          )

        else
          propval.update_attribute(:value, r_v)
        end
      end
    end
  end

  def create_variants(product, h = {})
    variant = Spree::Variant.find_by_sku(h[:sku])
    if variant.nil?
      variant = Spree::Variant.new(
        sku: h[:sku],
        product_id: product.id,
        price: h[:std_price],
        cost_currency: 'USD',
        track_inventory: true,
        tax_category_id: nil
      )
      @variants_created += 1
    end

    @options.each do |o|
      oval = @option_match[o.name]

      if oval.class == Array
        n = h[oval.first.to_sym]
        p = h[oval.last.to_sym]
      else
        n = h[oval.to_sym]
        p = h[oval.to_sym]
      end

      next if n.to_s.strip.blank?

      opt_val_obj = Spree::OptionValue.find_by_option_type_id_and_name(o.id, n)
      if opt_val_obj.nil?
        opt_val_obj = Spree::OptionValue.create(
          option_type_id: o.id,
          presentation: p,
          name: n
        )
      end

      unless variant.option_values.include?(opt_val_obj)
        variant.option_values << opt_val_obj
      end
    end
    variant.save!
  end

  def setup_product_options
    @options = []
    @option_match = { 'neck' => 'size',
                      'sleeve' => 'sleeve' }
    # setup options for products
    @neck_option = Spree::OptionType.find_by_name('neck')
    if @neck_option.nil?
      @neck_option = Spree::OptionType.create(name: 'neck',
                                              presentation: 'Neck')
    end

    @options << @neck_option
    #
    # @color_option = Spree::OptionType.find_by_name('color')
    # if @color_option.nil?
    #   @color_option = Spree::OptionType.create(      name: 'color',
    #                                                 presentation: 'Color')
    # end
    #
    # @options << @color_option

    @sleeve_option = Spree::OptionType.find_by_name('sleeve')
    if @sleeve_option.nil?
      @sleeve_option = Spree::OptionType.create(name: 'sleeve',
                                                presentation: 'Sleeve')
    end

    @options << @sleeve_option
  end

  def setup_properties_hash
    # little method to setup properties that would be needed for
    # shirts... they are only assigned if the data is not empty
    # setup properties
    @properties_hash = {}

    # Programs start
    # Style
    @style_prop = Spree::Property.find_by_name('style')
    if @style_prop.nil?
      @style_prop = Spree::Property.create(
        name: 'style',
        presentation: 'Style'
      )
    end
    @properties_hash[:style] = [@style_prop, 'style_name']
    # material
    @material_prop = Spree::Property.find_by_name('material')
    if @material_prop.nil?
      @material_prop = Spree::Property.create(
        name: 'material',
        presentation: 'Material'
      )
    end
    @properties_hash.merge!(material: [@material_prop, ''])
  end

}
