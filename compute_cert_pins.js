#!/usr/bin/env node
const tls = require('tls');
const crypto = require('crypto');

const args = process.argv.slice(2);
const hosts = args.length ? args : ['api.orbit.app','api.openweathermap.org'];

function getSPKIPin(host, port = 443, timeout = 15000) {
  return new Promise((resolve, reject) => {
    const socket = tls.connect({ host, port, servername: host, rejectUnauthorized: false }, () => {
      try {
        const cert = socket.getPeerCertificate(true);
        if (!cert || !cert.raw) {
          socket.end();
          return reject(new Error('certificate.raw unavailable'));
        }
        const der = cert.raw; // Buffer
        const pem = '-----BEGIN CERTIFICATE-----\n' + der.toString('base64').match(/.{1,64}/g).join('\n') + '\n-----END CERTIFICATE-----\n';
        const pubkey = crypto.createPublicKey(pem);
        const spkiDer = pubkey.export({ type: 'spki', format: 'der' });
        const hash = crypto.createHash('sha256').update(spkiDer).digest('base64');
        socket.end();
        resolve({ host, pin: hash });
      } catch (err) {
        socket.end();
        reject(err);
      }
    });

    socket.setTimeout(timeout, () => {
      socket.destroy();
      reject(new Error('timeout'));
    });

    socket.on('error', (err) => reject(err));
  });
}

(async () => {
  for (const h of hosts) {
    try {
      process.stdout.write(`${h}: `);
      const r = await getSPKIPin(h);
      console.log(r.pin);
    } catch (e) {
      console.log('ERROR -', e.message);
    }
  }
})();
