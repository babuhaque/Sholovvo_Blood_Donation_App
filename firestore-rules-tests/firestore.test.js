const { describe, it, afterEach, before, after } = require('node:test');
const assert = require('node:assert');
const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require('@firebase/rules-unit-testing');
const fs = require('node:fs');
const path = require('node:path');
const {
  serverTimestamp,
  doc,
  getDoc,
  setDoc,
  updateDoc,
  deleteDoc,
  runTransaction,
} = require('firebase/firestore');

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
  await testEnv.clearFirestore();
});

// Without an explicit teardown the Firestore gRPC channels stay open after the
// last test and `node --test` never exits, which hangs `emulators:exec`.
after(async () => {
  await testEnv.cleanup();
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
    const collection = ownerDb.collection('donation_history');

    // An unconstrained collection list can never be authorised: for a list the
    // rule engine binds `resource` to a placeholder document, so `donorUid` is
    // undefined and the read is denied. The query itself must be narrowed.
    await assertFails(collection.get());

    // Narrowed to the caller's own uid the same query is authorised and only
    // ever yields the caller's document.
    const ownSnapshot = await collection.where('donorUid', '==', ownerId).get();
    assert.strictEqual(ownSnapshot.size, 1);
    assert.strictEqual(ownSnapshot.docs[0].data().donorUid, ownerId);

    // Narrowed to another user's uid it is denied rather than returning data.
    await assertFails(collection.where('donorUid', '==', otherId).get());
  });
});

// ---------------------------------------------------------------------------
// Phase 1 - Response claims, donor response notifications and request claiming.
// These suites cover the collections touched by the Phase 1 fixes:
//   blood_requests, request_responses, response_claims, notifications.
// ---------------------------------------------------------------------------

const IDS = {
  recipient: 'recipient_owner_1',
  donor: 'donor_one_1',
  otherDonor: 'donor_two_2',
  request: 'req_alpha_1',
  response: 'resp_alpha_1',
};

// Mirrors RequestResponseService.getClaimId so the tests exercise the real id shape.
const claimDocId = (requestId, donorId) =>
  `req_${requestId.length}_${requestId}_donor_${donorId.length}_${donorId}`;

const donorResponsePayload = (overrides = {}) => ({
  recipientUid: IDS.recipient,
  requestId: IDS.request,
  responseId: IDS.response,
  type: 'donor_response',
  title: 'Donor Response (A+)',
  body: 'Donor One has accepted your request for Patient.',
  createdAt: serverTimestamp(),
  ...overrides,
});

const newRequestPayload = (overrides = {}) => ({
  recipientUid: IDS.donor,
  requestId: IDS.request,
  responseId: null,
  type: 'new_request',
  title: 'New A+ Blood Request',
  body: 'Patient needs 1 bag(s) of blood.',
  createdAt: serverTimestamp(),
  ...overrides,
});

const seedBase = async ({ requestStatus = 'open', withResponse = true } = {}) => {
  await testEnv.withSecurityRulesDisabled(async (adminCtx) => {
    const db = adminCtx.firestore();
    await db.collection('users').doc(IDS.recipient).set({
      uid: IDS.recipient,
      fullName: 'Recipient Owner',
      role: 'recipient',
      bloodGroup: 'O+',
      isAvailable: false,
    });
    await db.collection('users').doc(IDS.donor).set({
      uid: IDS.donor,
      fullName: 'Donor One',
      role: 'donor',
      bloodGroup: 'A+',
      isAvailable: true,
    });
    await db.collection('users').doc(IDS.otherDonor).set({
      uid: IDS.otherDonor,
      fullName: 'Donor Two',
      role: 'donor',
      bloodGroup: 'B+',
      isAvailable: true,
    });
    await db.collection('blood_requests').doc(IDS.request).set({
      userId: IDS.recipient,
      patientName: 'Patient',
      phoneNumber: '+8801700000000',
      bloodGroup: 'A+',
      bloodBags: 1,
      hospitalName: 'Dhaka Medical College',
      hospitalAddress: 'Dhaka',
      requiredDateTime: '2026-11-10 10:00 AM',
      requestType: 'Normal',
      notes: '',
      status: requestStatus,
      assignedDonorId: null,
      latitude: 23.8,
      longitude: 90.4,
      createdAt: new Date(),
    });

    if (withResponse) {
      await db.collection('request_responses').doc(IDS.response).set({
        requestId: IDS.request,
        donorId: IDS.donor,
        donorName: 'Donor One',
        donorPhone: '+8801700000001',
        bloodGroup: 'A+',
        status: 'accepted',
        createdAt: new Date(),
      });
    }
  });
};

