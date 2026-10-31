const { describe, it, afterEach, before } = require('node:test');
const assert = require('node:assert');
const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require('@firebase/rules-unit-testing');
const fs = require('node:fs');
const path = require('node:path');
const { serverTimestamp } = require('firebase/firestore');

let testEnv;

before(async () => {
  const rulesPath = path.resolve(__dirname, '../firestore.rules');
  const rules = fs.readFileSync(rulesPath, 'utf8');

  testEnv = await initializeTestEnvironment({
    projectId: 'demo-solovvo-tests',
    firestore: {
      host: '127.0.0.1',
      port: 8080,
      rules: rules,
    },
  });
});

afterEach(async () => {
  await testEnv.clearFirestoreData();
});

describe('Phase 2.1 Donation History Security Rules Comprehensive Tests', () => {
  const ownerId = 'user_owner_123';
  const otherId = 'user_other_456';

  const validDonationData = (overrides = {}) => ({
    donorUid: ownerId,
    bloodGroup: 'A+',
    hospitalName: 'Dhaka Medical College',
    status: 'pending',
    createdAt: serverTimestamp(),
    ...overrides,
  });

  it('1. Unauthenticated user cannot read or write donation history', async () => {
    const unauthDb = testEnv.unauthenticatedContext().firestore();
    const recordRef = unauthDb.collection('donation_history').doc('rec_unauth');

    await assertFails(recordRef.get());
    await assertFails(recordRef.set(validDonationData()));
  });

  it('2. Owner can read their own donation history', async () => {
    await testEnv.withSecurityRulesDisabled(async (adminCtx) => {
      await adminCtx.firestore().collection('donation_history').doc('rec_1').set({
        donorUid: ownerId,
        bloodGroup: 'A+',
        hospitalName: 'Dhaka Medical College',
        status: 'pending',
        createdAt: new Date(),
      });
    });

    const ownerDb = testEnv.authenticatedContext(ownerId).firestore();
    await assertSucceeds(ownerDb.collection('donation_history').doc('rec_1').get());
  });

  it('3. User cannot read another user\'s donation history', async () => {
    await testEnv.withSecurityRulesDisabled(async (adminCtx) => {
      await adminCtx.firestore().collection('donation_history').doc('rec_1').set({
        donorUid: ownerId,
        bloodGroup: 'A+',
        hospitalName: 'Dhaka Medical College',
        status: 'pending',
        createdAt: new Date(),
      });
    });

    const otherDb = testEnv.authenticatedContext(otherId).firestore();
    await assertFails(otherDb.collection('donation_history').doc('rec_1').get());
  });

  it('4. Owner can create a valid pending donation record with server timestamp', async () => {
    const ownerDb = testEnv.authenticatedContext(ownerId).firestore();
    const recordRef = ownerDb.collection('donation_history').doc('rec_valid');

    await assertSucceeds(recordRef.set(validDonationData()));
  });

  it('5. User cannot create a record for another UID', async () => {
    const ownerDb = testEnv.authenticatedContext(ownerId).firestore();
    const recordRef = ownerDb.collection('donation_history').doc('rec_spoofed');

    await assertFails(recordRef.set(validDonationData({ donorUid: otherId })));
  });

  it('6. Client cannot create a confirmed record', async () => {
    const ownerDb = testEnv.authenticatedContext(ownerId).firestore();
    const recordRef = ownerDb.collection('donation_history').doc('rec_confirmed');

    await assertFails(recordRef.set(validDonationData({ status: 'confirmed' })));
  });

  it('7. Creation fails with invalid blood group', async () => {
    const ownerDb = testEnv.authenticatedContext(ownerId).firestore();
    const recordRef = ownerDb.collection('donation_history').doc('rec_bad_blood');

    await assertFails(recordRef.set(validDonationData({ bloodGroup: 'Z+' })));
  });

  it('8. Creation fails with empty hospital name', async () => {
    const ownerDb = testEnv.authenticatedContext(ownerId).firestore();
    const recordRef = ownerDb.collection('donation_history').doc('rec_no_hospital');

    await assertFails(recordRef.set(validDonationData({ hospitalName: '' })));
  });

  it('9. Creation fails with missing required field (hospitalName)', async () => {
    const ownerDb = testEnv.authenticatedContext(ownerId).firestore();
    const recordRef = ownerDb.collection('donation_history').doc('rec_missing');
    const data = validDonationData();
    delete data.hospitalName;

    await assertFails(recordRef.set(data));
  });

  it('10. Creation fails with invalid createdAt timestamp (client local Date)', async () => {
    const ownerDb = testEnv.authenticatedContext(ownerId).firestore();
    const recordRef = ownerDb.collection('donation_history').doc('rec_bad_time');

    await assertFails(recordRef.set(validDonationData({ createdAt: new Date(0) })));
  });

  it('11. Client updates are completely denied', async () => {
    await testEnv.withSecurityRulesDisabled(async (adminCtx) => {
      await adminCtx.firestore().collection('donation_history').doc('rec_update').set({
        donorUid: ownerId,
        bloodGroup: 'A+',
        hospitalName: 'Dhaka Medical College',
        status: 'pending',
        createdAt: new Date(),
      });
    });

    const ownerDb = testEnv.authenticatedContext(ownerId).firestore();
    await assertFails(ownerDb.collection('donation_history').doc('rec_update').update({
      hospitalName: 'Updated Hospital',
    }));
  });

  it('12. Owner can delete own pending record', async () => {
    await testEnv.withSecurityRulesDisabled(async (adminCtx) => {
      await adminCtx.firestore().collection('donation_history').doc('rec_del').set({
        donorUid: ownerId,
        bloodGroup: 'A+',
        hospitalName: 'Dhaka Medical College',
        status: 'pending',
        createdAt: new Date(),
      });
    });

    const ownerDb = testEnv.authenticatedContext(ownerId).firestore();
    await assertSucceeds(ownerDb.collection('donation_history').doc('rec_del').delete());
  });

  it('13. Another user attempts to delete owner\'s pending record', async () => {
    await testEnv.withSecurityRulesDisabled(async (adminCtx) => {
      await adminCtx.firestore().collection('donation_history').doc('rec_del_other').set({
        donorUid: ownerId,
        bloodGroup: 'A+',
        hospitalName: 'Dhaka Medical College',
        status: 'pending',
        createdAt: new Date(),
      });
    });

    const otherDb = testEnv.authenticatedContext(otherId).firestore();
    await assertFails(otherDb.collection('donation_history').doc('rec_del_other').delete());
  });

  it('14. Cross-user collection query is restricted by rules (only returns owner documents)', async () => {
    await testEnv.withSecurityRulesDisabled(async (adminCtx) => {
      const col = adminCtx.firestore().collection('donation_history');
      await col.doc('rec_owner').set({
        donorUid: ownerId,
        bloodGroup: 'A+',
        hospitalName: 'Dhaka Medical College',
        status: 'pending',
        createdAt: new Date(),
      });
      await col.doc('rec_other').set({
        donorUid: otherId,
        bloodGroup: 'B+',
        hospitalName: 'Square Hospital',
        status: 'pending',
        createdAt: new Date(),
      });
    });

    const ownerDb = testEnv.authenticatedContext(ownerId).firestore();
    const snapshot = await ownerDb.collection('donation_history').get();
    assert.strictEqual(snapshot.size, 1);
    assert.strictEqual(snapshot.docs[0].data().donorUid, ownerId);
  });
});
