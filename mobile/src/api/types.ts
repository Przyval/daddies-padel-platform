// Types mirror the Flask /api/v1 response contract.

export type ApiEnvelope<T> =
  | { ok: true; data: T }
  | { ok: false; error: { code: string; message: string } };

export interface UserPublic {
  id: number;
  name: string;
  nickname: string;
  initials: string;
  avatar_url: string;
  membership: string;
  membership_label: string;
  member_tier_label: string;
  kta_tier: string;
}

export interface UserFull extends UserPublic {
  username: string;
  email: string;
  phone: string;
  bio: string;
  role: string;
  kta_number: string;
  membership_paid: boolean;
  membership_amount_paid: number;
  chips_balance: number;
  wallet_balance: number;
  referral_code: string;
  can_unlock_kta: boolean;
  stats: { sessions_played: number; tournaments_played: number; total_games: number; total_points: number };
  streak: { current: number; longest: number; total_weeks: number; at_risk: boolean; tier: string };
}

export interface AuthResult {
  access_token: string;
  refresh_token: string;
  user: UserFull;
}

export interface MembershipStatus {
  membership: string;
  membership_label: string;
  member_tier_label: string;
  kta_number: string;
  kta_tier: string;
  membership_paid: boolean;
  progress: {
    games_played: number;
    games_required: number;
    chips_balance: number;
    chips_required_elite: number;
    games_required_elite: number;
  };
}

export interface SessionSummary {
  id: number;
  title: string;
  date_time: string | null;
  location: string;
  price: number;
  max_players: number;
  status: string;
  event_type: string;
  confirmed_count: number;
  waitlist_count: number;
  is_full: boolean;
  my_status: string | null;
}

export interface TournamentSummary {
  id: number;
  name: string;
  date: string | null;
  status: string;
  format: string;
  format_label: string;
  format_icon: string;
  num_courts: number;
  scoring_mode: string;
  points_per_game: number;
  current_round: number;
  total_rounds: number;
  completed_matches: number;
  participant_count: number;
  created_by: number | null;
}

export interface StandingRow {
  rank: number;
  participant: { id: number; name: string; first_name: string; initials: string };
  points: number;
  wins: number;
  losses: number;
  ties: number;
  matches_played: number;
  games_won: number;
  games_lost: number;
  diff: number;
}

export interface LeaderboardRow {
  rank: number;
  value: number;
  metric: string;
  user: UserPublic;
}

export interface NotificationItem {
  id: number;
  title: string;
  body: string;
  icon: string;
  is_read: boolean;
  link: string;
  created_at: string | null;
}
