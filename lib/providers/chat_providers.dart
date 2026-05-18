import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tarnobrzeg112/core/enums.dart';
import 'package:tarnobrzeg112/models/chat_message.dart';
import 'package:tarnobrzeg112/models/pinned_message.dart';
import 'package:tarnobrzeg112/models/private_chat.dart';
import 'package:tarnobrzeg112/models/private_message.dart';
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

final pinnedMessagesProvider =
    StreamProvider.family<List<PinnedMessage>, ChatQuery>((ref, query) {
      return ref
          .watch(chatRepositoryProvider)
          .watchPinnedMessages(scope: query.scope, chatId: query.chatId);
    });

final privateChatsProvider = StreamProvider.family<List<PrivateChat>, String>((
  ref,
  uid,
) {
  return ref.watch(privateChatRepositoryProvider).watchChats(uid);
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
