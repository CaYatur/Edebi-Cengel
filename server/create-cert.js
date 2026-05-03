#!/usr/bin/env node
/**
 * Self-signed sertifika oluştur (OpenSSL'e ihtiyaç yok)
 * Kullanım: node create-cert.js
 */

const selfsigned = require('selfsigned');
const fs = require('fs');
const path = require('path');

const certDir = path.join(__dirname, 'certs');
const certPath = path.join(certDir, 'cert.pem');
const keyPath = path.join(certDir, 'key.pem');

// Sertifikaları zaten varsa
if (fs.existsSync(certPath) && fs.existsSync(keyPath)) {
  console.log('✅ Sertifikalar zaten var!');
  process.exit(0);
}

// Klasör oluştur
if (!fs.existsSync(certDir)) {
  fs.mkdirSync(certDir, { recursive: true });
  console.log('📁 certs klasörü oluşturuldu');
}

console.log('🔐 Self-signed sertifika oluşturuluyor...\n');

try {
  // Sertifika oluştur
  const pems = selfsigned.generate(
    [{ name: 'commonName', value: 'localhost' }],
    { days: 365, keySize: 2048 }
  );

  // Dosyalara yazdir
  fs.writeFileSync(certPath, pems.cert);
  fs.writeFileSync(keyPath, pems.private);

  console.log('✅ Sertifikalar başarıyla oluşturuldu!\n');
  console.log(`📄 Cert: ${certPath}`);
  console.log(`🔑 Key: ${keyPath}`);
  console.log('\nServer\'ı başlatırken HTTPS kullanılacak.\n');
} catch (error) {
  console.error('❌ Sertifika oluşturma hatası:', error.message);
  console.error('\n💡 Alternatif: selfsigned paketini yükleyin:');
  console.error('   npm install selfsigned\n');
  process.exit(1);
}
