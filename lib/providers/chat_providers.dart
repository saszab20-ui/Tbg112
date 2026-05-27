import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tarnobrzeg112/core/enums.dart';
import 'package:tarnobrzeg112/models/chat_message.dart';
import 'package:tarnobrzeg112/models/pinned_message.dart';
import 'package:tarnobrzeg112/models/private_chat.dart';
import 'package:tarnobrzeg112/models/private_message.dart';
import 'package:tarnobrzeg112/models/typing_user.dart';
import 'package:tarnobrzeg112/providers/auth_providers.dart';
import 'package:tarnobrzeg112/providers/firebase_providers.dart';

class ChatQuery {
  const ChatQuery({required this.scope, required this.chatId, this.limit = 80});

  final ChatScope scope;
  final String chatId;
  final int limit;

  @override
  bool operator ==(Object other) {
    return other is ChatQuery &&
        other.scope == scope &&
        other.chatId == chatId &&
        other.limit == limit;
  }

  @override
  int get hashCode => Object.hash(scope, chatId, limit);
}

class ChatReadQuery {
  const ChatReadQuery({
    required this.scope,
    required this.chatId,
    required this.uid,
  });

  final ChatScope scope;
  final String chatId;
  final String uid;

  @override
  bool operator ==(Object other) {
    return other is ChatReadQuery &&
        other.scope == scope &&
        other.chatId == chatId &&
        other.uid == uid;
  }

  @override
  int get hashCode => Object.hash(scope, chatId, uid);
}

final chatMessagesProvider =
    StreamProvider.family<List<ChatMessage>, ChatQuery>((ref, query) {
      return ref
          .watch(chatRepositoryProvider)
          .watchMessages(
            scope: query.scope,
            chatId: query.chatId,
            limit: query.limit,
          );
    });

final chatLastReadProvider = StreamProvider.family<DateTime?, ChatReadQuery>((
  ref,
  query,
) {
  return ref
      .watch(chatRepositoryProvider)
      .watchLastReadAt(
        scope: query.scope,
        chatId: query.chatId,
        uid: query.uid,
      );
});

final chatUnreadCountProvider = Provider.family<int, ChatReadQuery>((
  ref,
  query,
) {
  final messages =
      ref
          .watch(
            chatMessagesProvider(
              ChatQuery(scope: query.scope, chatId: query.chatId, limit: 50),
            ),
          )
          .asData
          ?.value ??
      const <ChatMessage>[];
  final lastRead = ref.watch(chatLastReadProvider(query)).asData?.value;
  final currentUser = ref.watch(currentAppUserProvider).asData?.value;
  final joinedAt = currentUser?.uid == query.uid ? currentUser?.joinedAt : null;
  return messages
      .where(
        (message) =>
            message.senderId != query.uid &&
            message.senderId != 'system' &&
            !message.isDeleted &&
            (message.visibleTo.isEmpty ||
                message.visibleTo.contains(query.uid)) &&
            (joinedAt == null || message.createdAt.isAfter(joinedAt)) &&
            (lastRead == null || message.createdAt.isAfter(lastRead)),
      )
      .length;
});

final pinnedMessagesProvider =
    StreamProvider.family<List<PinnedMessage>, ChatQuery>((ref, query) {
      return ref
          .watch(chatRepositoryProvider)
          .watchPinnedMessages(scope: query.scope, chatId: query.chatId);
    });

class TypingQuery {
  const TypingQuery({
    required this.scope,
    required this.chatId,
    required this.currentUserId,
  });

  final ChatScope scope;
  final String chatId;
  final String currentUserId;

  @override
  bool operator ==(Object other) {
    return other is TypingQuery &&
        other.scope == scope &&
        other.chatId == chatId &&
        other.currentUserId == currentUserId;
  }

  @override
  int get hashCode => Object.hash(scope, chatId, currentUserId);
}

final chatTypingProvider = StreamProvider.family<List<TypingUser>, TypingQuery>(
  (ref, query) {
    return ref
        .watch(chatRepositoryProvider)
        .watchTyping(
          scope: query.scope,
          chatId: query.chatId,
          currentUserId: query.currentUserId,
        );
  },
);

final privateChatsProvider = StreamProvider.family<List<PrivateChat>, String>((
  ref,
  uid,
) {
  return ref.watch(privateChatRepositoryProvider).watchChats(uid);
});

final privateUnreadTotalProvider = Provider<int>((ref) {
  final user = ref.watch(currentAppUserProvider).asData?.value;
  if (user == null) return 0;
  final chats = ref.watch(privateChatsProvider(user.uid)).asData?.value;
  if (chats == null) return 0;
  return chats.fold<int>(
    0,
    (sum, chat) => sum + (chat.unreadCount[user.uid] ?? 0),
  );
});

final chatUnreadTotalProvider = Provider<int>((ref) {
  final user = ref.watch(currentAppUserProvider).asData?.value;
  if (user == null) return 0;
  final main = ref.watch(
    chatUnreadCountProvider(
      ChatReadQuery(scope: ChatScope.global, chatId: 'main', uid: user.uid),
    ),
  );
  final unit = user.hasUnitChatAccess
      ? ref.watch(
          chatUnreadCountProvider(
            ChatReadQuery(
              scope: ChatScope.unit,
              chatId: user.unitId,
              uid: user.uid,
            ),
          ),
        )
      : 0;
  final groups = ref.watch(groupChatsProvider(user.uid)).asData?.value;
  final groupUnread =
      groups?.fold<int>(
        0,
        (sum, chat) => sum + (chat.unreadCount[user.uid] ?? 0),
      ) ??
      0;
  return main + unit + groupUnread;
});

final privateChatProvider = StreamProvider.family<PrivateChat?, String>((
  ref,
  chatId,
) {
  return ref.watch(privateChatRepositoryProvider).watchChat(chatId);
});

final groupChatsProvider = StreamProvider.family<List<PrivateChat>, String>((
  ref,
  uid,
) {
  final user = ref.watch(currentAppUserProvider).asData?.value;
  if (user == null || user.uid != uid) return const Stream.empty();
  return ref.watch(privateChatRepositoryProvider).watchGroups(user);
});

final privateMessagesProvider =
    StreamProvider.family<List<PrivateMessage>, String>((ref, chatId) {
      return ref.watch(privateChatRepositoryProvider).watchMessages(chatId);
    });

final deletedMessagesProvider = StreamProvider<List<ChatMessage>>((ref) {
  return ref.watch(chatRepositoryProvider).watchDeletedMessages();
});