describe('Phase 1.1 response_claims security rules', () => {
  it('1. Booking transaction can read a claim that does not exist yet', async () => {
    await seedBase({ withResponse: false });
    const db = testEnv.authenticatedContext(IDS.donor).firestore();
    const claimRef = doc(db, 'response_claims', claimDocId(IDS.request, IDS.donor));

    assert.strictEqual((await getDoc(claimRef)).exists(), false);
  });

  it('2. Donor can atomically create the response and claim, and claim the request', async () => {
    await seedBase({ withResponse: false });
    const db = testEnv.authenticatedContext(IDS.donor).firestore();
    const requestRef = doc(db, 'blood_requests', IDS.request);
    const responseRef = doc(db, 'request_responses', IDS.response);
    const claimRef = doc(db, 'response_claims', claimDocId(IDS.request, IDS.donor));

    await assertSucceeds(
      runTransaction(db, async (tx) => {
        const requestSnap = await tx.get(requestRef);
        assert.strictEqual(requestSnap.data().status, 'open');
        const claimSnap = await tx.get(claimRef);
        assert.strictEqual(claimSnap.exists(), false);

        tx.set(responseRef, {
          requestId: IDS.request,
          donorId: IDS.donor,
          donorName: 'Donor One',
          donorPhone: '+8801700000001',
          bloodGroup: 'A+',
          status: 'accepted',
          createdAt: serverTimestamp(),
        });
        tx.set(claimRef, {
          requestId: IDS.request,
          donorId: IDS.donor,
          responseId: IDS.response,
        });
        tx.update(requestRef, {
          status: 'accepted',
          assignedDonorId: IDS.donor,
          acceptedAt: serverTimestamp(),
        });
      }),
    );

    const stored = await getDoc(
      testEnv.authenticatedContext(IDS.donor).firestore().doc(`response_claims/${claimDocId(IDS.request, IDS.donor)}`),
    );
    assert.strictEqual(stored.data().responseId, IDS.response);
  });

  it('3. A donor cannot create a claim for someone else', async () => {
    await seedBase();
    const db = testEnv.authenticatedContext(IDS.otherDonor).firestore();

    await assertFails(
      setDoc(doc(db, 'response_claims', claimDocId(IDS.request, IDS.otherDonor)), {
        requestId: IDS.request,
        donorId: IDS.donor,
        responseId: IDS.response,
      }),
    );
  });

  it('4. A claim cannot reference a response belonging to a different request', async () => {
    await seedBase();
    const db = testEnv.authenticatedContext(IDS.donor).firestore();

    await assertFails(
      setDoc(doc(db, 'response_claims', claimDocId(IDS.request, IDS.donor)), {
        requestId: 'req_some_other',
        donorId: IDS.donor,
        responseId: IDS.response,
      }),
    );
  });

  it('5. A claim cannot point at a response that does not exist', async () => {
    await seedBase();
    const db = testEnv.authenticatedContext(IDS.donor).firestore();

    await assertFails(
      setDoc(doc(db, 'response_claims', claimDocId(IDS.request, IDS.donor)), {
        requestId: IDS.request,
        donorId: IDS.donor,
        responseId: 'resp_missing',
      }),
    );
  });

  it('6. A claim cannot carry extra fields', async () => {
    await seedBase();
    const db = testEnv.authenticatedContext(IDS.donor).firestore();

    await assertFails(
      setDoc(doc(db, 'response_claims', claimDocId(IDS.request, IDS.donor)), {
        requestId: IDS.request,
        donorId: IDS.donor,
        responseId: IDS.response,
        isWinner: true,
      }),
    );
  });

  it('7. An existing claim is readable only by the donor who owns it', async () => {
    await seedBase();
    await testEnv.withSecurityRulesDisabled(async (adminCtx) => {
      await adminCtx
        .firestore()
        .collection('response_claims')
        .doc(claimDocId(IDS.request, IDS.donor))
        .set({ requestId: IDS.request, donorId: IDS.donor, responseId: IDS.response });
    });

    const donorDb = testEnv.authenticatedContext(IDS.donor).firestore();
    await assertSucceeds(getDoc(doc(donorDb, 'response_claims', claimDocId(IDS.request, IDS.donor))));

    const otherDb = testEnv.authenticatedContext(IDS.otherDonor).firestore();
    await assertFails(getDoc(doc(otherDb, 'response_claims', claimDocId(IDS.request, IDS.donor))));
  });

  it('8. A winning claim cannot be edited or released', async () => {
    await seedBase();
    await testEnv.withSecurityRulesDisabled(async (adminCtx) => {
      await adminCtx
        .firestore()
        .collection('response_claims')
        .doc(claimDocId(IDS.request, IDS.donor))
        .set({ requestId: IDS.request, donorId: IDS.donor, responseId: IDS.response });
    });

    const db = testEnv.authenticatedContext(IDS.donor).firestore();
    const claimRef = doc(db, 'response_claims', claimDocId(IDS.request, IDS.donor));

    await assertFails(updateDoc(claimRef, { responseId: 'resp_other' }));
    await assertFails(deleteDoc(claimRef));
  });

  it('9. Unauthenticated users cannot read or write claims', async () => {
    await seedBase();
    const unauthDb = testEnv.unauthenticatedContext().firestore();

    await assertFails(getDoc(doc(unauthDb, 'response_claims', claimDocId(IDS.request, IDS.donor))));
    await assertFails(
      setDoc(doc(unauthDb, 'response_claims', claimDocId(IDS.request, IDS.donor)), {
        requestId: IDS.request,
        donorId: IDS.donor,
        responseId: IDS.response,
      }),
    );
  });
});

