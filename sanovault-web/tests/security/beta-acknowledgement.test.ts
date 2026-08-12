import assert from 'node:assert/strict';
import test from 'node:test';
import {
  BETA_ACKNOWLEDGEMENT_TEXT,
  BETA_ACKNOWLEDGEMENT_VERSION,
} from '../../lib/legal/beta-acknowledgement';

test('beta acknowledgement identifies its version and regulatory status', () => {
  assert.match(BETA_ACKNOWLEDGEMENT_VERSION, /^\d{4}-\d{2}-\d{2}$/);
  assert.match(BETA_ACKNOWLEDGEMENT_TEXT, /beta, experimental service/i);
  assert.match(BETA_ACKNOWLEDGEMENT_TEXT, /HIPAA, the GDPR, or India’s Digital Personal Data Protection Act \(DPDP\)/);
  assert.match(BETA_ACKNOWLEDGEMENT_TEXT, /cannot legally be waived/i);
});
