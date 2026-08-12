import assert from 'node:assert/strict';
import test from 'node:test';
import { verifyUploadSignature } from '../../lib/security/file-signature';

test('accepts correctly declared PDF and JPEG content', () => {
  assert.deepEqual(verifyUploadSignature(Buffer.from('%PDF-1.7'), 'application/pdf'), {
    extension: 'pdf', mimeType: 'application/pdf',
  });
  assert.deepEqual(verifyUploadSignature(Buffer.from([0xff, 0xd8, 0xff, 0xe0]), 'image/jpeg'), {
    extension: 'jpg', mimeType: 'image/jpeg',
  });
});

test('rejects spoofed, mismatched, and unsupported upload content', () => {
  assert.equal(verifyUploadSignature(Buffer.from('<script>alert(1)</script>'), 'application/pdf'), null);
  assert.equal(verifyUploadSignature(Buffer.from('%PDF-1.7'), 'image/png'), null);
  assert.equal(verifyUploadSignature(Buffer.from([0x00, 0x01, 0x02]), 'image/jpeg'), null);
});
