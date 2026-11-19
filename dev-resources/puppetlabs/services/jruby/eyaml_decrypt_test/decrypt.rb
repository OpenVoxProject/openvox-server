# frozen_string_literal: true

# eyaml_decrypt_test.clj loads this into a pooled JRuby instance of the server.

require 'openssl'

# Decrypts the ciphertext that encrypt.rb wrote to a directory the way
# hiera-eyaml's PKCS7 encryptor does, including the stand-in certificate that
# it builds from the first recipient.
def decrypt_eyaml(directory)
  private_key = OpenSSL::PKey::RSA.new(File.read(File.join(directory, 'private_key.pkcs7.pem')))
  pkcs7 = OpenSSL::PKCS7.new(File.binread(File.join(directory, 'ciphertext.der')))
  certificate = OpenSSL::X509::Certificate.new
  certificate.serial = pkcs7.recipients[0].serial
  certificate.issuer = pkcs7.recipients[0].issuer
  certificate.public_key = private_key.public_key
  pkcs7.decrypt(private_key, certificate).force_encoding('UTF-8')
end
