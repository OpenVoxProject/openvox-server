# frozen_string_literal: true

# Writes a private key, a certificate and the PKCS7 ciphertext of a plaintext
# into a directory, made the way hiera-eyaml's PKCS7 encryptor makes them in
# create_keys and encrypt. This runs on MRI, as it does on an agent, because
# BouncyCastle FIPS in approved-only mode refuses the RSA PKCS#1 v1.5 key
# transport that the encryption uses.
#
# Usage: ruby encrypt.rb <directory> <plaintext>

require 'openssl'

abort "Usage: #{$PROGRAM_NAME} <directory> <plaintext>" unless ARGV.length == 2
directory, plaintext = ARGV

key = OpenSSL::PKey::RSA.new(2048)
cert = OpenSSL::X509::Certificate.new
cert.not_before = Time.now
cert.not_after = Time.now + (50 * 365 * 24 * 60 * 60)
cert.public_key = key.public_key
cert.sign(key, OpenSSL::Digest.new('SHA256'))

cipher = OpenSSL::Cipher.new('aes-256-cbc')
ciphertext = OpenSSL::PKCS7.encrypt([cert], plaintext, cipher, OpenSSL::PKCS7::BINARY).to_der

File.write(File.join(directory, 'private_key.pkcs7.pem'), key.to_pem)
File.write(File.join(directory, 'public_key.pkcs7.pem'), cert.to_pem)
File.binwrite(File.join(directory, 'ciphertext.der'), ciphertext)
