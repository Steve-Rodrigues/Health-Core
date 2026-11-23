import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key});
  
  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
} 

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;

  User? get _user => _supabase.auth.currentUser;

  String _joinDate(User? user) {
    final raw = user?.createdAt;
    if (raw == null || raw.isEmpty) return 'Unknown';
    final date = DateTime.tryParse(raw);
    if (date == null) return 'Unknown';
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

//************************************************************************************/
  @override
  Widget build(BuildContext context) {
    final user = _user;

    return Scaffold(
      appBar: AppBar(title: const Text('Account Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Email', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(user?.email ?? 'Not available'),
                  const SizedBox(height: 16),
                  const Text('Joined', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(_joinDate(user)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          ListTile(
            tileColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            leading: const Icon(Icons.email_outlined),
            title: const Text('Change Email'),
            trailing: const Icon(Icons.chevron_right),
          ),
          const SizedBox(height: 8),
          ListTile(
            tileColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            leading: const Icon(Icons.lock_outline),
            title: const Text('Change Password'),
            trailing: const Icon(Icons.chevron_right),
          ),
          const SizedBox(height: 8),
          ListTile(
            tileColor: Theme.of(context).colorScheme.errorContainer,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            leading: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
            title: Text('Delete Account', style: TextStyle(color: Theme.of(context).colorScheme.error)),
            trailing: Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.error),
          ),
        ],
      ),
    );
  }
}
