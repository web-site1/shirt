Spree::Variant.class_eval do
  scope :my_styles, lambda {|sku|
    where(['SKU LIKE ? AND is_master', sku[/(.*)_/, 1] + '%'])
  }
end