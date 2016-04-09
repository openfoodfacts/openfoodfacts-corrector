# OpenFoodFacts Corrector Bot
# Search for brands to add relative or group ones.
# Example : "Ben & Jerry's" -> "Unilever"

require 'i18n'
require 'openfoodfacts'

I18n.available_locales = ["en", "fr"]

def openfoodfacts_slug(text)
  I18n.transliterate(text).downcase.strip.gsub(/ *[^\w]+ */i, '-')
end

# MOTHER => [CHILD1, CHILD2]
MOTHER_BRANDS = {
  "Blédina" => ["Blédichef", "Blédilait"],
  "Ferrero" => ["Kinder"]
}

def brand_from_name(name)
  Openfoodfacts::Brand.new(
    'name' => name,
    'url' => "http://world.openfoodfacts.org/brand/#{openfoodfacts_slug(name)}"
  )
end

def fix_mother_brand(child_brand, mother_brand)
  # 1. Fetch brands
  if child_brand = brand_from_name(child_brand) and mother_brand = brand_from_name(mother_brand)
    products_to_fix = []

    # 2. Compare brand products
    mother_brand_product_codes = mother_brand.products.map(&:code)
    child_brand_products = child_brand.products
    products_to_check = child_brand_products.reject { |product| mother_brand_product_codes.include? product.code }

    # 3. Fetch full products data
    full_products_fixed = products_to_check.map do |product|
      full_product = Openfoodfacts::Product.get(product.code)

      puts "- *******"
      puts "- Product #{full_product.code} : #{full_product.product_name}"
      puts "- Web: #{full_product.weburl} - API: #{full_product.url}"

      new_brands = "#{full_product.brands},#{mother_brand.name}"
      puts "> UDPATE brands FROM \"#{full_product.brands}\" TO \"#{new_brands}\""
      full_product.brands = new_brands

      full_product
    end

    # 4. Global report
    puts "- *** REPORT ***"
    puts "- #{child_brand.name} @ #{mother_brand.name}"
    puts "- #{child_brand_products.length} child brand product(s) found"
    puts "- #{products_to_check.length} product(s) to check"
    puts "- #{(products_to_check.length.to_f / child_brand_products.length * 100).round(2)}% products ratio to check"
    puts "- **************"

    full_products_fixed
  end
end

def run!(username, password, debug = true)
  debug = (debug != '0')
  puts "With DEBUG #{debug ? 'Enabled' : 'Disabled'}"
  puts "/!\\ /!\\ /!\\" unless debug

  if user = Openfoodfacts::User.login(username, password)
    MOTHER_BRANDS.each do |mother_brand, child_brands|
      child_brands.each do |child_brand|
        products_to_fix = fix_mother_brand(child_brand, mother_brand)

        products_to_fix.map do |product|
          if debug
            puts "> TO CHECK Product #{product.code} : @ #{product.weburl}"
          elsif product.update(user: user) # Update if not in debug
            puts "< UPDATED Product #{product.code} : @ #{product.weburl}"
            sleep 60 # Delay requests to avoid flooding the server
          else
            puts "< ERROR Product #{product.code} : @ #{product.weburl}"
          end
        end
      end
    end
  else
    raise "Not logged succesfully"
  end
end

if __FILE__ == $0
  if ARGV.length < 2
    puts "Usage: ruby openfoodfacts-corrector.rb USERNAME PASSWORD (DEBUG)"
    puts "Warning: with DEBUG at 0 the correction will be applied to the real OpenFoodFacts database."
  else
    run!(ARGV[0], ARGV[1], ARGV[2])
    puts "Ended"
  end
end