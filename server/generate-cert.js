// Self-signed sertifika oluştur
const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

const certDir = path.join(__dirname, 'certs');

// Dizini oluştur
if (!fs.existsSync(certDir)) {
  fs.mkdirSync(certDir, { recursive: true });
  console.log('📁 certs klasörü oluşturuldu');
}

const certPath = path.join(certDir, 'cert.pem');
const keyPath = path.join(certDir, 'key.pem');

// Sertifika zaten varsa
if (fs.existsSync(certPath) && fs.existsSync(keyPath)) {
  console.log('✅ Sertifikalar zaten var!');
  process.exit(0);
}

console.log('🔐 Self-signed sertifika oluşturuluyor...');

try {
  // OpenSSL ile sertifika oluştur
  const command = `openssl req -x509 -newkey rsa:2048 -nodes -out "${certPath}" -keyout "${keyPath}" -days 365 -subj "/CN=localhost"`;
  execSync(command, { stdio: 'inherit' });
  console.log('✅ Sertifikalar başarıyla oluşturuldu!');
  console.log(`📜 Cert: ${certPath}`);
  console.log(`🔑 Key: ${keyPath}`);
} catch (error) {
  console.error('❌ OpenSSL yüklü değil veya hata oluştu');
  console.error('💡 Windows PowerShell (Admin) ile şu komutu çalıştırabilirsiniz:');
  console.error(`$cert = New-SelfSignedCertificate -DnsName "localhost" -CertStoreLocation "cert:\\CurrentUser\\My" -NotAfter (Get-Date).AddDays(365)`);
  console.error(`Export-PfxCertificate -Cert $cert -FilePath certs\\cert.pfx -Password (ConvertTo-SecureString -String "password" -AsPlainText -Force)`);
  process.exit(1);
}
