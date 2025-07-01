import 'package:flutter/material.dart';

class MessageTab extends StatelessWidget {
  const MessageTab({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        const SliverAppBar(
          floating: true,
          pinned: true,
          backgroundColor: Colors.white,
          title: Text(
            'Messages',
            style: TextStyle(
              color: Color(0xFF6C63FF),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                _buildSearchBar(),
                const SizedBox(height: 16),
                _buildChatCard(
                  name: 'Sarah Chen',
                  company: 'Google',
                  position: 'Senior Flutter Developer',
                  lastMessage: 'Thank you for your interest! When would you be available for an interview?',
                  time: '2m ago',
                  unread: true,
                  imageUrl: 'https://i.pravatar.cc/150?img=1',
                ),
                _buildChatCard(
                  name: 'Michael Johnson',
                  company: 'Microsoft',
                  position: 'Software Engineer',
                  lastMessage: 'Your application has been received. We will review it shortly.',
                  time: '1h ago',
                  unread: false,
                  imageUrl: 'https://i.pravatar.cc/150?img=2',
                ),
                _buildChatCard(
                  name: 'Emily Wong',
                  company: 'Meta',
                  position: 'Mobile Developer',
                  lastMessage: 'Could you share your portfolio with us?',
                  time: '3h ago',
                  unread: true,
                  imageUrl: 'https://i.pravatar.cc/150?img=3',
                ),
                _buildChatCard(
                  name: 'David Kim',
                  company: 'Apple',
                  position: 'iOS Developer',
                  lastMessage: 'Looking forward to discussing the role with you.',
                  time: '1d ago',
                  unread: false,
                  imageUrl: 'https://i.pravatar.cc/150?img=4',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search messages',
                border: InputBorder.none,
              ),
              onChanged: (value) {
                // Handle search
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatCard({
    required String name,
    required String company,
    required String position,
    required String lastMessage,
    required String time,
    required bool unread,
    required String imageUrl,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 25,
            backgroundImage: NetworkImage(imageUrl),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      time,
                      style: TextStyle(
                        color: unread ? const Color(0xFF6C63FF) : Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '$company • $position',
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        lastMessage,
                        style: TextStyle(
                          color: unread ? Colors.black : Colors.grey,
                          fontWeight: unread ? FontWeight.w500 : FontWeight.normal,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (unread)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF6C63FF),
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 