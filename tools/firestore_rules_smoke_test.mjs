import { createRequire } from 'node:module';

const require = createRequire(
  new URL('../.firebase-smoke/package.json', import.meta.url),
);
const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require('@firebase/rules-unit-testing');
const {
  doc,
  getDoc,
  setDoc,
  updateDoc,
  serverTimestamp,
} = require('firebase/firestore');

const projectId = 'tarnobrzeg-112';

const testEnv = await initializeTestEnvironment({ projectId });

try {
  await testEnv.clearFirestore();

  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, 'users/adminUid'), {
      uid: 'adminUid',
      login: 'badura_admin',
      authEmail: 'badura_admin@tarnobrzeg112.local',
      role: 'admin',
      accountStatus: 'active',
      unitType: 'osp',
      unitName: '',
      unitId: '',
      blockedWrite: false,
      muted: false,
    });
    await setDoc(doc(db, 'users/ospUid'), {
      uid: 'ospUid',
      login: 'osp_user',
      role: 'user',
      accountStatus: 'active',
      unitType: 'osp',
      unitName: 'OSP Gorzyce',
      unitId: 'osp-gorzyce',
      blockedWrite: false,
      muted: false,
    });
    await setDoc(doc(db, 'users/pspUid'), {
      uid: 'pspUid',
      login: 'psp_user',
      role: 'user',
      accountStatus: 'active',
      unitType: 'psp',
      unitName: 'PSP Tarnobrzeg',
      unitId: 'psp-tarnobrzeg',
      blockedWrite: false,
      muted: false,
    });
    await setDoc(doc(db, 'users/mediaUid'), {
      uid: 'mediaUid',
      login: 'media_user',
      role: 'user',
      accountStatus: 'active',
      unitType: 'media',
      unitName: 'Media',
      unitId: 'media',
      blockedWrite: false,
      muted: false,
    });
    await setDoc(doc(db, 'users/mutedUid'), {
      uid: 'mutedUid',
      login: 'muted_user',
      role: 'user',
      accountStatus: 'active',
      unitType: 'osp',
      unitName: 'OSP Gorzyce',
      unitId: 'osp-gorzyce',
      blockedWrite: true,
      muted: true,
    });
    await setDoc(doc(db, 'chats/main'), {
      id: 'main',
      type: 'main',
      chatKind: 'main',
      name: 'Czat główny',
      participants: [],
      createdBy: 'system',
      updatedAt: serverTimestamp(),
    });
    await setDoc(doc(db, 'chats/unit_osp-gorzyce'), {
      id: 'unit_osp-gorzyce',
      type: 'unit',
      chatKind: 'unit',
      name: 'OSP Gorzyce',
      unitName: 'OSP Gorzyce',
      unitId: 'osp-gorzyce',
      participants: [],
      createdBy: 'system',
      updatedAt: serverTimestamp(),
    });
    await setDoc(doc(db, 'chats/group_test'), {
      id: 'group_test',
      type: 'group',
      chatKind: 'group',
      name: 'Okolice',
      createdBy: 'ospUid',
      participants: ['ospUid', 'mediaUid'],
      inviteCode: 'INVITE1',
      updatedAt: serverTimestamp(),
    });
    await setDoc(doc(db, 'invites/INVITE1'), {
      inviteCode: 'INVITE1',
      chatId: 'group_test',
      chatName: 'Okolice',
      createdBy: 'ospUid',
      createdAt: serverTimestamp(),
      maxUses: 10,
      usedCount: 0,
      usedBy: [],
      active: true,
    });
  });

  const message = (uid, login, chatId, chatType) => ({
    id: `${uid}_${chatId}`,
    chatId,
    scope: chatType === 'main' ? 'global' : chatType,
    chatType,
    senderId: uid,
    senderLogin: login,
    senderDisplayName: login,
    senderUnitName: '',
    text: 'Test wiadomości admina',
    mediaType: 'text',
    attachments: [],
    createdAt: serverTimestamp(),
    isDeleted: false,
    deleted: false,
    visibleTo: [],
    participants: [],
    reactions: {},
    reportCount: 0,
  });

  const adminDb = testEnv
    .authenticatedContext('adminUid', {
      email: 'badura_admin@tarnobrzeg112.local',
    })
    .firestore();
  const ospDb = testEnv.authenticatedContext('ospUid').firestore();
  const pspDb = testEnv.authenticatedContext('pspUid').firestore();
  const mediaDb = testEnv.authenticatedContext('mediaUid').firestore();
  const mutedDb = testEnv.authenticatedContext('mutedUid').firestore();

  await assertSucceeds(
    setDoc(
      doc(adminDb, 'chats/main/messages/admin_msg'),
      message('adminUid', 'badura_admin', 'main', 'main'),
    ),
  );
  await assertSucceeds(getDoc(doc(ospDb, 'chats/main')));
  await assertSucceeds(
    setDoc(
      doc(ospDb, 'chats/unit_osp-gorzyce/messages/osp_msg'),
      message('ospUid', 'osp_user', 'unit_osp-gorzyce', 'unit'),
    ),
  );
  await assertFails(getDoc(doc(pspDb, 'chats/unit_osp-gorzyce')));
  await assertFails(getDoc(doc(mediaDb, 'chats/unit_osp-gorzyce')));
  await assertSucceeds(getDoc(doc(mediaDb, 'chats/main')));
  await assertSucceeds(getDoc(doc(mediaDb, 'chats/group_test')));
  await assertFails(
    setDoc(
      doc(mutedDb, 'chats/main/messages/muted_msg'),
      message('mutedUid', 'muted_user', 'main', 'main'),
    ),
  );
  await assertFails(
    updateDoc(doc(ospDb, 'users/ospUid'), {
      role: 'admin',
      accountStatus: 'active',
    }),
  );
  await assertSucceeds(
    updateDoc(doc(adminDb, 'chats/main/messages/admin_msg'), {
      isDeleted: true,
      deleted: true,
      deletedAt: serverTimestamp(),
      deletedBy: 'adminUid',
      originalTextForAdmin: 'Test wiadomości admina',
      originalAttachmentsForAdmin: [],
      text: 'Wiadomość cofnięta',
      attachments: [],
    }),
  );

  console.log('FIRESTORE_RULES_SMOKE_OK');
} finally {
  await testEnv.cleanup();
}
