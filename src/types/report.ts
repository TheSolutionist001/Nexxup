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
