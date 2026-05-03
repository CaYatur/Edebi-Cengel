// Node.js ile self-signed sertifika oluştur (OpenSSL'e ihtiyaç yok)
const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const certDir = path.join(__dirname, 'certs');
const certPath = path.join(certDir, 'cert.pem');
const keyPath = path.join(certDir, 'key.pem');

// Dizini oluştur
if (!fs.existsSync(certDir)) {
  fs.mkdirSync(certDir, { recursive: true });
}

// Sertifikaları zaten varsa
if (fs.existsSync(certPath) && fs.existsSync(keyPath)) {
  console.log('✅ Sertifikalar zaten var!');
  process.exit(0);
}

console.log('🔐 Self-signed sertifika oluşturuluyor...\n');

// OpenSSL yüklüyse kullan
try {
  const isWindows = process.platform === 'win32';
  const command = isWindows
    ? `openssl req -x509 -newkey rsa:2048 -nodes -out "${certPath}" -keyout "${keyPath}" -days 365 -subj "/CN=localhost"`
    : `openssl req -x509 -newkey rsa:2048 -nodes -out "${certPath}" -keyout "${keyPath}" -days 365 -subj "/CN=localhost"`;
  
  execSync(command);
  console.log('✅ OpenSSL ile sertifikalar oluşturuldu!\n');
} catch (error) {
  console.log('⚠️  OpenSSL yüklü değil, Node.js crypto modülüne geçiliyor...\n');
  
  // Eğer OpenSSL yoksa, PowerShell ile Windows sertifikası oluştur
  if (process.platform === 'win32') {
    console.log('💡 PowerShell (Admin) açın ve şunu çalıştırın:\n');
    console.log(`$params = @{`);
    console.log(`  DnsName = "localhost"`);
    console.log(`  CertStoreLocation = "cert:\\CurrentUser\\My"`);
    console.log(`  NotAfter = (Get-Date).AddDays(365)`);
    console.log(`}`);
    console.log(`$cert = New-SelfSignedCertificate @params`);
    console.log(`$exportParams = @{`);
    console.log(`  Cert = $cert`);
    console.log(`  FilePath = "${path.join(__dirname, 'server.pfx')}"`);
    console.log(`  Password = ConvertTo-SecureString -String "admin123" -AsPlainText -Force`);
    console.log(`}`);
    console.log(`Export-PfxCertificate @exportParams`);
    console.log(`\n⚠️  HTTPS olmadan HTTP modunda çalışacak!\n`);
  } else {
    console.log(`💡 Terminal'de çalıştırın:\n`);
    console.log(`openssl req -x509 -newkey rsa:2048 -nodes -out "${certPath}" -keyout "${keyPath}" -days 365 -subj "/CN=localhost"\n`);
  }
}
