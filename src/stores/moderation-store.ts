import { defineStore } from 'pinia';
import { supabase } from '@/boot/supabase';
import { useAuthStore } from '@/stores/auth-store';
import type {
  AdminFeedback,
  AdminGroup,
  AdminOverview,
  AdminReport,
  AdminUser,
  ReportKind,
  ReportReason,
} from '@/types/report';

const targetColumn: Record<ReportKind, string> = {
  post: 'reported_post_id',
  profile: 'reported_profile_id',
  message: 'reported_message_id',
  group: 'reported_group_id',
};

export const useModerationStore = defineStore('moderation', () => {
  // Meldet ein Gesuch, ein Profil, eine Nachricht oder eine Gruppe.
  // Die Datenbank prueft, dass man nur melden kann, was man selbst sieht.
  async function report(kind: ReportKind, targetId: string, reason: ReportReason): Promise<void> {
    const authStore = useAuthStore();
    if (!authStore.user) throw new Error('Nicht eingeloggt');
    const { error } = await supabase.from('reports').insert({
      reporter_id: authStore.user.id,
      [targetColumn[kind]]: targetId,
      reason,
    });
    if (error) throw error;
  }

  const reportPost = (id: string, reason: ReportReason) => report('post', id, reason);
  const reportProfile = (id: string, reason: ReportReason) => report('profile', id, reason);

  async function sendFeedback(message: string, page: string): Promise<void> {
    const { error } = await supabase.from('feedback').insert({ message: message.trim(), page: page.slice(0, 200) });
    if (error) throw error;
  }

  // --- nur fuer Admins (die Datenbank prueft das in jeder Funktion selbst) ---
  async function listReports(): Promise<AdminReport[]> {
    const { data, error } = await supabase.rpc('admin_list_reports');
    if (error) throw error;
    return (data ?? []) as AdminReport[];
  }

  async function listFeedback(): Promise<AdminFeedback[]> {
    const { data, error } = await supabase.rpc('admin_list_feedback');
    if (error) throw error;
    return (data ?? []) as AdminFeedback[];
  }

  async function overview(): Promise<AdminOverview> {
    const { data, error } = await supabase.rpc('admin_overview');
    if (error) throw error;
    return data as AdminOverview;
  }

  async function listUsers(): Promise<AdminUser[]> {
    const { data, error } = await supabase.rpc('admin_list_users');
    if (error) throw error;
    return (data ?? []) as AdminUser[];
  }

  async function listGroups(): Promise<AdminGroup[]> {
    const { data, error } = await supabase.rpc('admin_list_groups');
    if (error) throw error;
    return (data ?? []) as AdminGroup[];
  }

  async function call(fn: string, args: Record<string, string>): Promise<void> {
    const { error } = await supabase.rpc(fn, args);
    if (error) throw error;
  }

  const resolveReport = (id: string) => call('admin_resolve_report', { p_report_id: id });
  const deletePost = (id: string) => call('admin_delete_post', { p_post_id: id });
  const deleteMessage = (id: string) => call('admin_delete_message', { p_message_id: id });
  const deleteGroup = (id: string) => call('admin_delete_group', { p_group_id: id });
  const banUser = (id: string) => call('ban_user', { p_target_id: id });
  const unbanUser = (id: string) => call('admin_unban_user', { p_target_id: id });

  return {
    report,
    reportPost,
    reportProfile,
    sendFeedback,
    listReports,
    listFeedback,
    overview,
    listUsers,
    listGroups,
    resolveReport,
    deletePost,
    deleteMessage,
    deleteGroup,
    banUser,
    unbanUser,
  };
});