describe('Phase 1.2 notifications security rules', () => {
  it('1. Donor can raise a donor_response notification resolved through responseId', async () => {
    await seedBase();
    const db = testEnv.authenticatedContext(IDS.donor).firestore();

    await assertSucceeds(
      setDoc(doc(db, 'notifications', `notif_resp_${IDS.response}`), donorResponsePayload()),
    );
  });

  it('2. donor_response is rejected when responseId points at a blood request instead', async () => {
    await seedBase();
    const db = testEnv.authenticatedContext(IDS.donor).firestore();

    await assertFails(
      setDoc(
        doc(db, 'notifications', 'notif_resp_bad'),
        donorResponsePayload({ responseId: IDS.request }),
      ),
    );
  });

  it('3. A donor cannot raise a donor_response notification for a response they do not own', async () => {
    await seedBase();
    const db = testEnv.authenticatedContext(IDS.otherDonor).firestore();

    await assertFails(
      setDoc(doc(db, 'notifications', `notif_resp_${IDS.response}`), donorResponsePayload()),
    );
  });

  it('4. A donor cannot address a donor_response notification to someone other than the request owner', async () => {
    await seedBase();
    const db = testEnv.authenticatedContext(IDS.donor).firestore();

    await assertFails(
      setDoc(
        doc(db, 'notifications', 'notif_resp_wrong_recipient'),
        donorResponsePayload({ recipientUid: IDS.otherDonor }),
      ),
    );
  });

  it('5. Request owner can raise a new_request notification for a matching donor', async () => {
    await seedBase();
    const db = testEnv.authenticatedContext(IDS.recipient).firestore();

    await assertSucceeds(
      setDoc(
        doc(db, 'notifications', `notif_req_new_request_${IDS.request}_${IDS.donor}`),
        newRequestPayload(),
      ),
    );
  });

  it('6. A new_request notification is rejected when the request does not exist', async () => {
    await seedBase();
    const db = testEnv.authenticatedContext(IDS.recipient).firestore();

    await assertFails(
      setDoc(
        doc(db, 'notifications', 'notif_req_missing'),
        newRequestPayload({ requestId: 'req_does_not_exist' }),
      ),
    );
  });

  it('7. A notification cannot carry unexpected fields', async () => {
    await seedBase();
    const db = testEnv.authenticatedContext(IDS.donor).firestore();

    await assertFails(
      setDoc(
        doc(db, 'notifications', `notif_resp_${IDS.response}`),
        donorResponsePayload({ isAdmin: true }),
      ),
    );
  });

  it('8. A notification must use a server timestamp', async () => {
    await seedBase();
    const db = testEnv.authenticatedContext(IDS.donor).firestore();

    await assertFails(
      setDoc(
        doc(db, 'notifications', `notif_resp_${IDS.response}`),
        donorResponsePayload({ createdAt: new Date(0) }),
      ),
    );
  });

  it('9. Sender can idempotently re-raise a notification without un-reading it', async () => {
    await seedBase();
    await testEnv.withSecurityRulesDisabled(async (adminCtx) => {
      await adminCtx
        .firestore()
        .collection('notifications')
        .doc(`notif_resp_${IDS.response}`)
        .set({ ...donorResponsePayload(), createdAt: new Date(), isRead: true });
    });

    const db = testEnv.authenticatedContext(IDS.donor).firestore();
    const notifRef = doc(db, 'notifications', `notif_resp_${IDS.response}`);

    await assertSucceeds(setDoc(notifRef, donorResponsePayload(), { merge: true }));

    const recipientDb = testEnv.authenticatedContext(IDS.recipient).firestore();
    const stored = await getDoc(doc(recipientDb, 'notifications', `notif_resp_${IDS.response}`));
    assert.strictEqual(stored.data().isRead, true);
  });

  it('10. Sender cannot flip the read state of an existing notification', async () => {
    await seedBase();
    await testEnv.withSecurityRulesDisabled(async (adminCtx) => {
      await adminCtx
        .firestore()
        .collection('notifications')
        .doc(`notif_resp_${IDS.response}`)
        .set({ ...donorResponsePayload(), createdAt: new Date(), isRead: true });
    });

    const db = testEnv.authenticatedContext(IDS.donor).firestore();

    await assertFails(
      setDoc(
        doc(db, 'notifications', `notif_resp_${IDS.response}`),
        { isRead: false },
        { merge: true },
      ),
    );
  });

  it('11. Sender cannot redirect an existing notification to another recipient', async () => {
    await seedBase();
    await testEnv.withSecurityRulesDisabled(async (adminCtx) => {
      await adminCtx
        .firestore()
        .collection('notifications')
        .doc(`notif_resp_${IDS.response}`)
        .set({ ...donorResponsePayload(), createdAt: new Date(), isRead: false });
    });

    const db = testEnv.authenticatedContext(IDS.donor).firestore();

    await assertFails(
      setDoc(
        doc(db, 'notifications', `notif_resp_${IDS.response}`),
        { recipientUid: IDS.otherDonor },
        { merge: true },
      ),
    );
  });

  it('12. Only the recipient can read their notification', async () => {
    await seedBase();
    await testEnv.withSecurityRulesDisabled(async (adminCtx) => {
      await adminCtx
        .firestore()
        .collection('notifications')
        .doc(`notif_resp_${IDS.response}`)
        .set({ ...donorResponsePayload(), createdAt: new Date(), isRead: false });
    });

    const recipientDb = testEnv.authenticatedContext(IDS.recipient).firestore();
    await assertSucceeds(getDoc(doc(recipientDb, 'notifications', `notif_resp_${IDS.response}`)));

    const otherDb = testEnv.authenticatedContext(IDS.otherDonor).firestore();
    await assertFails(getDoc(doc(otherDb, 'notifications', `notif_resp_${IDS.response}`)));
  });

  it('13. Recipient can mark their notification as read', async () => {
    await seedBase();
    await testEnv.withSecurityRulesDisabled(async (adminCtx) => {
      await adminCtx
        .firestore()
        .collection('notifications')
        .doc(`notif_resp_${IDS.response}`)
        .set({ ...donorResponsePayload(), createdAt: new Date(), isRead: false });
    });

    const db = testEnv.authenticatedContext(IDS.recipient).firestore();
    await assertSucceeds(
      updateDoc(doc(db, 'notifications', `notif_resp_${IDS.response}`), { isRead: true }),
    );
  });

  it('14. Unauthenticated users cannot read or write notifications', async () => {
    await seedBase();
    const unauthDb = testEnv.unauthenticatedContext().firestore();

    await assertFails(getDoc(doc(unauthDb, 'notifications', `notif_resp_${IDS.response}`)));
    await assertFails(
      setDoc(doc(unauthDb, 'notifications', `notif_resp_${IDS.response}`), donorResponsePayload()),
    );
  });
});

