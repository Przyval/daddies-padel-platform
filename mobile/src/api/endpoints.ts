import { api, unwrap } from './client';
import type {
  ApiEnvelope, AuthResult, UserFull, MembershipStatus, SessionSummary,
  TournamentSummary, StandingRow, LeaderboardRow, NotificationItem, UserPublic,
} from './types';

// axios returns Promise<AxiosResponse<ApiEnvelope<T>>>, which unwrap() accepts
// directly ({ data: ApiEnvelope<T> }). No casts needed.

export const Auth = {
  login: (email: string, password: string) =>
    unwrap<AuthResult>(api.post<ApiEnvelope<AuthResult>>('/auth/login', { email, password })),
  register: (body: { username: string; email: string; phone: string; password: string; referral_code?: string }) =>
    unwrap<AuthResult>(api.post<ApiEnvelope<AuthResult>>('/auth/register', body)),
  me: () => unwrap<UserFull>(api.get<ApiEnvelope<UserFull>>('/me')),
};

export const Membership = {
  status: () => unwrap<MembershipStatus>(api.get<ApiEnvelope<MembershipStatus>>('/membership')),
  upgrade: (referral_code?: string) =>
    unwrap<unknown>(api.post<ApiEnvelope<unknown>>('/membership/upgrade', { referral_code })),
};

export const Sessions = {
  list: (status = 'upcoming') =>
    unwrap<SessionSummary[]>(api.get<ApiEnvelope<SessionSummary[]>>(`/sessions?status=${status}`)),
  detail: (id: number) => unwrap<unknown>(api.get<ApiEnvelope<unknown>>(`/sessions/${id}`)),
  join: (id: number) => unwrap<unknown>(api.post<ApiEnvelope<unknown>>(`/sessions/${id}/join`)),
  history: () => unwrap<unknown>(api.get<ApiEnvelope<unknown>>('/sessions/history')),
};

export const Tournaments = {
  list: (status?: string) =>
    unwrap<TournamentSummary[]>(
      api.get<ApiEnvelope<TournamentSummary[]>>(`/tournaments${status ? `?status=${status}` : ''}`)
    ),
  detail: (id: number) => unwrap<unknown>(api.get<ApiEnvelope<unknown>>(`/tournaments/${id}`)),
  standings: (id: number) =>
    unwrap<StandingRow[]>(api.get<ApiEnvelope<StandingRow[]>>(`/tournaments/${id}/standings`)),
  score: (id: number, matchId: number, points_t1: number, points_t2: number) =>
    unwrap<unknown>(api.post<ApiEnvelope<unknown>>(`/tournaments/${id}/score/${matchId}`, { points_t1, points_t2 })),
  nextRound: (id: number) => unwrap<unknown>(api.post<ApiEnvelope<unknown>>(`/tournaments/${id}/next_round`)),
  complete: (id: number) => unwrap<unknown>(api.post<ApiEnvelope<unknown>>(`/tournaments/${id}/complete`)),
};

export const Community = {
  leaderboard: (tab = 'chips') =>
    unwrap<LeaderboardRow[]>(api.get<ApiEnvelope<LeaderboardRow[]>>(`/leaderboard?tab=${tab}`)),
  members: (q = '') =>
    unwrap<UserPublic[]>(api.get<ApiEnvelope<UserPublic[]>>(`/members${q ? `?q=${encodeURIComponent(q)}` : ''}`)),
  notifications: () =>
    unwrap<{ unread_count: number; notifications: NotificationItem[] }>(
      api.get<ApiEnvelope<{ unread_count: number; notifications: NotificationItem[] }>>('/notifications')
    ),
  markAllRead: () => unwrap<unknown>(api.post<ApiEnvelope<unknown>>('/notifications/read-all')),
};
