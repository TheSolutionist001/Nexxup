export type ReportReason = 'spam' | 'belaestigung' | 'unangemessen' | 'sonstiges';

export const reportReasonOptions: { label: string; value: ReportReason }[] = [
  { label: 'Spam', value: 'spam' },
  { label: 'Belästigung', value: 'belaestigung' },
  { label: 'Unangemessen', value: 'unangemessen' },
  { label: 'Sonstiges', value: 'sonstiges' },
];

// Rueckgabe von admin_list_reports()
export type ReportKind = 'post' | 'profile' | 'message' | 'group';

export interface AdminReport {
  report_id: string;
  kind: ReportKind;
  // Gemeldeter Text (Gesuch, Nachricht, Gruppenname/-beschreibung, Profiltext)
  content: string | null;
  reported_post_id: string | null;
  reported_message_id: string | null;
  reported_group_id: string | null;
  // Verantwortliche Person (Autor, Absender, Ersteller bzw. gemeldetes Profil)
  target_user_id: string | null;
  target_user_name: string | null;
  target_is_banned: boolean;
  reporter_id: string;
  reporter_name: string | null;
  reason: ReportReason | null;
  created_at: string;
}

// Rueckgabe von admin_list_feedback()
export interface AdminFeedback {
  id: string;
  user_name: string | null;
  message: string;
  page: string | null;
  created_at: string;
}

// Rueckgabe von admin_overview()
export interface AdminOverview {
  users_total: number;
  users_new_7d: number;
  users_active_7d: number;
  users_banned: number;
  groups_total: number;
  groups_public: number;
  groups_new_7d: number;
  meetups_upcoming: number;
  posts_active: number;
  posts_new_7d: number;
  messages_7d: number;
  rsvps_yes_upcoming: number;
  reports_open: number;
  feedback_total: number;
}

// Rueckgabe von admin_list_users()
export interface AdminUser {
  id: string;
  first_name: string;
  username: string;
  city: string | null;
  email: string;
  created_at: string;
  last_sign_in_at: string | null;
  is_admin: boolean;
  is_banned: boolean;
  groups_count: number;
  posts_count: number;
}

// Rueckgabe von admin_list_groups()
export interface AdminGroup {
  id: string;
  name: string;
  sport: string;
  city: string | null;
  is_public_event: boolean;
  creator_name: string | null;
  creator_username: string | null;
  members_active: number;
  members_waitlist: number;
  max_members: number;
  next_meetup_at: string | null;
  created_at: string;
}