describe('Phase 1.3 blood_requests claiming rules', () => {
  const claimUpdate = () => ({
    status: 'accepted',
    assignedDonorId: IDS.donor,
    acceptedAt: serverTimestamp(),
  });

  it('1. A matching, available donor can claim an open request', async () => {
    await seedBase();
    const db = testEnv.authenticatedContext(IDS.donor).firestore();

    await assertSucceeds(
      updateDoc(doc(db, 'blood_requests', IDS.request), claimUpdate()),
    );
  });

  it('2. A donor with a different blood group cannot claim the request', async () => {
    await seedBase();
    const db = testEnv.authenticatedContext(IDS.otherDonor).firestore();

    await assertFails(
      updateDoc(doc(db, 'blood_requests', IDS.request), {
        status: 'accepted',
        assignedDonorId: IDS.otherDonor,
        acceptedAt: serverTimestamp(),
      }),
    );
  });

  it('3. A donor cannot write fields outside the claim contract', async () => {
    await seedBase();
    const db = testEnv.authenticatedContext(IDS.donor).firestore();

    await assertFails(
      updateDoc(doc(db, 'blood_requests', IDS.request), {
        ...claimUpdate(),
        patientName: 'Hijacked',
      }),
    );
  });

  it('4. A donor cannot claim a request that is no longer open', async () => {
    await seedBase({ requestStatus: 'accepted' });
    const db = testEnv.authenticatedContext(IDS.donor).firestore();

    await assertFails(
      updateDoc(doc(db, 'blood_requests', IDS.request), claimUpdate()),
    );
  });

  it('5. The request owner can cancel their own request', async () => {
    await seedBase();
    const db = testEnv.authenticatedContext(IDS.recipient).firestore();

    await assertSucceeds(
      updateDoc(doc(db, 'blood_requests', IDS.request), { status: 'cancelled' }),
    );
  });

  it('6. An unrelated donor cannot modify the request', async () => {
    await seedBase();
    const db = testEnv.authenticatedContext(IDS.otherDonor).firestore();

    await assertFails(
      updateDoc(doc(db, 'blood_requests', IDS.request), { status: 'cancelled' }),
    );
  });
});

