# frozen_string_literal: true

# vox:smoke runs this with puppetserver ruby on the FIPS packages. Its argument
# is the directory where the agent's eyaml wrote its keys, a plaintext and the
# ciphertext of that plaintext. The FIPS build of jruby-openssl has to be the
# gem that loads, in FIPS mode, and hiera-eyaml has to decrypt the ciphertext.

require 'openssl'
require 'hiera/backend/eyaml/encryptor'
require 'hiera/backend/eyaml/utils'
require 'hiera/backend/eyaml/options'
require 'hiera/backend/eyaml/parser/parser'

spec = Gem.loaded_specs['jruby-openssl']
fips_build = spec&.metadata&.[]('jopenssl_variant') == 'fips'
abort "jruby-openssl #{spec&.version} is not the FIPS build in FIPS mode" unless fips_build && OpenSSL.fips_mode

directory = ARGV.fetch(0)
Hiera::Backend::Eyaml::Options.set('pkcs7_private_key' => File.join(directory, 'keys', 'private_key.pkcs7.pem'),
                                   'pkcs7_public_key' => File.join(directory, 'keys', 'public_key.pkcs7.pem'))
parser = Hiera::Backend::Eyaml::Parser::ParserFactory.hiera_backend_parser
decrypted = parser.parse(File.read(File.join(directory, 'ciphertext')).strip).map(&:to_plain_text).join
plaintext = File.read(File.join(directory, 'plaintext'))
abort "hiera-eyaml decrypted #{decrypted.inspect} instead of #{plaintext.inspect}" unless decrypted == plaintext
